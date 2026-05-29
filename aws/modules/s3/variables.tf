variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket."
  default     = "tf-main"
}

variable "owner_name" {
  type    = string
  default = "terraform_init"
}
