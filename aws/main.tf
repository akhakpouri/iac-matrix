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
  source                        = "./modules/rds"
  instance_name                 = "shared-rds"
  db_identifier                 = "shared-rds-instance"
  db_engine                     = var.db_engine
  db_version                    = var.db_version
  db_password                   = var.db_password
  vpc_cidr_block                = var.vpc_cidr_block
  public_subnet_rds_cidr_blocks = var.public_subnet_rds_cidr_blocks
  db_username                   = var.db_username
  db_password                   = var.db_password
  instance_class                = var.db_instance_class
  allocated_storage             = var.db_allocated_storage
  vpc_security_group_ids        = [module.vpc.default_security_group_id]
  db_subnet_group_name          = module.vpc.database_subnet_group_name
}
