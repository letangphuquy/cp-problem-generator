import glob
import platform
import subprocess
import sys
import time
import threading
import csv
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Set, Tuple

import psutil
from PIL import Image, ImageDraw, ImageFont

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
        # Check if it's a simple solution name (no path separators, no .cpp)
        # If so, expand it as sol/<name>.cpp
        expanded_target = raw_target
        if "/" not in raw_target and "\\" not in raw_target and not raw_target.endswith(".cpp"):
            expanded_path = Path("sol") / f"{raw_target}.cpp"
            if expanded_path.exists():
                expanded_target = str(expanded_path)
        
        candidate = Path(expanded_target)
        matches: List[Path]

        if candidate.exists():
            if candidate.is_dir():
                matches = sorted(candidate.rglob("*.cpp"))
            else:
                matches = [candidate] if candidate.suffix.lower() == ".cpp" else []
        else:
            matches = [Path(match) for match in sorted(glob.glob(expanded_target, recursive=True)) if Path(match).suffix.lower() == ".cpp"]

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


def compile_solutions(cpp_files: List[Path]) -> List[Path]:
    """Compile C++ files using compile.py utility with smart caching."""
    cpp_file_strs = [str(cpp.resolve()) for cpp in cpp_files]
    
    compile_script = Path("compile.py")
    if not compile_script.exists():
        print("❌ compile.py not found!")
        sys.exit(1)
    
    result = subprocess.run(
        [sys.executable, str(compile_script)] + cpp_file_strs,
        capture_output=True,
        text=True
    )
    
    # Print compile output
    if result.stdout:
        print(result.stdout, end="")
    
    if result.returncode != 0:
        if result.stderr:
            print(result.stderr, file=sys.stderr)
        sys.exit(1)
    
    # Return executable paths
    is_windows = platform.system() == "Windows"
    exe_suffix = ".exe" if is_windows else ""
    return [cpp.parent / f"{cpp.stem}{exe_suffix}" for cpp in cpp_files]


def format_time(ms: float) -> str:
    return f"{ms:.0f}ms"


def format_memory(memory_mb: float) -> str:
    return f"{memory_mb:.1f}MB"


def verdict_color(verdict: str) -> str:
    colors = {
        "AC": "\033[92m",
        "WA": "\033[91m",
        "TLE": "\033[93m",
        "RTE": "\033[95m",
    }
    return colors.get(verdict, "\033[0m")


def colored_verdict(verdict: str) -> str:
    return f"{verdict_color(verdict)}{verdict}\033[0m"


def judge_test(exec_path: Path, test_case: TestCase) -> RunStats:
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
    
    start_time = time.perf_counter()
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


