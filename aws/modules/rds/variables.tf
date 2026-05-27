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

variable "rds_username" {
  description = "Db username"
  type        = string
  default     = "postgres"
}

variable "rds_password" {
  description = "Db password"
  type        = string
  sensitive   = true
}

variable "instance_name" {
  description = "Name of the RDS instance"
  type        = string
}

variable "rds_identifier" {
  description = "Identifier of the RDS instance"
  type        = string
}

variable "db_engine" {
  description = "Database Engine"
  type        = string
  default     = "postgres"
}

variable "resource_family" {
  description = "Database resource family"
  type        = string
  default     = "postgres18"
}

variable "db_version" {
  description = "Database version"
  type        = string
  default     = "18.4"
}
