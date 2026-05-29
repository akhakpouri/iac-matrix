provider "aws" {
  region = var.region
}

# RDS connection info comes from the platform-shared workspace so there's one
# source of truth — endpoint changes there propagate without per-workspace
# variable updates.
data "terraform_remote_state" "rds" {
  backend = "remote"
  config = {
    organization = "akhakpouri"
    workspaces = {
      name = "platform-shared"
    }
  }
}

# Provider configured at the root and inherited by module "database". The
# master password stays a workspace var per the decentralized bootstrap design
# (each app workspace authenticates as master to provision its own logical DB).
provider "postgresql" {
  host            = data.terraform_remote_state.rds.outputs.postgres_address
  port            = data.terraform_remote_state.rds.outputs.postgres_port
  username        = data.terraform_remote_state.rds.outputs.master_username
  password        = var.rds_password
  database        = "postgres"
  superuser       = false
  scheme          = "awspostgres"
  connect_timeout = 15
}

module "container_registry" {
  source          = "git::https://github.com/akhakpouri/iac-matrix.git//aws/modules/ecr?ref=main"
  repository_name = "commerce-api-registry"
}

module "database" {
  source        = "git::https://github.com/akhakpouri/iac-matrix.git//aws/modules/db?ref=main"
  db_name       = "commerce"
  db_owner      = "commerce"
  db_schemas    = ["public", "commerce"]
  secret_name   = "/commerce-api/rds/psql"
  rds_host      = data.terraform_remote_state.rds.outputs.postgres_address
  database_port = data.terraform_remote_state.rds.outputs.postgres_port
}
