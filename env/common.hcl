# env/common.hcl
# Common Terragrunt configuration shared by all environments and regions
# This file contains generate blocks for provider and backend that are identical across all modules
#
# Usage: Include this file in module-level terragrunt.hcl files
#   include "common" {
#     path = find_in_parent_folders("common.hcl")
#   }

locals {
  # Read region from environment variable (set by TF_VAR_region)
  aws_region = get_env("TF_VAR_region", "eu-west-1")
}

# Generate provider configuration
# Region is read from TF_VAR_region environment variable
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-HCL
    provider "aws" {
      region = "${local.aws_region}"

      default_tags {
        tags = {
          ManagedBy = "Terragrunt"
        }
      }
    }
  HCL
}

# Generate backend configuration
# The actual backend config (bucket, key, etc.) comes from remote_state block in root.hcl
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-HCL
    terraform {
      backend "s3" {}
    }
  HCL
}
