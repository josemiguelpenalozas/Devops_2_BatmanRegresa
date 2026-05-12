variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "batman"
}

variable "key_pair_name" {
  description = "Nombre del Key Pair de AWS para la EC2 (creado manualmente en la consola)"
}

variable "db_password" {
  description = "Contraseña de MySQL"
  sensitive   = true
}

variable "db_name_ventas" {
  default = "ventas_db"
}

variable "db_name_despachos" {
  default = "despachos_db"
}
