module "api_registry" {
  source          = "git::https://github.com/akhakpouri/iac-matrix.git//aws/modules/ecr?ref=main"
  repository_name = "commerce-api-registry"
}

module "utils_registry" {
  source          = "git::https://github.com/akhakpouri/iac-matrix.git//aws/modules/ecr?ref=main"
  repository_name = "commerce-utils-registry"
}
