# commerce

Per-product directory housing the **commerce** ecosystem on AWS. The whole product deploys from a single Terraform Cloud workspace; `api` and `utils` are concerns within it, not separate workspaces — see [ADR-006](../../docs/project-notes/decisions.md#adr-006--one-commerce-workspace-for-the-whole-product-utils-is-not-its-own-workspace).

For deployment shape, scope, and CI/CD, see [`CLAUDE.md`](CLAUDE.md). This README is the orientation layer.

## Workspace

Single TFC workspace **`commerce`** (org `akhakpouri`, project `commerce`), working directory `aws/commerce/`.

| Component   | Status | Purpose |
|-------------|--------|---------|
| API service | Live   | ALB (HTTPS at `https://commerce.godevmatrix.me`) + ECS Fargate API service, `commerce-api-registry` ECR repo, logical DB + owner role + Secrets Manager secret on the shared RDS instance. |
| `utils`     | Live   | One-shot utility ECS task (migrations, backfills) + `commerce-utils-registry` ECR repo. Run via `aws ecs run-task` by CI. |

## How the workspace is wired

```
              platform-shared (aws/)
                outputs: postgres_address / postgres_port / master_username /
                         rds_security_group_id / vpc_id / public_subnet_ids /
                         private_subnet_ids
                              │
                  data.terraform_remote_state.platform
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

   module "utils_registry"  (git::...//aws/modules/ecr)
   └── aws_ecr_repository "commerce-utils-registry"
```

On top of the above, the workspace also builds the compute/serving layer: an ECS cluster, the API service + a one-shot `utils` task definition, an internet-facing ALB (target group + `:80`→`:443` redirect + HTTPS listener), an ACM cert + Route 53 alias record for `commerce.godevmatrix.me`, the `alb`/`task` security groups, IAM roles (incl. the `commerce-ci` OIDC role), and CloudWatch log groups. The ALB and tasks live in `platform-shared`'s VPC/subnets (read via the same remote state). The ECS task pulls the database secret at task-start time from `/commerce-api/rds/psql`, so the Go service never sees the RDS master credentials.

## Variables

The workspace reads almost everything from `platform-shared` via remote state. The only workspace-local inputs are:

| Var                 | Source                                           | Notes |
|---------------------|--------------------------------------------------|-------|
| `region`            | Default `us-east-1`                              | |
| `rds_password`      | TFC Variable Set (shared with `platform-shared`) | Master password for the shared RDS instance. Used by the postgres provider to authenticate as master when provisioning the logical DB + role. See [ADR-005](../../docs/project-notes/decisions.md#adr-005--per-app-db-bootstrap-is-terraform-driven-not-manual-psql). |
| `image_tag`         | Default `latest`                                 | Bootstrap tag for the task-def baseline. Real deploys are sha-tagged by CI; the service ignores task-def changes. |
| `cors_allowed_origin` | Default `*`                                     | Placeholder until a storefront/admin domain exists. |
| `api_desired_count` | Default `0`                                      | Number of API tasks. `0` until the first image is pushed; bump to 1 after CI's first deploy. |
| `github_repository` | Default `akhakpouri/commerce-api`                | `<org>/<repo>` permitted to assume the `commerce-ci` OIDC role. Security boundary for CI auth. |
| `api_hostname`      | Default `commerce.godevmatrix.me`                | Public DNS name; ACM cert subject + Route 53 record. |
| `hosted_zone_id`    | Default `Z041625321OQNKHW5WH2C`                  | Route 53 zone for `godevmatrix.me` (hand-managed; TF only writes the api + cert-validation records). |

## Adding another commerce service

If commerce grows a new service (worker, cron, etc.), it lives in *this* workspace as new `.tf` files (or a local module), not a new workspace — see [ADR-006](../../docs/project-notes/decisions.md#adr-006--one-commerce-workspace-for-the-whole-product-utils-is-not-its-own-workspace):

1. Add the resources to `aws/commerce/` (e.g. `ecs-<service>.tf`), reusing the existing ECS cluster, task execution role, networking, and the `data.terraform_remote_state.platform` already in the workspace.
2. Consume `aws/modules/{db,ecr,s3}` as needed via `git::` source pinned to a ref — e.g. another `module "<service>_registry"` for its image.
3. No new Variable Set attachment or remote_state wiring needed — it inherits the workspace's.
4. Add a row to the component table at the top of this README.
5. Promote to its own workspace only if the service gains a genuinely independent lifecycle, ownership, or access boundary (ADR-006, "Reversible when a real boundary appears").

## Dependencies

- **`platform-shared`** (org `akhakpouri`, workspace `platform-shared`) — must be applied first. Its outputs are this workspace's inputs.
- **`auth0`** — supplies `urn:commerce-api` audience and scope definitions consumed at runtime by the Go service. No Terraform reference; values must agree across repos.
