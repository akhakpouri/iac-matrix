# Provider config lives in the caller (root workspace), not here — a reusable
# module should declare what provider it needs (terraform.tf) and inherit the
# configured instance. The caller wires host/port/username from
# terraform_remote_state and the master password from a workspace var.

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
  source              = "terraform-aws-modules/secrets-manager/aws"
  version             = "~> 2.1"
  name                = var.secret_name
  description         = "Application database credentials for ${var.db_name}"
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

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_!@#"
}
