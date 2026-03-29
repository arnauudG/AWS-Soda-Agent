# env/env.hcl
# Environment catalog for the AWS Soda Agent package.
#
# Stack-first note:
# - Live configs are under env/stack/
# - This file only defines the environment keys and their settings.
#
# Account ID safety:
# - Do NOT commit your AWS account IDs here if you don't want them in git history.
# - Use the environment variable TG_EXPECTED_ACCOUNT_ID at runtime to enable the safety check.
#
# Organization:
# - Set TF_VAR_org at runtime to customise resource-name prefixes (default: "soda").

locals {
  valid_regions = ["eu-west-1", "us-east-1", "eu-central-1"]

  # ==========================================================================
  # ENVIRONMENT CONFIGURATIONS
  # ==========================================================================
  environments = {
    dev = {
      # AWS Account (optional)
      #
      # Leave empty to avoid committing account IDs. To enable account safety checks:
      #   export TG_EXPECTED_ACCOUNT_ID=123456789012
      aws_account_id = ""

      # VPC Settings
      vpc = {
        cidr               = "10.10.0.0/16"
        single_nat_gateway = true  # Dev: Single NAT gateway for cost optimization
        enable_flow_log    = false # Dev: Disabled for cost savings
      }

      # EKS Settings
      eks = {
        desired_size                   = 1
        min_size                       = 1
        max_size                       = 2
        instance_types                 = ["t3.small"]
        disk_size                      = 20
        capacity_type                  = "SPOT"
        cluster_endpoint_public_access = true
        cloudwatch_log_retention       = 7
      }

      # EC2 Ops
      ec2_ops = {
        instance_type = "t3.micro"
        volume_size   = 16
      }

      # Soda Agent
      soda_agent = {
        chart_repo    = "https://helm.soda.io/soda-agent/"
        chart_version = "" # Empty = latest; pin in prod (e.g. "1.3.15")
        chart_name    = "soda-agent"
        namespace     = "soda-agent"
        log_format    = "raw"
        log_level     = "INFO"
        cloud_region  = "eu"
      }
    }

    prod = {
      # AWS Account (optional)
      aws_account_id = ""

      # VPC Settings
      vpc = {
        cidr               = "10.20.0.0/16"
        single_nat_gateway = false          # HA: NAT per AZ
        enable_flow_log    = true           # Prod: Enable for security/compliance
      }

      # EKS Settings
      eks = {
        desired_size                   = 3
        min_size                       = 2
        max_size                       = 5
        instance_types                 = ["t3.small"]
        disk_size                      = 50
        capacity_type                  = "SPOT"
        cluster_endpoint_public_access = false # Private only in prod
        cloudwatch_log_retention       = 30
      }

      # EC2 Ops
      ec2_ops = {
        instance_type = "t3.small"
        volume_size   = 20
      }

      # Soda Agent (production: pin chart version for reproducibility)
      soda_agent = {
        chart_repo    = "https://helm.soda.io/soda-agent/"
        chart_version = "1.3.15" # Pinned for prod; bump after testing
        chart_name    = "soda-agent"
        namespace     = "soda-agent"
        log_format    = "raw"
        log_level     = "INFO"
        cloud_region  = "eu"
      }
    }
  }

  valid_environments = sort(keys(local.environments))

  # ==========================================================================
  # DEFAULTS (shared across all environments)
  # ==========================================================================
  defaults = {
    org         = get_env("TF_VAR_org", "soda")
    project     = "AWS-Soda-Agent"
    cost_center = "Engineering"
  }
}
