terraform {
  cloud {
    organization = "akhakpouri"

    workspaces {
      project = "Learn Terrafom"
      name    = "learn-terraform-aws"
    }

  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.28"
    }
  }
  required_version = ">= 1.14.0"
}
