# EC2 Ops Instance Module
# Wraps terraform-aws-modules/ec2-instance/aws and provides standardized outputs

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

module "ec2" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.0"

  name = var.name

  instance_type          = var.instance_type
  ami                    = var.ami
  ami_ssm_parameter      = var.ami_ssm_parameter
  vpc_security_group_ids = var.vpc_security_group_ids
  subnet_id              = var.subnet_id

  root_block_device = var.root_block_device

  create_iam_instance_profile = var.create_iam_instance_profile
  iam_role_name               = var.iam_role_name
  iam_role_use_name_prefix    = var.iam_role_use_name_prefix
  iam_role_policies           = var.iam_role_policies

  metadata_options = var.metadata_options

  placement_group = var.placement_group
  tenancy         = var.tenancy
  ebs_optimized   = var.ebs_optimized

  user_data_base64            = var.user_data_base64
  user_data_replace_on_change = var.user_data_replace_on_change

  associate_public_ip_address = var.associate_public_ip_address
  monitoring                  = var.monitoring

  tags = var.tags
}

resource "aws_iam_role_policy" "inline" {
  for_each = var.create_iam_instance_profile ? var.iam_inline_policies : {}

  name   = substr("${var.name}-${each.key}", 0, 128)
  role   = module.ec2.iam_role_name
  policy = each.value
}
