output "registry_id" {
  description = "the id of the ecr registry after it's created"
  value       = aws_ecr_repository.repository.id
}

output "registry_arn" {
  description = "the arn of the ecr registry"
  value       = aws_ecr_repository.repository.arn
}

output "repository_url" {
  description = "the url of the ecr registry"
  value       = aws_ecr_repository.repository.repository_url
}
