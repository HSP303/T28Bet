resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/containerinsights/${local.name}/application"
  retention_in_days = 7

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "dataplane" {
  name              = "/aws/containerinsights/${local.name}/dataplane"
  retention_in_days = 7

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "sqs_bets_visible_messages_high" {
  alarm_name          = "${local.name}-sqs-bets-visible-messages-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 100

  dimensions = {
    QueueName = aws_sqs_queue.bets.name
  }

  alarm_description  = "Fila SQS de apostas com mais de 100 mensagens visíveis."
  treat_missing_data = "notBreaching"

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "sqs_settlement_visible_messages_high" {
  alarm_name          = "${local.name}-sqs-settlement-visible-messages-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 100

  dimensions = {
    QueueName = aws_sqs_queue.settlement.name
  }

  alarm_description  = "Fila SQS de liquidação com mais de 100 mensagens visíveis."
  treat_missing_data = "notBreaching"

  tags = local.common_tags
}

resource "aws_cloudwatch_log_metric_filter" "application_error_count" {
  name           = "${local.name}-application-error-count"
  log_group_name = aws_cloudwatch_log_group.application.name
  pattern        = "{ $.level = 50 }"

  metric_transformation {
    name          = "${local.name}-application-error-count"
    namespace     = "T28Bet/Application"
    value         = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "application_error_count_high" {
  alarm_name          = "${local.name}-application-error-count-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.application_error_count.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.application_error_count.metric_transformation[0].namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 1

  alarm_description  = "Erros de aplicação detectados nos logs estruturados do backend."
  treat_missing_data = "notBreaching"

  tags = local.common_tags
}
