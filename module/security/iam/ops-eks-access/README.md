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

# IAM Ops EKS Access Module

Grants an EC2 instance's IAM role permission to access an EKS cluster.

## Description

This module attaches an inline IAM policy to an existing IAM role, granting permissions to:

- Describe EKS cluster
- List EKS clusters
- Access EKS cluster endpoint

This enables EC2 instances (like the ops instance) to run kubectl commands against the EKS cluster.

## Usage

```hcl
module "ops_eks_access" {
  source = "../../../module/security/iam/ops-eks-access"

  role_name    = dependency.ec2_ops.outputs.iam_role_name
  cluster_name = dependency.eks.outputs.cluster_name
  region       = "eu-west-1"

  policy_name = "ops-eks-describe"
}
```

## Required Inputs

| Name | Description | Type |
|------|-------------|------|
| `role_name` | Existing IAM role name to attach policy to | `string` |
| `cluster_name` | EKS cluster name | `string` |
| `region` | AWS region where the EKS cluster lives | `string` |

## Optional Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `policy_name` | Name for the inline policy | `string` | `"ops-eks-describe"` |

## Outputs

| Name | Description |
|------|-------------|
| `policy_name` | Name of the attached policy |

## Security Considerations

- Policy follows least-privilege principle
- Only grants describe/list permissions, not admin access
- For kubectl access, also configure EKS aws-auth ConfigMap

## Additional Setup Required

After applying this module, update the EKS aws-auth ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME
      username: ops-user
      groups:
        - system:masters  # Or more restricted group
```

## Dependencies

- `compute/ec2/ops` - EC2 instance with IAM role
- `compute/eks/cluster` - EKS cluster

## Dependent Modules

- None (this is a configuration module)
