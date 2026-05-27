data "aws_availability_zones" "availability_zones" {}

module "rds_vcp" {
  source = "terraform-aws-modules/vpc/aws"

  name                 = var.instance_name
  cidr                 = var.vpc_cidr_block
  azs                  = data.aws_availability_zones.availability_zones.names
  instance_tenancy     = "default"
  public_subnets       = var.public_subnet_rds_cidr_blocks
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = module.rds_vcp.public_subnets

  tags = {
    Name = "RDS subnet group"
  }
}

resource "aws_security_group" "rds" {
  name   = "shared_rds"
  vpc_id = module.rds_vcp.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "shared_rds"
  }
}

resource "aws_db_parameter_group" "shared" {
  name   = "shared"
  family = var.resource_family

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

resource "aws_db_instance" "rds_instance" {
  identifier             = var.rds_identifier
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = var.db_engine
  engine_version         = var.db_version
  username               = var.rds_username
  password               = var.rds_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.shared.name
  publicly_accessible    = true
  skip_final_snapshot    = true
}
