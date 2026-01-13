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
    random = {
      source  = "hashicorp/random"
      version = "~>3.7"
    }
  }
  required_version = ">= 1.14.0"
}
