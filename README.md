# IAC-Semana4

Aplicación serverless en AWS que procesa imágenes automáticamente. Recibe imágenes vía HTTP, las almacena en S3 y las recorta de forma circular (40×40 px) de manera asíncrona usando colas SQS.


## Arquitectura

```
Cliente (POST /upload)
   │
   ▼
API Gateway HTTP API v2 (HTTPS, TLS 1.2+, CORS)
   │
   ▼
Upload Lambda (nodejs20.x, 256 MB, 30s) ─── VPC Private Subnet
   │
   ▼
S3 Bucket (uploads/) ── SSE AES-256, Versioning, Lifecycle 30 días
   │
   ▼ (S3 Event Notification)
SQS Queue (visibility 360s, long polling 20s, DLQ after 3 retries)
   │
   ▼ (Event Source Mapping, batch 5)
Crop Lambda (nodejs20.x, 512 MB, 60s) ─── VPC Private Subnet
   │
   ▼
S3 Bucket (processed/) ── Imagen circular 40x40 PNG, Lifecycle 90 días
```

**Infraestructura de Red (VPC):**
- VPC con CIDR 10.0.0.0/16
- 2 Subredes Públicas (10.0.1.0/24, 10.0.2.0/24) con NAT Gateways
- 2 Subredes Privadas (10.0.11.0/24, 10.0.12.0/24) donde se ejecutan las Lambdas
- VPC Endpoint Gateway para S3 (gratuito)
- VPC Endpoint Interface para SQS (Private DNS habilitado)
- Security Groups dedicados por Lambda y por Endpoint

## Requisitos Previos

- **Docker** instalado y corriendo
- **Node.js 20+**
- **AWS CLI** configurado con credenciales válidas
- **Terraform** >= 1.5

## Despliegue

### Paso 1: Configurar Credenciales AWS
```bash
aws configure
# AWS Access Key ID: <tu-access-key>
# AWS Secret Access Key: <tu-secret-key>
# Default region name: us-east-2
# Default output format: json
```

### Paso 2: Compilar Dependencias con Docker
Desde la raíz del proyecto, ejecutar el script que empaqueta las dependencias de Node.js en un entorno idéntico a AWS Lambda:
```bash
./build.sh
```

### Paso 3: Inicializar Terraform
```bash
cd terraform
terraform init
```

> **Nota sobre el empaquetado (.zip):**
> Terraform comprime automáticamente el código de las Lambdas y sus dependencias en archivos `.zip` (`upload.zip`, `crop.zip`) justo antes del despliegue. Esto es un requisito de AWS Lambda. Estos archivos son autogenerados.

### Paso 4: Desplegar en el Entorno Deseado

> **Nota sobre la separación de entornos (DEV, QA, PROD):**
> Esta arquitectura está diseñada bajo las mejores prácticas del curso que se esta llevando a cabo(Infraestuctura como codigo). Se utilizan archivos de variables independientes (`dev`, `qa`, `prod`) para poder desplegar copias idénticas o parametrizadas de la misma arquitectura de forma aislada. Esto garantiza que las pruebas en desarrollo (DEV) o control de calidad (QA) nunca afecten los recursos ni los datos de producción (PROD).

#### Entorno DEV
```bash
terraform plan -var-file="envs/dev/terraform.tfvars"
terraform apply -var-file="envs/dev/terraform.tfvars"
```

#### Entorno QA
```bash
terraform plan -var-file="envs/qa/terraform.tfvars"
terraform apply -var-file="envs/qa/terraform.tfvars"
```

#### Entorno PROD
```bash
terraform plan -var-file="envs/prod/terraform.tfvars"
terraform apply -var-file="envs/prod/terraform.tfvars"
```

Al finalizar el `apply`, Terraform mostrará en consola los outputs con la URL del API Gateway y el nombre del bucket S3.

### Paso 5: Probar el Endpoint
Una vez desplegado, puedes probar subiendo una imagen con `curl`:
```bash
# Usando base64
curl -X POST <API_ENDPOINT>/upload \
  -H "Content-Type: image/jpeg" \
  --data-binary @mi-imagen.jpg

# Usando multipart/form-data
curl -X POST <API_ENDPOINT>/upload \
  -F "file=@mi-imagen.jpg"
```

## Destruir Recursos

**IMPORTANTE:** Para evitar costos innecesarios, destruir todos los recursos de AWS cuando ya no se necesiten:

```bash
cd terraform

# Destruir entorno DEV
terraform destroy -var-file="envs/dev/terraform.tfvars"

# Destruir entorno QA
terraform destroy -var-file="envs/qa/terraform.tfvars"

# Destruir entorno PROD
terraform destroy -var-file="envs/prod/terraform.tfvars"
```

Terraform pedirá confirmación antes de eliminar. Escribir `yes` para confirmar la destrucción de todos los recursos.

## Tecnologías Utilizadas

| Tecnología | Uso |
|------------|-----|
| **Terraform** | Infraestructura como Código (IaC) |
| **Docker** | Compilación de dependencias nativas (sharp) |
| **AWS Lambda** | Ejecución serverless de funciones Node.js 20 |
| **AWS API Gateway v2** | Endpoint HTTP para recibir imágenes |
| **AWS S3** | Almacenamiento de imágenes originales y procesadas |
| **AWS SQS** | Cola de mensajes para procesamiento asíncrono |
| **AWS VPC** | Aislamiento de red para las funciones Lambda |
| **AWS CloudWatch** | Logs y alarmas de monitoreo |
| **AWS SNS** | Notificaciones de alertas de la DLQ |
