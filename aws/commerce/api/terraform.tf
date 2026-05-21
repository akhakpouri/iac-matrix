terraform {
  cloud {
    organization = "akhakpouri"
    workspaces {
      name    = "commerce-api"
      project = "commerce-api"
    }
  }
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}
