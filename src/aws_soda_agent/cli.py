from __future__ import annotations

import argparse
import sys

from .orchestrator import destroy, deploy
from .shell import CommandError


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="soda-agent",
        description="AWS Soda Agent deploy/destroy CLI.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    deploy_parser = subparsers.add_parser("deploy", help="Deploy resources.")
    deploy_parser.add_argument(
        "--target",
        choices=["bootstrap", "stack", "full"],
        default="full",
        help="bootstrap=backend only, stack=backend+infra, full=backend+infra+addon",
    )

    destroy_parser = subparsers.add_parser("destroy", help="Destroy resources.")
    destroy_parser.add_argument(
        "--target",
        choices=["addon", "stack", "all"],
        default="stack",
        help="addon=addon only, stack=addon+infra, all=addon+infra+bootstrap",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    try:
        if args.command == "deploy":
            deploy(args.target)
        elif args.command == "destroy":
            destroy(args.target)
        else:
            parser.error(f"Unknown command: {args.command}")
            return 2
    except (RuntimeError, CommandError) as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\n[ERROR] Interrupted by user.", file=sys.stderr)
        return 130
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
