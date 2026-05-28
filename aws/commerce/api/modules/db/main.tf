provider "postgresql" {
  host            = var.rds_host
  port            = var.database_port
  username        = var.rds_username
  password        = var.rds_password
  database        = "postgres"
  superuser       = false
  scheme          = "awspostgres"
  connect_timeout = 15
}

resource "postgresql_database" "database" {
  name  = var.db_name
  owner = var.db_owner
}

resource "postgresql_role" "role" {
  depends_on = [random_password.db_password]
  name       = var.db_owner
  login      = true
  password   = random_password.db_password.result
}

resource "postgresql_grant" "grant" {
  for_each    = toset(var.db_schemas)
  role        = postgresql_role.role.name
  database    = postgresql_database.database.name
  schema      = each.value
  object_type = "schema"
  privileges  = ["ALL"]
}

module "secret_manager" {
  depends_on          = [random_password.db_password, postgresql_database.database, postgresql_role.role]
  source              = "git::https://github.com/terraform-aws-modules/terraform-aws-secrets-manager.git//"
  name                = "/commerce-api/rds/psql"
  description         = "Credentials of commerce database"
  block_public_policy = true
  secret_string = jsonencode({
    engine   = "postgresql",
    host     = var.rds_host,
    username = var.db_owner,
    password = random_password.db_password.result,
    port     = var.database_port,
    database = var.db_name
  })
}

resource "aws_secretsmanager" "name" {

}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_!@#"
}
