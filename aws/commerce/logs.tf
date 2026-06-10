resource "aws_cloudwatch_log_group" "commerce_api_logs" {
  name              = "/etc/commerce-api"
  retention_in_days = 30

  tags = {
    Application = "commerce-api"
  }
}

resource "aws_cloudwatch_log_group" "commerce_utils_logs" {
  name              = "/etc/commerce-utils"
  retention_in_days = 30

  tags = {
    Application = "commerce-utils"
  }
}
