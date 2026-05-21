# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in `aws/commerce-api/`.

Sibling-scoped to `aws/`. The parent `aws/CLAUDE.md` covers shared AWS infrastructure; this file is the commerce-api deployment layer.

## Status

**Planned, not yet written** (as of 2026-05-20). The Go service in the `commerce-api` repo has the auth0 integration and scope enforcement landed (#113 + #114 merged) and the JWT→user-row resolver done on `feature/issue-115`. This module stands the service up on AWS.

## Scope

Single-environment (`prod`) deployment in `us-east-1`. Solo developer — no staging environment yet; staging will be added as a parallel directory or workspace when the project grows.

Goal: one ALB-fronted ECS Fargate service running the API container, with database migrations executed as a separate one-shot ECS task. RDS already exists in `aws/modules/rds/` and is reused — no per-product DB.

## Planned architecture

| Concern | Resource |
|---------|----------|
| Image registry | `aws_ecr_repository` — one repo (two tags: `api`, `utils`) or two repos. Currently the Docker images live on Docker Hub public; ECR is part of this work. |
| Cluster | `aws_ecs_cluster` |
| API service | `aws_ecs_service` + `aws_ecs_task_definition` — long-running, attached to ALB target group. Container port `8080`. Healthcheck `GET /health/status/live`. |
| Migrations | `aws_ecs_task_definition` for the `utils` image — one-shot, triggered by CI before each API deploy. Idempotent via GORM AutoMigrate. |
| Load balancer | `aws_lb` (internet-facing) in default VPC's public subnets + `aws_lb_target_group` + `aws_lb_listener`. HTTP:80 initially; ACM cert + HTTPS:443 added once a final domain is picked (see "Domain" below). |
| Security groups | `alb` (inbound 80/443 from `0.0.0.0/0`); `task` (inbound 8080 from `alb` SG only); RDS SG (in `aws/modules/rds`) patched to accept 5432 from `task` SG. |
| IAM | Task execution role (ECR pull + Secrets Manager read + CloudWatch Logs write); task role (empty for now — the running container makes no AWS API calls). |
| Secrets | `aws_secretsmanager_secret.db_password` — the only true secret. Auth0 domain/audience and DB connection params live as plain env vars in the task definition. |
| Logs | `aws_cloudwatch_log_group` per task family; `awslogs` driver in the task def. |

## Inputs the Go service expects

Source of truth: `commerce-api/api/configs/dev.env.example` and `commerce-api/docs/project-notes/facts.md`. Snapshot at time of writing:

| Var | Source on AWS |
|-----|---------------|
| `ENV` | Plain env (`production`) |
| `SERVER_ADDRESS` | Plain env (`:8080`) |
| `CORS_ALLOWED_ORIGIN` | Plain env — depends on frontend domain |
| `DB_HOST` | Plain env — RDS endpoint output from `aws/modules/rds` |
| `DB_PORT` / `DB_NAME` / `DB_USER` / `DB_SCHEMA` / `DB_SSLMODE` | Plain env |
| `DB_PASSWORD` | Secrets Manager — injected as env at task start |
| `AUTH_DOMAIN` | Plain env (dev tenant: `dev-y7vm6nwrj5uw2n2e.us.auth0.com`) |
| `AUTH_AUDIENCE` | Plain env (`urn:commerce-api`) |

`dev.env.example` in the commerce-api repo is the canonical list — diff against it when adding or removing config keys.

## Dependencies on other modules

- **`aws/modules/rds`** — supplies the RDS endpoint, port, master creds, and the RDS SG id. Read via `terraform_remote_state` against the `learn-terraform-aws` workspace, or by moving RDS into this module's composition. Default plan: remote-state reference, keeping RDS shared.
- **`auth0/` (sibling top-level module)** — supplies the `urn:commerce-api` audience and scope definitions consumed at runtime by the API. No direct Terraform reference; values must agree across repos. Renaming a scope is always a multi-repo change (here, plus `api/internal/auth/scope.go` in the commerce-api Go repo).

## RDS bootstrap (one-time, before first deploy)

The RDS instance from `aws/modules/rds` is blank — no `commerce` database, no `commerce` user, no `commerce` schema. Per `commerce-api/docs/project-notes/facts.md`:

```sql
CREATE DATABASE commerce;
CREATE USER commerce WITH ENCRYPTED PASSWORD '...';
GRANT ALL PRIVILEGES ON DATABASE commerce TO commerce;
\c commerce
CREATE SCHEMA commerce AUTHORIZATION commerce;
```

These need the **RDS master user**, not the app's `commerce` user — only the master has `CREATE DATABASE` privilege. One-shot approach for solo prod: temporarily allow your IP in the RDS SG, run the four statements via local `psql`, revert the SG. Document the date and the password rotation in the operational log. After this, all subsequent schema changes are AutoMigrate-driven via the `utils` ECS task.

## CI/CD shape (lives in commerce-api repo, not here)

GitHub Actions workflow in the `commerce-api` repo, triggered on push to `main`:

1. `go test ./...`
2. Build `api` and `utils` Docker images
3. Auth to ECR via OIDC (no long-lived AWS keys in GitHub)
4. Push both images with `latest` + `${{ github.sha }}` tags
5. `aws ecs run-task` for `utils` — wait, fail the workflow if migration exits non-zero
6. `aws ecs update-service --force-new-deployment` for the API service

The IAM role this OIDC trust assumes is provisioned here. Document its ARN as an output so the Go repo can pin it.

## Domain

`api.khakpouri.me` is the placeholder DNS target — a CNAME to the ALB's DNS name. The final commerce-api domain hasn't been chosen yet (godevmatrix.me is being retired). Swapping later is a CNAME flip + an ACM cert; no infrastructure shape change.

## Out of scope (lives elsewhere)

- Application code, business logic, migrations content → `commerce-api` repo
- JWT signing, Auth0 client provisioning, scope definitions → `auth0/` module
- CI workflow YAML → `.github/workflows/` in the commerce-api repo
- M2M client used for local testing → `auth0/` module's `m2m-client` instances
