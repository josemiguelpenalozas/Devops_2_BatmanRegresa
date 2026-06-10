output "backend_ventas_ecr_url" {
  value = aws_ecr_repository.backend_ventas.repository_url
}

output "backend_despachos_ecr_url" {
  value = aws_ecr_repository.backend_despachos.repository_url
}

output "frontend_ecr_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}