#!/usr/bin/env python3
"""
Shared cached runner for validate/solve phases.

Usage:
  python run_phase_cached.py validate [--tests <spec>] [--continue-on-error]
  python run_phase_cached.py solve    [--tests <spec>]
"""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
import subprocess
import sys
from pathlib import Path
from typing import Dict, List

ROOT = Path(__file__).resolve().parent
SCRIPT_FILE = ROOT / "script.txt"
TEST_DIR = ROOT / "tests"
LOG_FILE = TEST_DIR / "run.log"
CACHE_FILE = ROOT / ".phase_cache.json"

IS_WINDOWS = platform.system() == "Windows"
VAL_BIN = ROOT / ("val.exe" if IS_WINDOWS else "val")
MODEL_BIN = ROOT / "sol" / ("model.exe" if IS_WINDOWS else "model")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def load_script_lines() -> List[str]:
    if not SCRIPT_FILE.exists():
        print("[ERR ] script.txt not found", file=sys.stderr)
        sys.exit(1)

    lines: List[str] = []
    for raw in SCRIPT_FILE.read_text(encoding="utf-8", errors="ignore").splitlines():
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        lines.append(stripped)
    return lines


def parse_test_spec(spec: str, total: int) -> List[str]:
    if total <= 0:
        return []

    if spec.lower() == "all":
        return [f"{i:02d}" for i in range(1, total + 1)]

    requested: set[int] = set()
    for token in spec.split(","):
        token = token.strip()
        if not token:
            continue
        if "-" in token:
            a, b = token.split("-", 1)
            if a.isdigit() and b.isdigit():
                start, end = int(a), int(b)
                if start <= end:
                    for i in range(start, end + 1):
                        if 1 <= i <= total:
                            requested.add(i)
        elif token.isdigit():
            i = int(token)
            if 1 <= i <= total:
                requested.add(i)

    return [f"{i:02d}" for i in sorted(requested)]


def load_cache() -> Dict[str, Dict[str, Dict[str, str]]]:
    if CACHE_FILE.exists():
        try:
            raw = json.loads(CACHE_FILE.read_text(encoding="utf-8"))
            if isinstance(raw, dict):
                raw.setdefault("validate", {})
                raw.setdefault("solve", {})
                return raw
        except (json.JSONDecodeError, OSError):
            pass
    return {"validate": {}, "solve": {}}


def save_cache(cache: Dict[str, Dict[str, Dict[str, str]]]) -> None:
    CACHE_FILE.write_text(json.dumps(cache, indent=2), encoding="utf-8")


def load_log_lines() -> List[str]:
    if not LOG_FILE.exists():
        return []
    return LOG_FILE.read_text(encoding="utf-8", errors="ignore").splitlines()


def upsert_log_entry(lines: List[str], test_id: str, phase: str, status: str) -> List[str]:
    prefix = f"{test_id} {phase} "
    out = [line for line in lines if not line.startswith(prefix)]
    out.append(f"{test_id} {phase} {status}")
    return out


def save_log_lines(lines: List[str]) -> None:
    TEST_DIR.mkdir(parents=True, exist_ok=True)
    LOG_FILE.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")


