# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

All Terraform commands run from the `aws/` directory.

```sh
cd aws
terraform init        # initialize backend & download providers/modules
terraform fmt         # format .tf files
terraform validate    # validate configuration
terraform plan
terraform apply
terraform destroy
```

This project uses a **Terraform Cloud** remote backend (org `akhakpouri`, workspace `learn-terraform-aws`). `plan`/`apply` execute remotely, so variables marked `sensitive` must be set in the workspace UI or via `terraform.tfvars` (gitignored). `terraform login` is required before `init`.

Required: Terraform >= 1.14.0.

## Architecture

The root module lives in `aws/` and composes four pieces:

1. **`module.vpc`** — external `terraform-aws-modules/vpc/aws` (v6.6.0). The "main" application VPC, with public/private subnets sliced from `public_subnet_cidr_blocks` / `private_subnet_cidr_blocks` by the `*_subnet_count` vars.
2. **`module.s3-instance`** → `./modules/s3-bucket` — bucket name is suffixed with the AWS account ID (via `aws_caller_identity`) to keep it globally unique.
3. **`module.hello`** — external `joatmon08/hello/random` (v6.0.0). Consumes `var.secret_key` and a `random_pet` id; not infrastructure, just a demo module.
4. **`module.rds`** → `./modules/rds` — PostgreSQL 17 RDS instance.

### Important: the RDS module owns its own VPC

`modules/rds/main.tf` instantiates a **second** `terraform-aws-modules/vpc/aws` (`module.rds_vcp`) with its own CIDR, subnets, subnet group, and security group. It is **not** attached to the root `module.vpc`. When changing networking, be aware that the RDS network is independent — the root VPC's subnets/SGs are not visible to the DB. The RDS SG currently allows 5432 from `0.0.0.0/0` and the instance is `publicly_accessible = true`; preserve or tighten intentionally.

### `modules/ec2-instance` is defined but unused

`aws/modules/ec2-instance/` exists with its own variables and an `aws_instance.app_server` resource, but **no `module "ec2-instance"` block in `aws/main.tf` currently references it**. The module also references `module.vpc.default_security_group_id` and `module.vpc.public_subnets[0]` from inside its own scope — those are not passed in, so wiring it up requires either passing VPC outputs as variables or restructuring. Don't assume EC2 instances are part of the live plan.

### Variable wiring quirks

- Several root-level vars (`enable_vpn_gateway`, `instance_count`, `resource_tags`, the EC2-related vars) are declared in `aws/variables.tf` but not consumed anywhere — they're scaffolding for not-yet-wired modules. The README documents them as if they were active; trust the code.
- `var.db_password` and `var.secret_key` are required sensitive vars with no defaults — `plan`/`apply` fails without them.
- The RDS module declares its own `vpc_cidr_block` default (`10.0.0.0/16`), which **overlaps** the root VPC's default. The README mentions `10.1.0.0/16` for RDS, but the code default is `10.0.0.0/16`; set explicitly when the two VPCs need to coexist or peer.

## Conventions

- Resource tagging is ad-hoc per module (some use `var.resource_tags`, some hardcode `Name`/`Owner`). There is no central tagging module.
- External modules are pinned by `version`; keep that discipline when adding new ones.
- `terraform.tfvars` is gitignored (per `.gitignore`) — never commit it, and never echo `secret_key` / `db_password` into logs or PRs.
