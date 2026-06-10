module "database" {
  source        = "git::https://github.com/akhakpouri/iac-matrix.git//aws/modules/db?ref=main"
  db_name       = "commerce"
  db_owner      = "commerce"
  db_schemas    = ["public", "commerce"]
  secret_name   = "/commerce-api/rds/psql"
  rds_host      = data.terraform_remote_state.platform.outputs.postgres_address
  database_port = data.terraform_remote_state.platform.outputs.postgres_port
}
