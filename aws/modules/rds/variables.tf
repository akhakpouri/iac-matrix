variable "instance_name" {
  type        = string
  description = "Instance name of the rds"
  default     = "main-rds-instance"
}

variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block for the RDS VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_rds_cidr_blocks" {
  description = "Available cidr blocks for public subnets."
  type        = list(string)
  default = [
    "10.0.4.0/24",
    "10.0.5.0/24",
    "10.0.6.0/24"
  ]
}

variable "db_password" {
  description = "Db password"
  type        = string
  sensitive   = true
}
