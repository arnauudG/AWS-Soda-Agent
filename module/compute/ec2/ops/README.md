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

# EC2 Ops Instance Module

Creates an EC2 instance for operations and administrative tasks.

## Description

This module creates an EC2 instance intended for ops/admin work. It wraps the terraform-aws-modules/ec2-instance/aws module and provides:

- Amazon Linux 2023 instance (default)
- IAM role with SSM access
- IMDSv2 enforced for security
- Configurable root volume
- No SSH required (use SSM Session Manager)

## Usage

```hcl
module "ec2_ops" {
  source = "../../../module/compute/ec2/ops"

  name          = "${org}-${env}-ops"
  instance_type = "t3.micro"

  vpc_security_group_ids = [dependency.sg_ops.outputs.security_group_id]
  subnet_id              = dependency.vpc.outputs.private_subnets[0]

  iam_role_name = "${org}-${env}-ops-role"
  iam_role_policies = {
    SSMCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
  iam_inline_policies = {
    logs_write = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
        Resource = "*"
      }]
    })
  }

  root_block_device = [
    {
      volume_size = 20
      volume_type = "gp3"
      encrypted   = true
    }
  ]

  tags = {
    Environment = "dev"
    Component   = "ops"
  }
}
```

## Required Inputs

| Name | Description | Type |
|------|-------------|------|
| `name` | Name of the EC2 instance | `string` |
| `instance_type` | EC2 instance type | `string` |
| `vpc_security_group_ids` | List of security group IDs | `list(string)` |
| `subnet_id` | Subnet ID | `string` |
| `iam_role_name` | IAM role name for the instance | `string` |

## Optional Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `ami` | AMI ID (uses SSM parameter if not set) | `string` | `null` |
| `ami_ssm_parameter` | SSM parameter for AMI | `string` | `null` |
| `root_block_device` | Root block device configuration | `list(any)` | `[]` |
| `create_iam_instance_profile` | Create IAM instance profile | `bool` | `true` |
| `iam_role_use_name_prefix` | Use name prefix for IAM role | `bool` | `true` |
| `iam_role_policies` | IAM role policies | `map(string)` | `{}` |
| `iam_inline_policies` | Inline IAM policy JSON documents attached to the role | `map(string)` | `{}` |
| `metadata_options` | Instance metadata options | `object` | IMDSv2 enforced |
| `user_data_base64` | User data as base64 | `string` | `null` |
| `associate_public_ip_address` | Associate public IP | `bool` | `false` |
| `monitoring` | Enable detailed monitoring | `bool` | `false` |
| `ebs_optimized` | Enable EBS optimization | `bool` | `false` |
| `tags` | Tags to apply to resources | `map(string)` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `instance_id` | EC2 instance ID |
| `instance_arn` | EC2 instance ARN |
| `instance_public_ip` | Public IP (if applicable) |
| `instance_private_ip` | Private IP |
| `iam_role_name` | IAM role name |
| `iam_role_arn` | IAM role ARN |

## Security Considerations

- Instance is deployed in private subnet (no public IP)
- Access via SSM Session Manager only (no SSH)
- IMDSv2 is enforced (http_tokens = "required")
- Root volume is encrypted
- IAM role follows least-privilege principle

## Cost Implications

| Instance Type | Cost (On-Demand) |
|---------------|------------------|
| t3.micro | ~$7/month |
| t3.small | ~$15/month |
| t3.medium | ~$30/month |

## Accessing the Instance

Use AWS Systems Manager Session Manager:

```bash
# Via AWS CLI
aws ssm start-session --target <instance-id>

# Via AWS Console
EC2 > Instances > Select Instance > Connect > Session Manager
```

## Dependencies

- `network/vpc` - VPC and private subnets
- `security/security-group/ops` - Security group

## Dependent Modules

- `security/iam/ops-eks-access` - Configures EKS access for the IAM role
