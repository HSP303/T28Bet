resource "aws_sqs_queue" "bets" {
  name                       = "${local.name}-bets"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600

  tags = local.common_tags
}

resource "aws_sqs_queue" "settlement" {
  name                       = "${local.name}-settlement"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600

  tags = local.common_tags
}

resource "aws_lambda_event_source_mapping" "gatilho_sqs_settlement" {
  event_source_arn = aws_sqs_queue.settlement.arn
  function_name    = aws_lambda_function.settlement.arn
  batch_size       = 5
}

resource "aws_sns_topic" "app" {
  name = "${local.name}-topic"

  tags = local.common_tags
}
