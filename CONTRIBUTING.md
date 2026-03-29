---
tags: []

category: Documentation
type: data/contributing
complexity: intermediate
time_required: 15-30 minutes
created: 2026-02-18
status: active
last_updated: 2026-02-18
---

# Contributing to AWS Soda Agent

This document describes how to contribute to this repository and how to prepare a release.

## Branching Strategy

This project follows **Trunk-Based Development** with optional release branches.

- **`main`** is always stable and releasable. Do **not** commit directly to `main`.
- All changes must be made on **short-lived feature branches**.
- Feature branches must be merged via **Pull Requests** (PRs).
- **Release branches** (`release/x.y.z`) are allowed only for stabilization (e.g. release/1.0.0). Ask before creating one.
- There is no long-lived `develop` branch.

## Commit Messages

All commit messages must follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification.

**Format:** `<type>(optional scope): <description>`

**Allowed types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`, `build`, `revert`

**Rules:**

- Description must be concise and imperative (e.g. "Add ALB timeout" not "Added ALB timeout").
- Scope is optional; if present it must be in parentheses (e.g. `feat(alb): add destroy timeout`).
- Avoid vague messages like "update", "fix stuff", or "changes".

**Examples:**

```
feat(eks): add node group auto-scaling configuration
fix(bootstrap): handle state lock on import
docs: update README quick start
chore: bump terraform-aws-modules/eks to 20.x
```

## Pull Requests

- Explain **why** the change exists, not only **what** changed.
- Keep PRs small and focused. Do not mix unrelated concerns in one PR.
- PRs are the primary review and decision artifact. Use them as self-review checkpoints when working alone; treat PR descriptions as long-term documentation.

## Pre-commit

Before pushing, run:

```bash
pre-commit install
pre-commit run --all-files
```

This runs trailing-whitespace checks, YAML/JSON checks, Terraform `fmt`/`validate`/`tflint`, and private-key detection. Fix any reported issues before opening a PR.

## Release Checklist (Before You Ship)

Use this checklist when preparing a release or before merging to `main`:

1. **Environment**
   - [ ] No secrets in the repository (search for API keys, passwords, tokens).
   - [ ] All required environment variables are documented in README.md.

2. **Validation**
   - [ ] `pre-commit run --all-files` passes.
   - [ ] `uv run --no-editable python -m aws_soda_agent.cli deploy --target bootstrap` passes for your env/account.

3. **Documentation**
   - [ ] README.md is accurate (prerequisites, quick start, env vars, troubleshooting).
   - [ ] CONTRIBUTING.md is up to date.
   - [ ] `env/stack/soda-agent/README.md` and related module READMEs reflect current layout.
   - [ ] No broken links or references to removed files (e.g. old script names).

4. **Deploy/Destroy (recommended)**
   - [ ] Full deploy and destroy test for the `soda-agent` stack in a non-production environment, if feasible.

5. **Branch and PR**
   - [ ] Changes are on a feature branch, not directly on `main`.
   - [ ] PR description explains the change and why it was made.
   - [ ] Commits follow Conventional Commits.

## Getting Help

- **README**: [README.md](README.md) — overview, quick start, deployment, env vars, troubleshooting.
- **CLI**: `uv run --no-editable python -m aws_soda_agent.cli --help` — deploy/destroy command usage.
- **Stacks**: [env/stack/soda-agent/README.md](env/stack/soda-agent/README.md) — stack module map and deploy/destroy usage.
