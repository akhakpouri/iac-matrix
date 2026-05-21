# Work Log

Per-GitHub-issue work tracking. New entries at the top.

---

## Issue #TBD — RDS hardening: parameterize + consolidate into shared VPC + tighten network

**Date:** 2026-05-21
**Status:** Open — not yet filed on GitHub
**Branch:** —

Two coordinated changes to `aws/modules/rds/`, both touching the same module:

**Parameterization (in flight — user driving):**
- Lift hardcoded `aws_db_instance` fields out of `main.tf` into variables: `identifier`, `instance_class`, `allocated_storage`, `engine_version`, `master_username`.
- Remove tutorial-isms: parameter group `name = "education"`, SG `name = "education_rds"`, master username `"edu"`.
- Add `outputs.tf` exposing `endpoint`, `port`, `address`, `master_username`, `security_group_id` so product workspaces can consume via `terraform_remote_state`.

**Hardening (follow-up — see ADR-004):**
- Drop the embedded `module.rds_vcp`. Module takes `vpc_id` + `subnet_ids` as inputs from the shared `aws-shared` workspace.
- Default `publicly_accessible = false`; place instance in private subnets.
- Replace `cidr_blocks = ["0.0.0.0/0"]` SG ingress with an `allowed_security_group_ids` list. Consumers attach by passing their task SG.
- Default `skip_final_snapshot = false`.

**Why bundled:** both changes rewrite the same resource block; doing them in separate passes means the parameterization PR adds variables that the hardening PR immediately reshapes (network inputs change, security defaults change). Easier to land together.

**Downstream doc updates required when this lands:**
- `aws/commerce/CLAUDE.md` — RDS bootstrap section (the "allow my IP, run psql, revert" recipe stops working once the instance is in a private VPC; replace with ECS-exec / bastion recipe).
- `docs/project-notes/facts.md` — RDS facts table (CIDR row goes away; public accessibility flips; username changes).

**Blocked on:** Nothing. ADR-004 accepted 2026-05-21.

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
