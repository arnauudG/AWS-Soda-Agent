locals {
  # Shared stack globals propagated from env/root.hcl.
  shared = read_terragrunt_config("${get_repo_root()}/env/stack/stack-globals.hcl")

  # Stack identity
  stack_name = "soda-agent"

  # Re-expose globals for child modules.
  env               = local.shared.locals.env
  aws_region        = local.shared.locals.aws_region
  org               = local.shared.locals.org
  modules_root      = local.shared.locals.modules_root
  tg_download_dir   = local.shared.locals.tg_download_dir
  defaults          = local.shared.locals.defaults
  actual_account_id = local.shared.locals.actual_account_id

  # Shared config maps
  vpc_config        = local.shared.locals.vpc_config
  eks_config        = local.shared.locals.eks_config
  ec2_ops_config    = local.shared.locals.ec2_ops_config
  soda_agent_config = local.shared.locals.soda_agent_config

  # Dedicated backend per stack
  state_bucket = "${local.actual_account_id}-${local.org}-${local.env}-${local.stack_name}-tfstate-${local.aws_region}"
  lock_table   = "${local.actual_account_id}-${local.org}-${local.env}-${local.stack_name}-tf-locks"

  common_tags = merge(local.shared.locals.common_tags, {
    Stack = local.stack_name
  })
}

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

download_dir             = local.tg_download_dir
retry_max_attempts       = 3
retry_sleep_interval_sec = 3

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
