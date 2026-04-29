variable "client_id" {
  type        = string
  description = "Auth0 client-id"
}

variable "domain" {
  type        = string
  description = "Auth0 domain!"
}

variable "client_secret" {
  type        = string
  description = "Auth0 client secret"
  sensitive   = true
}
