# Standardized outputs from VPC module
# These outputs are consumed by other components

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr_block
}

output "vpc_arn" {
  description = "VPC ARN"
  value       = module.vpc.vpc_arn
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnet_arns" {
  description = "List of public subnet ARNs"
  value       = module.vpc.public_subnet_arns
}

output "private_subnet_arns" {
  description = "List of private subnet ARNs"
  value       = module.vpc.private_subnet_arns
}

output "public_route_table_ids" {
  description = "List of public route table IDs"
  value       = module.vpc.public_route_table_ids
}

output "private_route_table_ids" {
  description = "List of private route table IDs"
  value       = module.vpc.private_route_table_ids
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc.natgw_ids
}

output "nat_public_ips" {
  description = "List of NAT Gateway public IPs"
  value       = module.vpc.nat_public_ips
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = module.vpc.igw_id
}

output "default_security_group_id" {
  description = "Default security group ID"
  value       = module.vpc.default_security_group_id
}
