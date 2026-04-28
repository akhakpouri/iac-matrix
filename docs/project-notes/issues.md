# Work Log

Per-GitHub-issue work tracking. New entries at the top.

---

## Issue #6 — Auth0 tenant configuration (Terraform module for managed authorization)

**Date:** 2026-04-28
**Status:** In progress
**Branch:** `feature/issue-6`

Provision and manage the Auth0 tenant for the commerce-api ecosystem (commerce-api Go service, upcoming Python financial-tracker API, storefront + admin SPAs). Single source of truth for authorization infrastructure. Driver: ADR-017 in `commerce-api/docs/project-notes/decisions.md` (revised 2026-04-27) — auth delegated to Auth0; this repo owns the tenant configuration.

### Decisions made on this branch

- ADR-001 — Top-level split by provider, separate state per root module
- ADR-002 — Auth0 module structure: `api` / `spa-client` / `m2m-client`
- ADR-003 — Bootstrap via hand-managed Terraform Management API client (manually created in dashboard, excluded from Terraform state)

### Scope

- [x] Add `auth0/auth0` Terraform provider (`>= 1.44.0`)
- [x] Bootstrap "Terraform" Management API client created manually in dashboard with required scopes
- [x] `secrets.tfvars` populated locally (gitignored)
- [ ] `modules/api/` — wraps `auth0_resource_server` + `auth0_resource_server_scopes`
- [ ] `modules/spa-client/` — wraps `auth0_client` (spa) + `auth0_client_credentials` (none)
- [ ] `modules/m2m-client/` — wraps `auth0_client` (m2m) + `auth0_client_credentials` + `auth0_client_grant`
- [ ] Root `main.tf` — composes modules + `auth0_branding` + `auth0_prompt`
- [ ] Resource server: commerce-api (audience identifier, RS256, scopes)
- [ ] Resource server: financial-tracker-api (audience identifier, RS256, scopes)
- [ ] SPA client: storefront
- [ ] SPA client: admin
- [ ] M2M client(s) for service-to-service callers (consumers TBD)
- [ ] Universal Login defaults (`auth0_branding`, `auth0_prompt`)
- [ ] Decide whether to wire Terraform Cloud backend for `auth0/` (workspace `learn-terraform-auth0`) or keep state local for now
- [ ] `outputs.tf` — audience identifiers, M2M client IDs/secrets (sensitive), domain
- [ ] Document bootstrap in `auth0/README.md` (or fold into `auth0/CLAUDE.md`)

### Out of scope (per issue)

- Frontend Auth0 SPA SDK integration (lives in frontend repos)
- JWT validation middleware (lives in each consuming service)
- Domain user database (Auth0 owns identity; consumers map `sub` → their own user row)
- Auth0 Action(s) for custom claims — deferred until concrete need

### Open questions

- Final scope vocabulary for commerce-api — pending route-classification work in commerce-api repo
- Final scope vocabulary for financial-tracker-api — service not yet built
- Real audience URIs (currently `https://api.commerce-api.example` placeholder)
- Cloud backend vs local state for `auth0/` (see ADR-001)
- Env strategy: single workspace for now; prod tenant requires its own bootstrap and workspace when it exists
