from __future__ import annotations

import json
import os
import shutil
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

from .shell import CommandError, CommandResult, run

DeployTarget = Literal["bootstrap", "stack", "full"]
DestroyTarget = Literal["addon", "stack", "all"]

STACK = "soda-agent"

ALLOWED_ENVS = {"dev", "prod"}
ALLOWED_REGIONS = {"eu-west-1", "us-east-1", "eu-central-1"}

NON_INTERACTIVE_ENV = {"TF_INPUT": "0", "TG_INPUT": "0"}
NO_BACKEND_BOOTSTRAP_ENV = {**NON_INTERACTIVE_ENV, "TG_BACKEND_BOOTSTRAP": "false"}

INFRA_DEPLOY_ORDER = [
    ("network/vpc", "VPC"),
    ("network/vpc-endpoints", "VPC Endpoints"),
    ("ops/sg-ops", "Security Groups (Ops)"),
    ("eks", "EKS Cluster"),
    ("ops/ec2-ops", "EC2 Ops Instance"),
    ("eks/ops-ec2-eks-access", "EKS Access Configuration"),
]
ADDON_MODULE = ("addons/soda-agent", "Soda Agent")
ROOT_ENV_VAR = "AWS_SODA_AGENT_ROOT"
_PROJECT_ROOT_CACHE: Path | None = None


@dataclass(frozen=True)
class Context:
    environment: str
    region: str
    org: str
    aws_account_id: str


def _discover_project_root() -> Path:
    def is_project_root(candidate: Path) -> bool:
        return (
            (candidate / "pyproject.toml").is_file()
            and (candidate / "env" / "stack" / "soda-agent" / "root.hcl").is_file()
            and (candidate / "module" / "application" / "helm" / "soda-agent").is_dir()
        )

    override = os.environ.get(ROOT_ENV_VAR, "").strip()
    if override:
        candidate = Path(override).expanduser().resolve()
        if is_project_root(candidate):
            return candidate
        raise RuntimeError(
            f"{ROOT_ENV_VAR} is set to {candidate}, but it is not a valid project root."
        )

    search_roots = [Path.cwd().resolve(), *Path.cwd().resolve().parents]
    module_path = Path(__file__).resolve()
    search_roots.extend(module_path.parents)

    for root in search_roots:
        if is_project_root(root):
            return root

    raise RuntimeError(
        "Unable to locate project root. Run from the repository directory or set "
        f"{ROOT_ENV_VAR} to the project root."
    )


def _project_root() -> Path:
    global _PROJECT_ROOT_CACHE
    if _PROJECT_ROOT_CACHE is None:
        _PROJECT_ROOT_CACHE = _discover_project_root()
    return _PROJECT_ROOT_CACHE


def _echo(level: str, color: str, message: str) -> None:
    reset = "\033[0m"
    print(f"{color}[{level}]{reset} {message}")


def info(message: str) -> None:
    _echo("INFO", "\033[0;34m", message)


def ok(message: str) -> None:
    _echo("OK", "\033[0;32m", message)


def warn(message: str) -> None:
    _echo("WARNING", "\033[1;33m", message)


def error(message: str) -> None:
    _echo("ERROR", "\033[0;31m", message)


def _print_result_output(result: CommandResult) -> None:
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="")


def _require_command(name: str) -> None:
    if shutil.which(name) is None:
        raise RuntimeError(f"Required command not found: {name}")


def _require_core_env() -> tuple[str, str, str]:
    environment = os.environ.get("TF_VAR_environment", "")
    region = os.environ.get("TF_VAR_region", "")
    org = os.environ.get("TF_VAR_org", "soda")

    if not environment or not region:
        raise RuntimeError("TF_VAR_environment and TF_VAR_region must be set.")
    if environment not in ALLOWED_ENVS:
        raise RuntimeError(
            f"Invalid TF_VAR_environment: {environment} (allowed: dev|prod)"
        )
    if region not in ALLOWED_REGIONS:
        raise RuntimeError(
            "Invalid TF_VAR_region: "
            f"{region} (allowed: eu-west-1|us-east-1|eu-central-1)"
        )
    return environment, region, org


