#!/usr/bin/env python3
"""
ConfigValidator: strict validation for problem.toml (RFC-003 V1.1).

This module is intentionally small and dependency-free so it can be used as the
first gate in the judge pipeline before any build/run/evaluate work happens.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Mapping
import sys

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - Python < 3.11 fallback
    import tomli as tomllib  # type: ignore[no-redef]


SUPPORTED_PROBLEM_TYPES = {"traditional", "custom_checker", "interactive", "grader"}
SUPPORTED_EVALUATION_MODES = {"token", "diff", "checker", "interactive"}
SUPPORTED_AGGREGATORS = {"min", "sum"}


@dataclass(frozen=True)
class ValidationIssue:
    path: str
    message: str


@dataclass(frozen=True)
class ValidationResult:
    valid: bool
    issues: list[ValidationIssue] = field(default_factory=list)

    def error_messages(self) -> list[str]:
        return [f"{issue.path}: {issue.message}" for issue in self.issues]


class ConfigValidator:
    """Validate RFC-003 V1.1 problem.toml documents."""

    def validate_file(self, file_path: str | Path) -> ValidationResult:
        path = Path(file_path)
        if not path.exists():
            return ValidationResult(False, [ValidationIssue("file", f"not found: {path}")])

        with path.open("rb") as handle:
            data = tomllib.load(handle)
        return self.validate(data)

    def validate(self, config: Mapping[str, Any]) -> ValidationResult:
        issues: list[ValidationIssue] = []

        problem = self._require_table(config, "problem", issues)
        build = self._require_table(config, "build", issues)
        run = self._require_table(config, "run", issues)
        evaluation = self._require_table(config, "evaluation", issues)

        if problem is not None:
            self._validate_problem(problem, issues)
        if build is not None:
            self._validate_build(build, problem, issues)
        if run is not None:
            self._validate_run(run, problem, issues)
        if evaluation is not None:
            self._validate_evaluation(evaluation, problem, issues)

        subtasks = config.get("subtasks")
        if subtasks is not None:
            self._validate_subtasks(subtasks, issues)

        self._validate_optional_tables(config, issues)
        return ValidationResult(not issues, issues)

    def _require_table(
        self,
        config: Mapping[str, Any],
        key: str,
        issues: list[ValidationIssue],
    ) -> Mapping[str, Any] | None:
        value = config.get(key)
        if not isinstance(value, Mapping):
            issues.append(ValidationIssue(key, "missing or not a table"))
            return None
        return value

    def _validate_problem(self, problem: Mapping[str, Any], issues: list[ValidationIssue]) -> None:
        self._reject_unknown_keys(problem, {"code", "name", "type", "tags"}, "problem", issues)
        self._require_string(problem, "code", "problem.code", issues)
        self._require_string(problem, "name", "problem.name", issues)
        problem_type = self._require_string(problem, "type", "problem.type", issues)
        if problem_type is not None and problem_type not in SUPPORTED_PROBLEM_TYPES:
            issues.append(ValidationIssue("problem.type", f"unsupported value: {problem_type}"))

        tags = problem.get("tags")
        if tags is not None and not self._is_string_list(tags):
            issues.append(ValidationIssue("problem.tags", "must be an array of strings"))

    def _validate_build(
        self,
        build: Mapping[str, Any],
        problem: Mapping[str, Any] | None,
        issues: list[ValidationIssue],
    ) -> None:
        allowed = {
            "language",
            "generator",
            "validator",
            "checker",
            "grader",
            "interactor",
            "extra_sources",
            "include_dirs",
            "defines",
            "flags",
            "internal_grader",
            "public_header",
        }
        self._reject_unknown_keys(build, allowed, "build", issues)

        if "solution" in build:
            issues.append(ValidationIssue("build.solution", "forbidden in RFC-003 V1.1; submission is supplied via CLI"))

        self._require_string(build, "language", "build.language", issues)
        for field_name in ("generator", "validator", "checker", "grader", "interactor"):
            if field_name in build:
                self._require_string(build, field_name, f"build.{field_name}", issues)

        for list_field in ("extra_sources", "include_dirs", "defines", "flags"):
            value = build.get(list_field)
            if value is not None and not self._is_string_list(value):
                issues.append(ValidationIssue(f"build.{list_field}", "must be an array of strings"))

        internal_grader = build.get("internal_grader")
        public_header = build.get("public_header")
        problem_type = problem.get("type") if isinstance(problem, Mapping) else None

        if problem_type == "grader":
            if not isinstance(internal_grader, Mapping):
                issues.append(ValidationIssue("build.internal_grader", "required for grader problems"))
            if not isinstance(public_header, Mapping):
                issues.append(ValidationIssue("build.public_header", "required for grader problems"))
            if not self._has_string(build, "grader"):
                issues.append(ValidationIssue("build.grader", "required for grader problems"))
        elif internal_grader is not None or public_header is not None:
            issues.append(ValidationIssue("build", "internal_grader/public_header are only valid for grader problems"))

        if problem_type == "interactive" and not self._has_string(build, "interactor"):
            issues.append(ValidationIssue("build.interactor", "required for interactive problems"))
        if problem_type == "custom_checker" and not self._has_string(build, "checker"):
            issues.append(ValidationIssue("build.checker", "required for custom checker problems"))

        if problem_type == "traditional":
            for field_name in ("checker", "grader", "interactor", "internal_grader", "public_header"):
                if field_name in build:
                    issues.append(ValidationIssue(f"build.{field_name}", "not allowed for traditional problems"))

    def _validate_run(
        self,
        run: Mapping[str, Any],
        problem: Mapping[str, Any] | None,
        issues: list[ValidationIssue],
    ) -> None:
        self._reject_unknown_keys(
            run,
            {
                "time_limit_ms",
                "memory_limit_mb",
                "process_limit",
                "wall_time_limit_ms",
                "idle_timeout_ms",
                "interactor_grace_ms",
            },
            "run",
            issues,
        )
        time_limit = self._require_positive_int(run, "time_limit_ms", "run.time_limit_ms", issues)
        self._require_positive_int(run, "memory_limit_mb", "run.memory_limit_mb", issues)
        process_limit = self._require_positive_int(run, "process_limit", "run.process_limit", issues)
        wall_time = self._require_positive_int(run, "wall_time_limit_ms", "run.wall_time_limit_ms", issues)
        idle_timeout = self._optional_positive_int(run, "idle_timeout_ms", "run.idle_timeout_ms", issues)
        self._optional_positive_int(run, "interactor_grace_ms", "run.interactor_grace_ms", issues)

        problem_type = problem.get("type") if isinstance(problem, Mapping) else None
        if problem_type == "interactive" and process_limit is not None and process_limit < 2:
            issues.append(ValidationIssue("run.process_limit", "must be >= 2 for interactive problems"))
        if problem_type == "interactive" and idle_timeout is not None and wall_time is not None and idle_timeout >= wall_time:
            issues.append(ValidationIssue("run.idle_timeout_ms", "must be strictly less than run.wall_time_limit_ms"))
        if time_limit is not None and wall_time is not None and wall_time < time_limit:
            issues.append(ValidationIssue("run.wall_time_limit_ms", "must be >= run.time_limit_ms"))

    def _validate_evaluation(
        self,
        evaluation: Mapping[str, Any],
        problem: Mapping[str, Any] | None,
        issues: list[ValidationIssue],
    ) -> None:
        self._reject_unknown_keys(
            evaluation,
            {"mode", "ignore_trailing_spaces", "ignore_blank_lines", "checker_exit_map"},
            "evaluation",
            issues,
        )
        mode = self._require_string(evaluation, "mode", "evaluation.mode", issues)
        if mode is not None and mode not in SUPPORTED_EVALUATION_MODES:
            issues.append(ValidationIssue("evaluation.mode", f"unsupported value: {mode}"))

        if mode == "checker" and not isinstance(evaluation.get("checker_exit_map"), Mapping):
            issues.append(ValidationIssue("evaluation.checker_exit_map", "required when evaluation.mode = 'checker'"))

        problem_type = problem.get("type") if isinstance(problem, Mapping) else None
        if problem_type == "traditional" and mode not in {"token", "diff"}:
            issues.append(ValidationIssue("evaluation.mode", "traditional problems must use token or diff"))
        if problem_type == "custom_checker" and mode != "checker":
            issues.append(ValidationIssue("evaluation.mode", "custom_checker problems must use checker mode"))
        if problem_type == "interactive" and mode != "interactive":
            issues.append(ValidationIssue("evaluation.mode", "interactive problems must use interactive mode"))
        if problem_type == "grader" and mode not in {"token", "diff", "checker"}:
            issues.append(ValidationIssue("evaluation.mode", "grader problems must use token, diff, or checker"))

        for bool_field in ("ignore_trailing_spaces", "ignore_blank_lines"):
            if bool_field in evaluation and not isinstance(evaluation[bool_field], bool):
                issues.append(ValidationIssue(f"evaluation.{bool_field}", "must be boolean"))

    def _validate_subtasks(self, subtasks: Any, issues: list[ValidationIssue]) -> None:
        if not isinstance(subtasks, list):
            issues.append(ValidationIssue("subtasks", "must be an array of tables"))
            return

        seen_ids: set[int] = set()
        for index, item in enumerate(subtasks):
            path = f"subtasks[{index}]"
            if not isinstance(item, Mapping):
                issues.append(ValidationIssue(path, "must be a table"))
                continue

            self._reject_unknown_keys(
                item,
                {"id", "name", "points", "tests", "aggregator", "dependencies", "enabled"},
                path,
                issues,
            )
            subtask_id = self._optional_positive_int(item, "id", f"{path}.id", issues)
            if subtask_id is not None:
                if subtask_id in seen_ids:
                    issues.append(ValidationIssue(f"{path}.id", f"duplicate subtask id: {subtask_id}"))
                seen_ids.add(subtask_id)

            self._require_string(item, "name", f"{path}.name", issues)
            self._require_positive_int(item, "points", f"{path}.points", issues)

            tests = item.get("tests")
            if tests is not None and not self._is_string_list(tests):
                issues.append(ValidationIssue(f"{path}.tests", "must be an array of strings"))

            aggregator = self._require_string(item, "aggregator", f"{path}.aggregator", issues)
            if aggregator is not None and aggregator not in SUPPORTED_AGGREGATORS:
                issues.append(ValidationIssue(f"{path}.aggregator", f"unsupported value: {aggregator}"))

            dependencies = item.get("dependencies")
            if dependencies is not None and not self._is_int_list(dependencies):
                issues.append(ValidationIssue(f"{path}.dependencies", "must be an array of integers"))

            if "enabled" in item and not isinstance(item["enabled"], bool):
                issues.append(ValidationIssue(f"{path}.enabled", "must be boolean"))

    def _validate_optional_tables(self, config: Mapping[str, Any], issues: list[ValidationIssue]) -> None:
        for table in ("generation", "cache", "artifacts", "extensions"):
            if table in config and not isinstance(config[table], Mapping):
                issues.append(ValidationIssue(table, "must be a table if present"))

    def _reject_unknown_keys(
        self,
        table: Mapping[str, Any],
        allowed_keys: set[str],
        path: str,
        issues: list[ValidationIssue],
    ) -> None:
        for key in table.keys():
            if key not in allowed_keys:
                issues.append(ValidationIssue(f"{path}.{key}", "unknown key"))

    def _has_string(self, table: Mapping[str, Any], key: str) -> bool:
        return isinstance(table.get(key), str) and bool(table.get(key))

    def _require_string(
        self,
        table: Mapping[str, Any],
        key: str,
        path: str,
        issues: list[ValidationIssue],
    ) -> str | None:
        value = table.get(key)
        if not isinstance(value, str) or not value:
            issues.append(ValidationIssue(path, "must be a non-empty string"))
            return None
        return value

    def _require_positive_int(
        self,
        table: Mapping[str, Any],
        key: str,
        path: str,
        issues: list[ValidationIssue],
    ) -> int | None:
        value = table.get(key)
        if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
            issues.append(ValidationIssue(path, "must be a positive integer"))
            return None
        return value

    def _optional_positive_int(
        self,
        table: Mapping[str, Any],
        key: str,
        path: str,
        issues: list[ValidationIssue],
    ) -> int | None:
        if key not in table:
            return None
        value = table.get(key)
        if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
            issues.append(ValidationIssue(path, "must be a positive integer"))
            return None
        return value

    def _is_string_list(self, value: Any) -> bool:
        return isinstance(value, list) and all(isinstance(item, str) for item in value)

    def _is_int_list(self, value: Any) -> bool:
        return isinstance(value, list) and all(isinstance(item, int) and not isinstance(item, bool) for item in value)


def main(argv: list[str] | None = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    if not args or args[0] in {"-h", "--help"}:
        print("Usage: python config_validator.py <problem.toml>")
        return 0

    validator = ConfigValidator()
    result = validator.validate_file(args[0])
    if result.valid:
        print("OK: config is valid")
        return 0

    print("INVALID: config has errors")
    for message in result.error_messages():
        print(f"- {message}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