def export_csv(
    output_file: Path,
    solution_names: List[str],
    tests: List[TestCase],
    results_matrix: List[List[str]],
    times_matrix: List[List[float]],
    scores: List[int],
    max_times: List[float],
    max_memories: List[float],
) -> None:
    with open(output_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        
        header = ["Test"] + [f"{name} (verdict)" for name in solution_names] + [f"{name} (time ms)" for name in solution_names]
        writer.writerow(header)
        
        for i, test in enumerate(tests):
            row = [test.name]
            row.extend(results_matrix[i])
            row.extend([f"{times_matrix[i][j]:.0f}" for j in range(len(solution_names))])
            writer.writerow(row)
        
        writer.writerow([])
        writer.writerow(["Total Score"] + [f"{scores[i]}/{len(tests)}" for i in range(len(solution_names))])
        writer.writerow(["Max Time (ms)"] + [f"{max_times[i]:.0f}" for i in range(len(solution_names))])
        writer.writerow(["Memory (MB)"] + [f"{max_memories[i]:.1f}" for i in range(len(solution_names))])


def render_image(
    output_file: Path,
    solution_names: List[str],
    tests: List[TestCase],
    results_matrix: List[List[str]],
    times_matrix: List[List[float]],
    scores: List[int],
    max_times: List[float],
    max_memories: List[float],
) -> None:
    verdict_to_rgb = {
        "AC": (76, 175, 80),
        "WA": (244, 67, 54),
        "TLE": (255, 193, 7),
        "RTE": (156, 39, 176),
    }
    
    col_width = 120
    row_height = 28
    header_height = 35
    
    num_cols = 1 + len(solution_names)
    num_rows = len(tests) + 4
    
    width = col_width * num_cols
    height = header_height + row_height * num_rows + 20
    
    img = Image.new("RGB", (width, height), color=(255, 255, 255))
    draw = ImageDraw.Draw(img)
    
    try:
        font_path = "C:\\Windows\\Fonts\\arial.ttf" if platform.system() == "Windows" else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
        bold_font_path = "C:\\Windows\\Fonts\\arialbd.ttf" if platform.system() == "Windows" else "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
        font = ImageFont.truetype(font_path, 10)
        bold_font = ImageFont.truetype(bold_font_path, 10)
    except (OSError, IOError):
        font = ImageFont.load_default()
        bold_font = font
    
    def draw_cell(x: int, y: int, w: int, h: int, text: str, bg_rgb: tuple, fg_rgb: tuple = (0, 0, 0), bold: bool = False) -> None:
        draw.rectangle([x, y, x + w, y + h], fill=bg_rgb, outline=(200, 200, 200))
        f = bold_font if bold else font
        draw.text((x + 5, y + 5), text, fill=fg_rgb, font=f)
    
    y = 10
    
    draw_cell(0, y, col_width, header_height, "Test", (200, 200, 200), bold=True)
    for j, sol in enumerate(solution_names):
        draw_cell((j + 1) * col_width, y, col_width, header_height, sol, (200, 200, 200), bold=True)
    y += header_height
    
    for i, test in enumerate(tests):
        draw_cell(0, y, col_width, row_height, test.name, (240, 240, 240))
        for j in range(len(solution_names)):
            verdict = results_matrix[i][j]
            time_ms = times_matrix[i][j]
            cell_text = f"{verdict}\n{format_time(time_ms)}"
            bg_color = verdict_to_rgb.get(verdict, (255, 255, 255))
            draw_cell((j + 1) * col_width, y, col_width, row_height, cell_text, bg_color, (0, 0, 0))
        y += row_height
    
    draw_cell(0, y, col_width, row_height, "Total Score", (220, 220, 220), bold=True)
    for j in range(len(solution_names)):
        draw_cell((j + 1) * col_width, y, col_width, row_height, f"{scores[j]}/{len(tests)}", (220, 220, 220))
    y += row_height
    
    draw_cell(0, y, col_width, row_height, "Max Time", (220, 220, 220), bold=True)
    for j in range(len(solution_names)):
        draw_cell((j + 1) * col_width, y, col_width, row_height, format_time(max_times[j]), (220, 220, 220))
    y += row_height
    
    draw_cell(0, y, col_width, row_height, "Memory Usage", (220, 220, 220), bold=True)
    for j in range(len(solution_names)):
        draw_cell((j + 1) * col_width, y, col_width, row_height, format_memory(max_memories[j]), (220, 220, 220))
    
    img.save(output_file)
    print(f"✅ Rendered image saved to {output_file}")


def evaluate_solutions(cpp_files: List[Path], tests: List[TestCase]) -> None:
    exec_paths = compile_solutions(cpp_files)
    solution_names = [cpp_file.stem for cpp_file in cpp_files]

    column_width = 16
    header = f"{'TEST NAME':<12} | " + " | ".join(f"{name:<{column_width}}" for name in solution_names)
    print(header)
    print("-" * len(header))

    score_by_solution = [0 for _ in cpp_files]
    max_time_by_solution = [0.0 for _ in cpp_files]
    max_memory_by_solution = [0.0 for _ in cpp_files]
    
    results_matrix: List[List[str]] = []
    times_matrix: List[List[float]] = []

    for test_case in tests:
        row_cells: List[str] = []
        results_row: List[str] = []
        times_row: List[float] = []
        
        for index, exec_path in enumerate(exec_paths):
            stats = judge_test(exec_path, test_case)
            if stats.verdict == "AC":
                score_by_solution[index] += 1
            max_time_by_solution[index] = max(max_time_by_solution[index], stats.time_ms)
            max_memory_by_solution[index] = max(max_memory_by_solution[index], stats.memory_mb)

            colored_verd = colored_verdict(stats.verdict)
            time_str = format_time(stats.time_ms)
            cell = f"{colored_verd} {time_str}"
            row_cells.append(f"{cell:<{column_width + 15}}")
            
            results_row.append(stats.verdict)
            times_row.append(stats.time_ms)
        
        results_matrix.append(results_row)
        times_matrix.append(times_row)
        print(f"{test_case.name:<12} | " + " | ".join(row_cells))

    print("-" * len(header))

    total_tests = len(tests)
    total_row = f"{'Total Score':<12} | " + " | ".join(f"{score}/{total_tests:<{column_width}}" for score in score_by_solution)
    max_time_row = f"{'Max Time':<12} | " + " | ".join(f"{format_time(value):<{column_width}}" for value in max_time_by_solution)
    memory_row = f"{'Memory Usage':<12} | " + " | ".join(f"{format_memory(value):<{column_width}}" for value in max_memory_by_solution)

    print(total_row)
    print(max_time_row)
    print(memory_row)
    
    export_csv(
        Path("results.csv"),
        solution_names,
        tests,
        results_matrix,
        times_matrix,
        score_by_solution,
        max_time_by_solution,
        max_memory_by_solution,
    )
    print(f"\n✅ Results saved to results.csv")
    
    render_image(
        Path("results.png"),
        solution_names,
        tests,
        results_matrix,
        times_matrix,
        score_by_solution,
        max_time_by_solution,
        max_memory_by_solution,
    )


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python evaluate.py <đường_dẫn_cpp|thư_mục|tên_sol|glob> [<target2> ...]")
        print("Ví dụ: python evaluate.py brute")
        print("Ví dụ: python evaluate.py brute model")
        print("Ví dụ: python evaluate.py sol/brute.cpp")
        print("Ví dụ: python evaluate.py sol")
        sys.exit(1)

    targets = collect_cpp_targets(sys.argv[1:])
    if not targets:
        print("❌ Không tìm thấy file .cpp hợp lệ để chấm.")
        sys.exit(1)

    tests = load_tests()
    
    print(f"\nBatch judging {len(targets)} solution(s) across {len(tests)} test(s)\n")
    evaluate_solutions(targets, tests)


if __name__ == "__main__":
    main()
