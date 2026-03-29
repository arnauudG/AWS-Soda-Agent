variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the cluster"
  type        = list(string)
}

variable "ops_security_group_id" {
  description = "Security group ID for ops EC2 access to cluster"
  type        = string
  default     = null
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts"
  type        = bool
  default     = true
}

variable "authentication_mode" {
  description = "Authentication mode for the cluster"
  type        = string
  default     = "API_AND_CONFIG_MAP"
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Enable cluster creator admin permissions"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to cluster endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Enable private access to cluster endpoint"
  type        = bool
  default     = true
}

variable "cluster_enabled_log_types" {
  description = "List of log types to enable"
  type        = list(string)
  default     = []
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 7
}

variable "cluster_encryption_config" {
  description = "Cluster encryption configuration"
  type = object({
    provider_key_arn = optional(string)
    resources        = list(string)
  })
  default = {
    provider_key_arn = null
    resources        = ["secrets"]
  }
}

variable "eks_managed_node_groups" {
  description = "EKS managed node groups configuration"
  type        = any
  default     = {}
}

variable "cluster_addons" {
  description = "EKS cluster addons configuration"
  type        = any
  default     = {}
}

variable "cluster_security_group_additional_rules" {
  description = "Additional security group rules for the cluster"
  type        = any
  default     = {}
}

variable "node_security_group_additional_rules" {
  description = "Additional security group rules for nodes"
  type        = any
  default     = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
