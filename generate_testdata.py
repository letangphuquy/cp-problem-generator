#!/usr/bin/env python3
"""
Intelligent test data generator with SHA256-based caching.
Skips regeneration if gen.cpp hash and generator arguments haven't changed.

Usage: python generate_testdata.py [--tests <spec>] [--clean]
"""

import hashlib
import json
import platform
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Tuple

CACHE_FILE = Path(".testdata_cache.json")
TEST_DIR = Path("tests")
SCRIPT_FILE = Path("script.txt")
GEN_EXECUTABLE = Path("gen.exe" if platform.system() == "Windows" else "gen")


def compute_file_hash(file_path: Path) -> str:
    """Compute SHA256 hash of a file."""
    sha256 = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            sha256.update(chunk)
    return sha256.hexdigest()


def load_testdata_cache() -> dict:
    """Load testdata cache from JSON file."""
    if CACHE_FILE.exists():
        try:
            return json.loads(CACHE_FILE.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, IOError):
            return {}
    return {}


def save_testdata_cache(cache: dict) -> None:
    """Save testdata cache to JSON file."""
    CACHE_FILE.write_text(json.dumps(cache, indent=2), encoding="utf-8")


def read_script_lines() -> List[str]:
    """Read non-comment, non-empty lines from script.txt."""
    if not SCRIPT_FILE.exists():
        print(f"❌ {SCRIPT_FILE} not found!")
        sys.exit(1)
    
    lines = []
    with open(SCRIPT_FILE, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            # Skip empty lines and comments
            if line and not line.startswith("#"):
                lines.append(line)
    
    return lines


def parse_test_spec(spec: str, total: int) -> List[int]:
    """Parse test specification string into list of test indices (1-indexed)."""
    if spec.lower() == "all":
        return list(range(1, total + 1))
    
    requested = []
    parts = spec.split(",")
    
    for part in parts:
        part = part.strip()
        if "-" in part:
            # Range format: 01-05
            start_str, end_str = part.split("-", 1)
            start = int(start_str.strip())
            end = int(end_str.strip())
            requested.extend(range(start, end + 1))
        else:
            # Single test: 03
            requested.append(int(part))
    
    return sorted(set(test for test in requested if 1 <= test <= total))


def generate_test(test_num: int, args: str) -> Tuple[bool, str]:
    """
    Generate a single test input.
    Returns (success, message)
    """
    test_padded = f"{test_num:02d}"
    inp_file = TEST_DIR / f"test{test_padded}.inp"
    
    if not GEN_EXECUTABLE.exists():
        return False, f"Generator executable not found: {GEN_EXECUTABLE}"
    
    try:
        with open(inp_file, "w", encoding="utf-8") as f:
            result = subprocess.run(
                [str(GEN_EXECUTABLE)] + args.split(),
                stdout=f,
                stderr=subprocess.PIPE,
                text=True,
                timeout=10
            )
        
        if result.returncode != 0:
            return False, f"Generator failed with args: {args}"
        
        return True, f"Generated test{test_padded}.inp (args: {args})"
    
    except subprocess.TimeoutExpired:
        return False, f"Generator timeout for test{test_padded}"
    except Exception as e:
        return False, str(e)


def main():
    if len(sys.argv) > 1:
        if sys.argv[1] in ["-h", "--help", "/?"]:
            print(__doc__)
            sys.exit(0)
    
    # Parse arguments
    test_spec = "all"
    clean = False
    
    i = 1
    while i < len(sys.argv):
        if sys.argv[i] == "--tests" and i + 1 < len(sys.argv):
            test_spec = sys.argv[i + 1]
            i += 2
        elif sys.argv[i] == "--clean":
            clean = True
            i += 1
        else:
            print(f"❌ Unknown option: {sys.argv[i]}")
            sys.exit(1)
    
    # Setup
    TEST_DIR.mkdir(exist_ok=True)
    
    # Read script
    script_lines = read_script_lines()
    if not script_lines:
        print(f"❌ No test cases found in {SCRIPT_FILE}")
        sys.exit(1)
    
    # Parse test spec
    requested_tests = parse_test_spec(test_spec, len(script_lines))
    if not requested_tests:
        print(f"⚠️  No tests matched spec: {test_spec}")
        sys.exit(0)
    
    # Load cache
    cache = load_testdata_cache()
    
    # Compute gen.cpp hash
    if not Path("gen.cpp").exists():
        print("❌ gen.cpp not found!")
        sys.exit(1)
    
    gen_hash = compute_file_hash(Path("gen.cpp"))
    
    # Process tests
    generated = 0
    cached = 0
    failed = 0
    
    print()
    for test_num in requested_tests:
        test_padded = f"{test_num:02d}"
        args = script_lines[test_num - 1]  # script_lines is 0-indexed
        inp_file = TEST_DIR / f"test{test_padded}.inp"
        
        cache_key = f"test{test_padded}"
        cached_entry = cache.get(cache_key, {})
        
        # Check if we should clean
        if clean and inp_file.exists():
            inp_file.unlink()
        
        # Check cache
        if (not clean and
            inp_file.exists() and
            cached_entry.get("gen_hash") == gen_hash and
            cached_entry.get("gen_args") == args):
            print(f"✅ test{test_padded}.inp (cached)")
            cached += 1
        else:
            # Generate
            success, message = generate_test(test_num, args)
            if success:
                print(f"⏳ {message}")
                
                # Update cache
                cache[cache_key] = {
                    "gen_hash": gen_hash,
                    "gen_args": args,
                    "input_hash": compute_file_hash(inp_file) if inp_file.exists() else None
                }
                generated += 1
            else:
                print(f"❌ test{test_padded}.inp - {message}")
                failed += 1
    
    # Save cache
    save_testdata_cache(cache)
    
    print()
    print(f"Results: {generated} generated, {cached} cached", end="")
    if failed > 0:
        print(f", {failed} failed")
        sys.exit(1)
    else:
        print()
        sys.exit(0)


if __name__ == "__main__":
    main()
