# Entorno de control de calidad: pruebas antes de pasar a producción
environment = "qa"

# El nombre del bucket debe ser único en todo AWS, por eso lleva el entorno y un sufijo del grupo
bucket_name = "image-processor-qa-images-upao-iac04"

# Etiquetas para identificar los recursos y sus costos por entorno
tags = {
  Project     = "image-processor"
  Environment = "qa"
  ManagedBy   = "terraform"
}