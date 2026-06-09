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
  }

  # El cluster depende de que la VPC y subnets estén listas
  depends_on = [
    aws_subnet.public_a,
    aws_subnet.public_b,
  ]
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

  instance_types = ["t3.medium"]
  capacity_type  = "ON_DEMAND"
}
