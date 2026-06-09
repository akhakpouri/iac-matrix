# commerce

Per-product directory housing the **commerce** ecosystem on AWS. The whole product deploys from a single Terraform Cloud workspace; `api` and `utils` are concerns within it, not separate workspaces — see [ADR-006](../../docs/project-notes/decisions.md#adr-006--one-commerce-workspace-for-the-whole-product-utils-is-not-its-own-workspace).

For deployment shape, scope, and CI/CD, see [`CLAUDE.md`](CLAUDE.md). This README is the orientation layer.

## Workspace

Single TFC workspace **`commerce`** (org `akhakpouri`, project `commerce`), working directory `aws/commerce/`.

| Component   | Status   | Purpose |
|-------------|----------|---------|
| API service | Building | ALB + ECS Fargate API service, `commerce-api-registry` ECR repo, logical DB + owner role + Secrets Manager secret on the shared RDS instance. |
| `utils`     | Planned  | One-shot utility ECS task (migrations, backfills) + `commerce-utils-registry` ECR repo. Not yet built. |

## How the workspace is wired

```
              platform-shared (aws/)
                outputs: postgres_address / postgres_port /
                         master_username / rds_security_group_id
                              │
                  data.terraform_remote_state.rds
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
   provider "postgresql"            module "database"  (git::...//aws/modules/db)
   (root, configured from           ├── postgresql_database "commerce"
   remote_state + master pw)        ├── postgresql_role "commerce" (random password)
                                    ├── postgresql_grant on schemas
                                    └── module.secret_manager
                                        └── /commerce-api/rds/psql in Secrets Manager

   module "api_registry"    (git::...//aws/modules/ecr)
   └── aws_ecr_repository "commerce-api-registry"

   module "utils_registry"  (git::...//aws/modules/ecr)   [planned]
   └── aws_ecr_repository "commerce-utils-registry"
```

The ECS service (defined alongside this as it's built out) pulls the database secret at task-start time from `/commerce-api/rds/psql`, so the Go service never sees the RDS master credentials.

## Variables

The workspace reads almost everything from `platform-shared` via remote state. The only workspace-local inputs are:

| Var            | Source                                                   | Notes |
|----------------|----------------------------------------------------------|-------|
| `region`       | Default `us-east-1`                                      | |
| `rds_password` | TFC Variable Set (shared with `platform-shared`)         | Master password for the shared RDS instance. Used by the postgres provider to authenticate as master when provisioning the logical DB + role. See [ADR-005](../../docs/project-notes/decisions.md#adr-005--per-app-db-bootstrap-is-terraform-driven-not-manual-psql). |

## Adding another commerce service

If commerce grows a new service (worker, cron, etc.), it lives in *this* workspace as new `.tf` files (or a local module), not a new workspace — see [ADR-006](../../docs/project-notes/decisions.md#adr-006--one-commerce-workspace-for-the-whole-product-utils-is-not-its-own-workspace):

1. Add the resources to `aws/commerce/` (e.g. `ecs-<service>.tf`), reusing the existing ECS cluster, task execution role, networking, and the `data.terraform_remote_state.rds` already in the workspace.
2. Consume `aws/modules/{db,ecr,s3}` as needed via `git::` source pinned to a ref — e.g. another `module "<service>_registry"` for its image.
3. No new Variable Set attachment or remote_state wiring needed — it inherits the workspace's.
4. Add a row to the component table at the top of this README.
5. Promote to its own workspace only if the service gains a genuinely independent lifecycle, ownership, or access boundary (ADR-006, "Reversible when a real boundary appears").

## Dependencies

- **`platform-shared`** (org `akhakpouri`, workspace `platform-shared`) — must be applied first. Its outputs are this workspace's inputs.
- **`auth0`** — supplies `urn:commerce-api` audience and scope definitions consumed at runtime by the Go service. No Terraform reference; values must agree across repos.
