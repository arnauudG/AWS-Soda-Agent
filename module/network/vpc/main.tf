# VPC Network Module
# Wraps terraform-aws-modules/vpc/aws and provides standardized outputs

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = var.name
  cidr = var.cidr

  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  enable_flow_log      = var.enable_flow_log

  vpc_tags                     = var.vpc_tags
  igw_tags                     = var.igw_tags
  nat_gateway_tags             = var.nat_gateway_tags
  nat_eip_tags                 = var.nat_eip_tags
  public_subnet_tags           = var.public_subnet_tags
  public_subnet_names          = var.public_subnet_names
  public_route_table_tags      = var.public_route_table_tags
  private_subnet_tags          = var.private_subnet_tags
  private_subnet_names         = var.private_subnet_names
  private_route_table_tags     = var.private_route_table_tags
  manage_default_security_group = var.manage_default_security_group
  default_security_group_ingress = var.default_security_group_ingress
  default_security_group_egress  = var.default_security_group_egress
  default_security_group_name    = var.default_security_group_name
  default_security_group_tags    = var.default_security_group_tags

  tags = var.tags
}
