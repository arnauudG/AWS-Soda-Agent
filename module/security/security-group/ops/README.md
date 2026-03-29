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

# Security Group - Ops Module

Creates a flexible AWS Security Group with configurable ingress and egress rules.

## Description

This is a generic security group module used throughout the project. It creates an AWS Security Group with:

- Configurable ingress rules (by CIDR or source security group)
- Configurable egress rules (by CIDR)
- Proper tagging and naming

Despite the name "ops", this module is a generic security group builder used for various purposes:
- Ops EC2 instance security group
- Any component requiring custom ingress/egress rules

## Usage

```hcl
module "sg_ops" {
  source = "../../../module/security/security-group/ops"

  name        = "soda-dev-ops-sg"
  description = "Security group for ops EC2 instance"
  vpc_id      = dependency.vpc.outputs.vpc_id

  # No inbound rules - access via SSM only
  ingress_rules = []

  # Restricted egress rules
  egress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "HTTPS to VPC endpoints"
      cidr_blocks = dependency.vpc.outputs.vpc_cidr_block
    },
    {
      from_port   = 53
      to_port     = 53
      protocol    = "udp"
      description = "DNS to VPC resolver"
      cidr_blocks = dependency.vpc.outputs.vpc_cidr_block
    }
  ]

  tags = {
    Environment = "dev"
    Component   = "ops-sg"
  }
}
```

## Required Inputs

| Name | Description | Type |
|------|-------------|------|
| `name` | Name of the security group | `string` |
| `description` | Description of the security group | `string` |
| `vpc_id` | VPC ID where the security group will be created | `string` |

## Optional Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `ingress_rules` | List of ingress rules (predefined) | `list(string)` | `[]` |
| `ingress_with_cidr_blocks` | List of ingress rules with CIDR blocks | `list(object)` | `[]` |
| `ingress_with_source_security_group_id` | List of ingress rules with source SG | `list(object)` | `[]` |
| `egress_rules` | List of egress rules (predefined) | `list(string)` | `[]` |
| `egress_with_cidr_blocks` | List of egress rules with CIDR blocks | `list(object)` | `[]` |
| `tags` | Tags to apply to the security group | `map(string)` | `{}` |

## Rule Object Structure

### ingress_with_cidr_blocks / egress_with_cidr_blocks
```hcl
{
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  description = "HTTPS traffic"
  cidr_blocks = "10.0.0.0/16"
}
```

### ingress_with_source_security_group_id
```hcl
{
  from_port                = 9000
  to_port                  = 9000
  protocol                 = "tcp"
  description              = "Allow from ALB"
  source_security_group_id = "sg-123456"
}
```

## Outputs

| Name | Description |
|------|-------------|
| `security_group_id` | Security group ID |
| `security_group_arn` | Security group ARN |
| `security_group_name` | Security group name |

## Security Considerations

- Follow least-privilege principle for rules
- Use VPC CIDR instead of `0.0.0.0/0` where possible
- Prefer security group references over CIDR blocks for internal traffic
- Add descriptions to all rules for documentation
- Review security groups regularly

## Common Patterns

### No Inbound Access (SSM Only)
```hcl
ingress_rules            = []
ingress_with_cidr_blocks = []
```

### Internal VPC Access Only
```hcl
ingress_with_cidr_blocks = [
  {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    description = "HTTPS from VPC"
    cidr_blocks = "10.10.0.0/16"  # VPC CIDR
  }
]
```

### Security Group to Security Group
```hcl
ingress_with_source_security_group_id = [
  {
    from_port                = 9000
    to_port                  = 9000
    protocol                 = "tcp"
    description              = "Allow from ALB security group"
    source_security_group_id = dependency.sg_alb.outputs.security_group_id
  }
]
```

## Dependencies

- `network/vpc` - VPC ID for security group placement

## Related Modules

- `security/security-group/rds` - Specialized for RDS instances
- `security/security-group/alb` - Would be specialized for ALBs (uses this module)
