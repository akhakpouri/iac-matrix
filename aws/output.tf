output "s3_bucket_name" {
  description = "The name of the s3 bucket"
  value       = module.s3-instance.bucket_name
}
