# VPC Endpoints Module
# Wraps terraform-aws-modules/vpc/aws//modules/vpc-endpoints and provides standardized outputs

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "5.8.1"

  vpc_id = var.vpc_id

  create_security_group      = var.create_security_group
  security_group_name        = var.security_group_name
  security_group_description = var.security_group_description
  security_group_rules       = var.security_group_rules
  security_group_tags        = var.security_group_tags

  endpoints = var.endpoints

  tags = var.tags
}
