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
| Project      | `Learn Terrafom`       |
| `aws/` workspace   | `learn-terraform-aws`   |
| `auth0/` workspace | `learn-terraform-auth0` (planned — not yet wired into `auth0/terraform.tf`) |

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
| Tenant domain | (set per environment via `var.auth0_domain`) |
| Bootstrap app | "Terraform" — manually created, see ADR-003 |
| Management API scopes (bootstrap) | `read:*` / `create:*` / `update:*` for: `resource_servers`, `clients`, `client_grants`, `branding`, `prompts` |

### Sensitive variables (no defaults — must be supplied)

- `var.auth0_client_id` — Management API client ID for the bootstrap app
- `var.auth0_client_secret` — Management API client secret for the bootstrap app

### Module shape (planned — see ADR-002)

| Module | Wraps | Per-instance |
|--------|-------|--------------|
| `modules/api/` | `auth0_resource_server` + `auth0_resource_server_scopes` | One per API |
| `modules/spa-client/` | `auth0_client` (spa) + `auth0_client_credentials` (none) | One per frontend |
| `modules/m2m-client/` | `auth0_client` (m2m) + `auth0_client_credentials` + `auth0_client_grant` | One per consumer |

### Planned APIs

| API | Audience identifier (placeholder) | Notes |
|-----|------------------------------------|-------|
| commerce-api | `https://api.commerce-api.example` (TBD) | Issue #6 — initial scopes pending route classification |
| financial-tracker-api | TBD | Issue #6 follow-up |

### Planned frontend SPAs

| App | Notes |
|-----|-------|
| Storefront SPA | Public client, PKCE |
| Admin SPA | Public client, PKCE |
