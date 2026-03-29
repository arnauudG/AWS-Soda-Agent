# env/root.hcl
# Top-level Terragrunt configuration
# - Reads TF_VAR_environment and TF_VAR_region
# - Validates environment, region, and AWS account
# - Provides shared inputs and remote state configuration

locals {
  # ==========================================================================
  # READ FROM ENVIRONMENT VARIABLES
  # ==========================================================================
  env        = get_env("TF_VAR_environment", "dev")
  aws_region = get_env("TF_VAR_region", "eu-west-1")

  # ==========================================================================
  # LOAD ENVIRONMENT CONFIGURATION
  # ==========================================================================
  env_config = read_terragrunt_config("${get_repo_root()}/env/env.hcl").locals

  # ==========================================================================
  # VALIDATE ENVIRONMENT
  # ==========================================================================
  valid_envs = local.env_config.valid_environments

  env_valid = contains(local.valid_envs, local.env)

  _env_check = local.env_valid ? true : throw(
    "Invalid environment '${local.env}'. Valid environments: ${join(", ", local.valid_envs)}"
  )

  env_settings = local.env_config.environments[local.env]

  # ==========================================================================
  # VALIDATE REGION
  # ==========================================================================
  valid_regions = local.env_config.valid_regions

  _region_check = contains(local.valid_regions, local.aws_region) ? true : throw(
    "Invalid region '${local.aws_region}'. Valid regions: ${join(", ", local.valid_regions)}"
  )

  # ==========================================================================
  # AWS ACCOUNT VALIDATION (SAFETY CHECK)
  # ==========================================================================
  # Allow local override via env var to avoid committing account IDs.
  expected_account_id = trimspace(get_env("TG_EXPECTED_ACCOUNT_ID", local.env_settings.aws_account_id))
  actual_account_id   = get_aws_account_id()

  _account_check = local.expected_account_id == "" ? true : (
    local.expected_account_id == local.actual_account_id ? true : throw(
      "AWS account mismatch! Expected ${local.expected_account_id} for '${local.env}' environment, but authenticated to ${local.actual_account_id}. Check your AWS credentials."
    )
  )

  # ==========================================================================
  # ORGANIZATION / GLOBAL SETTINGS
  # ==========================================================================
  defaults     = local.env_config.defaults
  org          = local.defaults.org
  modules_root = "${get_repo_root()}/module"

  tg_download_dir = pathexpand("~/.terragrunt-cache")

  # ==========================================================================
  # SHARED NAMING CONVENTIONS
  # ==========================================================================
  # Pattern: ${org}-${env}-<component>-<resource-type>
  # Example: ${org}-${env}-soda-agent-eks

  # ==========================================================================
  # STATE BACKEND NAMING
  # ==========================================================================
  state_bucket = "${local.actual_account_id}-${local.org}-${local.env}-tfstate-${local.aws_region}"
  lock_table   = "${local.actual_account_id}-${local.org}-${local.env}-tf-locks"

  # ==========================================================================
  # COMMON TAGS
  # ==========================================================================
  common_tags = {
    Terraform  = "true"
    ManagedBy  = "Terragrunt"
    Org        = local.org
    Env        = local.env
    Region     = local.aws_region
    Project    = local.defaults.project
    CostCenter = local.defaults.cost_center
    AccountId  = local.actual_account_id
  }

  # ==========================================================================
  # EXPOSE ENVIRONMENT-SPECIFIC CONFIGS
  # ==========================================================================
  vpc_config        = local.env_settings.vpc
  eks_config        = local.env_settings.eks
  ec2_ops_config    = local.env_settings.ec2_ops
  soda_agent_config = local.env_settings.soda_agent
}

# ==========================================================================
# REMOTE STATE CONFIGURATION
# ==========================================================================
remote_state {
  backend = "s3"
  config = {
    bucket         = local.state_bucket
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    dynamodb_table = local.lock_table
    encrypt        = true
  }
}

# ==========================================================================
# TERRAGRUNT SETTINGS
# ==========================================================================
download_dir             = local.tg_download_dir
retry_max_attempts       = 3
retry_sleep_interval_sec = 3

# ==========================================================================
# DEFAULT INPUTS EXPOSED TO MODULES
# ==========================================================================
inputs = {
  org          = local.org
  env          = local.env
  aws_region   = local.aws_region
  common_tags  = local.common_tags
  modules_root = local.modules_root

  vpc_config        = local.vpc_config
  eks_config        = local.eks_config
  ec2_ops_config    = local.ec2_ops_config
  soda_agent_config = local.soda_agent_config
}
