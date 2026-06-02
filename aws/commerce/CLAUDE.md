# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in `aws/commerce/`.

Sibling-scoped to `aws/`. The parent `aws/CLAUDE.md` covers shared AWS infrastructure; this file is the commerce-api deployment layer. See also `aws/commerce/README.md` for the orientation layer.

## Status

**In progress** (as of 2026-05-29). The `aws/commerce/api/` workspace has its ECR repo, logical DB on the shared instance, owner role + grants, and the app-credentials Secrets Manager secret all wired and applied. ECS / ALB / IAM still to land. The Go service in the `commerce-api` repo has the auth0 integration and scope enforcement done.

## Workspaces

| Path     | TFC workspace   | Status                                                                          |
|----------|-----------------|---------------------------------------------------------------------------------|
| `api/`   | `commerce-api`  | In progress — ECR + logical DB + secret landed; ECS / ALB / IAM still pending. |
| `utils/` | TBD             | Planned — one-shot utility ECS tasks (migrations, backfills).                  |

## Scope

Single-environment (`prod`) deployment in `us-east-1`. Solo developer — no staging environment yet; staging will be added as a parallel workspace when the project grows.

Goal: one ALB-fronted ECS Fargate service running the API container, with database migrations executed as a separate one-shot ECS task. RDS is the shared instance from `platform-shared`; the per-app DB + role + secret are managed in *this* workspace via `aws/modules/db` (ADR-005).

## Architecture

### Landed in `api/`

| Concern                 | Resource                                                                          | Source                                                                 |
|-------------------------|-----------------------------------------------------------------------------------|------------------------------------------------------------------------|
| Image registry          | `aws_ecr_repository.commerce-api-registry` (immutable tags, scan-on-push, AES256) | `git::...//aws/modules/ecr?ref=main`                                   |
| Logical database        | `postgresql_database.commerce` on the shared RDS instance                         | `git::...//aws/modules/db?ref=main`                                    |
| Owner role              | `postgresql_role.commerce` (LOGIN, password from `random_password`)               | same                                                                   |
| Schema grants           | `postgresql_grant` on `public` + `commerce` schemas                               | same                                                                   |
| App credentials secret  | `/commerce-api/rds/psql` in AWS Secrets Manager                                   | same (`module.secret_manager` → terraform-aws-modules/secrets-manager) |

### Planned (not yet implemented)

| Concern         | Resource |
|-----------------|----------|
| Cluster         | `aws_ecs_cluster` |
| API service     | `aws_ecs_service` + `aws_ecs_task_definition` — long-running, attached to ALB target group. Container port `8080`. Healthcheck `GET /health/status/live`. |
| Migrations      | `aws_ecs_task_definition` for the `utils` image — one-shot, triggered by CI before each API deploy. Idempotent via GORM AutoMigrate. |
| Load balancer   | `aws_lb` (internet-facing) in default VPC's public subnets + `aws_lb_target_group` + `aws_lb_listener`. HTTP:80 initially; ACM cert + HTTPS:443 once a final domain is picked. |
| Security groups | `alb` (inbound 80/443 from `0.0.0.0/0`); `task` (inbound 8080 from `alb` SG only); RDS SG patched to accept 5432 from `task` SG (when ADR-004 lands). |
| IAM             | Task execution role (ECR pull + Secrets Manager read + CloudWatch Logs write); task role (empty for now). |
| Logs            | `aws_cloudwatch_log_group` per task family; `awslogs` driver in the task def. |

## Inputs the Go service expects

Source of truth: `commerce-api/api/configs/dev.env.example` and `commerce-api/docs/project-notes/facts.md`. Snapshot at time of writing:

| Var                                                                | Source on AWS |
|--------------------------------------------------------------------|---------------|
| `ENV`                                                              | Plain env (`production`) |
| `SERVER_ADDRESS`                                                   | Plain env (`:8080`) |
| `CORS_ALLOWED_ORIGIN`                                              | Plain env — depends on frontend domain |
| `DB_HOST`                                                          | Plain env — `platform-shared`'s `postgres_address` output, read via `terraform_remote_state` and rendered into the task def |
| `DB_PORT` / `DB_NAME` / `DB_USER` / `DB_SCHEMA` / `DB_SSLMODE`     | Plain env |
| `DB_PASSWORD`                                                      | AWS Secrets Manager (`/commerce-api/rds/psql`) — injected as env at task start via the task definition's `secrets` block |
| `AUTH_DOMAIN`                                                      | Plain env (dev tenant: `dev-y7vm6nwrj5uw2n2e.us.auth0.com`) |
| `AUTH_AUDIENCE`                                                    | Plain env (`urn:commerce-api`) |

`dev.env.example` in the commerce-api repo is the canonical list — diff against it when adding or removing config keys.

## Dependencies

- **`platform-shared` workspace** (`aws/`) — supplies `postgres_address`, `postgres_port`, `master_username`, `rds_security_group_id` via `terraform_remote_state`. Must apply before `commerce-api`.
- **`shared-rds-master` TFC Variable Set** — supplies `rds_password` (master) to both `platform-shared` and this workspace. Used here to authenticate the `cyrilgdn/postgresql` provider when creating the logical DB + role.
- **`auth0/` (sibling top-level module)** — supplies the `urn:commerce-api` audience and scope definitions consumed at runtime by the API. No direct Terraform reference; values must agree across repos. Renaming a scope is always a multi-repo change (here, plus `api/internal/auth/scope.go` in the commerce-api Go repo).

## RDS bootstrap

Per [ADR-005](../../docs/project-notes/decisions.md#adr-005--per-app-db-bootstrap-is-terraform-driven-not-manual-psql), the per-app database, owner role, schema grants, and Secrets Manager secret are all provisioned in this workspace by `module "database"` (`aws/modules/db`). The postgresql provider authenticates as the RDS **master** (from the `shared-rds-master` Variable Set) and creates:

- A `commerce` database, owned by a `commerce` role.
- The `commerce` role with `LOGIN` and a password generated by `random_password`.
- `ALL PRIVILEGES` for the role on the `public` + `commerce` schemas.
- A Secrets Manager secret at `/commerce-api/rds/psql` containing the app's connection bundle (host / port / username / password / database).

Subsequent schema changes are AutoMigrate-driven via the `utils` ECS task once it's wired. The earlier "allow your IP, run psql from your laptop, revert" recipe is gone — superseded by ADR-005.

## CI/CD shape (lives in commerce-api repo, not here)

GitHub Actions workflow in the `commerce-api` repo, triggered on push to `main`:

1. `go test ./...`
2. Build `api` and `utils` Docker images
3. Auth to ECR via OIDC (no long-lived AWS keys in GitHub)
4. Push both images with `latest` + `${{ github.sha }}` tags
5. `aws ecs run-task` for `utils` — wait, fail the workflow if migration exits non-zero
6. `aws ecs update-service --force-new-deployment` for the API service

The IAM role this OIDC trust assumes is provisioned here (planned). Document its ARN as an output so the Go repo can pin it.

## Domain

`api.khakpouri.me` is the placeholder DNS target — a CNAME to the ALB's DNS name. The final commerce-api domain hasn't been chosen yet. Swapping later is a CNAME flip + an ACM cert; no infrastructure shape change.

## Out of scope (lives elsewhere)

- Application code, business logic, migrations content → `commerce-api` repo
- JWT signing, Auth0 client provisioning, scope definitions → `auth0/` module
- CI workflow YAML → `.github/workflows/` in the commerce-api repo
- M2M client used for local testing → `auth0/` module's `m2m-client` instances
