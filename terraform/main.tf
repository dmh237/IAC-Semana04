# 1 Variables

variable "environment" {
  description = "Entorno a provisionar: dev, qa o prod"
  type        = string
}

variable "bucket_name" {
  type        = string
  description = "Nombre del bucket S3"
}

variable "tags" {
  type        = map(any)
  description = "Tags globales del proyecto"
}

# 2 Provider AWS

provider "aws" {
  region  = "us-east-2"
  profile = "default" # Cambiar al nombre de tu perfil si usas SSO
}

# 3 Module principal
module "image_processor" {
  source = "./modules/image_processor"

  environment = var.environment
  bucket_name = var.bucket_name
  tags        = var.tags
}