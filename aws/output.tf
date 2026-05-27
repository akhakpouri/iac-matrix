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
