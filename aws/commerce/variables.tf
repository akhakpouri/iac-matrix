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

# Image tag the task definition points at. Per the sha-only decision, real
# deploys are sha-tagged and managed by CI (the service ignores task_definition
# changes), so this is just the bootstrap tag Terraform creates the baseline
# revision with.
variable "image_tag" {
  description = "Container image tag for the commerce-api task definition baseline."
  type        = string
  default     = "latest"
}

# CORS origin the API allows. Placeholder until a storefront/admin domain exists.
variable "cors_allowed_origin" {
  description = "Allowed CORS origin for the commerce API."
  type        = string
  default     = "*"
}

variable "api_desired_count" {
  description = "Number of commerce-api tasks the service keeps running."
  type        = number
  default     = 0
}

# GitHub repo (<org>/<repo>) allowed to assume the CI role via OIDC. This is the
# security boundary for CI auth — set it to the commerce app repo exactly.
# VERIFY this value; a wrong repo/owner either locks CI out or lets the wrong
# repo in. (Repo renamed commerce-api -> commerce 2026-06-26; the live trust
# policy was updated out-of-band with an admin principal because the TFC
# `terraform` user lacks iam:UpdateAssumeRolePolicy.)
variable "github_repository" {
  description = "GitHub <org>/<repo> permitted to assume the commerce-ci role."
  type        = string
  default     = "akhakpouri/commerce"
}

# Public hostname the API is served at (ACM cert subject + Route 53 record).
variable "api_hostname" {
  description = "Public DNS name for the commerce API."
  type        = string
  default     = "commerce.godevmatrix.me"
}

# Route 53 hosted zone for the domain. Hand-managed outside this workspace — we
# only read it and add the api record + ACM validation records into it.
variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID for the API domain."
  type        = string
  default     = "Z041625321OQNKHW5WH2C"
}
