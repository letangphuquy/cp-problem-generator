import glob
import hashlib
import platform
import subprocess
import sys
import tempfile
import time
import threading
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Set, Tuple

import psutil

TIME_LIMIT = 1.0


@dataclass(frozen=True)
class TestCase:
    name: str
    input_text: str
    expected_output: str


@dataclass
class RunStats:
    verdict: str
    time_ms: float
    memory_mb: float


def collect_cpp_targets(raw_targets: Iterable[str]) -> List[Path]:
    targets: List[Path] = []
    seen: Set[Path] = set()

    for raw_target in raw_targets:
        candidate = Path(raw_target)
        matches: List[Path]

        if candidate.exists():
            if candidate.is_dir():
                matches = sorted(candidate.rglob("*.cpp"))
            else:
                matches = [candidate] if candidate.suffix.lower() == ".cpp" else []
        else:
            matches = [Path(match) for match in sorted(glob.glob(raw_target, recursive=True)) if Path(match).suffix.lower() == ".cpp"]

        for match in matches:
            resolved = match.resolve()
            if resolved not in seen:
                seen.add(resolved)
                targets.append(resolved)

    return targets


def load_tests() -> List[TestCase]:
    test_dir = Path("tests")
    if not test_dir.exists():
        print("❌ Thư mục tests/ không tồn tại! Hãy chạy script sinh test trước.")
        sys.exit(1)

    test_cases: List[TestCase] = []
    for inp_path in sorted(test_dir.glob("*.inp")):
        out_path = inp_path.with_suffix(".out")
        if not out_path.exists():
            continue

        test_cases.append(
            TestCase(
                name=inp_path.stem,
                input_text=inp_path.read_text(encoding="utf-8", errors="ignore"),
                expected_output=out_path.read_text(encoding="utf-8", errors="ignore").strip(),
            )
        )

    if not test_cases:
        print("❌ Không tìm thấy cặp test .inp/.out nào trong thư mục tests/!")
        sys.exit(1)

    return test_cases


def compile_solution(cpp_file: Path, build_dir: Path) -> Path:
    if not cpp_file.exists():
        print(f"❌ Không tìm thấy file: {cpp_file}")
        sys.exit(1)

    is_windows = platform.system() == "Windows"
    exe_suffix = ".exe" if is_windows else ""
    digest = hashlib.sha1(str(cpp_file.resolve()).encode("utf-8")).hexdigest()[:8]
    exe_path = build_dir / f"{cpp_file.stem}_{digest}{exe_suffix}"

    print(f"⏳ Đang tự động biên dịch {cpp_file.name}...")
    compile_cmd = ["g++", "-O3", "-std=c++17", str(cpp_file), "-o", str(exe_path)]

    result = subprocess.run(compile_cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"❌ Lỗi biên dịch {cpp_file.name}:\n{result.stderr}")
        sys.exit(1)

    print("✅ Biên dịch thành công!\n")
    return exe_path


def format_time(ms: float) -> str:
    return f"{ms:.0f}ms"


def format_memory(memory_mb: float) -> str:
    return f"{memory_mb:.1f}MB"


def judge_test(exec_path: Path, test_case: TestCase) -> RunStats:
    start_time = time.perf_counter()
    process = subprocess.Popen(
        [str(exec_path)],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    max_memory = 0.0
    stop_event = threading.Event()

    def monitor_memory() -> None:
        nonlocal max_memory
        try:
            ps_process = psutil.Process(process.pid)
        except psutil.Error:
            return

        while not stop_event.is_set():
            try:
                current_memory = ps_process.memory_info().rss
                for child in ps_process.children(recursive=True):
                    try:
                        current_memory += child.memory_info().rss
                    except psutil.Error:
                        continue
                max_memory = max(max_memory, current_memory)
            except psutil.Error:
                pass
            if process.poll() is not None:
                break
            time.sleep(0.01)

    monitor_thread = threading.Thread(target=monitor_memory, daemon=True)
    monitor_thread.start()

    try:
        stdout, stderr = process.communicate(input=test_case.input_text, timeout=TIME_LIMIT)
        elapsed_ms = (time.perf_counter() - start_time) * 1000
        if process.returncode != 0:
            verdict = "RTE"
        elif stdout.strip() == test_case.expected_output:
            verdict = "AC"
        else:
            verdict = "WA"
    except subprocess.TimeoutExpired:
        process.kill()
        process.communicate()
        elapsed_ms = TIME_LIMIT * 1000
        verdict = "TLE"
    finally:
        stop_event.set()
        monitor_thread.join(timeout=0.2)

    return RunStats(verdict=verdict, time_ms=elapsed_ms, memory_mb=max_memory / (1024 * 1024))


def evaluate_solutions(cpp_files: List[Path], tests: List[TestCase], build_dir: Path) -> None:
    exec_paths = [compile_solution(cpp_file, build_dir) for cpp_file in cpp_files]
    solution_labels = [f"Sol {index + 1}" for index in range(len(cpp_files))]

    column_width = 16
    header = f"{'TEST NAME':<12} | " + " | ".join(f"{label + ' (time)':<{column_width}}" for label in solution_labels)
    print(header)
    print("-" * len(header))

    score_by_solution = [0 for _ in cpp_files]
    max_time_by_solution = [0.0 for _ in cpp_files]
    max_memory_by_solution = [0.0 for _ in cpp_files]

    for test_case in tests:
        row_cells: List[str] = []
        for index, exec_path in enumerate(exec_paths):
            stats = judge_test(exec_path, test_case)
            if stats.verdict == "AC":
                score_by_solution[index] += 1
            max_time_by_solution[index] = max(max_time_by_solution[index], stats.time_ms)
            max_memory_by_solution[index] = max(max_memory_by_solution[index], stats.memory_mb)

            cell = f"{stats.verdict} {format_time(stats.time_ms)}"
            row_cells.append(f"{cell:<{column_width}}")

        print(f"{test_case.name:<12} | " + " | ".join(row_cells))

    print("-" * len(header))

    total_tests = len(tests)
    total_row = f"{'Total Score':<12} | " + " | ".join(f"{score}/{total_tests:<{column_width - len(str(score)) - len(str(total_tests)) - 1}}" for score in score_by_solution)
    max_time_row = f"{'Max Time':<12} | " + " | ".join(f"{format_time(value):<{column_width}}" for value in max_time_by_solution)
    memory_row = f"{'Memory Usage':<12} | " + " | ".join(f"{format_memory(value):<{column_width}}" for value in max_memory_by_solution)

    print(total_row)
    print(max_time_row)
    print(memory_row)


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python evaluate.py <đường_dẫn_cpp|thư_mục|glob> [<target2> ...]")
        print("Ví dụ: python evaluate.py sol/brute.cpp")
        print("Ví dụ: python evaluate.py sol/brute.cpp sol/model.cpp")
        print("Ví dụ: python evaluate.py sol")
        sys.exit(1)

    targets = collect_cpp_targets(sys.argv[1:])
    if not targets:
        print("❌ Không tìm thấy file .cpp hợp lệ để chấm.")
        sys.exit(1)

    tests = load_tests()

    with tempfile.TemporaryDirectory(prefix="cp_eval_") as tmp_dir:
        build_dir = Path(tmp_dir)
        print(f"\nBatch judging {len(targets)} solution(s) across {len(tests)} test(s)\n")
        evaluate_solutions(targets, tests, build_dir)


if __name__ == "__main__":
    main()
