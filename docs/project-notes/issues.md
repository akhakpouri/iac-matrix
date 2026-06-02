# Work Log

Per-GitHub-issue work tracking. New entries at the top.

---

## Issue #14 — Docs refresh for the post-issue-13 architecture

**Date:** 2026-05-29
**Status:** In progress
**Branch:** `feature/issue-14`

Bring all READMEs and project-notes into line with the shape that landed in issue-13. The code moved; the docs hadn't.

**Scope:**

- [x] Rewrite root `README.md` — old version listed modules and vars that no longer exist (EC2, `secret_key`), pointed at the wrong TFC workspace (`learn-terraform-aws` → `platform-shared`), and had no mention of `auth0/`, `commerce-api`, the shared-instance + per-app-DB pattern, or the new module layout.
- [x] Create `aws/commerce/README.md` — orientation layer for the commerce product directory: workspaces table, wiring diagram, variables needed locally vs from remote_state, how to add another commerce workspace.
- [x] Update `docs/project-notes/facts.md` — TFC workspace name fix, drop EC2 row, add `commerce-api` workspace section, refresh RDS table for PG18 + new identifiers, add shared-modules table, refresh required-versions table.
- [x] Update this file (issues.md) — close Issue #13, supersede Issue #TBD's bootstrap scope with ADR-005 reference, add this entry.
- [x] Update `docs/project-notes/bugs.md` — first BUG entry for the PG18 `log_connections` boolean→enum break.

**Initially deferred but completed in-scope:**

- [x] `aws/CLAUDE.md` rewritten — dropped `module.s3-instance` / `module.hello` / `modules/ec2-instance` references, fixed the workspace name to `platform-shared`, added the shared-modules table, refreshed the "adding a product subdirectory" recipe for the `git::` + remote_state pattern.
- [x] `aws/commerce/CLAUDE.md` rewritten — status updated to "in progress", path fixed (`aws/commerce/` not `aws/commerce-api/`), workspaces table added, "Landed" vs "Planned" split, RDS bootstrap section replaced with ADR-005-aligned narrative, dependency on the `shared-rds-master` Variable Set documented.

---

## Issue #13 — Shared RDS instance + per-app logical DB via decentralized bootstrap

**Date:** 2026-05-28
**Status:** Done — pending PR merge to `main`
**Branch:** `feature/issue-13`

Rebuild the AWS module layout around a shared RDS instance with per-app logical databases provisioned by each app's own workspace. Outcome: adding `financial-tracker-api` later is a new workspace + a few module calls, not a new RDS instance and not copy-pasted module code.

### Decisions made on this branch

- **ADR-005** — Per-app DB bootstrap is Terraform-driven (`cyrilgdn/postgresql` module + `terraform_remote_state`), superseding ADR-004's "manual psql from inside the VPC" plan. ADR-004's networking refactor remains pending.

### Architectural shape (after)

- `platform-shared` (`aws/`) owns one shared RDS instance and one VPC. Outputs `postgres_address` / `postgres_port` / `master_username` / `rds_security_group_id` for consumers.
- App workspaces (first: `commerce-api` at `aws/commerce/api/`) own their ECR + logical DB + owner role + AWS Secrets Manager secret. They read RDS connection info from `platform-shared` via `terraform_remote_state` and authenticate as the RDS master to create their objects.
- Shared modules at `aws/modules/{rds,db,ecr,s3}`, consumed by product workspaces via `git::` source pinned to a ref.

### Concrete changes

