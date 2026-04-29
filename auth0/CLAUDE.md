# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Sibling-scoped to `auth0/`. The root `CLAUDE.md` covers the broader repo; this file is the Auth0-specific layer.

## Bootstrap (read first)

The Auth0 tenant itself is created manually in the dashboard — Terraform does not provision tenants. Same goes for the **Terraform Management API client** that this configuration authenticates as: it is a hand-managed M2M application in the dashboard (named "Terraform"), authorized against the Management API with the `read:*` / `create:*` / `update:*` scopes for every resource type managed here. Its credentials feed `var.auth0_client_id` and `var.auth0_client_secret`. All other applications and resource servers are managed by Terraform.

The chicken-and-egg only exists at bootstrap. If the bootstrap client's credentials rotate or its scopes are insufficient, those edits happen in the dashboard — never inline this client into the Terraform-managed set. See ADR-003 in `docs/project-notes/decisions.md`.

## Commands

```sh
cd auth0
terraform init
terraform plan
terraform apply
```

Variables (`domain`, `client_id`, `client_secret`) are stored as **workspace variables in TFC** under workspace `auth0` (org `akhakpouri`); `client_id` and `client_secret` are marked sensitive. Both local and remote runs read from the workspace — there are no committed `.tfvars` files. `terraform login` is a one-time setup so the CLI can authenticate to TFC; after that, `plan` / `apply` execute remotely on TFC's runners and stream output back to your terminal.

If you need to add a fourth variable, declare it in `auth0/variable.tf` first, then set its value in the TFC workspace UI before the next plan — TFC will fail the plan if a non-defaulted variable is unset.

## Module structure

Three modules under `modules/`, each wrapping one Auth0 concept:

- **`modules/api/`** — `auth0_resource_server` + `auth0_resource_server_scopes`. One call per API (commerce-api, financial-tracker-api).
- **`modules/spa-client/`** — `auth0_client` (`app_type = "spa"`) + `auth0_client_credentials` (`authentication_method = "none"`). One call per frontend. Public client — no `client_secret`.
- **`modules/m2m-client/`** — `auth0_client` (`app_type = "non_interactive"`, `grant_types = ["client_credentials"]`) + `auth0_client_credentials` + `auth0_client_grant`. One call per service-to-service consumer. Private client — `client_secret` is exposed as a sensitive output.

Three modules instead of one because the Auth0 app types (resource server / SPA / M2M) don't share field shapes — combining would force a variant-typed mega-module. See ADR-002.

`auth0_branding` and `auth0_prompt` stay in root `main.tf` — they're tenant singletons (one per tenant, no name field), so wrapping them in a module is just renaming.

## Sensitive outputs

M2M `client_secret` values come out of `auth0_client_credentials.<name>.client_secret`. If propagated via root `outputs.tf`, mark `sensitive = true`. With Terraform Cloud, sensitive outputs are masked in the UI but readable via API by anyone with workspace read access — treat them as workspace-secret, not export-safe.

## Out of scope (lives elsewhere)

- JWT validation middleware → consuming services (commerce-api, financial-tracker-api)
- Auth0 SPA SDK wiring → frontend repos
- Domain user database → Auth0 owns identity; consumers map the `sub` claim to their own user rows
- Auth0 Actions for custom claims → deferred per issue #6 until concrete need
