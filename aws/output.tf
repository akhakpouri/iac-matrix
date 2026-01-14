output "s3_bucket_name" {
  description = "The name of the s3 bucket"
  value       = module.s3-instance.bucket_name
}

output "app_server_count" {
  description = "Count of app servers provisisioned"
  value       = length(module.ec2-instance.instance_ids)
}
