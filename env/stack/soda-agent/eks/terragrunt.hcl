# env/stack/soda-agent/eks/terragrunt.hcl
# EKS cluster configuration (Soda Agent stack)

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "common" {
  path = find_in_parent_folders("common.hcl")
}

locals {
  org         = include.root.locals.org
  env         = include.root.locals.env
  aws_region  = include.root.locals.aws_region
  eks_config  = include.root.locals.eks_config
  common_tags = include.root.locals.common_tags

  cluster_name = "${local.org}-${local.env}-soda-agent-eks"
}

dependency "vpc" {
  config_path  = "../network/vpc"
  skip_outputs = false
  mock_outputs = {
    vpc_id          = "vpc-mock"
    private_subnets = ["subnet-a", "subnet-b", "subnet-c"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependency "sg_ops" {
  config_path  = "../ops/sg-ops"
  skip_outputs = false
  mock_outputs = {
    security_group_id = "sg-mock"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependencies {
  paths = [
    "../network/vpc",
    "../ops/sg-ops",
  ]
}

terraform {
  source = "${include.root.locals.modules_root}/compute/eks/cluster"
}

generate "versions_override" {
  path      = "versions_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-HCL
    terraform {
      required_providers {
        aws = { source = "hashicorp/aws", version = ">= 5.61.0, < 6.0.0" }
      }
    }
  HCL
}

inputs = {
  cluster_name    = local.cluster_name
  cluster_version = "1.31"

  vpc_id                = dependency.vpc.outputs.vpc_id
  subnet_ids            = dependency.vpc.outputs.private_subnets
  ops_security_group_id = dependency.sg_ops.outputs.security_group_id

  enable_irsa = true

  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true
  enable_pod_identity                      = false

  # Environment-specific endpoint access
  cluster_endpoint_public_access  = local.eks_config.cluster_endpoint_public_access
  cluster_endpoint_private_access = true

  # CloudWatch logging configuration
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
  cloudwatch_log_group_retention_in_days = local.eks_config.cloudwatch_log_retention

  # Encryption at rest
  cluster_encryption_config = {
    provider_key_arn = null
    resources        = ["secrets"]
  }

  # Environment-specific node group configuration
  eks_managed_node_groups = {
    ops = {
      name            = "${local.org}-${local.env}-soda-agent-ops-ng"
      use_name_prefix = false
      # Explicit IAM role name to avoid AWS 38-character name_prefix limit
      # The module generates: <name>-eks-node-group- which would be too long
      iam_role_use_name_prefix = false
      iam_role_name            = "${local.org}-${local.env}-soda-ops-ng-role"
      desired_size             = local.eks_config.desired_size
      min_size                 = local.eks_config.min_size
      max_size                 = local.eks_config.max_size
      instance_types           = local.eks_config.instance_types
      capacity_type            = local.eks_config.capacity_type
      ami_type                 = "AL2023_x86_64_STANDARD"

      disk_size = local.eks_config.disk_size
      disk_type = "gp3"

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
        instance_metadata_tags      = "enabled"
      }

      labels = {
        Environment = local.env
        NodeGroup   = "ops"
        ManagedBy   = "terraform"
        Stack       = "soda-agent"
      }

      update_config = {
        max_unavailable_percentage = local.env == "prod" ? 33 : 50
      }
    }
  }

  # Allow ops SG to reach the API
  cluster_security_group_additional_rules = {
    allow_ops_to_api = {
      type                     = "ingress"
      description              = "Allow ops EC2 to reach EKS API"
      protocol                 = "tcp"
      from_port                = 443
      to_port                  = 443
      source_security_group_id = dependency.sg_ops.outputs.security_group_id
    }
  }

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = local.env == "prod" ? "2" : "1"
        }
      })
    }
  }

  tags = merge(local.common_tags, {
    Component = "eks"
    Stack     = "soda-agent"
    Name      = local.cluster_name
  })
}
