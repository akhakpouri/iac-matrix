# ---------------------------------------------------------------------------
# Outputs consumed by humans and by CI in the commerce-api repo.
# ---------------------------------------------------------------------------

# Raw ALB DNS name (the alias target). Normally you hit api_url instead.
output "alb_dns_name" {
  description = "Public DNS name of the commerce ALB."
  value       = aws_lb.commerce_alb.dns_name
}

# The public, TLS-terminated URL for the API.
output "api_url" {
  description = "Public HTTPS URL of the commerce API."
  value       = "https://${var.api_hostname}"
}

# Image push targets for the CI build step (docker push <url>:<sha>).
output "api_repository_url" {
  description = "ECR repository URL for the commerce-api image."
  value       = module.api_registry.repository_url
}

output "utils_repository_url" {
  description = "ECR repository URL for the commerce-utils image."
  value       = module.utils_registry.repository_url
}

# Needed by the future CI OIDC role's iam:PassRole (it must be allowed to pass
# the execution role to ECS when registering task definitions).
output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role."
  value       = aws_iam_role.task_execution.arn
}

# App credentials secret on the shared RDS instance (host/user/password/...).
output "db_secret_arn" {
  description = "ARN of the commerce app DB credentials secret."
  value       = module.database.postgresql_secret_arn
}

# ARN the GitHub Actions workflow assumes via OIDC. Not sensitive — store it as
# a GitHub Actions variable (vars.AWS_CI_ROLE_ARN), not a secret.
output "ci_role_arn" {
  description = "ARN of the commerce-ci role for GitHub Actions OIDC."
  value       = aws_iam_role.ci.arn
}

# Event backbone (ADR-018). relay publishes here; local runs pick this up as
# the SNS_TOPIC_ARN env var.
output "domain_events_topic_arn" {
  description = "ARN of the commerce-domain-events SNS topic."
  value       = aws_sns_topic.domain_events.arn
}

# Used to `aws sqs receive-message` against directly while verifying the
# relay -> SNS -> SQS path end to end (no notifier consumer exists yet).
output "notifications_queue_url" {
  description = "URL of the commerce-notifications-queue SQS queue."
  value       = aws_sqs_queue.notifications.id
}
