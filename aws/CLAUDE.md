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

Terraform Cloud workspace: `learn-terraform-aws` under org `akhakpouri`. `plan` / `apply` execute remotely; sensitive vars set in the workspace UI or via gitignored `terraform.tfvars`.

Required: Terraform >= 1.14.0.

## Region

All resources in this module target **`us-east-1`**. Submodules under `aws/` assume the same region unless they declare otherwise explicitly.

## Architecture

The root module in this directory composes shared/foundational AWS resources. Product-specific compute (ECS services, Lambdas, etc.) lives in sibling subdirectories under `aws/<product>/` — currently just `aws/commerce-api/` (in progress).

Root-module pieces:

1. **`module.vpc`** — external `terraform-aws-modules/vpc/aws` (v6.6.0). The "main" application VPC. Public/private subnets sliced from `public_subnet_cidr_blocks` / `private_subnet_cidr_blocks` by the `*_subnet_count` vars.
2. **`module.s3-instance`** → `./modules/s3-bucket`. Bucket name suffixed with the AWS account ID (via `aws_caller_identity`) for global uniqueness. Currently used to host static assets for `khakpouri.me` (brochure site) — unrelated to the API products.
3. **`module.hello`** — external `joatmon08/hello/random` (v6.0.0). Consumes `var.secret_key` + a `random_pet` id. Not infrastructure — demo / learning module.
4. **`module.rds`** → `./modules/rds`. PostgreSQL 17 RDS instance. Shared across product submodules; commerce-api consumes it as its application database.

### Quirk: the RDS module owns its own VPC

`modules/rds/main.tf` instantiates a **second** `terraform-aws-modules/vpc/aws` (`module.rds_vcp`) with its own CIDR, subnets, subnet group, and security group. It is **not** attached to the root `module.vpc`. The RDS instance is currently `publicly_accessible = true` with `5432` open to `0.0.0.0/0` — the only path runtime traffic can take is the public internet.

> **Planned consolidation — see [ADR-004](../docs/project-notes/decisions.md#adr-004--rds-lives-in-the-shared-vpc-module-takes-networking-primitives-as-inputs) and the RDS hardening issue in `docs/project-notes/issues.md`.** The module will be refactored to take `vpc_id` + `subnet_ids` from the shared workspace, default `publicly_accessible = false`, and replace the world-open SG ingress with an `allowed_security_group_ids` list. This text describes current state; remove this quirk section once the refactor lands.

### `modules/ec2-instance/` is defined but unused

`modules/ec2-instance/` exists with its own variables and an `aws_instance.app_server` resource, but **no `module "ec2-instance"` block in `main.tf` references it**. The module also reaches for `module.vpc.default_security_group_id` and `module.vpc.public_subnets[0]` from inside its own scope — those are not passed in, so wiring it up requires either passing VPC outputs as variables or restructuring. Don't assume EC2 instances are part of the live plan.

### Variable wiring quirks

- Several root-level vars (`enable_vpn_gateway`, `instance_count`, `resource_tags`, the EC2-related vars) are declared in `variables.tf` but unused — scaffolding for not-yet-wired modules. The README documents them as if active; trust the code.
- `var.db_password` and `var.secret_key` are required sensitive vars with no defaults — `plan` / `apply` fails without them.
- The RDS module declares its own `vpc_cidr_block` default (`10.0.0.0/16`) which **overlaps** the root VPC's default. The README mentions `10.1.0.0/16` for RDS, but the code default is `10.0.0.0/16`; set explicitly when the two VPCs need to coexist or peer. (Goes away with ADR-004 — RDS will live in the shared VPC.)

## Conventions

- Resource tagging is ad-hoc per module (some use `var.resource_tags`, some hardcode `Name`/`Owner`). No central tagging module yet.
- External modules are pinned by `version`; preserve that discipline when adding new ones.
- `terraform.tfvars` is gitignored — never commit it, and never echo `secret_key` / `db_password` (or any future ECR/ECS creds) into logs or PRs.

## Adding a product subdirectory

When standing up infrastructure for a new product (commerce-api, financial-tracker-api, etc.):
- Create `aws/<product>/` as a sibling to `modules/`.
- Give it its own `CLAUDE.md` describing the product's deployment shape.
- Decide whether the product needs its own TFC workspace or composes into this root via a `module "<product>"` block. For non-trivial products with their own lifecycle, prefer a separate workspace — keeps `plan` blast radius scoped.
- Reuse `module.rds` (via remote-state data source or by reaching into outputs) rather than provisioning a per-product DB unless there's a real isolation requirement.
