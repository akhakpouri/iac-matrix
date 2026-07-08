# ---------------------------------------------------------------------------
# Relay's local dev identity — Phase 1 (see sns-sqs.tf for the full plan).
#
# relay isn't containerized yet; it runs on the developer's laptop against
# the real commerce-domain-events topic and needs a scoped credential to
# publish. The account's sqs-manager/sns-manager IAM groups grant
# full-account SQS/SNS management (AmazonSQSFullAccess / AmazonSNSFullAccess)
# and are hand-managed outside this repo — wrong shape for an app identity,
# so relay gets its own least-privilege IAM user instead of group membership.
#
# INTERIM: once relay is containerized as an ECS task def, it gets a task
# role in iam.tf instead (same pattern as aws_iam_role.task), reusing
# local.relay_publish_policy's statement verbatim, and this file is deleted.
# ---------------------------------------------------------------------------

locals {
  relay_publish_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "PublishDomainEvents"
      Effect   = "Allow"
      Action   = "sns:Publish"
      Resource = aws_sns_topic.domain_events.arn
    }]
  })
}

resource "aws_iam_user" "relay_local" {
  name = "commerce-relay-local"
}

resource "aws_iam_user_policy" "relay_publish" {
  name   = "publish-domain-events"
  user   = aws_iam_user.relay_local.name
  policy = local.relay_publish_policy
}

resource "aws_iam_access_key" "relay_local" {
  user = aws_iam_user.relay_local.name
}
