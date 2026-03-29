# env/stack/soda-agent/network/vpc/terragrunt.hcl
# VPC configuration for Soda Agent stack

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
  common_tags = include.root.locals.common_tags
  vpc_config  = include.root.locals.vpc_config

  prefix = "${local.org}-${local.env}-${local.aws_region}-soda-agent"
}

dependencies {
  paths = ["../../bootstrap"]
}

terraform {
  source = "${include.root.locals.modules_root}/network/vpc"
}

inputs = {
  name = "${local.prefix}-vpc"
  cidr = try(local.vpc_config.soda_agent_cidr, local.vpc_config.cidr)

  azs = ["${local.aws_region}a", "${local.aws_region}b", "${local.aws_region}c"]
  # Optimized subnet sizing: /22 = 1024 IPs per subnet (sufficient for EKS and workloads)
  public_subnets = [
    cidrsubnet(try(local.vpc_config.soda_agent_cidr, local.vpc_config.cidr), 6, 0), # x.x.0.0/22
    cidrsubnet(try(local.vpc_config.soda_agent_cidr, local.vpc_config.cidr), 6, 1), # x.x.4.0/22
    cidrsubnet(try(local.vpc_config.soda_agent_cidr, local.vpc_config.cidr), 6, 2)  # x.x.8.0/22
  ]
  private_subnets = [
    cidrsubnet(try(local.vpc_config.soda_agent_cidr, local.vpc_config.cidr), 6, 3), # x.x.12.0/22
    cidrsubnet(try(local.vpc_config.soda_agent_cidr, local.vpc_config.cidr), 6, 4), # x.x.16.0/22
    cidrsubnet(try(local.vpc_config.soda_agent_cidr, local.vpc_config.cidr), 6, 5)  # x.x.20.0/22
  ]

  enable_nat_gateway   = true
  single_nat_gateway   = local.vpc_config.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs - environment-specific
  # Note: Only enable_flow_log is supported by the VPC module
  # Additional flow log configuration (CloudWatch Logs, IAM roles, etc.) would need to be added to the module
  enable_flow_log = local.vpc_config.enable_flow_log

  # VPC tags
  vpc_tags = {
    Name = "${local.prefix}-vpc"
  }

  # Internet Gateway
  igw_tags = {
    Name = "${local.prefix}-igw"
  }

  # NAT Gateway(s)
  nat_gateway_tags = merge(local.common_tags, {
    Name      = "${local.prefix}-natgw"
    Component = "network"
  })

  # EIP(s) for NAT Gateway(s)
  nat_eip_tags = merge(local.common_tags, {
    Name      = "${local.prefix}-eip-nat"
    Component = "network"
  })

  # Public subnets + their route tables
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  public_subnet_names = [
    "${local.prefix}-public-a",
    "${local.prefix}-public-b",
    "${local.prefix}-public-c",
  ]
  public_route_table_tags = {
    Name = "${local.prefix}-rt-public"
  }

  # Private subnets + their route tables
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
  private_subnet_names = [
    "${local.prefix}-private-a",
    "${local.prefix}-private-b",
    "${local.prefix}-private-c",
  ]
  private_route_table_tags = {
    Name = "${local.prefix}-rt-private"
  }

  # Default Security Group - restrict to deny all by default
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []
  default_security_group_name    = "${local.prefix}-default-sg"
  default_security_group_tags = {
    Name        = "${local.prefix}-default-sg"
    Description = "Default security group for ${local.prefix}-vpc - all traffic denied by default"
  }

  # Base tags
  tags = merge(local.common_tags, {
    Component = "network"
    Stack     = "soda-agent"
    Name      = "${local.prefix}-vpc"
  })
}
