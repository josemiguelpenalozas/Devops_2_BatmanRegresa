output "backend_ventas_ecr" {
  value = aws_ecr_repository.backend_ventas.repository_url
}

output "backend_despachos_ecr" {
  value = aws_ecr_repository.backend_despachos.repository_url
}

output "frontend_ecr" {
  value = aws_ecr_repository.frontend.repository_url
}