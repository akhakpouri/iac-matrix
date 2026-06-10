# ---------------------------------------------------------------------------
# The commerce API: a long-running Fargate service behind the ALB.
#
# This is where everything else wires together:
#   - image      -> the api_registry ECR repo (registry.tf)
#   - roles      -> execution + task roles (iam.tf)
#   - logs       -> the api log group (logs.tf)
#   - DB_PASSWORD-> the Secrets Manager secret (database.tf)
#   - networking -> task SG + public subnets (security-groups.tf / remote state)
#   - traffic    -> the ALB target group (security-groups.tf)
# ---------------------------------------------------------------------------

# The task definition is the "blueprint" for a container: which image, how much
# CPU/memory, what env, which roles. Fargate requires awsvpc networking and the
# cpu/memory pair to be from the allowed Fargate combinations (256/512 is the
# smallest).
resource "aws_ecs_task_definition" "api" {
  family                   = "commerce-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  # execution_role = the ECS agent's identity (pull image, read secret, log).
  # task_role      = the application's identity (empty; commerce makes no AWS calls).
  execution_role_arn = aws_iam_role.task_execution.arn
  task_role_arn      = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "commerce-api"
      image     = "${module.api_registry.repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        { containerPort = 8080, protocol = "tcp" }
      ]

      # Plain (non-secret) config. Values either come from platform-shared's
      # outputs (DB host/port) or are literals from the service's expected env
      # (see aws/commerce/CLAUDE.md — diff against commerce-api's dev.env.example
      # when keys change). DB_PORT must be a string, so tostring().
      environment = [
        { name = "ENV", value = "production" },
        { name = "SERVER_ADDRESS", value = ":8080" },
        { name = "CORS_ALLOWED_ORIGIN", value = var.cors_allowed_origin },
        { name = "DB_HOST", value = data.terraform_remote_state.platform.outputs.postgres_address },
        { name = "DB_PORT", value = tostring(data.terraform_remote_state.platform.outputs.postgres_port) },
        { name = "DB_NAME", value = "commerce" },
        { name = "DB_USER", value = "commerce" },
        { name = "DB_SCHEMA", value = "commerce" },
        { name = "DB_SSLMODE", value = "require" },
        { name = "AUTH_DOMAIN", value = "dev-y7vm6nwrj5uw2n2e.us.auth0.com" },
        { name = "AUTH_AUDIENCE", value = "urn:commerce-api" },
      ]

      # Secret config. ECS pulls this from Secrets Manager at task start using
      # the EXECUTION role and injects it as an env var the app never sees in
      # plaintext config. The ":password::" suffix selects the `password` key
      # out of the JSON secret (format is arn:json-key:version-stage:version-id).
      secrets = [
        { name = "DB_PASSWORD", valueFrom = "${module.database.postgresql_secret_arn}:password::" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.commerce_api_logs.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# The service keeps `desired_count` copies of the task running, replaces
# unhealthy ones, and registers their IPs with the ALB target group.
resource "aws_ecs_service" "api" {
  name            = "commerce-api"
  cluster         = aws_ecs_cluster.commerce_cluster.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.api_desired_count
  launch_type     = "FARGATE"

  # Public subnets + a public IP because (for now) the task reaches ECR /
  # Secrets Manager / the still-public RDS over the internet — no NAT gateway.
  # When ADR-004 makes RDS private, this moves to private subnets + NAT.
  network_configuration {
    subnets          = data.terraform_remote_state.platform.outputs.public_subnet_ids
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.commerce_api.arn
    container_name   = "commerce-api" # must match the container name above
    container_port   = 8080
  }

  # ECS won't let a service register with a target group that isn't yet attached
  # to a listener — wait for the listener first.
  depends_on = [aws_lb_listener.http]

  # CI owns deployments: it pushes a sha-tagged image, registers a new task-def
  # revision, and updates the service. Ignoring these keeps `terraform apply`
  # from reverting whatever CI last deployed (and any autoscaling of the count).
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}
