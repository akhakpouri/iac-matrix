provider "aws" {
  region = var.region
}

provider "random" {

}

provider "time" {

}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "random_pet" "instance" {
  length = 2
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"

  name = "server-vpc"
  cidr = var.vpc_cidr_block

  azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets      = slice(var.private_subnet_cidr_blocks, 0, var.private_subnet_count)
  public_subnets       = slice(var.public_subnet_cidr_blocks, 0, var.public_subnet_count)
  enable_dns_hostnames = true
  enable_vpn_gateway   = var.enable_vpn_gateway
}

module "s3-instance" {
  source = "./modules/s3-bucket"
}

module "hello" {
  source  = "joatmon08/hello/random"
  version = "6.0.0"
  hellos = {
    hello        = random_pet.instance.id
    second_hello = "world"
  }
  some_key = var.secret_key
}

module "rds" {
  source      = "./modules/rds"
  db_password = var.db_password
}
