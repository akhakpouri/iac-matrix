variable "region" {
  type    = string
  default = "us-east-1"
}

variable "secret_key" {
  description = "secret key for the hllo module"
  type        = string
  sensitive   = true
}
