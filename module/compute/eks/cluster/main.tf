# EKS Cluster Module
# Wraps terraform-aws-modules/eks/aws and provides standardized outputs

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.61.0"
    }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.24.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = var.vpc_id
  subnet_ids      = var.subnet_ids

  cluster_additional_security_group_ids = var.ops_security_group_id != null ? [var.ops_security_group_id] : []

  enable_irsa                            = var.enable_irsa
  authentication_mode                    = var.authentication_mode
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
  cluster_endpoint_public_access         = var.cluster_endpoint_public_access
  cluster_endpoint_private_access        = var.cluster_endpoint_private_access
  cluster_enabled_log_types              = var.cluster_enabled_log_types
  cloudwatch_log_group_retention_in_days = var.cloudwatch_log_group_retention_in_days
  cluster_encryption_config              = var.cluster_encryption_config
  eks_managed_node_groups                = var.eks_managed_node_groups
  cluster_addons                          = var.cluster_addons
  cluster_security_group_additional_rules = var.cluster_security_group_additional_rules
  node_security_group_additional_rules    = var.node_security_group_additional_rules
  tags                                    = var.tags
}
