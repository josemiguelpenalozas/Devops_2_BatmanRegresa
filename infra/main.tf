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

############################
# VPC
############################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Subred pública: donde corren los contenedores ECS (accesibles desde internet)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
}

# Subred privada: donde vive la EC2 con MySQL (NO accesible desde internet)
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}a"
}

# Internet Gateway: puerta de salida/entrada para la subred pública
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# Tabla de rutas pública
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Tabla de rutas privada: sin salida a internet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# S3 Gateway Endpoint (gratis): permite que yum funcione en la subred privada
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.main.id
  service_name    = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = [aws_route_table.private.id]
}

############################
# SECURITY GROUPS
############################

# SG para los contenedores ECS
resource "aws_security_group" "ecs" {
  name   = "${var.project_name}-sg-ecs"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "Frontend"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Backend Ventas"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Backend Despachos"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# SG para la EC2 MySQL
resource "aws_security_group" "db" {
  name   = "${var.project_name}-sg-db"
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Regla separada: solo ECS puede hablar con MySQL
resource "aws_security_group_rule" "mysql_from_ecs" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = aws_security_group.ecs.id
  description              = "MySQL solo desde ECS"
}

############################
# ECR (3 repositorios)
############################

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

############################
# EC2 MySQL (subred privada)
############################

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "db" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.db.id]
  key_name               = var.key_pair_name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y mysql-server
    systemctl start mysqld
    systemctl enable mysqld

    until mysqladmin ping -u root --silent 2>/dev/null; do
      sleep 2
    done

    mysql -u root <<-EOSQL
      CREATE DATABASE IF NOT EXISTS ${var.db_name_ventas};
      CREATE DATABASE IF NOT EXISTS ${var.db_name_despachos};
      CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${var.db_password}';
      GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
      ALTER USER 'root'@'localhost' IDENTIFIED BY '${var.db_password}';
      FLUSH PRIVILEGES;
    EOSQL

    echo "[mysqld]" >> /etc/my.cnf
    echo "bind-address = 0.0.0.0" >> /etc/my.cnf
    systemctl restart mysqld
  EOF

  tags = {
    Name = "${var.project_name}-mysql"
  }
}

############################
# CLOUDWATCH LOGS
############################

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7
}

############################
# ECS CLUSTER
############################

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

data "aws_iam_role" "lab" {
  name = "LabRole"
}

############################
# TASK DEFINITION
############################

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "3072"
  execution_role_arn       = data.aws_iam_role.lab.arn

  container_definitions = jsonencode([

    {
      name  = "backend-ventas"
      image = "${aws_ecr_repository.backend_ventas.repository_url}:latest"

      portMappings = [{ containerPort = 8080 }]

      environment = [
        { name = "DB_ENDPOINT", value = aws_instance.db.private_ip },
        { name = "DB_PORT",     value = "3306" },
        { name = "DB_NAME",     value = var.db_name_ventas },
        { name = "DB_USERNAME", value = "root" },
        { name = "DB_PASSWORD", value = var.db_password }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "backend-ventas"
        }
      }
    },

    {
      name  = "backend-despachos"
      image = "${aws_ecr_repository.backend_despachos.repository_url}:latest"

      portMappings = [{ containerPort = 8081 }]

      environment = [
        { name = "DB_ENDPOINT", value = aws_instance.db.private_ip },
        { name = "DB_PORT",     value = "3306" },
        { name = "DB_NAME",     value = var.db_name_despachos },
        { name = "DB_USERNAME", value = "root" },
        { name = "DB_PASSWORD", value = var.db_password }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "backend-despachos"
        }
      }
    },

    {
      name  = "frontend"
      image = "${aws_ecr_repository.frontend.repository_url}:latest"

      portMappings = [{ containerPort = 80 }]

      dependsOn = [
        { containerName = "backend-ventas",    condition = "START" },
        { containerName = "backend-despachos", condition = "START" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "frontend"
        }
      }
    }

  ])
}

############################
# ECS SERVICE
############################

resource "aws_ecs_service" "app" {
  name            = "app"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  force_new_deployment               = true
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }
}