def _resolve_account_id() -> str:
    result = run(
        ["aws", "sts", "get-caller-identity", "--query", "Account", "--output", "text"],
        check=True,
    )
    account = result.stdout.strip()
    if not account:
        raise RuntimeError("Unable to resolve AWS account ID from current credentials.")
    return account


def _validate_uuid_env(var_name: str) -> None:
    value = os.environ.get(var_name, "").strip()
    if not value:
        return
    try:
        uuid.UUID(value)
    except ValueError as exc:
        raise RuntimeError(
            f"{var_name} must be a valid UUID when set (got: {value!r})."
        ) from exc


def _validate_paired_env(var_a: str, var_b: str) -> None:
    value_a = os.environ.get(var_a, "").strip()
    value_b = os.environ.get(var_b, "").strip()
    if bool(value_a) ^ bool(value_b):
        raise RuntimeError(
            f"{var_a} and {var_b} must be set together (or both unset)."
        )


def _validate_deploy_target(target: DeployTarget) -> Context:
    _require_command("aws")
    _require_command("terragrunt")
    if target in {"stack", "full"}:
        _require_command("terraform")

    if target == "full":
        api_key_id = os.environ.get("SODA_API_KEY_ID", "").strip()
        api_key_secret = os.environ.get("SODA_API_KEY_SECRET", "").strip()
        if not api_key_id or not api_key_secret:
            raise RuntimeError(
                "SODA_API_KEY_ID and SODA_API_KEY_SECRET are required for deploy --target full."
            )
        _validate_uuid_env("SODA_AGENT_ID")
        _validate_paired_env("SODA_IMAGE_APIKEY_ID", "SODA_IMAGE_APIKEY_SECRET")

    environment, region, org = _require_core_env()
    account = _resolve_account_id()
    return Context(environment=environment, region=region, org=org, aws_account_id=account)


def _validate_destroy_target(_: DestroyTarget) -> Context:
    _require_command("aws")
    _require_command("terragrunt")
    environment, region, org = _require_core_env()
    account = _resolve_account_id()
    return Context(environment=environment, region=region, org=org, aws_account_id=account)


def _module_dir(module_path: str) -> Path:
    return _project_root() / "env" / "stack" / "soda-agent" / module_path


def _bucket_exists(bucket: str) -> bool:
    return run(["aws", "s3api", "head-bucket", "--bucket", bucket], check=False).returncode == 0


def _table_exists(table: str, region: str) -> bool:
    return (
        run(
            [
                "aws",
                "dynamodb",
                "describe-table",
                "--table-name",
                table,
                "--region",
                region,
            ],
            check=False,
        ).returncode
        == 0
    )


def _table_status(table: str, region: str) -> str | None:
    result = run(
        [
            "aws",
            "dynamodb",
            "describe-table",
            "--table-name",
            table,
            "--region",
            region,
            "--query",
            "Table.TableStatus",
            "--output",
            "text",
        ],
        check=False,
    )
    if result.returncode != 0:
        combined = f"{result.stdout}\n{result.stderr}"
        if "ResourceNotFoundException" in combined:
            return None
        return "UNKNOWN"
    return (result.stdout or "").strip() or "UNKNOWN"


