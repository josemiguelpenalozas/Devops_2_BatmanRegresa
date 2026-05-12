terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_ecr_repository" "backend_ventas" {
  name         = "${var.project_name}-backend-ventas"
  force_delete = true
}

resource "aws_ecr_repository" "backend_despachos" {
  name         = "${var.project_name}-backend-despachos"
  force_delete = true
}

resource "aws_ecr_repository" "frontend" {
  name         = "${var.project_name}-frontend"
  force_delete = true
}