############################
# ECR — Repositorios de imágenes Docker
############################

resource "aws_ecr_repository" "backend_ventas" {
  name         = "${var.project_name}-backend-ventas"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "backend_despachos" {
  name         = "${var.project_name}-backend-despachos"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "frontend" {
  name         = "${var.project_name}-frontend"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}
