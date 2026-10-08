# terraform/modules/image_processor/iam.tf
resource "aws_iam_role" "upload_lambda_role" {
  name = "${var.environment}-upload-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "${var.environment}-upload-lambda-role" })
}

resource "aws_iam_role" "crop_lambda_role" {
  name = "${var.environment}-crop-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "${var.environment}-crop-lambda-role" })
}

/* ---- Política básica de ejecución (logs en CloudWatch) y VPC ---- */
resource "aws_iam_policy_attachment" "upload_basic_execution" {
  name       = "${var.environment}-upload-basic-exec"
  roles      = [aws_iam_role.upload_lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_policy_attachment" "crop_basic_execution" {
  name       = "${var.environment}-crop-basic-exec"
  roles      = [aws_iam_role.crop_lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy_attachment" "upload_vpc_access" {
  name       = "${var.environment}-upload-vpc-access"
  roles      = [aws_iam_role.upload_lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}
resource "aws_iam_policy_attachment" "crop_vpc_access" {
  name       = "${var.environment}-crop-vpc-access"
  roles      = [aws_iam_role.crop_lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

/* ---- Permisos S3 para la lambda de upload ---- */
resource "aws_iam_policy" "upload_s3_put" {
  name = "${var.environment}-upload-s3-put"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${aws_s3_bucket.images.arn}/uploads/*"
    }]
  })
}
resource "aws_iam_policy_attachment" "upload_s3_attach" {
  name       = "${var.environment}-upload-s3-attach"
  roles      = [aws_iam_role.upload_lambda_role.name]
  policy_arn = aws_iam_policy.upload_s3_put.arn
}

/* ---- Permisos S3 + SQS para la lambda de crop ---- */
resource "aws_iam_policy" "crop_s3" {
  name = "${var.environment}-crop-s3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.images.arn}/uploads/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.images.arn}/processed/*"
      }
    ]
  })
}
resource "aws_iam_policy_attachment" "crop_s3_attach" {
  name       = "${var.environment}-crop-s3-attach"
  roles      = [aws_iam_role.crop_lambda_role.name]
  policy_arn = aws_iam_policy.crop_s3.arn
}

/* ---- Permisos SQS (receive, delete, visibility) ---- */
resource "aws_iam_policy" "crop_sqs" {
  name = "${var.environment}-crop-sqs"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ChangeMessageVisibility",
        "sqs:GetQueueUrl"
      ]
      Resource = aws_sqs_queue.main.arn
    }]
  })
}
resource "aws_iam_policy_attachment" "crop_sqs_attach" {
  name       = "${var.environment}-crop-sqs-attach"
  roles      = [aws_iam_role.crop_lambda_role.name]
  policy_arn = aws_iam_policy.crop_sqs.arn
}