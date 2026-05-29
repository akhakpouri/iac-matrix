# matrix

Terraform-managed infrastructure for a multi-product ecosystem. The first product is `commerce-api`; `financial-tracker-api` is planned. Two top-level domains live side by side and run as independent Terraform Cloud workspaces — no shared state, no resource references across them.

| Path     | Purpose                                                              | Docs |
|----------|----------------------------------------------------------------------|------|
| `aws/`   | VPC, RDS, S3, and per-product compute (e.g. ECS Fargate per service) | [`aws/CLAUDE.md`](aws/CLAUDE.md) |
| `auth0/` | Auth0 tenant config: API resource servers, scopes, SPA + M2M clients | [`auth0/CLAUDE.md`](auth0/CLAUDE.md) |

## Architecture inside `aws/`

A hub-and-spoke shape: one shared workspace owns the network and the database server; product workspaces own everything specific to their service.

```
                  platform-shared (aws/)
                  ├── module.vpc           ── one VPC for everything
                  └── module.rds           ── one shared PostgreSQL instance
                          │ outputs
                          ▼
        terraform_remote_state ── consumed by every product workspace
                          │
   ┌──────────────────────┼──────────────────────────┐
commerce-api (aws/commerce/api/)    financial-tracker-api  (future)
   ├── module.container_registry     same shape
   └── module.database  ── creates a logical DB + role + secret
                          on the shared instance
```

Shared modules live at `aws/modules/{rds,db,ecr,s3}` and are consumed by product workspaces via `git::` sources, so adding a new app is `module "<x>" { source = ".../aws/modules/<x>?ref=..." }` plus a new TFC workspace, not a fork of the module code.

## Per-app database bootstrap

Per-app databases, owner roles, schema grants, and the AWS Secrets Manager secret containing the app's credentials are created in the **app's** workspace using `cyrilgdn/postgresql`, connecting as the RDS master user. See [ADR-005](docs/project-notes/decisions.md#adr-005--per-app-db-bootstrap-is-terraform-driven-not-manual-psql) for the full design.

## Adding a new product

1. Create `aws/<product>/<service>/` with its own `terraform.tf` pointing at a new TFC workspace under the org.
2. Add `data "terraform_remote_state" "rds"` reading `platform-shared` outputs.
3. Configure `provider "postgresql"` at the root using those outputs + a `master_password` workspace variable.
4. Consume `aws/modules/{ecr,db,s3}` via `git::` source pinned to a ref.
5. Document the workspace in the product's `README.md` and add it to the workspace table in `docs/project-notes/facts.md`.

For Auth0 resource servers consumed by the new product, see `auth0/CLAUDE.md`.

## Prerequisites

- Terraform `>= 1.14.0`
- Terraform Cloud access (org `akhakpouri`); run `terraform login` once
- AWS credentials configured (for runs that touch AWS) — either via TFC workspace variables for remote runs, or via local env / `~/.aws/credentials` for local execution mode

## Conventions

- **Secrets** live as TFC workspace variables (or Variable Sets across workspaces that share a secret) — never committed. `*.tfvars` is gitignored.
- **External modules** pinned at every reference: `version` for registry sources, `?ref=` for `git::` sources.
- **ADRs** for cross-module architectural decisions in [`docs/project-notes/decisions.md`](docs/project-notes/decisions.md). Module-specific notes live in each module's `CLAUDE.md`.
- **Scope spellings** defined in `auth0/` must match runtime expectations in consuming services — renaming a scope is always a two-repo change.

## Documentation index

- [Architecture decisions (ADRs)](docs/project-notes/decisions.md)
- [Open and in-flight issues](docs/project-notes/issues.md)
- [Bug log](docs/project-notes/bugs.md)
- [Project facts (versions, workspaces, defaults)](docs/project-notes/facts.md)
- AWS-specific guidance: [`aws/CLAUDE.md`](aws/CLAUDE.md)
- Per-product guidance: [`aws/commerce/README.md`](aws/commerce/README.md), [`aws/commerce/CLAUDE.md`](aws/commerce/CLAUDE.md)
- Auth0-specific guidance: [`auth0/CLAUDE.md`](auth0/CLAUDE.md)
