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

# VPC Endpoints Module

Creates AWS VPC Endpoints for private connectivity to AWS services.

## Description

This module creates VPC endpoints to enable private connectivity between your VPC and AWS services without requiring internet access. It supports:

- Interface endpoints (powered by AWS PrivateLink)
- Gateway endpoints (for S3 and DynamoDB)
- Automatic security group creation for interface endpoints

## Usage

```hcl
module "vpc_endpoints" {
  source = "../../../module/network/vpc-endpoints"

  vpc_id = dependency.vpc.outputs.vpc_id

  endpoints = {
    ssm = {
      service             = "ssm"
      service_type        = "Interface"
      private_dns_enabled = true
      subnet_ids          = dependency.vpc.outputs.private_subnets
    }
    ssmmessages = {
      service             = "ssmmessages"
      service_type        = "Interface"
      private_dns_enabled = true
      subnet_ids          = dependency.vpc.outputs.private_subnets
    }
    ec2messages = {
      service             = "ec2messages"
      service_type        = "Interface"
      private_dns_enabled = true
      subnet_ids          = dependency.vpc.outputs.private_subnets
    }
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = dependency.vpc.outputs.private_route_table_ids
    }
  }

  tags = {
    Environment = "dev"
    Project     = "AWS-Soda-Agent"
  }
}
```

## Required Inputs

| Name | Description | Type |
|------|-------------|------|
| `vpc_id` | VPC ID where endpoints will be created | `string` |

## Optional Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `endpoints` | Map of VPC endpoints to create | `map(object)` | `{}` |
| `create_security_group` | Create security group for interface endpoints | `bool` | `true` |
| `security_group_name` | Name of the security group | `string` | `null` |
| `security_group_description` | Description of the security group | `string` | `"Security group for VPC endpoints"` |
| `security_group_rules` | Security group rules for interface endpoints | `list(object)` | `[]` |
| `security_group_tags` | Tags for the security group | `map(string)` | `{}` |
| `tags` | Tags to apply to all resources | `map(string)` | `{}` |

## Endpoint Configuration

Each endpoint in the `endpoints` map supports:

| Field | Description | Type | Default |
|-------|-------------|------|---------|
| `service` | AWS service name (e.g., "ssm", "s3") | `string` | Required |
| `service_type` | "Interface" or "Gateway" | `string` | `"Interface"` |
| `private_dns_enabled` | Enable private DNS | `bool` | `true` |
| `subnet_ids` | Subnet IDs (for Interface) | `list(string)` | `[]` |
| `route_table_ids` | Route table IDs (for Gateway) | `list(string)` | `[]` |
| `security_group_ids` | Additional security groups | `list(string)` | `[]` |
| `tags` | Endpoint-specific tags | `map(string)` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `endpoints` | Map of created VPC endpoints |
| `security_group_id` | Security group ID (if created) |

## Common Endpoints for This Project

### SSM (Systems Manager) Access
Required for SSM Session Manager:
- `ssm` - SSM API
- `ssmmessages` - Session Manager messages
- `ec2messages` - EC2 messages

### ECR (Container Registry)
Required for pulling container images:
- `ecr.api` - ECR API
- `ecr.dkr` - Docker registry
- `s3` - S3 gateway (for ECR layers)

### Other Common Endpoints
- `sts` - Security Token Service
- `logs` - CloudWatch Logs
- `eks` - EKS API (for private clusters)

## Security Considerations

- Interface endpoints use PrivateLink for secure, private connectivity
- Security groups control access to interface endpoints
- Gateway endpoints don't require security groups
- Enable private DNS for seamless AWS SDK integration

## Cost Implications

| Endpoint Type | Cost |
|---------------|------|
| Interface Endpoint | ~$7.30/month per AZ + data processing |
| Gateway Endpoint | Free |

**Cost Optimization Tips:**
- Use Gateway endpoints for S3 and DynamoDB (free)
- Deploy Interface endpoints only in required AZs
- Consider if you really need all endpoints (SSM is often sufficient)

## Dependencies

- `network/vpc` - VPC, subnets, and route tables

## Dependent Modules

- `compute/ec2/ops` - Uses SSM endpoints for access
- `compute/eks/cluster` - Uses ECR endpoints for image pulls
