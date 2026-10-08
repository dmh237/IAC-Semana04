# 1 S3 Bucket

resource "aws_s3_bucket" "images" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = merge(var.tags, {
    Name = "${var.environment}-images-bucket"
  })
}

# Versión moderna de encryption (REEMPLAZA el bloque deprecated)
resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versioning separado (moderno)
resource "aws_s3_bucket_versioning" "images" {
  bucket = aws_s3_bucket.images.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle rules modernos
resource "aws_s3_bucket_lifecycle_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    id     = "uploads-expire"
    status = "Enabled"

    filter {
      prefix = "uploads/"
    }

    expiration {
      days = 30
    }
  }

  rule {
    id     = "processed-expire"
    status = "Enabled"

    filter {
      prefix = "processed/"
    }

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2 SQS (main + DLQ)

resource "aws_sqs_queue" "dlq" {
  name = "${var.environment}-images-dlq"

  message_retention_seconds  = 1209600
  visibility_timeout_seconds = 30

  tags = merge(var.tags, {
    Name = "${var.environment}-dlq"
  })
}

resource "aws_sqs_queue" "main" {
  name = "${var.environment}-images-queue"

  visibility_timeout_seconds = 360
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })

  tags = merge(var.tags, {
    Name = "${var.environment}-queue"
  })
}

# 3 Lambda Functions

# ---- Upload ZIP ----
data "archive_file" "upload_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda/upload"
  output_path = "${path.module}/upload.zip"
}

resource "aws_lambda_function" "upload" {
  function_name = "${var.environment}-upload-lambda"
  role          = aws_iam_role.upload_lambda_role.arn

  runtime = "nodejs20.x"
  handler = "index.handler"

  timeout     = 30
  memory_size = 256

  filename         = data.archive_file.upload_zip.output_path
  source_code_hash = data.archive_file.upload_zip.output_base64sha256

  environment {
    variables = {
      BUCKET        = aws_s3_bucket.images.bucket
      UPLOAD_PREFIX = "uploads/"
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.upload_lambda.id]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-upload-lambda"
  })
}

# ---- Crop ZIP ----
data "archive_file" "crop_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda/crop"
  output_path = "${path.module}/crop.zip"
}

resource "aws_lambda_function" "crop" {
  function_name = "${var.environment}-crop-lambda"
  role          = aws_iam_role.crop_lambda_role.arn

  runtime = "nodejs20.x"
  handler = "index.handler"

  timeout     = 60
  memory_size = 512

  filename         = data.archive_file.crop_zip.output_path
  source_code_hash = data.archive_file.crop_zip.output_base64sha256

  environment {
    variables = {
      BUCKET           = aws_s3_bucket.images.bucket
      PROCESSED_PREFIX = "processed/"
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.crop_lambda.id]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-crop-lambda"
  })
}

# 4 API Gateway

resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.environment}-image-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers = ["*"]
    allow_methods = ["POST"]
    allow_origins = ["*"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-http-api"
  })
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = 10000
    throttling_burst_limit = 5000
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw_logs.arn

    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }
}

resource "aws_apigatewayv2_integration" "upload_proxy" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.upload.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "upload_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.upload_proxy.id}"
}

# Permiso para que API Gateway invoque la Lambda de upload
resource "aws_lambda_permission" "apigw_invoke_upload" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
