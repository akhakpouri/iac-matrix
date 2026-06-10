# ---------------------------------------------------------------------------
# IAM for the commerce ECS tasks
#
# Two roles, both assumed by ECS on your behalf. The difference is *who* uses
# the role and *when*:
#
#   1. EXECUTION role — used by the ECS agent BEFORE your container starts:
#      pull the image from ECR, read the DB secret, write logs.
#   2. TASK role — used by your APPLICATION CODE while it runs, to call AWS
#      APIs. commerce talks to Postgres with a password (not IAM), so this one
#      is empty for now — it just exists so the task defs always have a role to
#      point at, and a place to add permissions later.
#
# Both task families (api + utils) share both roles: same image source, same
# secret, same logging, no app-level AWS calls. No reason to split them.
# ---------------------------------------------------------------------------

# Trust policy = "who is allowed to assume this role". For ECS tasks the
# answer is always the ECS Tasks service principal. Reused by both roles below.
locals {
  ecs_tasks_assume_role = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# ----- Execution role ------------------------------------------------------

resource "aws_iam_role" "task_execution" {
  name               = "commerce-task-execution"
  assume_role_policy = local.ecs_tasks_assume_role
}

# AWS-managed policy that grants exactly what the ECS agent needs to pull from
# ECR and write to CloudWatch Logs. It's maintained by AWS — don't hand-roll
# these permissions.
resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# The managed policy above does NOT include Secrets Manager. The execution role
# is what reads a task def's `secrets` block at startup and injects the values
# as env vars — so without this, the container never receives DB_PASSWORD.
# Scoped to our one secret (the ARN comes from the database module, so it stays
# correct even if the secret's random ARN suffix changes).
resource "aws_iam_role_policy" "task_execution_secret" {
  name = "read-db-secret"
  role = aws_iam_role.task_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = module.database.postgresql_secret_arn
    }]
  })
}

# ----- Task role -----------------------------------------------------------

# Assumed by the application container itself. Intentionally has NO permissions
# attached: commerce reaches RDS with a password from env and makes no AWS API
# calls. Kept as a stable attachment point so both task defs set task_role_arn.
resource "aws_iam_role" "task" {
  name               = "commerce-task"
  assume_role_policy = local.ecs_tasks_assume_role
}
