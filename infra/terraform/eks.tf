############################
# EKS Cluster
############################

resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-cluster"
  role_arn = data.aws_iam_role.labrole.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.public_a.id,
      aws_subnet.public_b.id
    ]
    security_group_ids = [aws_security_group.eks_cluster_sg.id]
  }

  # El cluster depende de que la VPC y subnets estén listas
  depends_on = [
    aws_subnet.public_a,
    aws_subnet.public_b,
  ]
}

############################
# Launch Template - Worker Nodes
############################

resource "aws_launch_template" "workers_lt" {
  name_prefix   = "${var.project_name}-workers-"
  instance_type = "t3.medium"

  vpc_security_group_ids = [aws_security_group.eks_nodes_sg.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-worker-node"
    }
  }
}

############################
# EKS Node Group (Workers)
############################

resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "workers"
  node_role_arn   = data.aws_iam_role.labrole.arn

  subnet_ids = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 4
  }

  launch_template {
    id      = aws_launch_template.workers_lt.id
    version = "$Latest"
  }

  capacity_type = "ON_DEMAND"

  depends_on = [aws_launch_template.workers_lt]
}