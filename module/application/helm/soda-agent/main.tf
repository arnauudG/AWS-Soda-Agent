terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws        = { source = "hashicorp/aws", version = ">= 5.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.23, < 3.0" }
    helm       = { source = "hashicorp/helm", version = ">= 2.12, < 3.0" }
  }
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

# ---------- Namespace creation ----------
resource "kubernetes_namespace" "this" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "soda-agent"
      "app.kubernetes.io/instance" = var.agent_name
    }
  }
}

# ---------- Image pull secret handling ----------
locals {
  using_existing_pullsec = trimspace(var.existing_image_pull_secret) != ""

  dockerconfigjson = jsonencode({
    auths = {
      "registry.cloud.soda.io" = {
        username = var.image_credentials_id
        password = var.image_credentials_secret
      }
    }
  })

  # Changes when credentials change → used to trigger rollout
  secret_checksum = sha256(local.dockerconfigjson)
}

# Create the imagePullSecret only when NOT reusing an existing one AND credentials are provided
resource "kubernetes_secret" "image_pull" {
  count = local.using_existing_pullsec ? 0 : (trimspace(var.image_credentials_id) != "" && trimspace(var.image_credentials_secret) != "" ? 1 : 0)

  metadata {
    name      = "${var.agent_name}-pullsecret" # keep stable (no timestamps)
    namespace = var.namespace
  }

  type = "kubernetes.io/docker-registry"

  data = {
    ".dockerconfigjson" = base64encode(local.dockerconfigjson)
  }

  # Clean rotation on cred changes (recreate instead of patch if desired)
  lifecycle {
    replace_triggered_by = [terraform_data.rotate_secret.id]
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels,
    ]
  }

  depends_on = [kubernetes_namespace.this]
}

# Lightweight trigger to force replacement when secret content changes
resource "terraform_data" "rotate_secret" {
  triggers_replace = { checksum = local.secret_checksum }
}

# Resolve the secret name regardless of creation path
locals {
  image_pull_secret_name = local.using_existing_pullsec ? var.existing_image_pull_secret : (length(kubernetes_secret.image_pull) > 0 ? kubernetes_secret.image_pull[0].metadata[0].name : null)
}

# ---------- Helm release ----------
# Determine if repository requires authentication (public Soda repo doesn't need it)
locals {
  # Official public Soda Helm repo doesn't require authentication
  # Only use auth for private/custom repositories
  use_repo_auth = !startswith(var.chart_repo, "https://helm.soda.io")
}

resource "helm_release" "soda_agent" {
  name             = "soda-agent"
  namespace        = var.namespace
  create_namespace = false # We create the namespace explicitly with kubernetes_namespace resource
  repository       = var.chart_repo
  chart            = var.chart_name
  version          = var.chart_version
  # Only set repository auth for private repositories (not the public Soda repo)
  repository_username = local.use_repo_auth ? var.api_key_id : null
  repository_password = local.use_repo_auth ? var.api_key_secret : null
  atomic           = true
  wait_for_jobs    = true
  timeout          = 900
  lint             = false
  # Use upgrade-install mode for idempotent installs (handles orphaned releases gracefully)
  # This is equivalent to: helm upgrade --install
  # If release doesn't exist, installs it; if it exists, upgrades it
  upgrade_install  = true

  # App settings
  set {
    name  = "soda.agent.name"
    value = var.agent_name
  }

  # When set, use existing agent (avoids "agent with name X already registered" on redeploy)
  dynamic "set" {
    for_each = trimspace(var.agent_id) != "" ? [1] : []
    content {
      name  = "soda.agent.id"
      value = var.agent_id
    }
  }

  set {
    name  = "soda.cloud.endpoint"
    value = var.cloud_endpoint
  }

  set_sensitive {
    name  = "soda.apikey.id"
    value = var.api_key_id
  }

  set_sensitive {
    name  = "soda.apikey.secret"
    value = var.api_key_secret
  }

  set {
    name  = "soda.agent.logFormat"
    value = var.log_format
  }

  set {
    name  = "soda.agent.loglevel"
    value = var.log_level
  }

  set {
    name  = "podAnnotations.secret-checksum"
    value = local.secret_checksum
  }

  set {
    name  = "podAnnotations.image-pull-secret-version"
    value = var.image_pull_secret_version
  }

  # Pass imagePullSecrets (existing or newly created)
  dynamic "set" {
    for_each = local.image_pull_secret_name != null ? [1] : []
    content {
      # Adjust if the chart expects a different values path
      name  = "existingImagePullSecrets[0].name"
      value = local.image_pull_secret_name
    }
  }

  # Ensure namespace and secret are created first when TF manages them
  depends_on = [kubernetes_namespace.this, kubernetes_secret.image_pull]
}
