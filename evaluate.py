import sys
import time
import subprocess
import platform
from pathlib import Path

TIME_LIMIT = 1.0 

def compile_solution(cpp_path):
    cpp_file = Path(cpp_path)
    if not cpp_file.exists():
        print(f"❌ Không tìm thấy file: {cpp_path}")
        sys.exit(1)

    is_windows = platform.system() == "Windows"
    exe_name = cpp_file.stem + (".exe" if is_windows else "")
    exe_path = cpp_file.parent / exe_name

    print(f"⏳ Đang tự động biên dịch {cpp_file.name}...")
    compile_cmd = ["g++", "-O3", "-std=c++17", str(cpp_file), "-o", str(exe_path)]
    
    result = subprocess.run(compile_cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"❌ Lỗi biên dịch {cpp_file.name}:\n{result.stderr}")
        sys.exit(1)
        
    print(f"✅ Biên dịch thành công!\n")
    return exe_path

def evaluate(cpp_path):
    # 1. Tự động compile file .cpp đầu vào
    exec_path = compile_solution(cpp_path)
    
    test_dir = Path("tests")
    if not test_dir.exists():
        print("❌ Thư mục tests/ không tồn tại! Hãy chạy script sinh test trước.")
        return

    inp_files = sorted(test_dir.glob("*.inp"))
    if not inp_files:
        print("❌ Không tìm thấy test nào trong thư mục!")
        return

    print(f"{'TEST NAME':<12} | {'VERDICT':<10} | {'TIME (ms)':<10}")
    print("-" * 40)

    passed = 0
    total = len(inp_files)

    C_AC = "\033[92m"    
    C_WA = "\033[91m"    
    C_TLE = "\033[93m"   
    C_RTE = "\033[95m"   
    C_RESET = "\033[0m"

    for inp_path in inp_files:
        out_path = inp_path.with_suffix(".out")
        if not out_path.exists():
            continue

        with open(inp_path, 'r') as fin, open(out_path, 'r') as fout:
            expected_out = fout.read().strip()
            
            start_time = time.perf_counter()
            try:
                result = subprocess.run(
                    [str(exec_path)],
                    stdin=fin,
                    capture_output=True,
                    text=True,
                    timeout=TIME_LIMIT
                )
                elapsed = time.perf_counter() - start_time
                
                if result.returncode != 0:
                    verdict, color = "RTE", C_RTE
                else:
                    actual_out = result.stdout.strip()
                    if actual_out == expected_out:
                        verdict, color = "AC", C_AC
                        passed += 1
                    else:
                        verdict, color = "WA", C_WA
                        
            except subprocess.TimeoutExpired:
                elapsed = TIME_LIMIT
                verdict, color = "TLE", C_TLE

            v_str = f"{color}{verdict}{C_RESET}"
            time_str = f"{elapsed * 1000:>5.0f} ms"
            print(f"{inp_path.stem:<12} | {v_str:<19} | {time_str}")

    print("-" * 40)
    score_color = C_AC if passed == total else C_WA
    print(f"KẾT QUẢ CỦA {Path(cpp_path).name}: {score_color}{passed}/{total} TESTS PASSED{C_RESET}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python evaluate.py <đường_dẫn_file_cpp>")
        print("Ví dụ: python evaluate.py sol/brute.cpp")
        sys.exit(1)
        
    evaluate(sys.argv[1])