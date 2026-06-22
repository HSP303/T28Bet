data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# ------------------ Criando a função lambda de notification ------------------
data "archive_file" "lambda_notification_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/notification/conv"
  output_path = "${path.module}/lambda_notification.zip"
}

resource "aws_lambda_function" "notification" {
  filename      = data.archive_file.lambda_notification_zip.output_path
  function_name = "funcao-notification"
  role          = data.aws_iam_role.lab_role.arn

  handler       = "handler.handler" 
  runtime       = "nodejs22.x"

  source_code_hash = data.archive_file.lambda_notification_zip.output_base64sha256
}


# ------------------ Criando a função lambda de settlement ------------------
data "archive_file" "lambda_settlement_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/settlement/conv"
  output_path = "${path.module}/lambda_settlement.zip"
}

resource "aws_lambda_function" "settlement" {
  filename      = data.archive_file.lambda_settlement_zip.output_path
  function_name = "funcao-settlement"
  role          = data.aws_iam_role.lab_role.arn

  handler       = "handler.handler" 
  runtime       = "nodejs22.x"

	layers = [aws_lambda_layer_version.mongoose_layer.arn]

  source_code_hash = data.archive_file.lambda_settlement_zip.output_base64sha256

  memory_size = 256

	vpc_config {
    subnet_ids = values(aws_subnet.private)[*].id

    security_group_ids = [
      aws_security_group.lambda.id
    ]
  }

	environment {
    variables = {
      SNS_RESULTS_TOPIC_ARN    = aws_sns_topic.app.arn
			SQS_SETTLEMENT_QUEUE_URL = aws_sqs_queue.settlement.url
			MONGO_URI                = var.mongodb_uri
		}
  }
}

# Criando as layers
data "archive_file" "layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/settlement/layer-mongoose"
  output_path = "${path.module}/mongoose_layer.zip"
}

resource "aws_lambda_layer_version" "mongoose_layer" {
  filename            = data.archive_file.layer_zip.output_path
  layer_name          = "mongoose-layer"
  description         = "Layer contendo o Mongoose para as funcoes do sistema"
  
  compatible_runtimes = ["nodejs22.x"]

  source_code_hash    = data.archive_file.layer_zip.output_base64sha256
}

# tal do seguro grupo
resource "aws_security_group" "lambda" {
  name        = "${local.name}-lambda-sg"
  description = "Security Group da Lambda Settlement"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}