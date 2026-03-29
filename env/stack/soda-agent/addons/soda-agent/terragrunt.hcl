# env/stack/soda-agent/addons/soda-agent/terragrunt.hcl
# Soda Agent Helm chart deployment

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "common" {
  path = find_in_parent_folders("common.hcl")
}

locals {
  org               = include.root.locals.org
  env               = include.root.locals.env
  aws_region        = include.root.locals.aws_region
  soda_agent_config = include.root.locals.soda_agent_config

  # Derive namespace from config (allows environment-specific overrides)
  namespace = local.soda_agent_config.namespace

  # Derive agent name using standard naming pattern
  # Pattern: ${org}-${env}-agent
  # During destroy or when cluster is unavailable, we use the standard pattern
  # During apply, we can derive from cluster name in inputs block
  agent_name = "${local.org}-${local.env}-agent"

  # Derive cloud endpoint from config (with env var override)
  cloud_region   = get_env("SODA_CLOUD_REGION", local.soda_agent_config.cloud_region)
  cloud_endpoint = local.cloud_region == "us" ? "https://cloud.us.soda.io" : "https://cloud.soda.io"

  # Validation for required environment variables
  # These are checked at Terragrunt evaluation time (before Terraform runs)
  # Note: Validation is lenient - allows empty values (Terraform will fail with clearer error if needed)
  # This allows destroy operations to proceed even if API keys are not set
  required_api_key_id     = get_env("SODA_API_KEY_ID", "")
  required_api_key_secret = get_env("SODA_API_KEY_SECRET", "")

  # Validate required environment variables (only if both are set - allows destroy without keys)
  # This provides helpful error messages during apply/plan, but doesn't block destroy
  _validate_api_keys = (
    local.required_api_key_id != "" && local.required_api_key_secret != ""
    ) ? true : (
    # Only throw error if one is set but not the other (partial configuration error)
    (local.required_api_key_id != "" || local.required_api_key_secret != "") ? throw(
      "ERROR: Partial API key configuration detected!\n" +
      "  Both SODA_API_KEY_ID and SODA_API_KEY_SECRET must be set together.\n" +
      "  These are Service Account API keys (not Profile API keys) from Soda Cloud.\n" +
      "  Get them from: Data Sources → Agents → New Soda Agent\n" +
      "  Current values:\n" +
      "    SODA_API_KEY_ID: ${local.required_api_key_id != "" ? "***SET***" : "NOT SET"}\n" +
      "    SODA_API_KEY_SECRET: ${local.required_api_key_secret != "" ? "***SET***" : "NOT SET"}\n" +
      "  Note: Empty values are allowed during destroy operations."
    ) : true # Both empty is okay (allows destroy without keys)
  )
}

dependency "eks" {
  config_path  = "../../eks"
  skip_outputs = false
  mock_outputs = {
    cluster_name = "${local.org}-${local.env}-soda-agent-eks"
  }
  # Allow mocks during init, plan, validate, AND destroy (when EKS might already be destroyed)
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "destroy"]
}

dependencies {
  paths = ["../../eks"]
}

terraform {
  source = "${include.root.locals.modules_root}/application/helm/soda-agent"
}

generate "versions_override" {
  path      = "versions_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-HCL
    terraform {
      required_providers {
        aws        = { source = "hashicorp/aws",        version = ">= 5.0, < 6.0" }
        kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.23, < 3.0" }
        helm       = { source = "hashicorp/helm",       version = ">= 2.12, < 3.0" }
      }
    }
  HCL
}

inputs = {
  # Derived from EKS dependency (orchestration)
  # Use try() to handle cases where dependency output is unavailable (e.g., during destroy)
  cluster_name = try(dependency.eks.outputs.cluster_name, "${local.org}-${local.env}-soda-agent-eks")

  # Derived from root config (region, org, env)
  region    = local.aws_region
  namespace = local.namespace

  # Derive agent name from cluster name if available, otherwise use standard pattern
  # This ensures consistency: cluster name drives agent name when possible
  agent_name = try(
    # Try to derive from cluster name: <org>-<env>-soda-agent-eks -> <org>-<env>-agent
    replace(dependency.eks.outputs.cluster_name, "-soda-agent-eks", "-agent"),
    # Fallback to standard pattern if cluster name unavailable
    local.agent_name
  )

  # Derived from environment config (env.hcl)
  chart_repo    = local.soda_agent_config.chart_repo
  chart_version = local.soda_agent_config.chart_version
  chart_name    = local.soda_agent_config.chart_name

  # Derived from config with env var override
  cloud_endpoint = local.cloud_endpoint

  # Optional: existing Agent ID from Soda Cloud (Agents → select agent → ID in URL).
  # Set when redeploying and you see "agent with name X already registered" (CrashLoopBackOff).
  agent_id = get_env("SODA_AGENT_ID", "")

  # Agent API keys: MUST be from Data Sources → Agents → New Soda Agent (not Profile → API Keys).
  # Per Soda docs: "values you copy+pasted from the New Soda Agent dialog box".
  api_key_id     = local.required_api_key_id
  api_key_secret = local.required_api_key_secret

  # Image registry (registry.cloud.soda.io): optional override.
  # If unset, agent keys above are used (same keys from New Soda Agent dialog work for both).
  # Set SODA_IMAGE_APIKEY_* only if Soda gave you separate registry credentials.
  image_credentials_id       = get_env("SODA_IMAGE_APIKEY_ID", local.required_api_key_id)
  image_credentials_secret   = get_env("SODA_IMAGE_APIKEY_SECRET", local.required_api_key_secret)
  existing_image_pull_secret = ""

  # Logging configuration from config with env var override
  log_format = get_env("SODA_LOG_FORMAT", local.soda_agent_config.log_format)
  log_level  = get_env("SODA_LOG_LEVEL", local.soda_agent_config.log_level)

  create_namespace = true
}
