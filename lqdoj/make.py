import os
import subprocess
import sys

def main():
    # 1. Biên dịch file generator.cpp
    print("Đang biên dịch generator.cpp...")
    compile_cmd = ["g++", "-O3", "generator.cpp", "-o", "gen"]
    compile_process = subprocess.run(compile_cmd)
    
    if compile_process.returncode != 0:
        print("Lỗi: Biên dịch thất bại. Vui lòng kiểm tra lại code C++.")
        sys.exit(1)
    
    print("Biên dịch thành công! Bắt đầu sinh test...\n")
    print("-" * 50)

    # Lệnh chạy file thực thi tùy thuộc vào hệ điều hành
    exe_name = "gen.exe" if os.name == 'nt' else "./gen"

    # Tạo thư mục gốc "Test" nếu chưa có
    main_test_dir = "Test"
    os.makedirs(main_test_dir, exist_ok=True)

    # 2. Đọc script.txt và sinh test
    test_id = 1
    try:
        with open("script.txt", "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                # Bỏ qua các dòng trống và dòng comment (bắt đầu bằng #)
                if not line or line.startswith("#"):
                    continue
                
                # Tách các argument
                args = line.split()
                
                # Tạo tên file theo định dạng Test/Test0001.inp
                test_name = f"Test{test_id:04d}"
                inp_file = os.path.join(main_test_dir, f"{test_name}.inp")
                out_file = os.path.join(main_test_dir, f"{test_name}.out")
                
                cmd = [exe_name] + args
                
                print(f"Đang sinh {inp_file} và {out_file}... (Tham số: {line})")
                
                # Chạy generator: stdout -> .inp, stderr -> .out
                with open(inp_file, "w", encoding="utf-8") as f_inp, \
                     open(out_file, "w", encoding="utf-8") as f_out:
                    
                    result = subprocess.run(cmd, stdout=f_inp, stderr=f_out, text=True)
                    
                    if result.returncode != 0:
                        print(f"  [!] Cảnh báo: Có lỗi xảy ra khi sinh test {test_id}")
                
                test_id += 1
                
    except FileNotFoundError:
        print("Lỗi: Không tìm thấy file 'script.txt'.")
        sys.exit(1)

    print("-" * 50)
    print(f"Hoàn tất! Đã sinh thành công {test_id - 1} testcases vào thư mục '{main_test_dir}'.")

if __name__ == "__main__":
    main()