output "namespace" {
  description = "Namespace where Soda Agent is deployed"
  value       = helm_release.soda_agent.namespace
}

output "release_name" {
  description = "Helm release name"
  value       = helm_release.soda_agent.name
}

output "image_pull_secret_name" {
  description = "Name of the imagePullSecret used by the agent (created or existing)"
  value       = local.image_pull_secret_name
}