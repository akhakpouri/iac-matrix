variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

# Master password for the shared RDS instance. Set as a workspace variable in
# TFC. The postgres provider uses this to authenticate as the master user
# (per the decentralized bootstrap design — each app workspace creates its own
# logical DB + role). All other RDS connection info comes from
# terraform_remote_state of the platform-shared workspace.
variable "rds_password" {
  description = "Master password of the shared RDS instance."
  type        = string
  sensitive   = true
}
