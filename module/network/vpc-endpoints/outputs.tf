# Standardized outputs from VPC Endpoints module
# Output only what the underlying module actually provides
# Note: The terraform-aws-modules/vpc/aws//modules/vpc-endpoints module version 5.8.1
# may not expose all endpoint details as outputs. We output what we can safely access.

output "security_group_id" {
  description = "Security group ID for interface endpoints (if created)"
  value       = try(module.vpc_endpoints.security_group_id, null)
}
