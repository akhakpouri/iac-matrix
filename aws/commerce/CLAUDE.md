# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in `aws/commerce/`.

Sibling-scoped to `aws/`. The parent `aws/CLAUDE.md` covers shared AWS infrastructure; this file is the commerce deployment layer. See also `aws/commerce/README.md` for the orientation layer.

## Status

**Live** (as of 2026-06-18). Applied and serving at **`https://commerce.godevmatrix.me`** — image pushed by CI, the API service is running, and the ALB terminates TLS (HTTP→HTTPS redirect). The full workspace is applied: both ECR repos, the logical DB + role + secret, the ECS cluster, the API service + task def, the one-shot `utils` task def, the ALB + target group + HTTP/HTTPS listeners, the ACM cert + Route 53 alias record, the two security groups, the IAM roles (incl. the `commerce-ci` OIDC role), and the CloudWatch log groups. The Go service in the `commerce-api` repo has the auth0 integration and scope enforcement done.

## Workspace

The whole commerce product deploys from a single TFC workspace, **`commerce`** (org `akhakpouri`, project `commerce`), working directory `aws/commerce/`. `api` and `utils` are concerns within it, not separate workspaces — see [ADR-006](../../docs/project-notes/decisions.md#adr-006--one-commerce-workspace-for-the-whole-product-utils-is-not-its-own-workspace).

| Component   | Status | Notes |
|-------------|--------|-------|
| API service | Live   | Running ECS Fargate service behind the ALB at `https://commerce.godevmatrix.me`; image deployed by CI. |
| `utils`     | Live   | One-shot migration task def + `commerce-utils-registry` ECR. No service — invoked via `aws ecs run-task` by CI. |

## Scope

Single-environment (`prod`) deployment in `us-east-1`. Solo developer — no staging environment yet; staging will be added as a parallel workspace (a `commerce-staging`) when the project grows.

Goal: one ALB-fronted ECS Fargate service running the API container, with database migrations executed as a separate one-shot ECS task. RDS is the shared instance from `platform-shared`; the per-app DB + role + secret are managed in *this* workspace via `aws/modules/db` (ADR-005).

## Architecture

### Landed (all `terraform validate`-clean; file noted in parentheses)

| Concern          | Resource |
|------------------|----------|
| Image registries | `module.api_registry` + `module.utils_registry` → `commerce-api-registry` / `commerce-utils-registry` (immutable tags, scan-on-push, AES256, lifecycle policy). `git::...//aws/modules/ecr?ref=main`. (`registry.tf`) |
| Logical database | `postgresql_database.commerce` + `postgresql_role.commerce` + `postgresql_grant` on `public`/`commerce` + `/commerce-api/rds/psql` secret. `git::...//aws/modules/db?ref=main`, ADR-005. (`database.tf`) |
| Cluster          | `aws_ecs_cluster.commerce_cluster`. (`ecs-cluster.tf`) |
| API service      | `aws_ecs_service.api` + `aws_ecs_task_definition.api` — Fargate/awsvpc, port `8080`, public subnets + `assign_public_ip`, attached to the ALB target group. `ignore_changes = [task_definition, desired_count]` (CI owns deploys). (`ecs-api.tf`) |
| Migrations       | `aws_ecs_task_definition.utils` — one-shot, **no service**; `aws ecs run-task` by CI. Idempotent via GORM AutoMigrate. (`ecs-utils.tf`) |
| Load balancer    | `aws_lb.commerce_alb` (internet-facing, public subnets) + `aws_lb_target_group.commerce_api` (`target_type = "ip"`, `:8080`, health `GET /health/status/live`) + `aws_lb_listener.http` (`:80`, **301-redirects to HTTPS**) + `aws_lb_listener.https` (`:443`, TLS 1.3, forwards to the target group). (`security-groups.tf`) |
| Security groups  | `aws_security_group.alb` (inbound 80 + 443 from `0.0.0.0/0`); `aws_security_group.task` (inbound 8080 from the `alb` SG only). (`security-groups.tf`) |
| Domain + TLS     | `aws_acm_certificate.commerce` (DNS-validated) for `commerce.godevmatrix.me` + validation records + `aws_route53_record.api` (alias A → ALB) in the hand-managed `godevmatrix.me` zone. (`dns-tls.tf`) |
| IAM              | `aws_iam_role.task_execution` (managed `AmazonECSTaskExecutionRolePolicy` + inline `secretsmanager:GetSecretValue` on the DB secret) + `aws_iam_role.task` (empty). (`iam.tf`) |
| Relay local credential (Phase 1, interim) | `aws_iam_user.relay_local` + inline `sns:Publish` policy scoped to the domain-events topic + `aws_iam_access_key.relay_local` — least-privilege identity for relay's local walking-skeleton runs, in place of the account's broad `sqs-manager`/`sns-manager` groups. Superseded by an ECS task role once relay is containerized (Phase 2); delete then. (`iam-relay.tf`) |
| Logs             | `aws_cloudwatch_log_group` `/ecs/commerce-api` + `/ecs/commerce-utils`, 30-day retention; `awslogs` driver in both task defs. (`logs.tf`) |

### Still pending

- **First image push + bump `api_desired_count`** above 0. Until an image exists in `commerce-api-registry` the service has nothing to run.
- **RDS SG ingress from the `task` SG.** Today RDS is still public, so the task reaches it over the internet; the SG-scoped path lands with ADR-004.
- **CI OIDC role** for GitHub Actions (deferred). `task_execution_role_arn` is already exported for its future `iam:PassRole`.
- **Relay containerization (Phase 2)** — replace `iam-relay.tf`'s interim IAM user with an ECS task role (same pattern as `aws_iam_role.task`), reusing `local.relay_publish_policy` verbatim; delete the Phase 1 user/key/outputs once the task role lands.

## Inputs the Go service expects

These are now rendered into `aws_ecs_task_definition.api` (`ecs-api.tf`) — plain values as `environment`, `DB_PASSWORD` via the `secrets` block. Source of truth: `commerce-api/api/configs/dev.env.example` and `commerce-api/docs/project-notes/facts.md`. Snapshot at time of writing:

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

`dev.env.example` in the commerce-api repo is the canonical list — diff against it when adding or removing config keys. `DB_SCHEMA = "commerce"`, `DB_SSLMODE = "require"`, and `CORS_ALLOWED_ORIGIN = "*"` are current placeholders set in `ecs-api.tf` — confirm them against `dev.env.example`.

Workspace-local variables (`variables.tf`): `region`, `rds_password` (Variable Set), `image_tag` (bootstrap tag, default `latest`; real deploys are sha-tagged by CI), `cors_allowed_origin` (default `*`), `api_desired_count` (default `0` until the first image is pushed).

## Dependencies

- **`platform-shared` workspace** (`aws/`) — supplies `postgres_address`, `postgres_port`, `master_username`, `rds_security_group_id` via `terraform_remote_state`. Must apply before `commerce`.
- **`shared-rds-master` TFC Variable Set** — supplies `rds_password` (master) to both `platform-shared` and this workspace. Used here to authenticate the `cyrilgdn/postgresql` provider when creating the logical DB + role.
- **`auth0/` (sibling top-level module)** — supplies the `urn:commerce-api` audience and scope definitions consumed at runtime by the API. No direct Terraform reference; values must agree across repos. Renaming a scope is always a multi-repo change (here, plus `api/internal/auth/scope.go` in the commerce-api Go repo).

## RDS bootstrap

Per [ADR-005](../../docs/project-notes/decisions.md#adr-005--per-app-db-bootstrap-is-terraform-driven-not-manual-psql), the per-app database, owner role, schema grants, and Secrets Manager secret are all provisioned in this workspace by `module "database"` (`aws/modules/db`). The postgresql provider authenticates as the RDS **master** (from the `shared-rds-master` Variable Set) and creates:

- A `commerce` database, owned by a `commerce` role.
- The `commerce` role with `LOGIN` and a password generated by `random_password`.
- `ALL PRIVILEGES` for the role on the `public` + `commerce` schemas.
- A Secrets Manager secret at `/commerce-api/rds/psql` containing the app's connection bundle (host / port / username / password / database).

Subsequent schema changes are AutoMigrate-driven via the `utils` ECS task (`aws_ecs_task_definition.utils`, run by CI). The earlier "allow your IP, run psql from your laptop, revert" recipe is gone — superseded by ADR-005.

## CI/CD shape (lives in commerce-api repo, not here)

GitHub Actions workflow in the `commerce-api` repo, triggered on push to `main`:

1. `go test ./...`
2. Build `api` and `utils` Docker images
3. Auth to ECR via OIDC (no long-lived AWS keys in GitHub)
4. Push both images tagged with `${{ github.sha }}` — **sha-only, no moving `latest`** (per the ecr lifecycle policy / ADR-006). The repos are `IMMUTABLE`, so a sha tag is pushed exactly once.
5. Register a new task-def revision pointing at that sha and `aws ecs run-task` for `utils` — wait, fail the workflow if migration exits non-zero
6. Update the API service to the new revision (`aws ecs update-service`). The service's `ignore_changes = [task_definition, desired_count]` means Terraform won't revert this on its next apply.

The CI OIDC role this trust assumes is still **planned** (deferred). The task **execution** role is built and its ARN is exported as `task_execution_role_arn` — the OIDC role will need `iam:PassRole` on it.

## Domain

The API is served at **`https://commerce.godevmatrix.me`** (output `api_url`). An `aws_route53_record` alias A record points the hostname at the ALB, and an ACM cert (DNS-validated) terminates TLS on the `:443` listener; `:80` 301-redirects to HTTPS. The `godevmatrix.me` hosted zone (`Z041625321OQNKHW5WH2C`) is managed outside this workspace — Terraform only reads it and writes the api record + cert-validation records into it. Changing the hostname is a `var.api_hostname` edit (+ a new cert validation). The cert must stay in the ALB's region (`us-east-1`).

## Out of scope (lives elsewhere)

- Application code, business logic, migrations content → `commerce-api` repo
- JWT signing, Auth0 client provisioning, scope definitions → `auth0/` module
- CI workflow YAML → `.github/workflows/` in the commerce-api repo
- M2M client used for local testing → `auth0/` module's `m2m-client` instances
