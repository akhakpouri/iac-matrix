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
