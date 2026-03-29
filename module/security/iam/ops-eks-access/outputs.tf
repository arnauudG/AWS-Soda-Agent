output "attached_role_name" {
  description = "Role the policy was attached to"
  value       = data.aws_iam_role.ops.name
}

output "policy_arn" {
  description = "ARN of the created EKS access policy"
  value       = aws_iam_policy.eks_manage.arn
}