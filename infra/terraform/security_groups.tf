############################
# Security Group - EKS Control Plane (Cluster)
############################

resource "aws_security_group" "eks_cluster_sg" {
  name        = "${var.project_name}-cluster-sg"
  description = "Security group para el plano de control de EKS"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Salida completa hacia los nodos y a internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-cluster-sg"
  }
}

############################
# Security Group - EKS Worker Nodes
############################

resource "aws_security_group" "eks_nodes_sg" {
  name        = "${var.project_name}-nodes-sg"
  description = "Security group para los nodos worker de EKS"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name                                                = "${var.project_name}-nodes-sg"
    "kubernetes.io/cluster/${var.project_name}-cluster" = "owned"
  }
}

# Los nodos pueden hablar entre ellos (pods, DNS interno, etc.)
resource "aws_security_group_rule" "nodes_self_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_nodes_sg.id
  source_security_group_id = aws_security_group.eks_nodes_sg.id
}

# El control plane necesita hablar con los nodos (kubelet, webhooks, etc.)
resource "aws_security_group_rule" "cluster_to_nodes_ingress" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes_sg.id
  source_security_group_id = aws_security_group.eks_cluster_sg.id
}

# Los nodos necesitan hablar con el control plane (API server, puerto 443)
resource "aws_security_group_rule" "nodes_to_cluster_ingress" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster_sg.id
  source_security_group_id = aws_security_group.eks_nodes_sg.id
}

# Tráfico HTTP/HTTPS desde internet hacia el frontend (LoadBalancer -> nodos)
resource "aws_security_group_rule" "nodes_http_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_nodes_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "nodes_https_ingress" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_nodes_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# Rango de NodePort de Kubernetes, necesario para servicios tipo LoadBalancer/NodePort
resource "aws_security_group_rule" "nodes_nodeport_ingress" {
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_nodes_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# Salida completa de los nodos (pull de imágenes ECR, DNS, internet, etc.)
resource "aws_security_group_rule" "nodes_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.eks_nodes_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}