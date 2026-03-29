terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Helpful for non-standard partitions too
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

# Resolve the existing role (created by ec2-ops)
data "aws_iam_role" "ops" {
  name = var.role_name
}

locals {
  cluster_arn = "arn:${data.aws_partition.current.partition}:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
}

# Minimal policy so the instance can run:
# - aws eks update-kubeconfig (DescribeCluster)
# - discovery helpers (ListClusters)
resource "aws_iam_policy" "eks_manage" {
  name        = var.policy_name
  description = "Allow EKS describe/list for kubeconfig"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "EksDescribeCluster",
        Effect   = "Allow",
        Action   = ["eks:DescribeCluster"],
        Resource = local.cluster_arn
      },
      {
        Sid      = "EksListClusters",
        Effect   = "Allow",
        Action   = ["eks:ListClusters"],
        Resource = "*"
      }
    ]
  })
  tags = {
    Terraform = "true"
    Component = "ops-access"
  }
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = data.aws_iam_role.ops.name
  policy_arn = aws_iam_policy.eks_manage.arn
}