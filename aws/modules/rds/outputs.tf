# Consumed by app workspaces (via terraform_remote_state) to open a PostgreSQL
# connection to the shared instance and to authorize themselves at the SG.
# `address` + `port` stay separate (not just `endpoint`) because the postgresql
# provider wants host and port as distinct fields.

output "postgres_address" {
  description = "Hostname of the shared PostgreSQL instance (no port)."
  value       = aws_db_instance.rds_instance.address
}

output "postgres_port" {
  description = "Port of the shared PostgreSQL instance."
  value       = aws_db_instance.rds_instance.port
}

output "postgres_endpoint" {
  description = "address:port of the shared PostgreSQL instance."
  value       = aws_db_instance.rds_instance.endpoint
}

output "master_username" {
  description = "Master username on the shared instance (used by app workspaces to create per-app roles/databases)."
  value       = aws_db_instance.rds_instance.username
}

output "security_group_id" {
  description = "Security group attached to the shared instance. App workspaces' task SGs must be allowed in here to reach RDS post-ADR-004."
  value       = aws_security_group.rds.id
}
