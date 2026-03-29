# Security Group for Ops EC2 Instance Module
# Wraps terraform-aws-modules/security-group/aws and provides standardized outputs

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"

  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id

  ingress_rules                        = var.ingress_rules
  ingress_with_cidr_blocks             = var.ingress_with_cidr_blocks
  ingress_with_source_security_group_id = var.ingress_with_source_security_group_id
  egress_rules                         = var.egress_rules
  egress_with_cidr_blocks              = var.egress_with_cidr_blocks

  tags = var.tags
}
