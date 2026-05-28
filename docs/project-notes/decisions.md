# Architectural Decision Records

## ADR-001 — Top-level split by provider, with separate state per root module

**Date:** 2026-04-28
**Status:** Active

The repository is organized with one top-level directory per cloud / IdP provider, each a self-contained Terraform root module:

```
matrix/
├── aws/      # AWS infrastructure (VPC, RDS, S3, ...)
└── auth0/    # Auth0 tenant configuration
```

Each root has its own state and (when used) its own Terraform Cloud workspace. `aws/` is configured against TFC org `akhakpouri`, workspace `learn-terraform-aws`. `auth0/` will use a sibling workspace (`learn-terraform-auth0`) once the cloud backend is wired in — currently the `auth0/terraform.tf` declares no backend, so state is local during initial development.

### Rationale

- AWS resources and Auth0 resources have **zero overlap** — no shared `data` sources, no cross-provider references, no resources that span the two. Coupling them into one root would couple their apply cycles and blast radii without benefit.
- Different change cadences: AWS infra changes infrequently; Auth0 config (scopes, M2M clients per consumer) churns whenever new services or frontends come online.
- Different credentials: AWS uses standard provider chain (env vars / SSO); Auth0 uses a hand-managed Management API client. Mixing means the union of secrets sits in one workspace.

### Consequences

- No `terraform_remote_state` cross-references. If a future resource genuinely needs to pull a value across (e.g. AWS Secrets Manager storing the M2M client secret), it gets read via the live AWS / Auth0 API, not state-to-state.
- Adding a third provider follows the same pattern: new top-level directory, new TFC workspace.

---

## ADR-002 — Auth0 module structure: api / spa-client / m2m-client

**Date:** 2026-04-28
**Status:** Active

Auth0 resources are organized into three small modules under `auth0/modules/`, each wrapping one Auth0 concept:

| Module | Wraps | Per-instance |
|--------|-------|--------------|
| `api/` | `auth0_resource_server` + `auth0_resource_server_scopes` | One per API (commerce-api, financial-tracker-api) |
| `spa-client/` | `auth0_client` (`spa`) + `auth0_client_credentials` (`none`) | One per frontend |
| `m2m-client/` | `auth0_client` (`non_interactive`) + `auth0_client_credentials` + `auth0_client_grant` | One per service-to-service consumer |

### Rationale

- The three Auth0 app shapes (resource server, public/SPA, M2M) **do not share fields**. SPAs are public clients (no secret, PKCE, scopes requested per-login); M2M clients are private (secret, `client_credentials`, scopes pre-granted via `auth0_client_grant`); resource servers are not applications at all. A single "auth0-app" module would be a giant variant block.
- Three small modules each do one thing → smaller blast radius per module change, smaller variable surface, easier to reason about which inputs matter.
- The `aws/` side modules each wrap **multi-resource bundles** (RDS = VPC + subnet group + SG + parameter group + instance). Auth0 resources are higher-level — `auth0_resource_server` is one resource — so each module here wraps 2–3 tightly-coupled resources rather than a single resource.

### What stays flat (not modularized)

`auth0_branding` and `auth0_prompt` live directly in `auth0/main.tf`. They are **tenant singletons** (one per tenant, no `name` field). Wrapping a singleton in a module is just renaming.

### Consequences

- Adding a new API: one `module "<name>" { source = "./modules/api" ... }` call.
- Adding a new frontend or M2M consumer: same shape, different module source.
- Cross-module coupling lives in root: an M2M client that calls a particular API references `module.<api>.audience` as the `target_audience` input.

---

## ADR-003 — Auth0 bootstrap via hand-managed Terraform Management API client

**Date:** 2026-04-28
**Status:** Active

Terraform authenticates against the Auth0 Management API as a dedicated M2M application named "Terraform" (or equivalent). This application is **created manually in the Auth0 dashboard** and **excluded from Terraform-managed state**. Its `client_id` and `client_secret` feed `var.auth0_client_id` and `var.auth0_client_secret`. All other Auth0 resources — APIs, M2M clients for product services, SPA clients for frontends — are managed by Terraform.

