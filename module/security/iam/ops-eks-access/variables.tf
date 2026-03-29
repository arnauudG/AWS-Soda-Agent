variable "role_name" {
  description = "Existing IAM role name to attach policy to (created by ec2-ops)"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "region" {
  description = "AWS region where the EKS cluster lives"
  type        = string
}

variable "policy_name" {
  description = "Name for the inline policy granting EKS describe/list"
  type        = string
  default     = "ops-eks-describe"
}