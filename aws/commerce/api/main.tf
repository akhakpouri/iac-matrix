provider "aws" {
  region = var.region
}

module "container_registry" {
  source          = "../../modules/ecr"
  repository_name = "commerce-api-registry"
}