def _purge_bucket_versions(bucket: str) -> None:
    """Delete all objects, versions, and delete markers from a versioned bucket."""
    if not _bucket_exists(bucket):
        return

    info(f"Purging all objects/versions from S3 bucket {bucket} before destroy.")

    key_marker = ""
    version_marker = ""
    while True:
        cmd = ["aws", "s3api", "list-object-versions", "--bucket", bucket, "--output", "json"]
        if key_marker:
            cmd.extend(["--key-marker", key_marker])
        if version_marker:
            cmd.extend(["--version-id-marker", version_marker])

        page = run(cmd, check=False)
        if page.returncode != 0:
            # If bucket vanishes during cleanup, we are done.
            if "NoSuchBucket" in page.stderr:
                return
            raise RuntimeError(
                f"Failed to list object versions for bucket {bucket}: {page.stderr or page.stdout}"
            )

        payload = json.loads(page.stdout or "{}")
        objects = []
        for item in payload.get("Versions", []):
            objects.append({"Key": item["Key"], "VersionId": item["VersionId"]})
        for item in payload.get("DeleteMarkers", []):
            objects.append({"Key": item["Key"], "VersionId": item["VersionId"]})

        if objects:
            # AWS API supports up to 1000 objects per request.
            for idx in range(0, len(objects), 1000):
                batch = objects[idx : idx + 1000]
                run(
                    [
                        "aws",
                        "s3api",
                        "delete-objects",
                        "--bucket",
                        bucket,
                        "--delete",
                        json.dumps({"Objects": batch, "Quiet": True}),
                    ],
                    check=True,
                )

        if not payload.get("IsTruncated", False):
            break

        key_marker = payload.get("NextKeyMarker", "")
        version_marker = payload.get("NextVersionIdMarker", "")


def _force_delete_bootstrap_backend(bucket: str, table: str, region: str) -> None:
    """Last-resort cleanup when Terraform backend checksum is broken."""
    warn("Falling back to direct AWS deletion for bootstrap backend.")

    for attempt in range(1, 19):
        if _bucket_exists(bucket):
            _purge_bucket_versions(bucket)
            bucket_delete = run(
                ["aws", "s3api", "delete-bucket", "--bucket", bucket, "--region", region],
                check=False,
            )
            bucket_combined = f"{bucket_delete.stdout}\n{bucket_delete.stderr}"
            if bucket_delete.returncode != 0 and "NoSuchBucket" not in bucket_combined:
                # Bucket may still be propagating deletes; retry loop handles this.
                warn(f"S3 bucket deletion attempt {attempt} not yet complete.")

        status = _table_status(table, region)
        if status not in (None, "DELETING"):
            table_delete = run(
                ["aws", "dynamodb", "delete-table", "--table-name", table, "--region", region],
                check=False,
            )
            table_combined = f"{table_delete.stdout}\n{table_delete.stderr}"
            if table_delete.returncode != 0 and "ResourceNotFoundException" not in table_combined:
                warn(f"DynamoDB table deletion attempt {attempt} not yet complete.")

        bucket_gone = not _bucket_exists(bucket)
        table_state = _table_status(table, region)
        table_gone = table_state is None
        if bucket_gone and table_gone:
            return

        info(
            "Waiting for bootstrap backend deletion propagation "
            f"(attempt {attempt}/18, bucket_exists={not bucket_gone}, table_status={table_state})."
        )
        time.sleep(5)

    final_state = _table_status(table, region)
    raise RuntimeError(
        "Direct bootstrap backend deletion did not fully complete. "
        f"bucket_exists={_bucket_exists(bucket)}, table_status={final_state}"
    )


def _terragrunt_import_if_needed(
    bootstrap_dir: Path,
    address: str,
    import_id: str,
    env: dict[str, str] | None = None,
) -> str:
    """Import a resource when needed, but tolerate already-managed state."""
    result = run(
        ["terragrunt", "import", address, import_id],
        cwd=bootstrap_dir,
        check=False,
        env=env or NON_INTERACTIVE_ENV,
    )
    _print_result_output(result)
    if result.returncode == 0:
        return "imported"
    combined = f"{result.stdout}\n{result.stderr}"
    if "state data in S3 does not have the expected content" in combined:
        warn(f"{address} import failed due to backend checksum mismatch.")
        return "checksum_mismatch"
    if "Resource already managed by Terraform" in combined:
        info(f"{address} is already tracked in state; skipping import.")
        return "already_managed"
    raise CommandError(f"Failed to import {address} ({import_id}).")


