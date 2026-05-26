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

variable "db_username" {
  description = "Db username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Db password"
  type        = string
  sensitive   = true
}

variable "instance_name" {
  description = "Name of the RDS instance"
  type        = string
}

variable "db_identifier" {
  description = "Identifier of the RDS database instance"
  type        = string
}

variable "db_engine" {
  description = "Database Engine"
  type        = list(string)
  default     = ["postgres", "mysql", "mariadb"]
}

variable "resource_family" {
  description = "Database resource family"
  type        = list(string)
  default     = ["postgres18", "postgres17", "mysql8.0", "mariadb10.5", "postgres16", "mysql5.7", "mariadb10.3"]
}

variable "db_version" {
  description = "Database version"
  type        = string
  default     = "17.4"
}
