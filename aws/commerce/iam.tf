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

# ---------------------------------------------------------------------------
# CI identity (GitHub Actions via OIDC)
#
# GitHub presents a short-lived OIDC token; AWS trusts GitHub's OIDC provider;
# the workflow assumes the `commerce-ci` role, which is scoped to this repo's
# main branch. No long-lived AWS keys are stored in GitHub.
# ---------------------------------------------------------------------------

# GitHub's OIDC issuer cert. AWS no longer validates the thumbprint for known
# IdPs, but the provider resource still requires one — fetch it dynamically so
# it never goes stale on rotation.
data "tls_certificate" "github_oidc" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

# ACCOUNT SINGLETON: only one provider per URL per AWS account. If this account
# already has a GitHub OIDC provider, DO NOT apply this — import the existing one
# (`terraform import aws_iam_openid_connect_provider.github <arn>`) instead.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_oidc.certificates[0].sha1_fingerprint]
}

# The CI role. The trust policy is the security boundary: only the OIDC provider
# may assume it, only with the sts.amazonaws.com audience, and only from this
# repo's main branch (the `sub` condition). A loose `sub` would let other repos
# or branches in — keep it exact.
resource "aws_iam_role" "ci" {
  name = "commerce-ci"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:ref:refs/heads/main" }
      }
    }]
  })
}

# Phase 1 — push images to the two ECR repos. GetAuthorizationToken is account-
# level so it must be "*"; the push/pull actions are scoped to the two repos.
resource "aws_iam_role_policy" "ci_ecr_push" {
  name = "ecr-push"
  role = aws_iam_role.ci.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "EcrPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = [
          module.api_registry.registry_arn,
          module.utils_registry.registry_arn,
        ]
      },
    ]
  })
}

# ----- Phase 2 (deploy) — uncomment when you add the deploy steps -----------
# Lets CI register a task-def revision, run the utils migration, and roll the
# API service. iam:PassRole is required for RegisterTaskDefinition/RunTask to
# hand the task its execution + task roles — deploys fail silently without it.
#
# resource "aws_iam_role_policy" "ci_deploy" {
#   name = "ecs-deploy"
#   role = aws_iam_role.ci.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "EcsDeploy"
#         Effect = "Allow"
#         Action = [
#           "ecs:RegisterTaskDefinition",
#           "ecs:RunTask",
#           "ecs:UpdateService",
#           "ecs:DescribeServices",
#           "ecs:DescribeTasks",
#         ]
#         Resource = "*" # RegisterTaskDefinition has no resource-level support
#       },
#       {
#         Sid      = "PassTaskRoles"
#         Effect   = "Allow"
#         Action   = "iam:PassRole"
#         Resource = [aws_iam_role.task_execution.arn, aws_iam_role.task.arn]
#         Condition = {
#           StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" }
#         }
#       },
#     ]
#   })
# }
