terraform {
  cloud {
    organization = "akhakpouri"
    workspaces {
      name    = "commerce"
      project = "commerce"
    }
  }
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    postgresql = {
      source = "cyrilgdn/postgresql"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
}
