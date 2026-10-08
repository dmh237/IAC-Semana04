terraform {
  # backend "s3" {
  #   bucket         = "image-processor-tfstate"
  #   key            = "global/terraform.tfstate"
  #   region         = "us-east-2"
  #   encrypt        = true
  #   dynamodb_table = "image-processor-lock"
  # }

  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}