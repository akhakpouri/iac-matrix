# Work Log

Per-GitHub-issue work tracking. New entries at the top.

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
- [ ] `auth0/modules/api/` — wraps `auth0_resource_server` + `auth0_resource_server_scopes`
- [ ] Resource server: commerce-api (audience identifier, RS256, scopes)
- [ ] Universal Login defaults (`auth0_branding`, `auth0_prompt`)
- [ ] Root `main.tf` — composes `module "commerce_api"` + branding/prompt
- [ ] `outputs.tf` — commerce-api audience + scope names
- [ ] Document bootstrap + plan/apply workflow (`auth0/CLAUDE.md` already drafted)

### Open questions

- Final scope vocabulary for commerce-api — pending route-classification work in commerce-api repo
- Real audience URI (currently `https://api.commerce-api.example` placeholder)
- Env strategy: single workspace for now; prod tenant requires its own bootstrap and workspace when it exists

### Out of scope

- Frontend Auth0 SPA SDK integration (lives in frontend repos)
- JWT validation middleware (lives in each consuming service)
- Domain user database (Auth0 owns identity; consumers map `sub` → their own user row)
- Auth0 Action(s) for custom claims — deferred until concrete need
