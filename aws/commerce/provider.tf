provider "aws" {
  region = var.region
}

# Provider configured at the root and inherited by module "database". The
# master password stays a workspace var per the decentralized bootstrap design
# (each app workspace authenticates as master to provision its own logical DB).
provider "postgresql" {
  host            = data.terraform_remote_state.platform.outputs.postgres_address
  port            = data.terraform_remote_state.platform.outputs.postgres_port
  username        = data.terraform_remote_state.platform.outputs.master_username
  password        = var.rds_password
  database        = "postgres"
  superuser       = false
  scheme          = "awspostgres"
  connect_timeout = 15
}
