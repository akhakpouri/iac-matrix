variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
  nullable    = false
}

variable "image_retention_count" {
  description = "Number of most-recent images to keep; older images are expired by the lifecycle policy."
  type        = number
  default     = 30
}

variable "untagged_image_expiry_days" {
  description = "Days after which untagged images (e.g. orphaned multi-arch manifests) are expired."
  type        = number
  default     = 7
}
