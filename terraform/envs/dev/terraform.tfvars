   # Entorno de desarrollo: pruebas del equipo
   environment = "dev"

   # El nombre del bucket debe ser único en todo AWS, por eso lleva el entorno y un sufijo del grupo
   bucket_name = "image-processor-dev-images-upao-iac04"

   # Etiquetas para identificar los recursos y sus costos por entorno
   tags = {
     Project     = "image-processor"
     Environment = "dev"
     ManagedBy   = "terraform"
   }