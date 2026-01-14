data "aws_caller_identity" "current" {}
resource "aws_s3_bucket" "main_bucket" {
  bucket = "${var.bucket_name}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name  = var.bucket_name
    owner = "${var.owner_name}-tutorial"
  }
}