def _terragrunt_output_exists(module_path: str) -> bool:
    module_dir = _module_dir(module_path)
    if not module_dir.is_dir():
        return False
    result = run(
        ["terragrunt", "output", "-json"],
        cwd=module_dir,
        check=False,
        env=NON_INTERACTIVE_ENV,
    )
    if result.returncode != 0:
        return False
    payload = result.stdout.strip()
    if not payload or payload == "{}":
        return False
    try:
        decoded = json.loads(payload)
    except json.JSONDecodeError:
        return False
    return bool(decoded)


def _terragrunt_apply(module_path: str, module_name: str) -> None:
    module_dir = _module_dir(module_path)
    if not module_dir.is_dir():
        raise RuntimeError(f"Module directory not found: {module_dir}")

    info(f"Deploying {module_name}...")
    apply_result = run(
        ["terragrunt", "apply", "--auto-approve"],
        cwd=module_dir,
        check=False,
        env=NON_INTERACTIVE_ENV,
    )
    _print_result_output(apply_result)
    if apply_result.returncode == 0:
        ok(f"{module_name} deployed.")
        return

    combined = f"{apply_result.stdout}\n{apply_result.stderr}"
    retryable = (
        "Required plugins are not installed" in combined
        or "terraform init" in combined
    )
    if not retryable:
        raise CommandError(f"Failed to deploy {module_name}.")

    warn(f"{module_name}: provider init required, retrying with terragrunt init -upgrade.")
    init_result = run(
        ["terragrunt", "init", "-upgrade"],
        cwd=module_dir,
        check=False,
        env=NON_INTERACTIVE_ENV,
    )
    _print_result_output(init_result)
    retry_result = run(
        ["terragrunt", "apply", "--auto-approve"],
        cwd=module_dir,
        check=False,
        env=NON_INTERACTIVE_ENV,
    )
    _print_result_output(retry_result)
    if retry_result.returncode != 0:
        raise CommandError(f"Failed to deploy {module_name} after init retry.")
    ok(f"{module_name} deployed.")


def _terragrunt_destroy(module_path: str, module_name: str) -> None:
    module_dir = _module_dir(module_path)
    if not _terragrunt_output_exists(module_path):
        warn(f"{module_name} not found, skipping.")
        return
    info(f"Destroying {module_name}...")
    result = run(
        ["terragrunt", "destroy", "--auto-approve"],
        cwd=module_dir,
        check=False,
        env=NON_INTERACTIVE_ENV,
    )
    _print_result_output(result)
    if result.returncode != 0:
        raise CommandError(f"Failed to destroy {module_name}.")
    ok(f"{module_name} destroyed.")


def _bootstrap_bucket_name(ctx: Context) -> str:
    return f"{ctx.aws_account_id}-{ctx.org}-{ctx.environment}-{STACK}-tfstate-{ctx.region}"


def _bootstrap_table_name(ctx: Context) -> str:
    return f"{ctx.aws_account_id}-{ctx.org}-{ctx.environment}-{STACK}-tf-locks"


def _terragrunt_reconfigure_backend(module_dir: Path, env: dict[str, str]) -> None:
    # Refresh backend metadata so org/env/region changes don't reuse stale bucket names.
    run(
        ["terragrunt", "init", "-reconfigure", "-upgrade"],
        cwd=module_dir,
        check=False,
        env=env,
    )


