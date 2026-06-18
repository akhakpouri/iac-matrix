# Project Facts & Configuration

## Repository organization

| Directory | Provider | Purpose |
|-----------|----------|---------|
| `aws/`    | AWS      | VPC, S3, shared RDS PostgreSQL, per-product compute (ECR + logical DB + ECS/ALB) |
| `auth0/`  | Auth0    | Tenant config: APIs, M2M clients, SPA clients, Universal Login |

See ADR-001 for the per-provider split rationale.

## Terraform Cloud

| Workspace                    | Path                  | Project            | Notes |
|------------------------------|-----------------------|--------------------|-------|
| `platform-shared`            | `aws/`                | `platform-shared`  | Owns the VPC and the single shared RDS instance. Exports endpoint/SG + VPC/subnets via outputs. |
| `commerce`                   | `aws/commerce/`       | `commerce`         | Whole commerce product (api + utils, ADR-006): ECR repos, logical DB, ECS/ALB/IAM/logs. Reads `platform-shared` via `terraform_remote_state`. |
| `auth0`                      | `auth0/`              | (none)             | Auth0 tenant — sits ungrouped under the org. |

Org: `akhakpouri`.

### Sensitive variables (workspace-scoped)

- `rds_password` — master password for the shared RDS instance. Defined once as a TFC **Variable Set** and attached to both `platform-shared` and `commerce` so rotation is a single edit.
- `auth0_client_id`, `auth0_client_secret`, `domain` — set as workspace variables on the `auth0` workspace.

Sensitive values are never committed. Gitignored `*.tfvars` is permitted for local-execution workspaces, but the persistent store is TFC workspace vars / Variable Sets.

## Required versions

| Component                                              | Version    | Pinned in                                                           |
|--------------------------------------------------------|------------|---------------------------------------------------------------------|
| Terraform                                              | `>= 1.14.0`| Root `CLAUDE.md`, `aws/CLAUDE.md`                                   |
| `hashicorp/aws`                                        | unpinned   | `aws/terraform.tf`, `aws/commerce/terraform.tf`                     |
| `cyrilgdn/postgresql`                                  | `~> 1.25`  | `aws/modules/db/terraform.tf`, `aws/commerce/terraform.tf`          |
| `hashicorp/random`                                     | unpinned   | `aws/modules/db/terraform.tf`                                       |
| `terraform-aws-modules/vpc/aws`                        | `6.6.1`    | `aws/main.tf` (root VPC). `aws/modules/rds/main.tf` uses unpinned reference for the nested VPC — to be removed when ADR-004 lands. |
| `terraform-aws-modules/secrets-manager/aws`            | `~> 2.1`   | `aws/modules/db/main.tf`                                            |
| `auth0/auth0`                                          | `>= 1.44.0`| `auth0/terraform.tf`                                                |

## AWS — `platform-shared` workspace (`aws/`)

| Key                          | Value                                         | Source                                    |
|------------------------------|-----------------------------------------------|-------------------------------------------|
| Region                       | `us-east-1`                                   | `var.region` default                      |
| Main VPC name                | `server-vpc`                                  | `aws/main.tf:module "vpc"`                |
| Main VPC CIDR                | `10.0.0.0/16`                                 | `var.vpc_cidr_block` default              |
| Availability zones           | `us-east-1a`, `us-east-1b`, `us-east-1c`      | hardcoded in `aws/main.tf`                |
| Public subnets (default)     | 2, sliced from `10.0.1.0/24`–`10.0.8.0/24`    | `var.public_subnet_cidr_blocks`           |
| Private subnets (default)    | 2, sliced from `10.0.101.0/24`–`10.0.108.0/24`| `var.private_subnet_cidr_blocks`          |
| VPN gateway                  | enabled (default)                             | `var.enable_vpn_gateway`                  |

### Shared RDS instance (current — pre-ADR-004 posture)

Owned by `aws/modules/rds/`, instantiated once as `module "rds"` in `aws/main.tf`.

