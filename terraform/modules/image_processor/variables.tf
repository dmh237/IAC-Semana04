# terraform/modules/image_processor/variables.tf
variable "environment" {
  description = "Nombre del entorno (dev, qa, prod)"
  type        = string
}

variable "bucket_name" {
  description = "Nombre único del bucket S3 donde se almacenan las imágenes"
  type        = string
}

variable "tags" {
  description = "Mapa de etiquetas que se aplicará a todos los recursos"
  type        = map(string)
  default     = {}
}