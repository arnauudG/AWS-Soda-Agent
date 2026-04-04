# AWS Soda Agent

Infrastructure as Code package for deploying **Soda Agent** on AWS EKS using Terraform + Terragrunt, orchestrated by a Python CLI.

## Purpose

Deploy a complete, self-contained Soda Agent environment in AWS through a single CLI command. The agent runs containerized on EKS and connects outbound to Soda Cloud for centralized data quality monitoring.

## Business context

Data engineering teams need a managed Soda Agent that connects to Soda Cloud to execute data quality checks against their data sources. This package provides deterministic deploy/destroy flows, cost-optimized dev defaults (SPOT instances, single NAT), and an ops instance for day-2 debugging.

## Scope

**In scope:** VPC networking with multi-AZ subnet layout, EKS cluster with managed SPOT node groups, Soda Agent Helm chart, VPC endpoints for private AWS service access, ops EC2 instance (SSM only), stack-scoped state backend.

**Out of scope:** data source connectivity configuration, Soda Cloud account setup, multi-cluster federation, HTTPS ingress (agent is outbound-only), CI/CD pipeline.

## Architecture

The stack deploys Soda Agent as a Helm chart on EKS in private subnets. The agent connects outbound to Soda Cloud via NAT gateway — there is no inbound internet traffic to the application. An ops EC2 instance in a public subnet provides administrative access via SSM Session Manager.

See `soda-agent-architecture.drawio` and `soda-agent-architecture.svg` for the full diagram.

### Network layout

The VPC is carved into `/22` subnets (1024 IPs each) using `cidrsubnet(cidr, 6, index)`, distributed across 3 availability zones.

```
VPC 10.10.0.0/16 (dev) · 10.20.0.0/16 (prod)
├── Public subnets (/22 per AZ)
│   ├── AZ-a: 10.10.0.0/22   ← Ops EC2, NAT gateway
│   ├── AZ-b: 10.10.4.0/22   ← NAT gateway (prod per-AZ)
│   └── AZ-c: 10.10.8.0/22   ← NAT gateway (prod per-AZ)
│
└── Private subnets (/22 per AZ)
    ├── AZ-a: 10.10.12.0/22  ← EKS node group, VPC endpoints
    ├── AZ-b: 10.10.16.0/22  ← EKS node group, VPC endpoints
    └── AZ-c: 10.10.20.0/22  ← EKS node group, VPC endpoints
```

### Traffic flow

Soda Agent pods run on EKS managed node groups in private subnets. Outbound traffic to Soda Cloud (`cloud.soda.io`) exits through NAT gateway(s) in the public subnets and the internet gateway. There is no inbound internet traffic — the agent initiates all connections to Soda Cloud.

The ops EC2 instance in the AZ-a public subnet provides `kubectl` and `helm` access to the EKS cluster API on port 443. Access to the ops instance itself is exclusively through SSM Session Manager — no SSH keys, no public IP dependency.

### VPC endpoints

Eight VPC endpoints keep control-plane and container-registry traffic off the public internet:

- `ssm`, `ssmmessages`, `ec2messages` — Interface endpoints for SSM Session Manager
- `ecr.api`, `ecr.dkr` — Interface endpoints for ECR container image pulls
- `sts` — Interface endpoint for security token service
- `logs` — Interface endpoint for CloudWatch Logs
- `s3` — Gateway endpoint for ECR layer downloads and state access

### NAT gateway topology

Dev uses a single NAT gateway (cost optimization). Prod uses one NAT gateway per AZ (resilience). Controlled by `vpc.single_nat_gateway` in `env/env.hcl`.

### EKS cluster

The EKS cluster runs Kubernetes 1.31 with managed node groups using SPOT instances (`t3.small`). Core add-ons (CoreDNS, kube-proxy, VPC CNI with prefix delegation) are managed by EKS. The cluster API endpoint is public in dev and private-only in prod.

The Soda Agent is deployed as a Helm chart into the `soda-agent` namespace. The agent pod connects to Soda Cloud for orchestration and job execution.

### State backend

A dedicated S3 bucket (versioned, encrypted) + DynamoDB lock table is bootstrapped per stack/environment as the first deployment step. Naming: `<account>-<org>-<env>-soda-agent-tfstate-<region>`.

## Module execution order

The CLI orchestrator (`aws_soda_agent.cli`) executes Terragrunt modules in deterministic order.

### Deploy order

