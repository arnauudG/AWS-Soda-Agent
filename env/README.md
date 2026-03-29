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

# Terragrunt configuration (`env/`)

This folder contains the shared Terragrunt configuration and the live ("apply-able") Terragrunt stacks.

## Key files

- `env/root.hcl`
  - The global Terragrunt configuration.
  - Responsibilities:
    - Read environment/region definitions from `env/env.hcl`
    - Compute common values (org, tags, naming, modules_root)
    - Configure `remote_state` (S3 backend + DynamoDB locking)
    - Safety checks (environment validity, region validity, account validation)

- `env/env.hcl`
  - Environment definitions (e.g. `dev`, `prod`) and shared defaults.
  - `uv run --no-editable python -m aws_soda_agent.cli ...` uses `TF_VAR_environment` to choose the active environment.

- `env/common.hcl`
  - Common Terragrunt `generate` blocks.
  - Generates a minimal `provider.tf` and an empty Terraform `backend` block.

## Live stacks

All live Terragrunt configs (the things you actually `terragrunt apply`) are under:

- `env/stack/` — soda-agent (includes its own `bootstrap/` and stack-level `root.hcl`)

See [env/stack/soda-agent/README.md](stack/soda-agent/README.md) for the module map and how to run deploy/destroy.
