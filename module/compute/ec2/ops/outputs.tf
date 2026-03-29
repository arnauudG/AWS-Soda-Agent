# Standardized outputs from EC2 ops instance
# These outputs are consumed by other components

output "instance_id" {
  description = "EC2 instance ID"
  value       = module.ec2.id
}

output "instance_arn" {
  description = "EC2 instance ARN"
  value       = module.ec2.arn
}

output "instance_private_ip" {
  description = "Private IP address of the instance"
  value       = module.ec2.private_ip
}

output "instance_public_ip" {
  description = "Public IP address of the instance (if applicable)"
  value       = module.ec2.public_ip
}

output "iam_role_name" {
  description = "IAM role name attached to the instance"
  value       = module.ec2.iam_role_name
}

output "iam_role_arn" {
  description = "IAM role ARN attached to the instance"
  value       = module.ec2.iam_role_arn
}

output "security_group_ids" {
  description = "Security group IDs attached to the instance"
  # The module doesn't expose security groups as output, so return from input
  value       = var.vpc_security_group_ids
}
