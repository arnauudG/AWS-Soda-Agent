# Standardized outputs from EKS cluster
# These outputs are consumed by other components

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = module.eks.oidc_provider_arn
}

output "eks_managed_node_groups" {
  description = "EKS managed node groups outputs"
  value       = module.eks.eks_managed_node_groups
}

output "cluster_addons" {
  description = "Cluster addons"
  value       = module.eks.cluster_addons
}

output "eks_managed_node_groups_autoscaling_group_names" {
  description = "Autoscaling group names for node groups"
  value       = module.eks.eks_managed_node_groups_autoscaling_group_names
}

output "node_security_group_id" {
  description = "Security group ID attached to EKS nodes"
  value       = module.eks.node_security_group_id
}
