# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`matrix` holds Terraform-managed infrastructure for the multi-product ecosystem (currently `commerce-api`, with `financial-tracker-api` planned). Two top-level domains live side by side:

| Path | Purpose |
|------|---------|
| `auth0/` | Auth0 tenant configuration — API resource servers (audiences), per-API scopes, SPA + M2M clients. Provider: `auth0/auth0`. See `auth0/CLAUDE.md`. |
| `aws/` | AWS infrastructure — VPC, RDS, S3, and per-product compute (e.g. ECS Fargate for commerce-api). See `aws/CLAUDE.md`. |

The two domains are operationally independent — separate Terraform Cloud workspaces, no shared state, no resource references across them. The runtime services in their respective product repos are the glue: each one validates JWTs issued by Auth0 and reads/writes the RDS managed under `aws/`.

## Backend & secrets

- Remote backend: **Terraform Cloud**, organization `akhakpouri`. Each top-level module is its own workspace (`auth0`, `learn-terraform-aws`, and any future per-product workspaces); `plan` / `apply` execute remotely. Run `terraform login` once before `init` anywhere.
- Sensitive vars (Auth0 client secrets, DB passwords, future cloud creds) live as workspace variables in TFC or in gitignored `*.tfvars` / `*.auto.tfvars` files. **Never commit any `.tfvars` file.** Never echo secrets into logs, PR descriptions, or terminal output.
- Required: Terraform >= 1.14.0.

## Working in this repo

- Each module has its own `CLAUDE.md` with commands, architecture, and quirks specific to its domain. Read it before touching unfamiliar territory.
- External modules are pinned by `version` at every reference. Maintain that discipline when adding new ones.
- Resource tagging is currently ad-hoc per module — no central tagging convention yet.
- **Cross-repo coupling:** scope names defined in `auth0/` (audiences, scope strings) must match what consuming services expect at runtime. For commerce-api specifically, scope spellings live in `api/internal/auth/scope.go` and are the source of truth on the consumer side — renaming a scope is always a two-repo change. Same kind of coupling will apply to financial-tracker-api when it lands.

## Project notes

`docs/project-notes/` holds the ADRs and historical context shared across all modules. Module-specific decisions reference ADR numbers from there. New ADRs go in that directory regardless of which module they describe.