def deploy_bootstrap(ctx: Context) -> None:
    bootstrap_dir = _module_dir("bootstrap")
    if not bootstrap_dir.is_dir():
        raise RuntimeError(f"Bootstrap directory not found: {bootstrap_dir}")

    bucket = _bootstrap_bucket_name(ctx)
    table = _bootstrap_table_name(ctx)

    info("Bootstrapping remote state backend.")
    info(
        f"Environment={ctx.environment} Region={ctx.region} Account={ctx.aws_account_id}"
    )
    info(f"S3 bucket: {bucket}")
    info(f"DynamoDB table: {table}")
    _terragrunt_reconfigure_backend(bootstrap_dir, NON_INTERACTIVE_ENV)

    state_exists = run(
        ["terragrunt", "output", "-json", "state_bucket"],
        cwd=bootstrap_dir,
        check=False,
        env=NON_INTERACTIVE_ENV,
    ).returncode == 0

    if state_exists:
        info("Bootstrap state detected; applying (expected no-op if up to date).")
        result = run(
            ["terragrunt", "apply", "--auto-approve"],
            cwd=bootstrap_dir,
            check=True,
            env=NON_INTERACTIVE_ENV,
        )
        _print_result_output(result)
        ok("Bootstrap completed.")
        return

    bucket_exists = (
        run(
            ["aws", "s3api", "head-bucket", "--bucket", bucket],
            check=False,
        ).returncode
        == 0
    )
    table_exists = (
        run(
            [
                "aws",
                "dynamodb",
                "describe-table",
                "--table-name",
                table,
                "--region",
                ctx.region,
            ],
            check=False,
        ).returncode
        == 0
    )

    if bucket_exists and table_exists:
        warn("Bootstrap resources exist but state is missing; importing resources first.")
        _terragrunt_import_if_needed(bootstrap_dir, "aws_s3_bucket.tfstate", bucket)
        _terragrunt_import_if_needed(bootstrap_dir, "aws_dynamodb_table.locks", table)
        result = run(
            ["terragrunt", "apply", "--auto-approve"],
            cwd=bootstrap_dir,
            check=True,
            env=NON_INTERACTIVE_ENV,
        )
        _print_result_output(result)
        ok("Bootstrap imported and completed.")
        return

    info("Bootstrap resources not found; creating.")
    result = run(
        ["terragrunt", "apply", "--auto-approve"],
        cwd=bootstrap_dir,
        check=True,
        env=NON_INTERACTIVE_ENV,
    )
    _print_result_output(result)
    ok("Bootstrap created and completed.")


