# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in `aws/`.

Sibling-scoped to `auth0/`. The root `CLAUDE.md` covers the broader repo; this file is the AWS-specific layer.

## Commands

All commands run from this directory (`matrix/aws/`):

```sh
terraform init        # initialize backend & download providers/modules
terraform fmt
terraform validate
terraform plan
terraform apply
terraform destroy
```

Terraform Cloud workspace: **`platform-shared`** under org `akhakpouri` (project `platform-shared`). `plan` / `apply` execute remotely; sensitive vars set as workspace variables in TFC or — where the same value is consumed by multiple workspaces — as a TFC **Variable Set** (e.g. `rds_password` via `shared-rds-master`).

Required: Terraform >= 1.14.0.

## Region

All resources in this module target **`us-east-1`**. Subdirectories under `aws/` assume the same region unless they declare otherwise explicitly.

## Architecture

The root module here owns the **shared** AWS resources — the main VPC and the single shared PostgreSQL RDS instance. Product-specific compute (ECS services, Lambdas, ECR repos, per-app DBs) lives in sibling subdirectories under `aws/<product>/<service>/` — currently `aws/commerce/api/` (in progress).

Root-module pieces:

1. **`module.vpc`** — external `terraform-aws-modules/vpc/aws` (v6.6.1). The main application VPC. Public/private subnets sliced from `public_subnet_cidr_blocks` / `private_subnet_cidr_blocks` by the `*_subnet_count` vars.
2. **`module.rds`** → `./modules/rds`. PostgreSQL 18.4 instance. **One** shared instance for the whole platform; per-app databases are provisioned by each app workspace (see ADR-005).

### Outputs (consumed by product workspaces via `terraform_remote_state`)

`aws/output.tf` exports:

- `postgres_address`, `postgres_port`, `postgres_endpoint` — connection info
- `master_username` — for app workspaces configuring the `cyrilgdn/postgresql` provider
- `rds_security_group_id` — for app workspaces to add their task SGs to once ADR-004 lands

### Shared modules

| Module          | Used by                              | Purpose                                                                 |
|-----------------|--------------------------------------|-------------------------------------------------------------------------|
| `modules/rds`   | `platform-shared` (local source)     | The shared RDS instance: nested VPC + subnets + SG + parameter group + instance. |
| `modules/db`    | App workspaces via `git::` source    | Per-app logical database + owner role + Secrets Manager secret. Uses `cyrilgdn/postgresql`. See ADR-005. |
| `modules/ecr`   | App workspaces via `git::` source    | Per-app ECR repository — immutable tags, scan-on-push, AES256.          |
| `modules/s3`    | Currently unused at workspace level  | Generic S3 bucket module — available if a workspace needs a bucket.     |

### Quirk: the RDS module owns its own VPC (pending ADR-004)

`modules/rds/main.tf` instantiates a **second** `terraform-aws-modules/vpc/aws` (`module.rds_vcp`) with its own CIDR, subnets, subnet group, and security group. It is **not** attached to the root `module.vpc`. The RDS instance is currently `publicly_accessible = true` with `5432` open to `0.0.0.0/0` — the only path traffic can take is the public internet.

> **Planned consolidation — see [ADR-004](../docs/project-notes/decisions.md#adr-004--rds-lives-in-the-shared-vpc-module-takes-networking-primitives-as-inputs).** The module will be refactored to take `vpc_id` + `subnet_ids` from this workspace, default `publicly_accessible = false`, and replace the world-open SG ingress with an `allowed_security_group_ids` list. This text describes current state; remove this section once the refactor lands.
>
> **Knock-on:** app workspaces (commerce-api today, future products) configure `cyrilgdn/postgresql` to connect to RDS at plan time. When the instance goes private, every such workspace needs an execution-mode change or a TFC agent inside the VPC. Plan that on the same PR.

### Variable wiring quirks

- The RDS module declares a `vpc_cidr_block` default (`10.0.0.0/16`) which **overlaps** the root VPC's default. Pass `vpc_cidr_block` explicitly on `module "rds"` if the two VPCs ever need to coexist or peer. (Goes away with ADR-004 — RDS will live in the shared VPC.)
- `var.rds_password` is the master password. It's set via the `shared-rds-master` TFC Variable Set attached to both `platform-shared` and `commerce-api`, so rotation is a single edit. Back the value up in a password manager — **TFC sensitive variables are write-only**.

## Conventions

- **External modules pinned at every reference** — `version` for registry sources, `?ref=` for `git::` sources. Preserve this when adding new ones.
- **`terraform.tfvars` is gitignored** — never commit it, never echo `rds_password` (or any ECR/ECS/Auth0 creds) into logs or PRs.
- Resource tagging is ad-hoc per module. No central tagging module yet.

## Adding a product subdirectory

When standing up infrastructure for a new product (e.g. `financial-tracker-api`):

1. Create `aws/<product>/<service>/` with its own `terraform.tf` pointing at a new TFC workspace.
2. **Authorize the new workspace to read `platform-shared`'s state** — in TFC, open `platform-shared` → Settings → General → Remote state sharing → add the new workspace. Without this, `terraform_remote_state` lookups from the new workspace fail with `Error retrieving state: forbidden`.
3. Add `data "terraform_remote_state" "rds"` reading `platform-shared` outputs.
4. Configure `provider "postgresql"` at the workspace root from those outputs + the `rds_password` workspace variable (attach the `shared-rds-master` Variable Set so master creds are shared).
5. Consume the shared modules via `git::` source pinned to a ref:
   - `aws/modules/ecr` — per-app repo
   - `aws/modules/db` — per-app logical database + owner role + Secrets Manager secret (ADR-005)
   - `aws/modules/s3` — bucket if the app needs one
6. Give the directory its own `CLAUDE.md` describing the product's deployment shape; create a product-level `README.md` if there are multiple workspaces under one product.
7. Document the new workspace in `docs/project-notes/facts.md`.

See `aws/commerce/CLAUDE.md` for a worked example.
