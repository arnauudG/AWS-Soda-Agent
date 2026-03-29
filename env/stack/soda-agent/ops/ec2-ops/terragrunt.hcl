# env/stack/soda-agent/ops/ec2-ops/terragrunt.hcl
# EC2 Ops instance configuration (Soda Agent stack)

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "common" {
  path = find_in_parent_folders("common.hcl")
}

locals {
  org            = include.root.locals.org
  env            = include.root.locals.env
  aws_region     = include.root.locals.aws_region
  common_tags    = include.root.locals.common_tags
  ec2_ops_config = include.root.locals.ec2_ops_config
  account_id     = get_aws_account_id()
}

generate "versions_override" {
  path      = "versions_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-HCL
    terraform {
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = ">= 5.0, < 6.0"
        }
      }
    }
  HCL
}

dependency "vpc" {
  config_path  = "../../network/vpc"
  skip_outputs = false
  mock_outputs = {
    vpc_id         = "vpc-123456"
    public_subnets = ["subnet-x", "subnet-y", "subnet-z"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependency "sg_ops" {
  config_path                             = "../sg-ops"
  skip_outputs                            = false
  mock_outputs                            = { security_group_id = "sg-123456" }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependencies {
  paths = [
    "../../network/vpc",
    "../sg-ops"
  ]
}

terraform {
  source = "${include.root.locals.modules_root}/compute/ec2/ops"
}

inputs = {
  name              = "${local.org}-${local.env}-soda-agent-ops"
  vpc_id            = dependency.vpc.outputs.vpc_id
  ami_ssm_parameter = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  instance_type     = local.ec2_ops_config.instance_type

  subnet_id                   = dependency.vpc.outputs.public_subnets[0]
  associate_public_ip_address = true

  placement_group = null
  tenancy         = "default"

  create_iam_instance_profile = true
  iam_role_use_name_prefix    = false
  iam_role_name               = "${local.org}-${local.env}-soda-agent-ops-role"

  # IAM policies for ops instance
  iam_role_policies = {
    ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    eks = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    ecr = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  }

  iam_inline_policies = {
    cloudwatch_logs_write = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogStreams"
          ]
          Resource = [
            "arn:aws:logs:${local.aws_region}:${local.account_id}:log-group:/aws/ec2/${local.org}-${local.env}-soda-agent-ops*",
            "arn:aws:logs:${local.aws_region}:${local.account_id}:log-group:/aws/ec2/${local.org}-${local.env}-soda-agent-ops*:log-stream:*"
          ]
        }
      ]
    })
  }

  create_security_group  = false
  vpc_security_group_ids = [dependency.sg_ops.outputs.security_group_id]

  monitoring    = true
  ebs_optimized = false

  root_block_device = [{
    volume_size           = local.ec2_ops_config.volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    iops                  = 3000
    throughput            = 125
  }]

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  user_data_replace_on_change = true
  user_data = templatefile(
    "${get_terragrunt_dir()}/user-data/install_ops_box.sh.tmpl",
    { region = local.aws_region }
  )

  tags = merge(local.common_tags, {
    Component = "ops-ec2"
    Stack     = "soda-agent"
    Name      = "${local.org}-${local.env}-soda-agent-ops"
  })
}
