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
    }
    random = {
      source  = "hashicorp/random"
    }
    time = {
      source  = "hashicorp/time"
    }
  }
  required_version = ">= 1.14.0"
}
