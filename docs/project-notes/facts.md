# Project Facts & Configuration

## Repository organization

| Directory | Provider | Purpose |
|-----------|----------|---------|
| `aws/`    | AWS      | VPC, EC2 (defined-but-unused), S3, RDS PostgreSQL |
| `auth0/`  | Auth0    | Tenant config: APIs, M2M clients, SPA clients, Universal Login |

See ADR-001 for the per-provider split rationale.

## Terraform Cloud

| Key          | Value                  |
|--------------|------------------------|
| Organization | `akhakpouri`           |
| `aws/` workspace   | `learn-terraform-aws` (project: `Learn Terrafom`) |
| `auth0/` workspace | `auth0` (no project — sits ungrouped under the org) |

Sensitive variables (`auth0_client_id`, `auth0_client_secret`, and `domain` for the auth0 workspace; `secret_key`, `db_password` for the aws workspace) are stored as workspace variables in TFC, not in committed `.tfvars` files.

## Required versions

| Component | Version  |
|-----------|----------|
| Terraform | `>= 1.14.0` |
| `hashicorp/aws`    | unpinned (`aws/terraform.tf`) |
| `hashicorp/random` | unpinned |
| `hashicorp/time`   | unpinned |
| `auth0/auth0`      | `>= 1.44.0` |

## AWS — root module (`aws/`)

| Key | Value | Source |
|-----|-------|--------|
| Region | `us-east-1` | `var.region` default |
| Main VPC CIDR | `10.0.0.0/16` | `var.vpc_cidr_block` default |
| Availability zones | `us-east-1a`, `us-east-1b`, `us-east-1c` | hardcoded in `aws/main.tf` |
| Public subnets (default count) | 2, sliced from `10.0.1.0/24`–`10.0.8.0/24` | `var.public_subnet_cidr_blocks` |
| Private subnets (default count) | 2, sliced from `10.0.101.0/24`–`10.0.108.0/24` | `var.private_subnet_cidr_blocks` |

### RDS (separate VPC, owned by `modules/rds`)

| Key | Value |
|-----|-------|
| Engine | PostgreSQL 17.4 |
| Instance class | `db.t3.micro` |
| Allocated storage | 5 GB |
| Username | `edu` |
| Default RDS VPC CIDR | `10.0.0.0/16` (overlaps main VPC default — see open issue) |
| RDS public subnets | `10.0.4.0/24`, `10.0.5.0/24`, `10.0.6.0/24` |
| Public accessibility | `true` |
| Security group ingress | `0.0.0.0/0:5432` |

> RDS provisions its own VPC (`module.rds_vcp` inside `aws/modules/rds/main.tf`) — it is **not** attached to the root `module.vpc`.

### Sensitive variables (no defaults — must be supplied)

- `var.secret_key` — used by the `joatmon08/hello/random` module
- `var.db_password` — RDS master password

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
