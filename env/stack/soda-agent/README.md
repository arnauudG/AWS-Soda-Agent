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

# Soda Agent Stack

Independent Terragrunt stack that deploys **Soda Agent** (data quality monitoring) on Amazon EKS. This stack owns its own VPC, EKS cluster, ops instance, and the Soda Agent Helm add-on.

## Purpose

- Run Soda Agent in Kubernetes to connect to Soda Cloud and execute data quality checks.
- Provide a production-ready, repeatable deployment via IaC (Terraform/Terragrunt) and AWS (EKS, VPC, SSM).

## Stack Layout

| Path | Description |
|------|-------------|
| `network/vpc` | VPC, public/private subnets, NAT gateway(s) |
| `network/vpc-endpoints` | Interface and gateway endpoints (ECR, S3, SSM, STS, CloudWatch Logs, etc.) |
| `ops/sg-ops` | Security groups for ops resources |
| `ops/ec2-ops` | Ops EC2 instance (SSM Session Manager, no SSH keys) |
| `eks` | EKS cluster + managed node group(s) + core add-ons |
| `eks/ops-ec2-eks-access` | IAM so the ops role can describe the cluster (e.g. for `kubectl`) |
| `addons/soda-agent` | Soda Agent Helm chart (orchestrator + jobs) |

## Deploy

```bash
export TF_VAR_environment=dev TF_VAR_region=eu-west-1
export SODA_API_KEY_ID=... SODA_API_KEY_SECRET=...
uv run --no-editable python -m aws_soda_agent.cli deploy --target full
```

Core-only (no Soda Agent add-on):

```bash
uv run --no-editable python -m aws_soda_agent.cli deploy --target stack
```

Redeploy existing Soda Agent (reattach by ID):

```bash
export TF_VAR_environment=dev TF_VAR_region=eu-west-1
export SODA_API_KEY_ID=... SODA_API_KEY_SECRET=...
export SODA_AGENT_ID=<existing-agent-uuid>
uv run --no-editable python -m aws_soda_agent.cli deploy --target full
```

The add-on path is reconciliation-based and idempotent: if namespace, pull-secret, or Helm release state drift exists, the CLI imports/reconciles those resources and retries automatically.

## Destroy

```bash
# Add-on only
uv run --no-editable python -m aws_soda_agent.cli destroy --target addon

# Add-on + infrastructure (keeps bootstrap)
uv run --no-editable python -m aws_soda_agent.cli destroy --target stack

# Add-on + infrastructure + bootstrap
uv run --no-editable python -m aws_soda_agent.cli destroy --target all
```

Add-on is destroyed first (Helm uninstall), then EKS, ops, network. Bootstrap is left in place unless you run `uv run --no-editable python -m aws_soda_agent.cli destroy --target all`.

## Documentation

- **Module (Helm chart wrapper):** [module/application/helm/soda-agent/README.md](../../../module/application/helm/soda-agent/README.md) — inputs, outputs, API keys, troubleshooting.
- **Root:** [README.md](../../../README.md) — project overview, env vars, deployment guide.
- **Contributing:** [CONTRIBUTING.md](../../../CONTRIBUTING.md) — branching, commits, PRs, release checklist.

## Debugging

For day-2 operations, use AWS CLI + kubectl:

```bash
export TF_VAR_environment=dev TF_VAR_region=eu-west-1
aws eks update-kubeconfig --name "${TF_VAR_org:-soda}-${TF_VAR_environment}-soda-agent-eks" --region "$TF_VAR_region"
kubectl get pods -n soda-agent
kubectl logs -n soda-agent <pod> --previous --tail=100
```

Helm pending-operation recovery:

```bash
helm -n soda-agent status soda-agent
helm -n soda-agent history soda-agent
```

## Production Readiness

- **Chart version:** Prod pins `chart_version` in `env/env.hcl` (e.g. `1.3.15`); dev may use latest.
- **Chart repo:** Full URL `https://helm.soda.io/soda-agent/` is used so Terraform does not depend on a pre-run `helm repo add`.
- **Agent ID:** Set `SODA_AGENT_ID` when reusing an existing agent (e.g. after destroy/redeploy) to avoid CrashLoopBackOff ("agent name already registered").
- **Secrets:** API keys are sensitive and not logged; prefer a secrets manager + CI/CD injection; do not commit secrets.
- **State:** Terraform state may contain sensitive values; restrict access to state bucket and lock table.
- **Networking:** EKS nodes need outbound HTTPS to Soda Cloud and `registry.cloud.soda.io`; VPC endpoints (ECR, S3, etc.) are deployed for private connectivity where applicable.
