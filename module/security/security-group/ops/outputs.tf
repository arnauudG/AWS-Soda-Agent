# Standardized outputs from Security Group module

output "security_group_id" {
  description = "Security group ID"
  value       = module.security_group.security_group_id
}

output "security_group_arn" {
  description = "Security group ARN"
  value       = module.security_group.security_group_arn
}

output "security_group_vpc_id" {
  description = "VPC ID of the security group"
  value       = module.security_group.security_group_vpc_id
}