def destroy_bootstrap(ctx: Context, *, interactive: bool = True) -> None:
    bootstrap_dir = _module_dir("bootstrap")
    if not bootstrap_dir.is_dir():
        raise RuntimeError(f"Bootstrap directory not found: {bootstrap_dir}")

    bucket = _bootstrap_bucket_name(ctx)
    table = _bootstrap_table_name(ctx)

    warn("BOOTSTRAP DESTRUCTION WARNING")
    warn(f"Environment={ctx.environment} Region={ctx.region} Account={ctx.aws_account_id}")
    warn(f"S3 bucket: {bucket}")
    warn(f"DynamoDB table: {table}")
    _terragrunt_reconfigure_backend(bootstrap_dir, NO_BACKEND_BOOTSTRAP_ENV)

    if interactive:
        answer = input("Type 'DESTROY BOOTSTRAP' to confirm: ").strip()
        if answer != "DESTROY BOOTSTRAP":
            info("Cancelled.")
            return

    state_exists = run(
        ["terragrunt", "output", "-json", "state_bucket"],
        cwd=bootstrap_dir,
        check=False,
        env=NO_BACKEND_BOOTSTRAP_ENV,
    ).returncode == 0

    if not state_exists:
        bucket_exists = _bucket_exists(bucket)
        table_exists = _table_exists(table, ctx.region)
        if bucket_exists and table_exists:
            warn("Importing existing bootstrap resources before destroy.")
            s3_import = _terragrunt_import_if_needed(
                bootstrap_dir,
                "aws_s3_bucket.tfstate",
                bucket,
                env=NO_BACKEND_BOOTSTRAP_ENV,
            )
            ddb_import = _terragrunt_import_if_needed(
                bootstrap_dir,
                "aws_dynamodb_table.locks",
                table,
                env=NO_BACKEND_BOOTSTRAP_ENV,
            )
            if s3_import == "checksum_mismatch" or ddb_import == "checksum_mismatch":
                warn("Checksum mismatch detected during bootstrap import; switching to direct AWS cleanup.")
                _force_delete_bootstrap_backend(bucket, table, ctx.region)
                ok("Bootstrap destroyed.")
                return

    if _bucket_exists(bucket):
        info("Pre-cleaning bootstrap state bucket before terragrunt destroy.")
        _purge_bucket_versions(bucket)

    result = run(
        ["terragrunt", "destroy", "--auto-approve"],
        cwd=bootstrap_dir,
        check=False,
        env=NO_BACKEND_BOOTSTRAP_ENV,
    )
    _print_result_output(result)
    if result.returncode == 0:
        ok("Bootstrap destroyed.")
        return

    combined = f"{result.stdout}\n{result.stderr}"
    lock_release_error = "Error releasing the state lock" in combined
    bucket_not_empty = "BucketNotEmpty" in combined
    checksum_mismatch = "state data in S3 does not have the expected content" in combined

    # For BucketNotEmpty, avoid a second terragrunt destroy because terragrunt may
    # bootstrap backend resources implicitly in some environments.
    # Switch directly to AWS deletion logic.
    if bucket_not_empty:
        warn("Bootstrap bucket still non-empty after first pass; switching to direct AWS cleanup.")
        _force_delete_bootstrap_backend(bucket, table, ctx.region)
        ok("Bootstrap destroyed.")
        return

    if checksum_mismatch:
        warn("Terraform backend checksum mismatch detected during bootstrap destroy.")
        _force_delete_bootstrap_backend(bucket, table, ctx.region)
        ok("Bootstrap destroyed.")
        return

    # Known edge-case: lock table deletion races lock release.
    # If resources are already gone, treat operation as successful.
    if lock_release_error and not _bucket_exists(bucket) and not _table_exists(table, ctx.region):
        warn("State lock release error detected after backend deletion; treating bootstrap destroy as complete.")
        ok("Bootstrap destroyed.")
        return

    raise CommandError("Failed to destroy bootstrap resources.")


def deploy(target: DeployTarget) -> None:
    ctx = _validate_deploy_target(target)
    info(
        f"Deploy target={target} env={ctx.environment} region={ctx.region} account={ctx.aws_account_id}"
    )

    if target == "bootstrap":
        deploy_bootstrap(ctx)
        return

    deploy_bootstrap(ctx)
    for module_path, module_name in INFRA_DEPLOY_ORDER:
        _terragrunt_apply(module_path, module_name)

    if target == "full":
        agent_id = os.environ.get("SODA_AGENT_ID", "").strip()
        if agent_id:
            info(
                "Add-on mode: redeploy/reattach existing Soda Agent "
                f"(SODA_AGENT_ID={agent_id})."
            )
        else:
            info(
                "Add-on mode: new Soda Agent registration "
                "(set SODA_AGENT_ID to reattach an existing agent)."
            )
        _terragrunt_apply(*ADDON_MODULE)

    ok("Deploy completed.")


def destroy(target: DestroyTarget) -> None:
    ctx = _validate_destroy_target(target)
    info(
        f"Destroy target={target} env={ctx.environment} region={ctx.region} account={ctx.aws_account_id}"
    )

    if target in {"stack", "all"}:
        answer = input(f"Destroy target '{target}' in {ctx.environment}/{ctx.region}? (yes/no): ")
        if answer.strip().lower() != "yes":
            info("Cancelled.")
            return

    if target == "addon":
        _terragrunt_destroy(*ADDON_MODULE)
        ok("Destroy completed.")
        return

    _terragrunt_destroy(*ADDON_MODULE)
    for module_path, module_name in reversed(INFRA_DEPLOY_ORDER):
        _terragrunt_destroy(module_path, module_name)

    if target == "all":
        destroy_bootstrap(ctx, interactive=True)
    else:
        info("Bootstrap preserved (use destroy --target all to remove it).")

    ok("Destroy completed.")
