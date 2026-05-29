output "postgres_address" {
  description = "Hostname of the shared PostgreSQL instance (no port)."
  value       = module.rds.postgres_address
}

output "postgres_port" {
  description = "Port of the shared PostgreSQL instance."
  value       = module.rds.postgres_port
}

output "postgres_endpoint" {
  description = "address:port of the shared PostgreSQL instance."
  value       = module.rds.postgres_endpoint
}

output "master_username" {
  description = "Master username on the shared instance. Consumed by app workspaces via terraform_remote_state."
  value       = module.rds.master_username
}

output "rds_security_group_id" {
  description = "Security group on the shared RDS instance. App workspaces add their task SGs here to gain access."
  value       = module.rds.security_group_id
}
