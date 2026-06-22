resource "aws_sqs_queue" "bets" {
  name                       = "${local.name}-bets"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600

  tags = local.common_tags
}

resource "aws_sqs_queue" "settlement" {
  name                       = "${local.name}-settlement"
  visibility_timeout_seconds = 330
  message_retention_seconds  = 345600

  tags = local.common_tags
}

resource "aws_sns_topic" "app" {
  name = "${local.name}-topic"

  tags = local.common_tags
}
