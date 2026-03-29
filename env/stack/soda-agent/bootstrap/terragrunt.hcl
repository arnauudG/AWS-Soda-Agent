# env/stack/soda-agent/bootstrap/terragrunt.hcl
# Stack-scoped bootstrap configuration - creates dedicated S3 state bucket + DynamoDB lock table
# No remote_state include since bootstrap creates the state bucket

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  org         = include.root.locals.org
  env         = include.root.locals.env
  aws_region  = include.root.locals.aws_region
  common_tags = include.root.locals.common_tags

  # State bucket and lock table names come from stack root.hcl
  state_bucket = include.root.locals.state_bucket
  lock_table   = include.root.locals.lock_table
}

inputs = {
  org          = local.org
  env          = local.env
  state_bucket = local.state_bucket
  lock_table   = local.lock_table
  common_tags  = local.common_tags
}

terraform {
  source = "./."
}

skip = false

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-HCL
    terraform {
      required_version = ">= 1.6"
      backend "s3" {}
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = ">= 5.61.0, < 6.0.0"
        }
      }
    }

    provider "aws" {
      region = "${local.aws_region}"
    }
  HCL
}

generate "bootstrap" {
  path      = "main.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-HCL
    variable "org" { type = string }
    variable "env" { type = string }
    variable "state_bucket" { type = string }
    variable "lock_table" { type = string }
    variable "common_tags" {
      type = map(string)
      default = {}
    }

    resource "aws_s3_bucket" "tfstate" {
      bucket        = var.state_bucket
      force_destroy = false

      tags = merge(var.common_tags, {
        Component = "bootstrap"
        Name      = var.state_bucket
      })
    }

    resource "aws_s3_bucket_ownership_controls" "tfstate" {
      bucket = aws_s3_bucket.tfstate.id
      rule {
        object_ownership = "BucketOwnerEnforced"
      }
    }

    resource "aws_s3_bucket_versioning" "tfstate" {
      bucket = aws_s3_bucket.tfstate.id
      versioning_configuration {
        status = "Enabled"
      }
    }

    resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
      bucket = aws_s3_bucket.tfstate.id

      rule {
        id     = "delete-old-versions"
        status = "Enabled"
        filter {}

        noncurrent_version_expiration {
          noncurrent_days = 90
        }
      }

      rule {
        id     = "transition-to-glacier"
        status = "Enabled"
        filter {}

        noncurrent_version_transition {
          noncurrent_days = 30
          storage_class   = "GLACIER"
        }
      }
    }

    resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
      bucket = aws_s3_bucket.tfstate.id
      rule {
        apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
      }
    }

    resource "aws_s3_bucket_public_access_block" "tfstate" {
      bucket                  = aws_s3_bucket.tfstate.id
      block_public_acls       = true
      block_public_policy     = true
      ignore_public_acls      = true
      restrict_public_buckets = true
    }

    resource "aws_s3_bucket_policy" "tfstate_tls_only" {
      bucket = aws_s3_bucket.tfstate.id
      policy = jsonencode({
        Version = "2012-10-17",
        Statement = [{
          Sid       = "DenyInsecureTransport",
          Effect    = "Deny",
          Principal = "*",
          Action    = "s3:*",
          Resource  = [aws_s3_bucket.tfstate.arn, "$${aws_s3_bucket.tfstate.arn}/*"],
          Condition = { Bool = { "aws:SecureTransport" = "false" } }
        }]
      })
    }

    resource "aws_dynamodb_table" "locks" {
      name         = var.lock_table
      billing_mode = "PAY_PER_REQUEST"
      hash_key     = "LockID"

      attribute {
        name = "LockID"
        type = "S"
      }

      point_in_time_recovery {
        enabled = true
      }

      server_side_encryption {
        enabled = true
      }

      tags = merge(var.common_tags, {
        Component = "bootstrap"
        Name      = var.lock_table
      })
    }

    output "state_bucket" { value = aws_s3_bucket.tfstate.bucket }
    output "lock_table"   { value = aws_dynamodb_table.locks.name }
  HCL
}