def run_validate(tests: List[str], continue_on_error: bool, cache: Dict[str, Dict[str, Dict[str, str]]]) -> int:
    if not VAL_BIN.exists():
        print(f"[ERR ] Validator binary not found: {VAL_BIN}", file=sys.stderr)
        return 1

    validator_hash = sha256_file(VAL_BIN)
    log_lines = load_log_lines()
    failed = 0

    print("--- Phase: Validate Inputs ---")
    for padded in tests:
        inp = TEST_DIR / f"test{padded}.inp"
        test_id = f"test{padded}"

        if not inp.exists():
            print(f"[WARN] {test_id}.inp not found - skipping")
            continue

        inp_hash = sha256_file(inp)
        cached = cache["validate"].get(test_id, {})

        if (
            cached.get("status") == "ok"
            and cached.get("input_hash") == inp_hash
            and cached.get("validator_hash") == validator_hash
        ):
            print(f" [ OK ] {test_id}.inp  [valid, cached]")
            log_lines = upsert_log_entry(log_lines, test_id, "validate", "ok")
            continue

        with inp.open("rb") as fin:
            res = subprocess.run([str(VAL_BIN)], stdin=fin, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        if res.returncode == 0:
            print(f" [ OK ] {test_id}.inp  [valid]")
            cache["validate"][test_id] = {
                "status": "ok",
                "input_hash": inp_hash,
                "validator_hash": validator_hash,
            }
            log_lines = upsert_log_entry(log_lines, test_id, "validate", "ok")
        else:
            print(f"[ERR ] {test_id}.inp  [INVALID]", file=sys.stderr)
            cache["validate"][test_id] = {
                "status": "fail",
                "input_hash": inp_hash,
                "validator_hash": validator_hash,
            }
            log_lines = upsert_log_entry(log_lines, test_id, "validate", "fail")
            failed += 1
            if not continue_on_error:
                print("[ERR ] Stopping on first validation failure. Use --continue-on-error to continue.", file=sys.stderr)
                break

    save_log_lines(log_lines)
    save_cache(cache)

    if failed > 0:
        print(f"[ERR ] Validate phase: {failed} test(s) failed.", file=sys.stderr)
        return 1

    print(f"--- Validate phase complete ({len(tests)} tests) ---")
    return 0


def run_solve(tests: List[str], cache: Dict[str, Dict[str, Dict[str, str]]]) -> int:
    if not MODEL_BIN.exists():
        print(f"[ERR ] Model binary not found: {MODEL_BIN}", file=sys.stderr)
        return 1

    model_hash = sha256_file(MODEL_BIN)
    log_lines = load_log_lines()
    failed = 0

    print("--- Phase: Solve (Generate Outputs) ---")
    for padded in tests:
        test_id = f"test{padded}"
        inp = TEST_DIR / f"test{padded}.inp"
        out = TEST_DIR / f"test{padded}.out"

        if not inp.exists():
            print(f"[WARN] {test_id}.inp not found - skipping")
            continue

        inp_hash = sha256_file(inp)
        cached = cache["solve"].get(test_id, {})

        cached_ok = (
            cached.get("status") == "ok"
            and cached.get("input_hash") == inp_hash
            and cached.get("model_hash") == model_hash
            and out.exists()
        )

        if cached_ok:
            current_out_hash = sha256_file(out)
            if current_out_hash == cached.get("out_hash"):
                print(f" [ OK ] {test_id}.out  [cached]")
                log_lines = upsert_log_entry(log_lines, test_id, "solve", "ok")
                continue

        with inp.open("rb") as fin, out.open("wb") as fout:
            res = subprocess.run([str(MODEL_BIN)], stdin=fin, stdout=fout)

        if res.returncode == 0:
            out_hash = sha256_file(out)
            cache["solve"][test_id] = {
                "status": "ok",
                "input_hash": inp_hash,
                "model_hash": model_hash,
                "out_hash": out_hash,
            }
            print(f" [ OK ] {test_id}.out")
            log_lines = upsert_log_entry(log_lines, test_id, "solve", "ok")
        else:
            if out.exists():
                out.unlink()
            cache["solve"][test_id] = {
                "status": "fail",
                "input_hash": inp_hash,
                "model_hash": model_hash,
            }
            print(f"[ERR ] {test_id}: model solution failed", file=sys.stderr)
            log_lines = upsert_log_entry(log_lines, test_id, "solve", "fail")
            failed += 1

    save_log_lines(log_lines)
    save_cache(cache)

    if failed > 0:
        print(f"[ERR ] Solve phase: {failed} test(s) failed.", file=sys.stderr)
        return 1

    print(f"--- Solve phase complete ({len(tests)} tests) ---")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("phase", choices=["validate", "solve"])
    parser.add_argument("--tests", default="all")
    parser.add_argument("--continue-on-error", action="store_true")
    parser.add_argument("-h", "--help", action="help")
    args = parser.parse_args()

    lines = load_script_lines()
    requested = parse_test_spec(args.tests, len(lines))

    if not requested:
        print(f"[WARN] No tests matched spec: {args.tests}")
        return 0

    cache = load_cache()

    if args.phase == "validate":
        return run_validate(requested, args.continue_on_error, cache)
    return run_solve(requested, cache)


if __name__ == "__main__":
    raise SystemExit(main())
