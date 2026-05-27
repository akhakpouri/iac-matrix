# Consumed by the `db` module/workspace to open a PostgreSQL connection to the
# shared instance. `address` + `port` are kept separate (not just `endpoint`)
# because the postgresql provider wants host and port as distinct fields.
#
# The instance is created with for_each over var.db_engine, so we select the
# "postgres" instance explicitly. If postgres is ever removed from db_engine
# these outputs will (correctly) fail to resolve.

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
  description = "Master username on the shared instance (used by the db module to create per-app roles/databases)."
  value       = aws_db_instance.rds_instance.username
}
