provider "aws" {
  region = var.region
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = "server-vpc"
  cidr = var.vpc_cidr_block

  azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets      = slice(var.private_subnet_cidr_blocks, 0, var.private_subnet_count)
  public_subnets       = slice(var.public_subnet_cidr_blocks, 0, var.public_subnet_count)
  enable_dns_hostnames = true
  enable_vpn_gateway   = var.enable_vpn_gateway
}

module "rds" {
  source         = "./modules/rds"
  rds_identifier = "shared-instance"
  rds_password   = var.rds_password
  rds_username   = var.rds_username
  instance_name  = "shared-vpc"
}
