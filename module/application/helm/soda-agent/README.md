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

# Soda Agent Helm Module

Deploys the Soda Agent to an EKS cluster using Helm.

## Description

This module deploys the Soda Agent to Kubernetes via Helm. The Soda Agent:

- Connects to Soda Cloud for data quality monitoring
- Executes data quality checks on your data sources
- Runs on EKS with auto-configured authentication

## Usage

```hcl
module "soda_agent" {
  source = "../../../module/application/helm/soda-agent"

  cluster_name = dependency.eks.outputs.cluster_name
  region       = "eu-west-1"
  namespace    = "soda-agent"
  agent_name   = "soda-dev-eu-west-1-agent"

  chart_repo    = "https://helm.soda.io/soda-agent/"
  chart_version = "1.3.15"  # Pin in production
  chart_name    = "soda-agent"
  agent_id      = ""       # Optional: existing agent ID when redeploying

  cloud_endpoint = "https://cloud.soda.io"

  api_key_id     = var.SODA_API_KEY_ID
  api_key_secret = var.SODA_API_KEY_SECRET

  # Image registry credentials (defaults to API keys for v1.2.0+)
  image_credentials_id     = var.SODA_API_KEY_ID
  image_credentials_secret = var.SODA_API_KEY_SECRET

  create_namespace = true
}
```

## Agent ID vs. registration

- **Without `agent_id` (default):** The Soda orchestrator starts and tries to **register a new agent** in Soda Cloud with `agent_name`. This works only if that name is **not already taken** (e.g. first-time install, or you have not created an agent with that name in Soda Cloud). If the name is already registered, the orchestrator fails with `agent with name X already registered` and the pod goes into CrashLoopBackOff.
- **With `agent_id` set:** The orchestrator **uses the existing agent** (no registration). Use this when redeploying after a destroy, or when the agent name is already taken (e.g. you created the agent in Soda Cloud UI first). Set `SODA_AGENT_ID` to the agent’s UUID from Soda Cloud (Agents → select agent → ID in the URL).

So deployment (Terraform/Helm) always **installs** the Soda Agent workload (Helm release + pods). Whether the pod stays healthy depends on Soda Cloud: either a new agent is registered (name free) or an existing agent is used (ID provided).

## Required Inputs

| Name | Description | Type |
|------|-------------|------|
| `cluster_name` | EKS cluster name | `string` |
| `region` | AWS region of the cluster | `string` |
| `agent_name` | Soda agent name (unique per Soda Cloud account) | `string` |
| `api_key_id` | Soda Cloud API key ID | `string` |
| `api_key_secret` | Soda Cloud API key secret | `string` |

## Optional Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `namespace` | Kubernetes namespace | `string` | `"soda-agent"` |
| `agent_id` | Existing Soda Agent ID (from Soda Cloud Agents → agent → ID in URL). When set, orchestrator uses this agent instead of registering a new one. | `string` | `""` |
| `chart_repo` | Helm chart repository URL or repo name (use full URL for CI/reproducibility, e.g. `https://helm.soda.io/soda-agent/`) | `string` | `"https://helm.soda.io/soda-agent/"` |
| `chart_version` | Chart version; empty = latest (pin in production, e.g. `1.3.15`) | `string` | `""` |
| `chart_name` | Helm chart name | `string` | `"soda-agent"` |
| `cloud_endpoint` | Soda Cloud endpoint | `string` | `"https://cloud.soda.io"` |
| `image_credentials_id` | Registry API key ID (defaults to agent API key if unset in live config) | `string` | `""` |
| `image_credentials_secret` | Registry API key secret | `string` | `""` |
| `existing_image_pull_secret` | Existing image pull secret name (if set, module does not create one) | `string` | `""` |
| `image_pull_secret_version` | Rollout knob when reusing external secret | `string` | `"v1"` |
| `log_format` | Log format (raw/json) | `string` | `"raw"` |
| `log_level` | Log level (ERROR/WARN/INFO/DEBUG/TRACE) | `string` | `"INFO"` |
| `create_namespace` | Create namespace if not exists | `bool` | `true` |

## Outputs

| Name | Description |
|------|-------------|
| `release_name` | Helm release name |
| `namespace` | Kubernetes namespace where the agent is deployed |
| `image_pull_secret_name` | Name of the imagePullSecret used by the agent (created or existing) |

## Soda Cloud Regions

| Region | Endpoint |
|--------|----------|
| EU | `https://cloud.soda.io` |
| US | `https://cloud.us.soda.io` |

Set `cloud_endpoint` based on your Soda Cloud region.

## Security Considerations

- API keys are marked as sensitive and not logged
- Image pull secrets are created automatically
- Agent runs with minimal permissions in dedicated namespace
- Use IRSA for AWS data source access (not yet implemented)

Note: Terraform state should still be treated as sensitive. Even with `set_sensitive` and sensitive variables, secrets can end up in state and must not be shared.

## Cost Implications

The Soda Agent itself runs on your EKS cluster nodes:

| Resource | Cost Impact |
|----------|-------------|
| Pod resources | ~0.5 vCPU, 1GB RAM per agent pod |
| Data transfer | Variable (depends on check frequency) |

## Dependencies

- `compute/eks/cluster` - EKS cluster for agent deployment

## API keys (per Soda docs)

Per [Soda Kubernetes deployment docs](https://docs.soda.io/deployment-options/soda-agent/deploy-soda-agent/deploy-a-soda-agent-in-a-kubernetes-cluster): use **only** the values from the **New Soda Agent** dialog in Soda Cloud.

| Env var | Purpose | Source |
|--------|---------|--------|
| `SODA_API_KEY_ID` / `SODA_API_KEY_SECRET` | Agent registration + Soda Cloud connection | **Data Sources → Agents → New Soda Agent** — copy ID and Secret from the dialog |
| `SODA_IMAGE_APIKEY_ID` / `SODA_IMAGE_APIKEY_SECRET` | (Optional) Pull images from `registry.cloud.soda.io` | If unset, agent keys above are used. Set only if Soda gave you separate registry credentials. |

**Do not use** keys from **Profile → API Keys** for `SODA_API_KEY_*` — those are human user keys and cause `403 Invalid user type: HumanUser`. Use only the keys from the **New Soda Agent** dialog (agent/Service Account keys).

**Steps:**

1. Log in to Soda Cloud
2. Go to **Data Sources → Agents**
3. Click **New Soda Agent** (or open an existing agent)
4. Copy the API key **ID** and **Secret** from the dialog
5. Set `SODA_API_KEY_ID` and `SODA_API_KEY_SECRET` to those values (leave `SODA_IMAGE_*` unset unless you have separate registry credentials)

**Important**: The agent name must be unique within your Soda Cloud account. If you get registration errors, try a different name or delete the old agent from Soda Cloud.

## Troubleshooting

### Agent not appearing in Soda Cloud
```bash
# Check pod logs
kubectl logs -n soda-agent -l app.kubernetes.io/name=soda-agent

# Check pod status
kubectl get pods -n soda-agent
```

### Image pull errors
Verify your API keys are correct and have access to the Soda private registry.

### Connection issues
- Check EKS node security groups allow outbound HTTPS
- Verify VPC NAT Gateway is working for internet access

## References

- [Soda: Deploy a Soda Agent in a Kubernetes cluster](https://docs.soda.io/soda-v4/deployment-options/deploy-soda-agent/deploy-a-soda-agent-in-a-kubernetes-cluster) — official deployment and API key guidance.
- [Soda Agent Helm chart](https://helm.soda.io/soda-agent/) — public Helm repository.
