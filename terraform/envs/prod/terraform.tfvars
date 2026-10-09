# Entorno de producción: versión final para los usuarios
environment = "prod"

# El nombre del bucket debe ser único en todo AWS, por eso lleva el entorno y un sufijo del grupo
bucket_name = "image-processor-prod-images-upao-iac04"

# Etiquetas para identificar los recursos y sus costos por entorno
tags = {
  Project     = "image-processor"
  Environment = "prod"
  ManagedBy   = "terraform"
}