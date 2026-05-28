module "container_registry" {
  source          = "./modules/ecr"
  repository_name = "commerce-api-registry"
}

module "database" {
  rds_host      = var.rds_host
  rds_password  = var.rds_password
  rds_username  = var.rds_username
  database_port = var.database_port
  source        = "./modules/db"
  db_name       = "commerce"
  db_owner      = "commerce"
  db_schemas    = ["public", "commerce"]
}
