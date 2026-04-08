import sys
import time
import subprocess
from pathlib import Path

# Cấu hình thời gian giới hạn (1.0 giây)
TIME_LIMIT = 1.0 

def evaluate(exec_path):
    test_dir = Path("tests")
    if not test_dir.exists():
        print("❌ Thư mục tests/ không tồn tại! Hãy chạy script sinh test trước.")
        return

    inp_files = sorted(test_dir.glob("*.inp"))
    if not inp_files:
        print("❌ Không tìm thấy test nào trong thư mục!")
        return

    # In Header bảng kết quả
    print(f"{'TEST NAME':<12} | {'VERDICT':<10} | {'TIME (ms)':<10}")
    print("-" * 40)

    passed = 0
    total = len(inp_files)

    # Mã màu Terminal cho ngầu
    C_AC = "\033[92m"    # Xanh lá
    C_WA = "\033[91m"    # Đỏ
    C_TLE = "\033[93m"   # Vàng
    C_RTE = "\033[95m"   # Tím
    C_RESET = "\033[0m"

    for inp_path in inp_files:
        out_path = inp_path.with_suffix(".out")
        if not out_path.exists():
            continue

        with open(inp_path, 'r') as fin, open(out_path, 'r') as fout:
            expected_out = fout.read().strip()
            
            start_time = time.perf_counter()
            try:
                # Chạy process với subprocess
                result = subprocess.run(
                    [exec_path],
                    stdin=fin,
                    capture_output=True,
                    text=True,
                    timeout=TIME_LIMIT
                )
                elapsed = time.perf_counter() - start_time
                
                # Đánh giá Verdict
                if result.returncode != 0:
                    verdict = "RTE"
                    color = C_RTE
                else:
                    actual_out = result.stdout.strip()
                    if actual_out == expected_out:
                        verdict = "AC"
                        color = C_AC
                        passed += 1
                    else:
                        verdict = "WA"
                        color = C_WA
                        
            except subprocess.TimeoutExpired:
                elapsed = TIME_LIMIT
                verdict = "TLE"
                color = C_TLE

            # Format dòng in ra
            v_str = f"{color}{verdict}{C_RESET}"
            time_str = f"{elapsed * 1000:>5.0f} ms"
            
            # 19 khoảng trắng để bù trừ độ dài mã màu ANSI trong f-string
            print(f"{inp_path.stem:<12} | {v_str:<19} | {time_str}")

    # In kết quả tổng hợp
    print("-" * 40)
    score_color = C_AC if passed == total else C_WA
    print(f"KẾT QUẢ: {score_color}{passed}/{total} TESTS PASSED{C_RESET}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python evaluate.py <đường_dẫn_file_thực_thi>")
        print("Ví dụ: python evaluate.py ./brute")
        sys.exit(1)
        
    exec_file = sys.argv[1]
    evaluate(exec_file)