| Key                       | Value                                           |
|---------------------------|-------------------------------------------------|
| Identifier                | `shared-instance`                               |
| Engine / version          | PostgreSQL `18.4`                               |
| Parameter family          | `postgres18`                                    |
| Instance class            | `db.t3.micro` (hardcoded in module)             |
| Allocated storage         | `5` GB (hardcoded in module)                    |
| Master username           | `postgres` (default)                            |
| Master password           | `var.rds_password` (TFC Variable Set)           |
| Skip final snapshot       | `true` (pending ADR-004 → `false`)              |
| Public accessibility      | `true` (pending ADR-004 → `false`)              |
| Owns its own VPC          | yes — `module.rds_vcp` (pending ADR-004 → drop) |
| RDS VPC CIDR              | `10.0.0.0/16` (overlaps main VPC — trap)        |
| RDS subnets               | `10.0.4.0/24`, `10.0.5.0/24`, `10.0.6.0/24`     |
| Security group ingress    | `0.0.0.0/0:5432` (pending ADR-004 → SG list)    |
| Parameter group           | `shared`, `log_connections = "all"` (PG18 enum) |

> The nested VPC, world-open SG, and `publicly_accessible = true` are all the pre-hardening state ADR-004 will fix. See [ADR-004](decisions.md#adr-004--rds-lives-in-the-shared-vpc-module-takes-networking-primitives-as-inputs).

### Outputs (consumed by product workspaces via `terraform_remote_state`)

| Output                  | Value                            |
|-------------------------|----------------------------------|
| `postgres_address`      | RDS hostname (no port)           |
| `postgres_port`         | RDS port                         |
| `postgres_endpoint`     | `address:port`                   |
| `master_username`       | master user on the instance      |
| `rds_security_group_id` | SG id (for app workspaces to add their task SGs to under ADR-004) |
| `vpc_id`                | shared VPC id (for product ALB/ECS networking) |
| `public_subnet_ids`     | shared VPC public subnet ids (list) |
| `private_subnet_ids`    | shared VPC private subnet ids (list) |

### Shared modules (consumed by product workspaces via `git::` source)

| Module          | Purpose                                                                 |
|-----------------|-------------------------------------------------------------------------|
| `modules/rds`   | The shared RDS server. Only `platform-shared` uses it (local source).    |
| `modules/db`    | Per-app logical database + owner role + AWS Secrets Manager secret. Uses `cyrilgdn/postgresql`. See [ADR-005](decisions.md#adr-005--per-app-db-bootstrap-is-terraform-driven-not-manual-psql). |
| `modules/ecr`   | Per-app ECR repository. Image tag immutability + scan-on-push + AES256.  |
| `modules/s3`    | Generic S3 bucket. Currently unused at the workspace level.              |

## AWS — `commerce` workspace (`aws/commerce/`)

Whole commerce product in one workspace (api + utils, ADR-006). Reads `platform-shared` via `data.terraform_remote_state.platform`.

| Key                       | Value                                                                  |
|---------------------------|------------------------------------------------------------------------|
| Region                    | `us-east-1`                                                            |
| RDS / VPC connection info | Read from `platform-shared` outputs via `terraform_remote_state`       |
| ECR repositories          | `commerce-api-registry`, `commerce-utils-registry` (`module.api_registry` / `module.utils_registry`) |
| Logical database name     | `commerce`                                                             |
| Owner role                | `commerce` (login; password generated by `modules/db`)                  |
| Schemas granted to owner  | `public`, `commerce`                                                   |
| Secret name (app creds)   | `/commerce-api/rds/psql` in AWS Secrets Manager                        |
| ECS cluster               | `commerce-cluster`                                                     |
| API service / task def    | `aws_ecs_service.api` + `aws_ecs_task_definition.api` (Fargate, port 8080, `api_desired_count` default 0) |
| Utils task def            | `aws_ecs_task_definition.utils` (one-shot, no service; `aws ecs run-task` by CI) |
| Load balancer             | `commerce-alb` (internet-facing, public subnets) → `commerce-target-group` (`ip`, :8080, health `/health/status/live`); `:80` listener 301-redirects to `:443` (HTTPS, TLS 1.3, ACM cert) |
| Public URL / domain       | `https://commerce.godevmatrix.me` — ACM cert (DNS-validated) + Route 53 alias A record → ALB, in the hand-managed `godevmatrix.me` zone (`Z041625321OQNKHW5WH2C`) |
| Security groups           | `commerce-alb-sg` (80 + 443 from `0.0.0.0/0`); `commerce-task-sg` (8080 from alb SG only) |
| IAM roles                 | `commerce-task-execution` (ECR pull + logs + Secrets Manager read), `commerce-task` (empty) |
| Log groups                | `/ecs/commerce-api`, `/ecs/commerce-utils` (30-day retention)         |
| Image tagging             | sha-only (no `latest`); CI pushes `${git.sha}`, service `ignore_changes` on task def/count |
| Module source ref         | `?ref=main`                                                            |

### Sensitive variables on this workspace

- `rds_password` — master password (same Variable Set as `platform-shared`).

## Auth0 — root module (`auth0/`)

| Key | Value |
|-----|-------|
| Tenant domain | Supplied via TFC workspace variable `domain` |
| Bootstrap app | "Terraform" — manually created, see ADR-003 |
| Management API scopes (bootstrap) | `read:*` / `create:*` / `update:*` for: `resource_servers`, `clients`, `client_grants`, `branding`, `prompts` |

### Variables (declared in `auth0/variable.tf`, supplied via TFC workspace vars)

- `var.domain` — tenant domain (e.g. `your-tenant.us.auth0.com`)
- `var.client_id` — Management API client ID for the bootstrap app
- `var.client_secret` — Management API client secret for the bootstrap app (sensitive)

### Module shape (target — see ADR-002)

| Module | Wraps | Per-instance | Current state |
|--------|-------|--------------|---------------|
| `modules/api/` | `auth0_resource_server` + `auth0_resource_server_scopes` | One per API | Parameterized — accepts `name`, `identifier`, `scopes` (required) plus `signing_alg`, `token_lifetime`, `allow_offline_access` (defaulted). Used by commerce-api today; ready for #7. |
| `modules/spa-client/` | `auth0_client` (spa) + `auth0_client_credentials` (none) | One per frontend | Not built (#8) |
| `modules/m2m-client/` | `auth0_client` (m2m) + `auth0_client_credentials` + `auth0_client_grant` | One per consumer | Not built (#9) |

### APIs

| API | Status | Audience identifier | Scopes |
|-----|--------|---------------------|--------|
| commerce-api | Applied (#6) — dashboard name `Commerce Api Server` | `commerce-api-server` (bare slug — URI form recommended; Auth0 won't let you change `identifier` in place, so renaming requires recreate + token reissue) | `orders:{read,write,delete}`, `products:{read,write,delete}`, `users:{read,write,delete}` |
| financial-tracker-api | Planned (#7) — blocked on `modules/api/` parameterization | TBD | TBD |

### Frontend SPAs

| App | Status | Notes |
|-----|--------|-------|
| Storefront SPA | Planned (#8) — blocked on first frontend repo | Public client, PKCE |
| Admin SPA | Planned (#8) — blocked on first frontend repo | Public client, PKCE |

### Tenant-level config (applied)

- **Universal Login**: `new` experience, identifier-first
- **Branding**: primary `#0059ff`, page background `#f4f4f4`, placeholder logo from Auth0 marketplace CDN
- Block names: `auth0_branding.default_branding`, `auth0_prompt.default_prompt`

### Root outputs

| Output | Source |
|--------|--------|
| `commerce_api_audience` | `module.commerce_api.audience` |
| `commerce_api_scopes` | `module.commerce_api.scope_names` |
