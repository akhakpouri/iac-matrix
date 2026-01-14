output "bucket_name" {
  description = "Final name of the S3 bucket"
  value       = aws_s3_bucket.main_bucket.bucket
}
