terraform {
  cloud {
    organization = "akhakpouri"

    workspaces {
      project = "platform-shared"
      name    = "platform-shared"
    }
  }
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}
