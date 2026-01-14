data "aws_availability_zones" "availability_zones" {}

module "rds_vcp" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.0.0"

  name                 = "rds-vpc"
  cidr                 = var.vpc_cidr_block
  azs                  = data.aws_availability_zones.availability_zones.names
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
  name   = "education_rds"
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
    Name = "education_rds"
  }
}

resource "aws_db_parameter_group" "education" {
  name   = "education"
  family = "postgres17"

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

resource "aws_db_instance" "rds_instance" {
  identifier             = "education-rds-instance"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "17.4"
  username               = "edu"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.education.name
  publicly_accessible    = true
  skip_final_snapshot    = true
}
