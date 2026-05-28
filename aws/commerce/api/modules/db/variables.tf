variable "db_name" {
  description = "database name"
  type        = string
}

variable "db_owner" {
  description = "database owner"
  type        = string
}

variable "db_schemas" {
  description = "list of schemas to grant all privileges."
  type        = list(string)
  default     = ["public"]
}

variable "rds_host" {
  description = "RDS host"
  type        = string
}

variable "database_port" {
  description = "default database port"
  type        = number
  default     = 5432
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
