data "archive_file" "lambda_notification_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/notification/conv"
  output_path = "${path.module}/lambda_notification.zip"
}

data "archive_file" "lambda_settlement_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/settlement/conv"
  output_path = "${path.module}/lambda_settlement.zip"
}

data "archive_file" "mongoose_layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/settlement/layer-mongoose/nodejs"
  output_path = "${path.module}/mongoose_layer.zip"
}

data "external" "mongo_lb" {
  program = ["bash", "${path.module}/scripts/get-mongo-lb.sh", "t28bet", "mongo-lb-svc"]

  depends_on = [kubernetes_service_v1.mongo_lambda]
}

resource "kubernetes_service_v1" "mongo_lambda" {
  metadata {
    name      = "mongo-lb-svc"
    namespace = "t28bet"

    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internal"
      "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = "mongo"
    }

    port {
      port        = 27017
      target_port = 27017
      protocol    = "TCP"
    }
  }

  wait_for_load_balancer = true
}

resource "aws_security_group" "lambda_settlement" {
  name        = "${local.name}-lambda-settlement"
  description = "Security group for settlement Lambda"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_lambda_layer_version" "mongoose_layer" {
  filename            = data.archive_file.mongoose_layer_zip.output_path
  layer_name          = "${local.name}-mongoose-layer"
  description         = "Layer com mongoose para as funcoes do sistema"
  compatible_runtimes = ["nodejs20.x"]
  source_code_hash    = data.archive_file.mongoose_layer_zip.output_base64sha256
}

resource "aws_lambda_function" "settlement" {
  filename         = data.archive_file.lambda_settlement_zip.output_path
  function_name    = "${local.name}-settlement"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "handler.handler"
  runtime          = "nodejs20.x"
  memory_size      = 256
  timeout          = 300
  source_code_hash = data.archive_file.lambda_settlement_zip.output_base64sha256
  layers           = [aws_lambda_layer_version.mongoose_layer.arn]

  vpc_config {
    subnet_ids         = values(aws_subnet.private)[*].id
    security_group_ids = [aws_security_group.lambda_settlement.id]
  }

  environment {
    variables = {
      MONGO_URI             = format("mongodb://%s:27017/t28bet", try(data.external.mongo_lb.result.hostname, ""))
      SNS_RESULTS_TOPIC_ARN = aws_sns_topic.app.arn
    }
  }
}

resource "aws_lambda_event_source_mapping" "settlement_queue" {
  event_source_arn = aws_sqs_queue.settlement.arn
  function_name    = aws_lambda_function.settlement.arn
  batch_size       = 1
  enabled          = true
}

resource "aws_lambda_function" "notification" {
  filename         = data.archive_file.lambda_notification_zip.output_path
  function_name    = "${local.name}-notification"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "handler.handler"
  runtime          = "nodejs20.x"
  memory_size      = 128
  timeout          = 30
  source_code_hash = data.archive_file.lambda_notification_zip.output_base64sha256
}

resource "aws_lambda_permission" "allow_sns_invoke_notification" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notification.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.app.arn
}

resource "aws_sns_topic_subscription" "notification_lambda" {
  topic_arn = aws_sns_topic.app.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.notification.arn

  depends_on = [aws_lambda_permission.allow_sns_invoke_notification]
}
