---
tags: []

category: Documentation
type: data/readme
complexity: intermediate
time_required: 15-30 minutes
created: 2026-02-18
status: active
last_updated: 2026-02-18
---

# VPC Network Module

Creates an AWS VPC with public and private subnets across multiple availability zones.

## Description

This module wraps [terraform-aws-modules/vpc/aws](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest) to provide a standardized VPC configuration. It creates:

- VPC with configurable CIDR block
- Public subnets (for ALB, NAT Gateway)
- Private subnets (for EKS, EC2, RDS)
- Internet Gateway
- NAT Gateway (single or multi-AZ)
- Route tables for public/private subnets

## Usage

```hcl
module "vpc" {
  source = "../../../module/network/vpc"

  name = "${org}-${env}-${region}-soda-agent-vpc"
  cidr = "10.10.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  public_subnets  = ["10.10.0.0/22", "10.10.4.0/22", "10.10.8.0/22"]
  private_subnets = ["10.10.12.0/22", "10.10.16.0/22", "10.10.20.0/22"]

  enable_nat_gateway   = true
  single_nat_gateway   = true  # Cost optimization for dev
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = "dev"
    Project     = "AWS-Soda-Agent"
  }
}
```

## Required Inputs

| Name | Description | Type |
|------|-------------|------|
| `name` | Name of the VPC | `string` |
| `cidr` | CIDR block for the VPC | `string` |
| `azs` | List of availability zones | `list(string)` |
| `public_subnets` | List of public subnet CIDR blocks | `list(string)` |
| `private_subnets` | List of private subnet CIDR blocks | `list(string)` |

## Optional Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_nat_gateway` | Enable NAT Gateway | `bool` | `true` |
| `single_nat_gateway` | Use single NAT Gateway for cost optimization | `bool` | `false` |
| `enable_dns_hostnames` | Enable DNS hostnames | `bool` | `true` |
| `enable_dns_support` | Enable DNS support | `bool` | `true` |
| `enable_flow_log` | Enable VPC Flow Logs | `bool` | `false` |
| `manage_default_security_group` | Manage default security group | `bool` | `true` |
| `default_security_group_ingress` | Default security group ingress rules | `list(any)` | `[]` |
| `default_security_group_egress` | Default security group egress rules | `list(any)` | `[]` |
| `vpc_tags` | Tags for the VPC | `map(string)` | `{}` |
| `igw_tags` | Tags for the Internet Gateway | `map(string)` | `{}` |
| `nat_gateway_tags` | Tags for NAT Gateways | `map(string)` | `{}` |
| `public_subnet_tags` | Tags for public subnets | `map(string)` | `{}` |
| `private_subnet_tags` | Tags for private subnets | `map(string)` | `{}` |
| `tags` | Tags to apply to all resources | `map(string)` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | VPC ID |
| `vpc_cidr_block` | VPC CIDR block |
| `vpc_arn` | VPC ARN |
| `public_subnets` | List of public subnet IDs |
| `private_subnets` | List of private subnet IDs |
| `public_subnet_arns` | List of public subnet ARNs |
| `private_subnet_arns` | List of private subnet ARNs |
| `public_route_table_ids` | List of public route table IDs |
| `private_route_table_ids` | List of private route table IDs |
| `nat_gateway_ids` | List of NAT Gateway IDs |
| `nat_public_ips` | List of NAT Gateway public IPs |
| `internet_gateway_id` | Internet Gateway ID |
| `default_security_group_id` | Default security group ID |

## Security Considerations

- Default security group is configured to deny all ingress and egress traffic
- Private subnets have no direct internet access (egress through NAT Gateway only)
- Enable VPC Flow Logs in production for network monitoring
- Subnet CIDR blocks should be sized appropriately (/22 = 1024 IPs per subnet)

## Cost Implications

| Resource | Dev (single_nat_gateway=true) | Prod (single_nat_gateway=false) |
|----------|-------------------------------|--------------------------------|
| NAT Gateway | ~$32/month | ~$96/month (3 AZs) |
| Data Processing | $0.045/GB | $0.045/GB |

**Cost Optimization Tips:**
- Use `single_nat_gateway = true` for dev environments
- Enable VPC endpoints for AWS services to reduce NAT Gateway data costs
- Consider NAT Instance instead of NAT Gateway for very low-traffic environments

## Dependencies

- None (this is a foundational module)

## Dependent Modules

- `network/vpc-endpoints` - Creates VPC endpoints using this VPC
- `compute/eks/cluster` - Creates EKS cluster in private subnets
- `compute/ec2/ops` - Creates EC2 instances in private subnets
- All security group modules use the VPC ID
