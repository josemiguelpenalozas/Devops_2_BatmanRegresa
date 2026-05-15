output "backend_ventas_ecr_url" {
  value = aws_ecr_repository.backend_ventas.repository_url
}

output "backend_despachos_ecr_url" {
  value = aws_ecr_repository.backend_despachos.repository_url
}

output "frontend_ecr_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "ec2_private_ip" {
  value       = aws_instance.db.private_ip
  description = "IP privada de la EC2 con MySQL (solo accesible desde la VPC)"
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}