### Rationale

Auth0 has no concept of "tenant-level credentials" — every Management API call must authenticate as some application. That creates a chicken-and-egg: Terraform needs an authenticated identity to create the very applications it manages. Resolved by manually creating one bootstrap application that exists outside the Terraform-managed set.

The bootstrap app is granted the Management API with exactly the scopes needed to manage the resources in this repo (e.g. `read:resource_servers`, `create:resource_servers`, `update:resource_servers`, `read:clients`, `create:clients`, `update:clients`, `read:client_grants`, `create:client_grants`, `update:client_grants`, `read:branding`, `update:branding`, `read:prompts`, `update:prompts`). Tightening or expanding that scope set is a manual dashboard edit.

### Consequences

- The bootstrap app must **never** be managed by Terraform. If `auth0_client.terraform_bootstrap` showed up in this config, the first apply that revoked its grants would break the next plan.
- Credential rotation is manual: rotate in the dashboard, update the workspace variable / `secrets.tfvars`.
- A new environment (e.g. prod tenant) repeats the bootstrap manually before Terraform can manage anything in it.

---

## ADR-004 — RDS lives in the shared VPC; module takes networking primitives as inputs

**Date:** 2026-05-21
**Status:** Accepted (networking implementation pending). Bootstrap mechanism superseded by [ADR-005](#adr-005--per-app-db-bootstrap-is-terraform-driven-not-manual-psql).

`modules/rds/` will be refactored to consume `vpc_id`, `subnet_ids`, and an `allowed_security_group_ids` list rather than provisioning its own VPC, subnets, and a wide-open security group. The shared `aws-shared` workspace owns the VPC; the RDS module becomes just a database (subnet group, SG, parameter group, instance) that plugs into that shared network.

### Rationale

- Today `modules/rds/main.tf` instantiates a second `terraform-aws-modules/vpc/aws` (`module.rds_vcp`) with its own CIDR space. This second VPC has no route to the main VPC where future ECS tasks will run — there is no peering, no transit gateway. The only path runtime traffic can take to RDS today is the public internet, gated by `publicly_accessible = true` and an SG ingress of `0.0.0.0/0:5432`.
- Collapsing RDS into the shared VPC keeps application traffic internal; SG rules become the access control (allow `5432` from each consuming service's task SG, deny everything else).
- The module's `vpc_cidr_block` default (`10.0.0.0/16`) overlaps the main VPC's default — even if peering were added later it wouldn't work without a CIDR change first. Consolidation removes the trap.
- Aligns with the shared-resources pattern (ADR-001 / hub-and-spoke): `aws-shared` owns the network, product workspaces consume it via `terraform_remote_state`.

### Module shape after refactor

```hcl
module "rds" {
  source = "./modules/rds"

  identifier                 = "shared-postgres"
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.private_subnets   # private, not public
  allowed_security_group_ids = []                           # appended per-consumer over time
  master_username            = "postgres"
  db_password                = var.db_password
  # instance_class, allocated_storage, engine_version: defaulted, overridable
}
```

The module no longer owns `module.rds_vcp`, `data.aws_availability_zones`, or the world-open SG ingress.

### Security posture after refactor

- `publicly_accessible = false` by default; instance in private subnets.
- SG ingress empty by default; consumers attach by passing their own SG id into `allowed_security_group_ids`, rendered as `source_security_group_id` ingress rules.
- `skip_final_snapshot = false` by default so accidental destroys leave a recoverable snapshot.
- Master password remains a TFC workspace variable; per-product DB users created via the manual bootstrap documented in `aws/commerce/CLAUDE.md` (which becomes a from-inside-the-VPC operation — `psql` via ECS exec or a temporary bastion — not a "temporarily allow your IP" operation).

### Consequences

- State for `learn-terraform-aws` is currently empty (verified 2026-05-21), so the refactor applies fresh — no in-place migration of an existing RDS instance is needed.
- Any future product reaching RDS goes through the shared VPC; its task SG must be added to `allowed_security_group_ids`. There is no public endpoint to fall back on.
- The RDS bootstrap section in `aws/commerce/CLAUDE.md` must be updated when this lands — the "allow my IP, run psql, revert" pattern stops working.
- Pairs with the same-pass parameterization of hardcoded `aws_db_instance` fields (`identifier`, `instance_class`, `allocated_storage`, `engine_version`, `master_username`). Both changes touch the same module and are tracked together — see issue entry.

## ADR-005 — Per-app DB bootstrap is Terraform-driven, not manual psql

**Date:** 2026-05-28
**Status:** Accepted
**Supersedes:** ADR-004's bootstrap mechanism (the "manual psql from inside the VPC" approach in the Security-posture section). ADR-004's networking refactor remains pending and is unaffected.

Per-app databases, owner roles, schema grants, and the AWS Secrets Manager secret containing the app's credentials are provisioned by a shared Terraform module (`aws/modules/db`) using `cyrilgdn/postgresql`. Each app's TFC workspace consumes the module via `git::` source and configures the postgres provider at the root, reading `postgres_address` / `postgres_port` / `master_username` from `platform-shared` via `terraform_remote_state`.

### Rationale

- **Declarative + reviewable.** A per-app DB/role/grant exists in version control rather than in a runbook step. Adding `financial-tracker` is `module "database" {…}` + a workspace, not a checklist of psql commands.
- **No per-app runbook drift.** ADR-004's manual bootstrap relies on each app's CLAUDE.md staying in sync with what was actually typed. The Terraform module makes the bootstrap one source of truth.
- **App secret provisioned in the same pass.** `terraform-aws-modules/secrets-manager/aws` (~> 2.1) creates the per-app secret atomically with the role, so the password the module generates never has to leave Terraform.
- **DRY.** The module lives once at `aws/modules/db`; every app workspace pulls it by git source pinned to a ref.

### Module shape

```hcl
# In each app workspace (e.g. aws/commerce/api/)
data "terraform_remote_state" "rds" { backend = "remote"; config = { … workspaces = { name = "platform-shared" } } }

provider "postgresql" {
  host      = data.terraform_remote_state.rds.outputs.postgres_address
  port      = data.terraform_remote_state.rds.outputs.postgres_port
  username  = data.terraform_remote_state.rds.outputs.master_username
  password  = var.rds_password           # workspace var, master password
  database  = "postgres"
  scheme    = "awspostgres"
  superuser = false
}

module "database" {
  source        = "git::https://github.com/akhakpouri/iac-matrix.git//aws/modules/db?ref=main"
  db_name       = "commerce"
  db_owner      = "commerce"
  db_schemas    = ["public", "commerce"]
  secret_name   = "/commerce-api/rds/psql"
  rds_host      = data.terraform_remote_state.rds.outputs.postgres_address
  database_port = data.terraform_remote_state.rds.outputs.postgres_port
}
```

### Consequences

- **App workspaces need network reach to RDS at plan time** — the postgresql provider connects on every plan and apply, not just apply. Works today because the instance is `publicly_accessible = true` (the pre-ADR-004 posture). When ADR-004 lands and the instance becomes private, each app workspace's run must reach RDS over the private network: either switch that workspace to Local execution, use a TFC agent inside the VPC, or tunnel. Pick one and document it on the same PR as the ADR-004 implementation.
- **Master password lives in every app workspace** as a TFC variable. The decentralized design accepts this trade for self-contained app workspaces. Rotation requires updating each app workspace's `rds_password` plus the master on the instance.
- **Module changes require commit + push** (git source). For an unstable module, pin the ref to a tag (`?ref=v0.1.0`) per app so upgrades are explicit.
- **ADR-004's "manual psql bootstrap" bullet** (Security-posture section, "per-product DB users created via the manual bootstrap…") is superseded. The networking and SG-restriction parts of ADR-004 are untouched and still pending.
- **`aws/commerce/CLAUDE.md`'s "RDS bootstrap" section** needs to be rewritten to point at this module instead of describing the four `CREATE DATABASE`/`CREATE USER`/`GRANT`/`CREATE SCHEMA` statements.
