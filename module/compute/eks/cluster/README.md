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

# EKS Cluster Module

Creates an Amazon EKS (Elastic Kubernetes Service) cluster with managed node groups.

## Description

This module wraps [terraform-aws-modules/eks/aws](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest) to provide a standardized EKS cluster configuration. It creates:

- EKS control plane
- Managed node groups with configurable instance types
- OIDC provider for IAM Roles for Service Accounts (IRSA)
- Core cluster addons (CoreDNS, kube-proxy, VPC CNI)
- CloudWatch logging for cluster components
- Encryption at rest for Kubernetes secrets

## Usage

```hcl
module "eks" {
  source = "../../../module/compute/eks/cluster"

  cluster_name    = "${org}-${env}-eks"
  cluster_version = "1.31"

  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnets

  enable_irsa = true

  eks_managed_node_groups = {
    ops = {
      name           = "${org}-${env}-ops-ng"
      desired_size   = 1
      min_size       = 1
      max_size       = 2
      instance_types = ["t3.small"]
      capacity_type  = "SPOT"
      ami_type       = "AL2023_x86_64_STANDARD"
    }
  }

  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
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
| `cluster_name` | EKS cluster name | `string` |
| `cluster_version` | Kubernetes version (e.g., "1.31") | `string` |
| `vpc_id` | VPC ID where the cluster will be created | `string` |
| `subnet_ids` | List of private subnet IDs for the cluster | `list(string)` |

## Optional Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `ops_security_group_id` | Security group ID for ops EC2 access | `string` | `null` |
| `enable_irsa` | Enable IAM Roles for Service Accounts | `bool` | `true` |
| `authentication_mode` | Authentication mode (API, CONFIG_MAP, API_AND_CONFIG_MAP) | `string` | `"API_AND_CONFIG_MAP"` |
| `enable_cluster_creator_admin_permissions` | Enable admin permissions for cluster creator | `bool` | `true` |
| `cluster_endpoint_public_access` | Enable public access to cluster endpoint | `bool` | `true` |
| `cluster_endpoint_private_access` | Enable private access to cluster endpoint | `bool` | `true` |
| `cluster_enabled_log_types` | List of log types to enable | `list(string)` | `[]` |
| `cloudwatch_log_group_retention_in_days` | CloudWatch log retention in days | `number` | `7` |
| `cluster_encryption_config` | Cluster encryption configuration | `object` | secrets encrypted |
| `eks_managed_node_groups` | EKS managed node groups configuration | `any` | `{}` |
| `cluster_addons` | EKS cluster addons configuration | `any` | `{}` |
| `cluster_security_group_additional_rules` | Additional cluster security group rules | `any` | `{}` |
| `node_security_group_additional_rules` | Additional node security group rules | `any` | `{}` |
| `tags` | Tags to apply to resources | `map(string)` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_name` | EKS cluster name |
| `cluster_id` | EKS cluster ID |
| `cluster_arn` | EKS cluster ARN |
| `cluster_endpoint` | EKS cluster API endpoint |
| `cluster_certificate_authority_data` | Base64 encoded certificate data (sensitive) |
| `cluster_security_group_id` | Security group ID attached to the EKS cluster |
| `cluster_oidc_issuer_url` | OIDC issuer URL for IRSA |
| `oidc_provider_arn` | ARN of the OIDC provider |
| `eks_managed_node_groups` | EKS managed node groups outputs |
| `cluster_addons` | Cluster addons |
| `node_security_group_id` | Security group ID attached to EKS nodes |

## Security Considerations

- Kubernetes secrets are encrypted at rest using AWS KMS
- IRSA is enabled by default for secure IAM access from pods
- Cluster endpoint can be restricted to specific CIDRs
- IMDSv2 is enforced on all nodes (http_tokens = "required")
- Node metadata tags are enabled for instance identification

## Cost Implications

| Resource | Dev | Prod |
|----------|-----|------|
| EKS Control Plane | $72/month | $72/month |
| Node Group (t3.small SPOT) | ~$5/month | ~$15/month |
| Node Group (t3.medium ON_DEMAND) | N/A | ~$30/month |
| CloudWatch Logs | Variable | Variable |

**Cost Optimization Tips:**
- Use SPOT instances for non-critical workloads
- Configure Cluster Autoscaler to scale nodes to zero when idle
- Reduce CloudWatch log retention in dev environments
- Use single NAT Gateway with EKS in private subnets

## Dependencies

- `network/vpc` - VPC and subnets for cluster placement
- `security/security-group/ops` - Security group for ops EC2 access (optional)

## Dependent Modules

- `security/iam/ops-eks-access` - Configures RBAC for ops EC2
- `application/helm/soda-agent` - soda-agent add-on (Helm)

## Node Group Configuration Examples

### Development (Cost-Optimized)
```hcl
eks_managed_node_groups = {
  ops = {
    desired_size   = 1
    min_size       = 1
    max_size       = 2
    instance_types = ["t3.small"]
    capacity_type  = "SPOT"
  }
}
```

### Production (High Availability)
```hcl
eks_managed_node_groups = {
  main = {
    desired_size   = 3
    min_size       = 2
    max_size       = 10
    instance_types = ["t3.medium", "t3.large"]
    capacity_type  = "ON_DEMAND"
  }
}
```
