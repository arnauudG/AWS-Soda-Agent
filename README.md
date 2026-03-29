# AWS Soda Agent

Infrastructure as Code (IaC) package for deploying **Soda Agent** on AWS using Terraform and Terragrunt. Soda Agent runs containerized on Amazon EKS, connecting to [Soda Cloud](https://cloud.soda.io) for centralized data quality monitoring.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Package Contents](#package-contents)
- [Prerequisites](#prerequisites)
- [Environment Variables](#environment-variables)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Components](#components)
- [Design Decisions](#design-decisions)
- [Troubleshooting](#troubleshooting)
- [Security Notes](#security-notes)
- [Contributing](#contributing)
- [Additional Documentation](#additional-documentation)

## Overview

This package deploys a complete, self-contained Soda Agent stack on AWS:

- **Amazon EKS** cluster with managed node groups (SPOT instances)
- **VPC** with public/private subnets across 3 AZs
- **VPC Endpoints** for private AWS service access (ECR, S3, SSM, STS, CloudWatch)
- **Ops EC2 instance** for debugging (SSM Session Manager, no SSH)
- **Soda Agent Helm chart** deployed into EKS

All resource names follow the pattern `${org}-${env}-soda-agent-<resource>`, where `org` is configurable via `TF_VAR_org` (default: `soda`).

## Architecture

```
                         Soda Cloud (EU/US)
                              |
                    ┌─────────┴─────────┐
                    │   Soda Agent Pod  │
                    │  (Helm on EKS)    │
                    └─────────┬─────────┘
                              │
┌─────────────────────────────┴────────────────────────────────┐
│  AWS Account                                                 │
│                                                              │
│  ┌─ VPC (10.x.0.0/16) ────────────────────────────────────┐  │
│  │                                                        │  │
│  │  ┌─ Private Subnets ──────────────────────────────┐    │  │
│  │  │  EKS Managed Node Groups (t3.small, SPOT)      │    │  │
│  │  │  Ops EC2 Instance (SSM access)                 │    │  │
│  │  │  VPC Endpoints (ECR, S3, SSM, STS, CW Logs)    │    │  │
│  │  └────────────────────────────────────────────────┘    │  │
│  │                                                        │  │
│  │  ┌─ Public Subnets ───────────────────────────────┐    │  │
│  │  │  NAT Gateway(s)   Internet Gateway             │    │  │
│  │  └────────────────────────────────────────────────┘    │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  S3 (tfstate) + DynamoDB (locks) — per-stack backend         │
└──────────────────────────────────────────────────────────────┘
```

## Package Contents

```
AWS-Soda-Agent/
├── pyproject.toml                    # uv project and CLI entrypoint
├── src/aws_soda_agent/               # Python CLI package (deploy/destroy orchestration)
├── .pre-commit-config.yaml           # Terraform fmt/validate/tflint/tfsec/checkov
│
├── env/                              # Terragrunt configuration
│   ├── root.hcl                     # Global config: validations, remote state, shared inputs
│   ├── env.hcl                      # Environment definitions (dev/prod)
│   ├── common.hcl                   # Common provider/backend generation
│   └── stack/
│       ├── stack-globals.hcl        # Shared stack-level variable propagation
│       └── soda-agent/              # Live infrastructure configs
│           ├── root.hcl             # Stack-scoped remote state
│           ├── bootstrap/           # S3 + DynamoDB for state backend
│           ├── network/
│           │   ├── vpc/             # VPC, subnets, routing, NAT
│           │   └── vpc-endpoints/
│           ├── ops/
│           │   ├── sg-ops/          # Security groups for ops
│           │   └── ec2-ops/         # Ops EC2 instance
│           ├── eks/
│           │   ├── terragrunt.hcl          # EKS cluster + node groups
│           │   └── ops-ec2-eks-access/     # IAM/RBAC for ops → EKS
│           └── addons/
│               └── soda-agent/      # Helm chart deployment
│
└── module/                           # Reusable Terraform modules
    ├── application/helm/soda-agent/  # Helm provider wrapper
    ├── compute/
    │   ├── ec2/ops/                  # Ops EC2 instance
    │   └── eks/cluster/              # EKS cluster (wraps terraform-aws-modules/eks)
    ├── network/
    │   ├── vpc/                      # VPC (wraps terraform-aws-modules/vpc)
    │   └── vpc-endpoints/            # VPC endpoints
    └── security/
        ├── iam/ops-eks-access/       # IAM for ops EC2 → EKS
        └── security-group/ops/       # Security group module
```

## Prerequisites

### Required Tools

| Tool | Purpose | Minimum Version |
|------|---------|----------------|
| **uv** | Python runtime + CLI execution | Latest |
| **Python** | Runtime for the CLI | >= 3.11 |
| **Terraform** | Infrastructure provisioning | >= 1.5.0 |
| **Terragrunt** | Terraform orchestration | Latest |
| **AWS CLI** | AWS API access | v2.x |
| **kubectl** | EKS cluster access | Latest |
| **Helm** | Kubernetes package manager (optional, for debugging) | v3.x |

### AWS Account Setup

Your AWS credentials need permissions to create: VPC, subnets, NAT gateways, EKS clusters, EC2 instances, security groups, IAM roles, S3 buckets, DynamoDB tables, and CloudWatch Logs.

### Soda Cloud Setup

1. Log in to [Soda Cloud](https://cloud.soda.io)
2. Go to **Data Sources > Agents > New Soda Agent**
3. Copy the **API Key ID** and **API Key Secret** from the dialog
4. Do **NOT** use keys from Profile > API Keys (those are human user keys and will 403)

## Environment Variables

All configuration is passed via environment variables. No configuration files are needed. This makes the package CI/CD-ready out of the box.

### Required (all commands)

| Variable | Description | Example |
|----------|-------------|---------|
| `TF_VAR_environment` | Target environment | `dev` or `prod` |
| `TF_VAR_region` | AWS region | `eu-west-1`, `us-east-1`, `eu-central-1` |
| `AWS_PROFILE` or `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` | AWS credentials | - |
| `SODA_API_KEY_ID` | Soda Cloud API key ID (required only for `deploy --target full`) | - |
| `SODA_API_KEY_SECRET` | Soda Cloud API key secret (required only for `deploy --target full`) | - |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `TF_VAR_org` | `soda` | Organisation prefix for all resource names |
| `SODA_CLOUD_REGION` | `eu` | Soda Cloud region (`eu` or `us`) |
| `SODA_LOG_LEVEL` | `INFO` | Agent log level |
| `SODA_LOG_FORMAT` | `raw` | Log format (`raw` or `json`) |
| `SODA_AGENT_ID` | - | Existing agent UUID (set when redeploying to avoid name conflict) |
| `SODA_IMAGE_APIKEY_ID` | `SODA_API_KEY_ID` | Separate registry credentials (only if provided by Soda) |
| `SODA_IMAGE_APIKEY_SECRET` | `SODA_API_KEY_SECRET` | Separate registry credentials |
| `TG_EXPECTED_ACCOUNT_ID` | - | Safety check: fail if authenticated to wrong AWS account |

## Quick Start

```bash
# 1. Clone
git clone https://github.com/arnauudG/AWS-Soda-Agent.git
cd AWS-Soda-Agent

# 2. Export required variables
export T
export TF_VAR_environment=dev
export TF_VAR_region=eu-west-1
export AWS_PROFILE=my-profile
export SODA_API_KEY_ID=<your-key-id>
export SODA_API_KEY_SECRET=<your-key-secret>

# 3. Sync local CLI environment
uv sync

# 4. Deploy
uv run --no-editable python -m aws_soda_agent.cli deploy --target full

# 5. Verify
cd env/stack/soda-agent/eks
terragrunt output cluster_endpoint
```

## Usage

Everything goes through `uv run --no-editable python -m aws_soda_agent.cli`:

`--no-editable` ensures reliable execution in workspaces with spaces in the path.

```bash
# Deploy full stack (bootstrap + infra + Soda Agent add-on)
uv run --no-editable python -m aws_soda_agent.cli deploy --target full

# Deploy state backend only
uv run --no-editable python -m aws_soda_agent.cli deploy --target bootstrap

# Deploy bootstrap + infrastructure (no Soda Agent add-on)
uv run --no-editable python -m aws_soda_agent.cli deploy --target stack

# Destroy only Soda Agent add-on
uv run --no-editable python -m aws_soda_agent.cli destroy --target addon

# Destroy add-on + infrastructure (preserves bootstrap)
uv run --no-editable python -m aws_soda_agent.cli destroy --target stack

# Destroy add-on + infrastructure + bootstrap
uv run --no-editable python -m aws_soda_agent.cli destroy --target all
```

### New Deploy vs Redeploy

- New deployment (register a new agent): set `SODA_API_KEY_ID` + `SODA_API_KEY_SECRET`, leave `SODA_AGENT_ID` unset.
- Redeploy/reattach existing agent: set the same API keys and set `SODA_AGENT_ID` to the existing agent UUID from Soda Cloud.
- Optional registry overrides: `SODA_IMAGE_APIKEY_ID` and `SODA_IMAGE_APIKEY_SECRET` must be set together (or both unset).

### Target Matrix

| Command | Target | What it does | Required checks |
|---------|--------|--------------|-----------------|
| `deploy` | `bootstrap` | Deploy/import only state backend (S3 + DynamoDB) | core env + `aws` + `terragrunt` + AWS auth |
| `deploy` | `stack` | `bootstrap` + core infra modules | bootstrap checks + `terraform` |
| `deploy` | `full` | `stack` + Soda Agent Helm add-on | stack checks + `SODA_API_KEY_ID` + `SODA_API_KEY_SECRET` |
| `destroy` | `addon` | Destroy only Soda Agent add-on | core env + `aws` + `terragrunt` + AWS auth |
| `destroy` | `stack` | Destroy add-on + infra, keep bootstrap | destroy checks + interactive confirmation |
| `destroy` | `all` | Destroy add-on + infra + bootstrap | stack checks + confirmation + bootstrap confirmation |

### CLI Reference

- Show help: `uv run --no-editable python -m aws_soda_agent.cli --help`
- Deploy default target: `full` (if `--target` is omitted)
- Destroy default target: `stack` (if `--target` is omitted)
- Non-interactive apply/destroy flags are set internally (`TF_INPUT=0`, `TG_INPUT=0`)
- For unusual launch contexts, set `AWS_SODA_AGENT_ROOT` to your repo root before running commands

### Operator Runbook

Use these blocks as day-2 copy/paste commands.

#### 1) New Deploy (new Soda Agent registration)

```bash
export TF_VAR_environment=dev
export TF_VAR_region=eu-west-1
export AWS_PROFILE=my-profile
export SODA_API_KEY_ID=<agent-key-id>
export SODA_API_KEY_SECRET=<agent-key-secret>
unset SODA_AGENT_ID

uv sync
uv run --no-editable python -m aws_soda_agent.cli deploy --target full
```

#### 2) Redeploy / Reattach Existing Agent

```bash
export TF_VAR_environment=dev
export TF_VAR_region=eu-west-1
export AWS_PROFILE=my-profile
export SODA_API_KEY_ID=<agent-key-id>
export SODA_API_KEY_SECRET=<agent-key-secret>
export SODA_AGENT_ID=<existing-agent-uuid>

uv sync
uv run --no-editable python -m aws_soda_agent.cli deploy --target full
```

#### 3) Partial Destroy (remove add-on only)

```bash
export TF_VAR_environment=dev
export TF_VAR_region=eu-west-1
export AWS_PROFILE=my-profile

uv run --no-editable python -m aws_soda_agent.cli destroy --target addon
```

#### 4) Full Teardown (add-on + stack + bootstrap)

```bash
export TF_VAR_environment=dev
export TF_VAR_region=eu-west-1
export AWS_PROFILE=my-profile

uv run --no-editable python -m aws_soda_agent.cli destroy --target all
```

### Individual Module

For advanced use, you can apply individual modules directly:

```bash
cd env/stack/soda-agent/network/vpc
terragrunt apply
```

## Components

### Bootstrap

Creates a per-stack S3 bucket and DynamoDB table for Terraform state. Import-aware: if resources exist but state is missing, they are imported automatically.

**Naming**: `${ACCOUNT_ID}-${org}-${env}-soda-agent-tfstate-${region}` / `...-tf-locks`

### VPC & Networking

| Setting | Dev | Prod |
|---------|-----|------|
| CIDR | 10.10.0.0/16 | 10.20.0.0/16 |
| NAT Gateway | Single (cost-optimized) | Per-AZ (HA) |
| Flow Logs | Disabled | Enabled |

### EKS Cluster

| Setting | Dev | Prod |
|---------|-----|------|
| Node instances | t3.small (1-2) | t3.small (2-5) |
| Capacity | SPOT | SPOT |
| Kubernetes | v1.31 | v1.31 |
| Public endpoint | Yes | No |
| Log retention | 7 days | 30 days |

### Soda Agent Helm Chart

| Setting | Dev | Prod |
|---------|-----|------|
| Chart version | Latest | Pinned (1.3.15) |
| Namespace | soda-agent | soda-agent |
| Cloud endpoint | EU (`cloud.soda.io`) | EU (`cloud.soda.io`) |

### Ops EC2 Instance

Small instance (`t3.micro` dev / `t3.small` prod) accessible only via AWS SSM Session Manager. Used for debugging EKS and running kubectl.

## Design Decisions

### Independent Stack Architecture

The Soda Agent stack is fully self-contained with its own VPC, state backend, and networking. This eliminates cross-stack dependencies and simplifies deployment/destruction.

### Terragrunt Orchestration

Shared config in `env/root.hcl` + `env/env.hcl` provides DRY environment definitions. Dependencies between modules are declared explicitly. Remote state is configured automatically per module.

### Single Entry Point

One `uv` CLI (`uv run --no-editable python -m aws_soda_agent.cli`) provides deploy and destroy workflows with target-based scope control. All configuration is injected via environment variables — no config files to manage or commit. Directly compatible with CI/CD pipelines where secrets are injected at runtime.

### Configurable Organisation Prefix

All resource names use `${org}-${env}-soda-agent-<resource>`. The `org` prefix defaults to `soda` but can be overridden with `TF_VAR_org` to avoid naming collisions when deploying in shared accounts.

### Bootstrap Import-Aware Design

Bootstrap automatically imports existing S3/DynamoDB resources if they exist but state is missing, enabling recovery from state loss.

### Mock Outputs for Validation

All Terragrunt dependencies include `mock_outputs` with `mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]`, allowing validation without deploying dependencies.

### Naming Conventions

- Resources: `${org}-${env}-soda-agent-<resource-type>` (e.g., `soda-dev-soda-agent-eks`)
- VPC: `${org}-${env}-${region}-soda-agent-vpc`
- State bucket: `${account}-${org}-${env}-soda-agent-tfstate-${region}`
- Agent name: `${org}-${env}-agent`

## Troubleshooting

### AWS Credentials Not Working

1. Verify your environment variables are set: `env | grep -E 'AWS_|TF_VAR_'`
2. If using access keys, ensure `AWS_PROFILE` is unset: `unset AWS_PROFILE`
3. Test: `aws sts get-caller-identity`

### Soda Agent CrashLoopBackOff

**Cause**: Agent name already registered in Soda Cloud from a previous deployment.

**Fix**: Set `SODA_AGENT_ID` to the existing agent's UUID (visible in Soda Cloud URL: Agents > agent > ID in URL), then redeploy.

### State Lock Error

```
Error: Error acquiring the state lock
```

Only unlock if you are sure no other process is using the state:
```bash
cd env/stack/soda-agent/<module>
terragrunt force-unlock <lock-id>
```

### Bootstrap Resources Exist But State Missing

The deploy handles this automatically via import. If it doesn't:
```bash
cd env/stack/soda-agent/bootstrap
terragrunt import aws_s3_bucket.tfstate <bucket-name>
terragrunt import aws_dynamodb_table.locks <table-name>
terragrunt apply
```

### Bootstrap Destroy Fails (`BucketNotEmpty` / lock release error)

If `destroy --target all` fails while deleting bootstrap, typical causes are:
- The state bucket still has object versions/delete markers.
- Terraform deleted the DynamoDB lock table before lock release completed.

The CLI now purges bucket versions and retries automatically, and treats the known lock-release race as successful if bucket + table are already gone.
It also tolerates `terragrunt import` races where a resource is already managed in state.
If Terraform backend checksum drift is detected (S3/DynamoDB digest mismatch), the CLI falls back to direct AWS deletion of the bootstrap bucket and lock table.

### Soda API Key 403 Error

You're using **Profile API Keys** (human user keys). You need **Service Account** keys from:
**Data Sources > Agents > New Soda Agent** (copy from dialog).

`deploy --target full` validates that the Soda Agent API keys are set before add-on deployment.

## Security Notes

1. **Terraform State Contains Secrets** — Even with `sensitive = true`, state files store plaintext. Protect your state backend.
2. **Never Commit Secrets** — All secrets are passed via environment variables. Never hardcode them.
3. **EKS nodes run in private subnets** — Outbound traffic goes through NAT gateway.
4. **Ops access via SSM only** — No SSH keys, no public IPs on ops instances.
5. **State backend is encrypted** — S3 AES256, public access blocked, TLS enforced, versioning enabled.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for branching strategy, commit conventions, and release checklist.

## Additional Documentation

| Document | Description |
|----------|-------------|
| [env/README.md](env/README.md) | Terragrunt config hierarchy |
| [env/stack/soda-agent/README.md](env/stack/soda-agent/README.md) | Soda Agent stack deployment guide |
| Module READMEs | `module/**/README.md` — inputs, outputs, usage |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Branching, commits, release checklist |

## License

Proprietary. See repository or maintainers for license terms.