- Renamed `aws/modules/db` → `aws/modules/rds` (the instance module). `db` is now the logical-database module (`postgresql_database` + `postgresql_role` + `postgresql_grant` + `module.secret_manager`).
- Hoisted `aws/commerce/api/modules/{ecr,db}` up to `aws/modules/{ecr,db}` so they're shareable, and switched `commerce/api` to consume them via `git::` source.
- Moved `provider "postgresql"` configuration out of the child module into the `commerce/api` root, where it's configured from `data.terraform_remote_state.rds` outputs + `var.rds_password`.
- `aws/output.tf` now re-exports `master_username` and `rds_security_group_id` in addition to the existing `postgres_*` outputs.
- Deleted `aws/modules/ec2/` (defined-but-unused; its internal `module.vpc.*` references didn't resolve).
- Removed unused root vars `secret_key` and `resource_tags`.
- Fixed broken `aws_db_instance.rds_instance["postgres"]` indexing in `aws/modules/rds/outputs.tf` (legacy of an earlier `for_each` shape).
- Module `cyrilgdn/postgresql ~> 1.25` and `terraform-aws-modules/secrets-manager/aws ~> 2.1` pinned.

### Operational implications

- `rds_password` is now a TFC **Variable Set** attached to both `platform-shared` (creates the instance with this master) and `commerce-api` (authenticates as master to provision its DB). Rotation is one edit.
- The postgresql provider connects on every plan/apply, so app workspaces need network reach to RDS. Works today because the instance is `publicly_accessible = true`. When ADR-004 lands and the instance becomes private, app workspaces' execution mode (or a TFC agent) will need to change — flagged on the ADR-004 entry below.

### Bugs surfaced and fixed on this branch

- **BUG-001** — `log_connections` is an enum (not boolean) in PG18. See `bugs.md`.

---

## Issue #TBD — RDS hardening: parameterize + consolidate into shared VPC + tighten network

**Date:** 2026-05-21
**Status:** Partially complete — parameterization landed in #13, network hardening still pending.
**Branch:** —

Two coordinated changes to `aws/modules/rds/`, both touching the same module:

**Parameterization — DONE in #13:**
- ✅ Hardcoded `aws_db_instance` fields lifted to variables where they were tutorial-style names (`identifier` → `var.rds_identifier`, `engine`/`engine_version` → vars, `master_username` → `var.rds_username` with `"postgres"` default). `instance_class` and `allocated_storage` still hardcoded — defer until a real tier decision.
- ✅ Tutorial-isms removed: parameter group `name = "shared"`, SG `name = "shared_rds"`, master username default `"postgres"`.
- ✅ `outputs.tf` exposes `endpoint`, `port`, `address`, `master_username`, `security_group_id` consumed via `terraform_remote_state`.

**Bootstrap mechanism — SUPERSEDED by [ADR-005](decisions.md#adr-005--per-app-db-bootstrap-is-terraform-driven-not-manual-psql):**
- The "manual psql from inside the VPC" bullet in ADR-004's Security-posture section no longer applies. Per-app users/databases now provisioned by `aws/modules/db` (cyrilgdn/postgresql).

**Network hardening — STILL PENDING (ADR-004):**
- Drop the embedded `module.rds_vcp`. Module takes `vpc_id` + `subnet_ids` as inputs from the shared `aws-shared` workspace.
- Default `publicly_accessible = false`; place instance in private subnets.
- Replace `cidr_blocks = ["0.0.0.0/0"]` SG ingress with an `allowed_security_group_ids` list. Consumers attach by passing their task SG.
- Default `skip_final_snapshot = false`.

**Downstream impact when network hardening lands:**

- App workspaces using `cyrilgdn/postgresql` lose network reach to RDS from TFC remote runners (private endpoint). Each affected workspace needs an execution-mode change or an in-VPC TFC agent. Picked-when documented on the same PR.
- `aws/commerce/CLAUDE.md` — RDS bootstrap section already obsolete per ADR-005; the network change just confirms the manual-psql recipe is gone.
- `docs/project-notes/facts.md` — RDS facts table (CIDR row goes away; public accessibility flips).

**Blocked on:** Nothing — ADR-004 accepted 2026-05-21; ready when prioritized.

---

## Issue #9 — Auth0: first M2M client (service-to-service)

**Date:** 2026-04-29
**Status:** Open — blocked
**Branch:** —

Build `auth0/modules/m2m-client/` and instantiate it for the first concrete cross-service caller. Split from #6 — no concrete consumer yet, scope vocabulary depends on the real caller.

**Blocked on:** First concrete service-to-service caller identified.

---

## Issue #8 — Auth0: SPA clients for storefront + admin

**Date:** 2026-04-29
**Status:** Open — blocked
**Branch:** —

Build `auth0/modules/spa-client/` and instantiate for storefront + admin frontends. Split from #6 — frontends don't exist yet; callback URLs / origins need real apps.

**Blocked on:** First frontend repo initialized.

---

## Issue #7 — Auth0: financial-tracker-api resource server

**Date:** 2026-04-29
**Status:** Open — blocked
**Branch:** —

Second instantiation of `auth0/modules/api/` for the financial-tracker API. Split from #6 — keeps #6 focused on commerce-api as the first concrete consumer; financial-tracker plugs in once the service is concrete enough to lock in scopes.

**Blocked on:** #6 (the `modules/api/` module must exist first), financial-tracker-api service implementation (route surface needed before scope vocabulary is final).

---

## Issue #6 — Auth0 tenant configuration (commerce-api + tenant-level setup)

**Date:** 2026-04-28
**Status:** In progress
**Branch:** `feature/issue-6`

Provision and manage the Auth0 tenant for the commerce-api ecosystem. Single source of truth for authorization infrastructure. Driver: ADR-017 in `commerce-api/docs/project-notes/decisions.md` (revised 2026-04-27) — auth delegated to Auth0; this repo owns the tenant configuration.

**Descoped 2026-04-29:** SPA clients (#8), M2M clients (#9), and the financial-tracker resource server (#7) split into follow-ups so this PR ships behind a concrete consumer (commerce-api) rather than ahead of hypothetical ones.

### Decisions made on this branch

- ADR-001 — Top-level split by provider, separate state per root module
- ADR-002 — Auth0 module structure: `api` / `spa-client` / `m2m-client`
- ADR-003 — Bootstrap via hand-managed Terraform Management API client (manually created in dashboard, excluded from Terraform state)

### Scope (trimmed to commerce-api + tenant-level)

- [x] Add `auth0/auth0` Terraform provider (`>= 1.44.0`)
- [x] Bootstrap "Terraform" Management API client created manually in dashboard with required scopes
- [x] TFC backend wired (`auth0/terraform.tf`, workspace `auth0` under org `akhakpouri`)
- [x] Sensitive variables (`domain`, `client_id`, `client_secret`) configured as TFC workspace variables
- [x] `auth0/modules/api/` exists with `auth0_resource_server` + `auth0_resource_server_scopes` (hardcoded — see structural issues below)
- [x] Resource server: commerce-api applied (audience `commerce-api-server`, RS256, 9 scopes across orders/products/users × read/write/delete)
- [x] Universal Login defaults applied (currently inside `modules/api/commerce.tf` — see structural issues)
- [x] Root `main.tf` composes `module "commerce_api"`
- [x] `outputs.tf` at root (`commerce_api_audience`, `commerce_api_scopes`) and at module level (`audience`, `name`, `scope_names`)
- [x] Bootstrap + workflow documented in `auth0/CLAUDE.md` (refreshed for TFC workflow 2026-04-29)

### Structural cleanup (resolved on this branch)

1. ✅ `auth0_branding` + `auth0_prompt` moved from `modules/api/commerce.tf` to root (`auth0/main.tf`), renamed to `default_branding` / `default_prompt` — they're tenant singletons.
2. ✅ `modules/api/` parameterized — accepts `name`, `identifier`, `scopes` (required) plus `signing_alg`, `token_lifetime`, `allow_offline_access` (defaulted). Resource blocks renamed from commerce-specific to generic (`resource_server`, `resource_server_scopes`). Ready for #7.
3. ✅ `token_lifetime` corrected from `84600` to `86400`.
4. ⏸️ Deferred: `identifier = "commerce-api-server"` is still a bare slug. Will be replaced with a URI once a real domain is purchased — see Open questions. No consumers yet, so recreate-and-reissue at that point is low cost.

### Pending before close

- Open PR against `main` with body referencing `Closes #6`
- Merge
- #6 closes on merge

### Open questions

- Final scope vocabulary for commerce-api — current 9 scopes (orders/products/users × read/write/delete) are a reasonable first pass but still pending route-classification work in commerce-api repo
- Real audience URI — current `commerce-api-server` slug is placeholder; replace with URI form (`https://commerce-api.<domain>/`) once a domain is purchased. Recreate-and-reissue at that point.
- Env strategy: single workspace for now; prod tenant requires its own bootstrap and workspace when it exists

### Out of scope

- Frontend Auth0 SPA SDK integration (lives in frontend repos)
- JWT validation middleware (lives in each consuming service)
- Domain user database (Auth0 owns identity; consumers map `sub` → their own user row)
- Auth0 Action(s) for custom claims — deferred until concrete need
