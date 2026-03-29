variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "region" {
  type        = string
  description = "AWS region of the cluster"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace to install the agent into"
  default     = "soda-agent"
}

variable "agent_name" {
  type        = string
  description = "Soda agent name (unique per Soda Cloud account). Use a STABLE value (no timestamps)."
}

variable "agent_id" {
  type        = string
  description = "Optional: existing Soda Agent ID from Soda Cloud (Agents → select agent → ID in URL). When set, the orchestrator uses this agent instead of registering a new one. Required when redeploying and the agent name is already registered."
  default     = ""
}

variable "chart_repo" {
  type        = string
  description = "Soda Agent Helm chart repository URL. Official public repo: https://helm.soda.io/soda-agent/"
  default     = "https://helm.soda.io/soda-agent/"
}

variable "chart_version" {
  type        = string
  description = "Chart version to install; empty for latest"
  default     = ""
}

variable "chart_name" {
  type        = string
  description = "Soda Agent Helm chart name or URL"
  default     = "soda-agent"
}

variable "cloud_endpoint" {
  type        = string
  description = "Soda Cloud endpoint (EU=https://cloud.soda.io, US=https://cloud.us.soda.io)"
  default     = "https://cloud.soda.io"
}

variable "api_key_id" {
  type        = string
  description = "Soda Cloud API key id"
  sensitive   = true
}

variable "api_key_secret" {
  type        = string
  description = "Soda Cloud API key secret"
  sensitive   = true
}

variable "image_credentials_id" {
  type        = string
  description = "Optional: API key id for Soda private registry"
  default     = ""
  sensitive   = true
}

variable "image_credentials_secret" {
  type        = string
  description = "Optional: API key secret for Soda private registry"
  default     = ""
  sensitive   = true
}

variable "existing_image_pull_secret" {
  type        = string
  description = "Optional: name of an existing imagePullSecret to use (if set, TF won't create one)"
  default     = ""
}

variable "image_pull_secret_version" {
  type        = string
  description = "Rollout knob when reusing an external secret; bump to force Helm upgrade (e.g., v1 -> v2)."
  default     = "v1"
}

variable "log_format" {
  type        = string
  description = "raw or json"
  default     = "raw"
}

variable "log_level" {
  type        = string
  description = "ERROR, WARN, INFO, DEBUG, or TRACE"
  default     = "INFO"
}

variable "create_namespace" {
  type        = bool
  description = "Create the namespace if it doesn't exist (passed to Helm)"
  default     = true
}