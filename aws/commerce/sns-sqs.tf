# ---------------------------------------------------------------------------
# Event backbone (ADR-018, commerce-api#130) — first slice.
#
# One SNS topic carries every domain event; each consumer gets its own SQS
# queue subscribed with a filter policy on the `event_type` message attribute.
# This file provisions the messaging plane only (topic + one queue + its DLQ +
# subscription). It does NOT provision compute for relay/notifier — relay is
# being run locally against these real resources first ("walking skeleton");
# an ECS task def + IAM task role for relay is a follow-up once it's
# containerized, same pattern as iam.tf's task role for api/utils.
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "domain_events" {
  name = "commerce-domain-events"
}

# Dead-letter queue for the notifications consumer. A message lands here after
# maxReceiveCount deliveries without a DeleteMessage — i.e. the consumer keeps
# failing it. Nothing drains this automatically; per ADR-018 a CloudWatch
# alarm on depth > 0 is the intended follow-up (ADR-019 Phase 1).
resource "aws_sqs_queue" "notifications_dlq" {
  name = "commerce-notifications-dlq"
}

resource "aws_sqs_queue" "notifications" {
  name = "commerce-notifications-queue"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notifications_dlq.arn
    maxReceiveCount     = 5
  })
}

# SNS can only deliver into an SQS queue if the queue's own policy allows it —
# subscribing them to each other is not enough. Scoped to exactly this topic
# via the SourceArn condition (otherwise any SNS topic in the account, or
# another account, could publish into it).
resource "aws_sqs_queue_policy" "notifications_allow_sns" {
  queue_url = aws_sqs_queue.notifications.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowSNSDelivery"
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.notifications.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_sns_topic.domain_events.arn }
      }
    }]
  })
}

# Raw delivery on: the SQS message body is the bare event envelope, not an SNS
# wrapper JSON blob. Filter policy means this queue only ever receives
# OrderPlaced — additional event types (OrderShipped, ...) get their own
# queue + filter later; the topic and relay never change (ADR-018).
resource "aws_sns_topic_subscription" "notifications" {
  topic_arn            = aws_sns_topic.domain_events.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.notifications.arn
  raw_message_delivery = true

  filter_policy = jsonencode({
    event_type = ["OrderPlaced"]
  })
}
