variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "db_password" {
  type      = string
  sensitive = true
}
