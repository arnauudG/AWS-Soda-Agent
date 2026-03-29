# env/stack/soda-agent/eks/ops-ec2-eks-access/terragrunt.hcl
# EKS Access configuration - grants ops EC2 instance access to EKS cluster (Soda Agent stack)

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "common" {
  path = find_in_parent_folders("common.hcl")
}

locals {
  org        = include.root.locals.org
  env        = include.root.locals.env
  aws_region = include.root.locals.aws_region
}

dependency "eks" {
  config_path  = ".."
  skip_outputs = false
  mock_outputs = {
    cluster_name = "mock-cluster"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependency "ec2_ops" {
  config_path  = "../../ops/ec2-ops"
  skip_outputs = false
  mock_outputs = {
    iam_role_name = "mock-role"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependencies {
  paths = [
    "..",
    "../../ops/ec2-ops"
  ]
}

terraform {
  source = "${include.root.locals.modules_root}/security/iam/ops-eks-access"
}

inputs = {
  region       = local.aws_region
  cluster_name = dependency.eks.outputs.cluster_name
  role_name    = dependency.ec2_ops.outputs.iam_role_name
  policy_name  = "${local.org}-${local.env}-soda-agent-ops-eks-describe"
}