| Step | Module path | Domain | bootstrap | stack | full |
|------|-------------|--------|:---------:|:-----:|:----:|
| 1 | `bootstrap` | State | ✓ | ✓ | ✓ |
| 2 | `network/vpc` | Network | | ✓ | ✓ |
| 3 | `network/vpc-endpoints` | Network | | ✓ | ✓ |
| 4 | `ops/sg-ops` | Security | | ✓ | ✓ |
| 5 | `eks` | Compute | | ✓ | ✓ |
| 6 | `ops/ec2-ops` | Compute | | ✓ | ✓ |
| 7 | `eks/ops-ec2-eks-access` | IAM | | ✓ | ✓ |
| 8 | `addons/soda-agent` | App | | | ✓ |

### Destroy order

Reverse of deploy. `destroy --target addon` removes step 8. `destroy --target stack` removes 8–2. `destroy --target all` removes everything including bootstrap.

## Configuration reference

### Variables by deploy target

| Variable | bootstrap | stack | full | Notes |
|----------|:---------:|:-----:|:----:|-------|
| `TF_VAR_environment` | ✓ | ✓ | ✓ | `dev` or `prod` |
| `TF_VAR_region` | ✓ | ✓ | ✓ | `eu-west-1`, `us-east-1`, `eu-central-1` |
| AWS credentials | ✓ | ✓ | ✓ | `AWS_PROFILE` or access key pair |
| `SODA_API_KEY_ID` | | | ✓ | Service Account key from Soda Cloud |
| `SODA_API_KEY_SECRET` | | | ✓ | Service Account secret from Soda Cloud |
| `TF_VAR_org` | opt | opt | opt | Resource name prefix (default: `soda`) |

Legend: ✓ = required, opt = optional override

### Soda Agent variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SODA_AGENT_ID` | empty | Existing agent UUID for redeploy/reattach |
| `SODA_CLOUD_REGION` | `eu` | Soda Cloud region (`eu` or `us`) |
| `SODA_LOG_LEVEL` | `INFO` | Agent log level |
| `SODA_LOG_FORMAT` | `raw` | Log format (`raw` or `json`) |
| `SODA_IMAGE_APIKEY_ID` | uses `SODA_API_KEY_ID` | Separate registry credentials (if provided by Soda) |
| `SODA_IMAGE_APIKEY_SECRET` | uses `SODA_API_KEY_SECRET` | Separate registry credentials |
| `TG_EXPECTED_ACCOUNT_ID` | empty | Safety check against wrong AWS account |

### Environment-specific defaults (env/env.hcl)

| Setting | Dev | Prod |
|---------|-----|------|
| VPC CIDR | 10.10.0.0/16 | 10.20.0.0/16 |
| NAT gateway | Single | Per-AZ |
| VPC flow logs | Disabled | Enabled |
| EKS node group | 1–2 × t3.small SPOT | 2–5 × t3.small SPOT |
| EKS public endpoint | Yes | No |
| CW log retention | 7 days | 30 days |
| Ops EC2 | t3.micro, 16 GB | t3.small, 20 GB |
| Helm chart version | Latest | Pinned (1.3.15) |

### Soda Cloud API keys

Use **only** keys from the **New Soda Agent** dialog in Soda Cloud:

