# env/stack/stack-globals.hcl
# Shared stack-level configuration that re-exports root.hcl locals.
# Each stack's own root.hcl reads this file so all global settings
# are available without duplicating the import chain.

locals {
  # Import all root-level config
  root = read_terragrunt_config("${get_repo_root()}/env/root.hcl")

  # Re-export for stack-level root.hcl files
  env               = local.root.locals.env
  aws_region        = local.root.locals.aws_region
  org               = local.root.locals.org
  modules_root      = local.root.locals.modules_root
  tg_download_dir   = local.root.locals.tg_download_dir
  defaults          = local.root.locals.defaults
  actual_account_id = local.root.locals.actual_account_id
  common_tags       = local.root.locals.common_tags

  # Environment-specific config maps
  vpc_config        = local.root.locals.vpc_config
  eks_config        = local.root.locals.eks_config
  ec2_ops_config    = local.root.locals.ec2_ops_config
  soda_agent_config = local.root.locals.soda_agent_config
}
