# terraform/modules/image_processor/outputs.tf
output "api_endpoint" {
  description = "URL pública del HTTP API (POST /upload)"
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}

output "bucket_name" {
  description = "Nombre del bucket S3 donde se guardan las imágenes"
  value       = aws_s3_bucket.images.id
}

output "upload_lambda_name" {
  description = "Nombre de la Lambda de subida"
  value       = aws_lambda_function.upload.function_name
}

output "crop_lambda_name" {
  description = "Nombre de la Lambda de recorte"
  value       = aws_lambda_function.crop.function_name
}

output "sqs_queue_url" {
  description = "URL de la cola principal (SQS) que dispara crop‑lambda"
  value       = aws_sqs_queue.main.id
}