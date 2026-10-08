#!/bin/bash
set -e

echo "Empaquetando Lambdas con Docker (Amazon Linux)"

# Imagen oficial de AWS para construir entornos Node.js 20.x idénticos a Lambda
BUILD_IMAGE="public.ecr.aws/sam/build-nodejs20.x:latest"

echo "1  Construyendo dependencias para Upload Lambda..."
# -v monta el directorio actual dentro del contenedor
# --rm elimina el contenedor al terminar
docker run --rm \
  -v "$PWD/lambda/upload":/var/task \
  -w /var/task \
  $BUILD_IMAGE \
  npm install --production

echo ""
echo "2  Construyendo dependencias para Crop Lambda (sharp)..."
docker run --rm \
  -v "$PWD/lambda/crop":/var/task \
  -w /var/task \
  $BUILD_IMAGE \
  npm install --production

echo ""
echo "Construcción completada exitosamente."
echo "Las dependencias (node_modules) ahora están listas para Amazon Linux."
echo "Ya puedes ejecutar Terraform para subir la infraestructura."