1. Log in to [Soda Cloud](https://cloud.soda.io)
2. Go to **Data Sources → Agents → New Soda Agent**
3. Copy the **API Key ID** and **API Key Secret** from the dialog

Do **not** use keys from Profile → API Keys — those are human user keys and cause `403 Invalid user type: HumanUser`.

### Agent ID vs. registration

Without `SODA_AGENT_ID`: the agent registers a new agent name in Soda Cloud. This works only if the name is not already taken. If it is, the pod enters CrashLoopBackOff with "agent with name X already registered."

With `SODA_AGENT_ID`: the agent reuses an existing agent (no registration). Use this when redeploying after a destroy, or when the agent name is already taken. Find the ID in Soda Cloud: Agents → select agent → UUID in the URL.

## Quick start

```bash
# 1. Clone and install
git clone <repository-url>
cd AWS-Soda-Agent
uv sync

# 2. Set required variables
export TF_VAR_environment=dev
export TF_VAR_region=eu-west-1
export AWS_PROFILE=my-profile
export SODA_API_KEY_ID=<your-key-id>
export SODA_API_KEY_SECRET=<your-key-secret>

# 3. Deploy full stack
uv run --no-editable python -m aws_soda_agent.cli deploy --target full

# 4. Verify
cd env/stack/soda-agent/eks
terragrunt output cluster_endpoint
```

`--no-editable` is recommended when project paths include spaces.

## Usage

### Command reference

```bash
# Help
uv run --no-editable python -m aws_soda_agent.cli --help

# Full deploy (bootstrap + infra + Soda Agent Helm)
uv run --no-editable python -m aws_soda_agent.cli deploy --target full

# Infrastructure only (no Helm add-on)
uv run --no-editable python -m aws_soda_agent.cli deploy --target stack

# Bootstrap only
uv run --no-editable python -m aws_soda_agent.cli deploy --target bootstrap

# Destroy Soda Agent add-on only
uv run --no-editable python -m aws_soda_agent.cli destroy --target addon

# Destroy add-on + infra (keep bootstrap)
uv run --no-editable python -m aws_soda_agent.cli destroy --target stack

# Destroy everything including bootstrap
uv run --no-editable python -m aws_soda_agent.cli destroy --target all
```

### Target matrix

| Command | Target | What it does |
|---------|--------|--------------|
| `deploy` | `bootstrap` | State backend only (S3 + DynamoDB) |
| `deploy` | `stack` | Backend + VPC + endpoints + EKS + ops |
| `deploy` | `full` | Stack + Soda Agent Helm chart |
| `destroy` | `addon` | Soda Agent Helm chart only |
| `destroy` | `stack` | Add-on + infra, preserve bootstrap |
| `destroy` | `all` | Everything including bootstrap teardown |

### New deploy vs. redeploy

```bash
# New agent (first time)
unset SODA_AGENT_ID
uv run --no-editable python -m aws_soda_agent.cli deploy --target full

# Redeploy existing agent
export SODA_AGENT_ID=<existing-agent-uuid>
uv run --no-editable python -m aws_soda_agent.cli deploy --target full
```

## Prerequisites

| Tool | Purpose | Minimum version |
|------|---------|-----------------|
| `uv` | Python runtime + CLI | latest |
| `python` | CLI runtime | >= 3.11 |
| `terraform` | Infrastructure provisioning | >= 1.5.0 |
| `terragrunt` | Orchestration and dependencies | latest |
| `aws` CLI | AWS API access | v2.x |
| `kubectl` | EKS cluster access | latest |
| `helm` | Soda Agent Helm deployment | v3.x |

## Package contents

```
├── pyproject.toml                       # uv package + entrypoint
├── src/aws_soda_agent/
│   ├── cli.py                           # argparse interface
│   ├── orchestrator.py                  # deploy/destroy orchestration
│   └── shell.py                         # subprocess wrapper
├── env/
│   ├── root.hcl                         # global config, validations, remote state
│   ├── env.hcl                          # environment catalog (dev/prod)
│   ├── common.hcl                       # provider + backend generation
│   └── stack/soda-agent/
│       ├── root.hcl                     # stack-scoped remote state
│       ├── bootstrap/                   # S3 + DynamoDB state backend
│       ├── network/
│       │   ├── vpc/                     # VPC + subnets + NAT
│       │   └── vpc-endpoints/           # SSM, ECR, STS, CW, S3
│       ├── ops/
│       │   ├── sg-ops/                  # ops security group
│       │   └── ec2-ops/                 # ops EC2 + user-data
│       ├── eks/
│       │   ├── (main)                   # EKS cluster + node groups
│       │   └── ops-ec2-eks-access/      # IAM for ops → EKS
│       └── addons/soda-agent/           # Helm chart deployment
├── module/                              # reusable Terraform modules
│   ├── application/helm/soda-agent/
│   ├── compute/ec2/ops/
│   ├── compute/eks/cluster/
│   ├── network/vpc/
│   ├── network/vpc-endpoints/
│   ├── security/iam/ops-eks-access/
│   └── security/security-group/ops/
└── .pre-commit-config.yaml              # fmt/validate/tflint/tfsec/checkov
```

## Operational runbook

### Preflight

```bash
aws sts get-caller-identity
uv run --no-editable python -m aws_soda_agent.cli --help
```

### Verify EKS and Soda Agent after deploy

```bash
# Configure kubectl
aws eks update-kubeconfig \
  --name "${TF_VAR_org:-soda}-${TF_VAR_environment}-soda-agent-eks" \
  --region "$TF_VAR_region"

# Check pods
kubectl get pods -n soda-agent

# Check agent logs
kubectl logs -n soda-agent -l app.kubernetes.io/name=soda-agent --tail=50

# Helm status
helm -n soda-agent status soda-agent
```

### SSM access to ops instance

```bash
INSTANCE_ID=$(cd env/stack/soda-agent/ops/ec2-ops && terragrunt output -raw instance_id)
aws ssm start-session --target "$INSTANCE_ID"
```

### Helm pending operation recovery

If the Helm release is stuck in `pending-install` or `pending-upgrade`:

```bash
helm -n soda-agent history soda-agent
helm -n soda-agent rollback soda-agent <last-stable-revision>
```

The CLI handles this automatically during `deploy --target full` with up to 6 reconciliation attempts.

## Troubleshooting

### Soda Agent CrashLoopBackOff

Cause: agent name already registered in Soda Cloud from a previous deployment. Fix: set `SODA_AGENT_ID` to the existing agent UUID and redeploy.

### Image pull errors

Verify API keys have access to `registry.cloud.soda.io`. Check pod events: `kubectl describe pod -n soda-agent <pod-name>`.

### Soda API Key 403

You're using Profile API Keys (human user keys). Use Service Account keys from Data Sources → Agents → New Soda Agent.

### State lock error

Confirm no concurrent apply/destroy is running. Force unlock only if safe: `terragrunt force-unlock <lock-id>`.

### Bootstrap destroy fails (BucketNotEmpty / lock release)

The CLI purges bucket versions and retries automatically. It also tolerates the known DynamoDB lock-release race condition when resources are already gone.

### Add-on deploy fails (already exists / Helm pending)

The CLI auto-reconciles: imports existing namespace and image pull secret, resolves pending Helm states with rollback or uninstall fallback, then retries.

## Architecture decision records

### ADR-001: CLI-first orchestration

A Python CLI centralizes deploy/destroy orchestration, bootstrap import recovery, Helm pending-state reconciliation, and environment validation. Direct Terragrunt remains possible for debugging.

### ADR-002: Independent stack architecture

The Soda Agent stack is fully self-contained with its own VPC, state backend, and networking. No cross-stack dependencies.

### ADR-003: Environment-driven configuration

All runtime config is injected via environment variables. No static config files to manage or commit. Environment catalog in `env/env.hcl` defines dev/prod defaults.

### ADR-004: EKS with SPOT instances

Managed node groups use SPOT capacity for cost optimization. Soda Agent workloads are stateless and tolerate interruption. SPOT savings are ~60-70% vs. on-demand.

### ADR-005: Outbound-only networking

No ALB, no inbound rules. The Soda Agent initiates all connections to Soda Cloud. This simplifies security: no ingress rules, no TLS certificate management, no domain configuration.

### ADR-006: Ops EC2 in public subnet

The ops instance is in a public subnet with a public IP for SSM reachability. No inbound security group rules — access is exclusively via SSM Session Manager. This avoids the cost of an SSM VPC endpoint for the ops instance while keeping the EKS nodes fully private.

### ADR-007: Configurable organization prefix

All resource names use `${org}-${env}-soda-agent-<resource>`. Override with `TF_VAR_org` to avoid naming collisions in shared accounts.

### ADR-008: Bootstrap import-aware design

Bootstrap automatically imports existing S3/DynamoDB resources if they exist but state is missing, enabling recovery from state loss or manual intervention.

### ADR-009: Helm reconciliation on retry

The add-on deploy handles pre-existing namespace/secret resources (via Terraform import) and stuck Helm releases (via rollback to last stable revision or uninstall fallback) automatically.

## Security notes

1. Terraform state contains secrets (even with `sensitive = true`) — protect backend access with IAM.
2. Never commit Soda API keys or AWS credentials into repo files.
3. EKS nodes run in private subnets — outbound traffic goes through NAT gateway only.
4. Ops EC2 access via SSM only — no SSH keys, no inbound security group rules.
5. S3 state backend is encrypted (AES256), versioned, public access blocked, TLS enforced.
6. EKS cluster endpoint is private-only in prod (`cluster_endpoint_public_access = false`).
7. IMDSv2 is enforced on all EC2 instances (`http_tokens = required`).
8. Default VPC security group is locked down (no ingress, no egress).
9. Set `TG_EXPECTED_ACCOUNT_ID` in CI/CD to prevent cross-account misfire.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for branching strategy, commit conventions, and release checklist.

## Additional documentation

| Document | Description |
|----------|-------------|
| `soda-agent-architecture.drawio` | Architecture diagram (infrastructure topology) |
| `soda-agent-architecture.svg` | SVG architecture diagram |
| [env/README.md](env/README.md) | Terragrunt config hierarchy |
| [env/stack/soda-agent/README.md](env/stack/soda-agent/README.md) | Stack deployment guide |
| [module/application/helm/soda-agent/README.md](module/application/helm/soda-agent/README.md) | Helm chart module (inputs, API keys, troubleshooting) |
| [module/compute/eks/cluster/README.md](module/compute/eks/cluster/README.md) | EKS cluster module |
| [module/network/vpc/README.md](module/network/vpc/README.md) | VPC module |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Process and release guidance |