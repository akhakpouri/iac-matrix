# commerce

Per-product directory housing the **commerce-api** ecosystem on AWS. Each subdirectory is its own Terraform Cloud workspace with an independent lifecycle.

For deployment shape, scope, and CI/CD, see [`CLAUDE.md`](CLAUDE.md). This README is the orientation layer.

## Workspaces

| Path     | TFC workspace   | Status   | Purpose |
|----------|-----------------|----------|---------|
| `api/`   | `commerce-api`  | Building | ALB + ECS Fargate API service, per-app ECR repo, logical DB + owner role + Secrets Manager secret on the shared RDS instance. |
| `utils/` | TBD             | Planned  | One-shot utility ECS tasks (migrations, backfills). Not yet built. |

## How `api/` is wired

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

   module "container_registry"  (git::...//aws/modules/ecr)
   └── aws_ecr_repository "commerce-api-registry"
```

The ECS service (defined elsewhere in this workspace as it's built out) pulls the database secret at task-start time from `/commerce-api/rds/psql`, so the Go service never sees the RDS master credentials.

## Variables

`api/` reads almost everything from `platform-shared` via remote state. The only workspace-local inputs are:

| Var            | Source                                                   | Notes |
|----------------|----------------------------------------------------------|-------|
| `region`       | Default `us-east-1`                                      | |
| `rds_password` | TFC Variable Set (shared with `platform-shared`)         | Master password for the shared RDS instance. Used by the postgres provider to authenticate as master when provisioning the logical DB + role. See [ADR-005](../../docs/project-notes/decisions.md#adr-005--per-app-db-bootstrap-is-terraform-driven-not-manual-psql). |

## Adding another commerce workspace

If commerce grows a new service (worker, cron, etc.):

1. Create `aws/commerce/<service>/` with its own `terraform.tf` pointing at a new TFC workspace under the `commerce-api` project.
2. Add `data "terraform_remote_state" "rds"` reading `platform-shared` outputs.
3. Configure `provider "postgresql"` at the root from those outputs + `var.rds_password`.
4. Consume `aws/modules/{db,ecr,s3}` as needed via `git::` source pinned to a ref.
5. Attach the shared `rds_password` Variable Set to the new workspace.
6. Add a row to the workspace table at the top of this README.

## Dependencies

- **`platform-shared`** (org `akhakpouri`, workspace `platform-shared`) — must be applied first. Its outputs are this workspace's inputs.
- **`auth0`** — supplies `urn:commerce-api` audience and scope definitions consumed at runtime by the Go service. No Terraform reference; values must agree across repos.
