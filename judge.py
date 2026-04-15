#!/usr/bin/env python3
"""Unified judge CLI entrypoint (v1 bootstrap)."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

from config_validator import ConfigValidator


def cmd_check_config(args: argparse.Namespace) -> int:
    config_path = Path(args.config)
    validator = ConfigValidator()
    result = validator.validate_file(config_path)

    if result.valid:
        print(f"OK: {config_path} is valid")
        return 0

    print(f"INVALID: {config_path} has {len(result.issues)} error(s)")
    for message in result.error_messages():
        print(f"- {message}")
    return 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="judge",
        description="Judge CLI bootstrap entrypoint",
    )
    subparsers = parser.add_subparsers(dest="command")

    check_config = subparsers.add_parser(
        "check-config",
        help="Validate problem.toml against RFC-003 v1.1 constraints",
    )
    check_config.add_argument(
        "config",
        nargs="?",
        default="problem.toml",
        help="Path to config file (default: problem.toml)",
    )
    check_config.set_defaults(handler=cmd_check_config)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv if argv is not None else sys.argv[1:])

    if not hasattr(args, "handler"):
        parser.print_help()
        return 2

    return args.handler(args)


if __name__ == "__main__":
    raise SystemExit(main())
