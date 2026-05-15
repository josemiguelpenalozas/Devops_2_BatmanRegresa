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

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Subred pública A: donde corren los contenedores ECS
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-a"
  }
}

# Subred pública B: segunda zona para ECS
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-b"
  }
}

# Subred privada: donde vive la EC2 con MySQL
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-private"
  }
}

# Internet Gateway: puerta de salida/entrada para la subred pública
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# EIP para el NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

# NAT Gateway: permite que la subred privada acceda a internet (para descargar Docker image)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "${var.project_name}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# Tabla de rutas pública
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-rt-public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Tabla de rutas privada: sale a internet via NAT Gateway (necesario para docker pull)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-rt-private"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
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
# Usa Docker en lugar de instalar mysql-server directamente,
# ya que mysql-server no está disponible en los repos de AL2023.
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
    set -xe
    exec > /var/log/user-data.log 2>&1

    dnf update -y
    dnf install -y docker --allowerasing

    systemctl start docker
    systemctl enable docker

    # Esperar a que Docker esté listo
    until docker info > /dev/null 2>&1; do
      echo "Esperando Docker..."
      sleep 3
    done

    # Levantar MySQL como contenedor
    docker run -d \
      --name mysql \
      -e MYSQL_ROOT_PASSWORD="${var.db_password}" \
      -e MYSQL_ROOT_HOST=% \
      -p 3306:3306 \
      --log-opt max-size=10m \
      --log-opt max-file=3 \
      --restart unless-stopped \
      mysql:8 \
      --bind-address=0.0.0.0 \
      --performance-schema=OFF

    echo "Esperando que MySQL esté listo..."
    sleep 20

    until docker exec mysql mysqladmin ping -uroot -p"${var.db_password}" --silent 2>/dev/null; do
      echo "MySQL aún no responde, esperando..."
      sleep 5
    done

    echo "MySQL listo. Creando bases de datos..."

    docker exec mysql mysql -uroot -p"${var.db_password}" -e "
      CREATE DATABASE IF NOT EXISTS ${var.db_name_ventas};
      CREATE DATABASE IF NOT EXISTS ${var.db_name_despachos};
      CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${var.db_password}';
      GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
      FLUSH PRIVILEGES;
    "

    echo "Script finalizado correctamente"
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

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health/readiness || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 5
        startPeriod = 120
      }

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

      restartPolicy = {
        enabled              = true
        ignoredExitCodes     = []
        restartAttemptPeriod = 60
      }
    },

    {
      name  = "backend-despachos"
      image = "${aws_ecr_repository.backend_despachos.repository_url}:latest"

      portMappings = [{ containerPort = 8081 }]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8081/actuator/health/readiness || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 5
        startPeriod = 120
      }

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

      restartPolicy = {
        enabled              = true
        ignoredExitCodes     = []
        restartAttemptPeriod = 60
      }
    },

    {
      name  = "frontend"
      image = "${aws_ecr_repository.frontend.repository_url}:latest"

      portMappings = [{ containerPort = 80 }]

      dependsOn = [
        { containerName = "backend-ventas",    condition = "HEALTHY" },
        { containerName = "backend-despachos", condition = "HEALTHY" }
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
    subnets          = [aws_subnet.public.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }
}
