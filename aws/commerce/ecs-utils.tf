# ---------------------------------------------------------------------------
# The commerce "utils" one-shot task: database migrations / backfills.
#
# Unlike the API, this is JUST a task definition — there is no aws_ecs_service,
# no load balancer, and no port. It isn't long-running; CI invokes it on demand
# with `aws ecs run-task` before each API deploy and fails the pipeline if the
# migration exits non-zero. Migrations are idempotent (GORM AutoMigrate).
#
# It reuses the same execution + task roles and the same DB secret as the API —
# it only needs to reach Postgres, not serve traffic.
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "utils" {
  family                   = "commerce-utils"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "commerce-utils"
      image     = "${module.utils_registry.repository_url}:${var.image_tag}"
      essential = true

      # No portMappings: nothing connects to this container. Only the DB-related
      # config is needed — migrations don't serve HTTP, so no auth/CORS/server
      # vars. (If the utils binary shares the API's config loader and demands the
      # full env set, add the missing keys here.)
      environment = [
        { name = "ENV", value = "production" },
        { name = "DB_HOST", value = data.terraform_remote_state.platform.outputs.postgres_address },
        { name = "DB_PORT", value = tostring(data.terraform_remote_state.platform.outputs.postgres_port) },
        { name = "DB_NAME", value = "commerce" },
        { name = "DB_USER", value = "commerce" },
        { name = "DB_SCHEMA", value = "commerce" },
        { name = "DB_SSLMODE", value = "require" },
      ]

      secrets = [
        { name = "DB_PASSWORD", valueFrom = "${module.database.postgresql_secret_arn}:password::" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.commerce_utils_logs.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}
