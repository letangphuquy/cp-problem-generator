#!/usr/bin/env python3
"""
Universal C++ compilation utility with smart file hash caching.
Usage: python compile.py <source1.cpp> [source2.cpp] ...

Features:
- Uses SHA256 file hashing to skip recompilation of unchanged files
- Persistent cache in .eval_cache.json
- Cross-platform (Windows, Linux, macOS)
- Compiles with g++ -O3 -std=c++17
"""

import hashlib
import json
import platform
import subprocess
import sys
from pathlib import Path
from typing import Dict

CACHE_FILE = Path(".eval_cache.json")
COMPILER = "g++"
COMPILE_FLAGS = ["-O3", "-std=c++17"]


def load_compile_cache() -> dict:
    """Load compilation cache from JSON file."""
    if CACHE_FILE.exists():
        try:
            return json.loads(CACHE_FILE.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, IOError):
            return {}
    return {}


def save_compile_cache(cache: dict) -> None:
    """Save compilation cache to JSON file."""
    CACHE_FILE.write_text(json.dumps(cache, indent=2), encoding="utf-8")


def compute_file_hash(cpp_file: Path) -> str:
    """Compute SHA256 hash of a file."""
    sha256 = hashlib.sha256()
    with open(cpp_file, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            sha256.update(chunk)
    return sha256.hexdigest()


def compile_file(cpp_file: Path) -> bool:
    """
    Compile a single C++ file using cached hashes.
    Returns True if successful, False otherwise.
    """
    cpp_file = cpp_file.resolve()
    
    if not cpp_file.exists():
        print(f"❌ File not found: {cpp_file}")
        return False
    
    is_windows = platform.system() == "Windows"
    exe_suffix = ".exe" if is_windows else ""
    
    # Place executable in the same directory as source file
    exe_path = cpp_file.parent / f"{cpp_file.stem}{exe_suffix}"
    
    # Compute file hash
    file_hash = compute_file_hash(cpp_file)
    cache_key = str(cpp_file)
    
    # Check cache
    compile_cache = load_compile_cache()
    cached_data = compile_cache.get(cache_key, {})
    
    if cached_data.get("hash") == file_hash and cached_data.get("exe"):
        cached_exe = Path(cached_data["exe"])
        if cached_exe.exists():
            print(f"✅ {cpp_file.name} (skipped - no changes)")
            return True
    
    # Compile
    print(f"⏳ Compiling {cpp_file.name}...")
    compile_cmd = [COMPILER] + COMPILE_FLAGS + [str(cpp_file), "-o", str(exe_path)]
    
    result = subprocess.run(compile_cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"❌ Compilation failed for {cpp_file.name}:")
        print(result.stderr)
        return False
    
    print(f"✅ {cpp_file.name} compiled successfully")
    
    # Update cache
    compile_cache[cache_key] = {"hash": file_hash, "exe": str(exe_path)}
    save_compile_cache(compile_cache)
    
    return True


def main():
    if len(sys.argv) < 2:
        print("Usage: python compile.py <source1.cpp> [source2.cpp] ...")
        print("Compiles C++ files with smart hash-based caching")
        sys.exit(1)
    
    # Collect all C++ files to compile
    cpp_files = [Path(arg) for arg in sys.argv[1:]]
    
    failed_count = 0
    for cpp_file in cpp_files:
        if not compile_file(cpp_file):
            failed_count += 1
    
    print()
    if failed_count > 0:
        print(f"❌ {failed_count} file(s) failed to compile")
        sys.exit(1)
    else:
        print("✅ All files compiled successfully!")
        sys.exit(0)


if __name__ == "__main__":
    main()
