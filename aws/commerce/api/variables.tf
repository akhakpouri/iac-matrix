variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "rds_host" {
  description = "RDS host"
  type        = string
}

variable "rds_password" {
  description = "RDS password"
  type        = string
  sensitive   = true
}

variable "rds_username" {
  description = "RDS username"
  type        = string
  default     = "postgres"
}

variable "database_port" {
  description = "default database port"
  type        = number
  default     = 5432
}
