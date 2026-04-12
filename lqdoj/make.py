import os
import subprocess
import sys

def main():
    # 1. Biên dịch file generator.cpp sử dụng compile.py utility
    print("Đang biên dịch generator.cpp...")
    
    # Call the compile.py utility from parent directory
    parent_dir = os.path.dirname(os.path.abspath(__file__))
    compile_script = os.path.join(parent_dir, "..", "compile.py")
    generator_src = os.path.join(parent_dir, "generator.cpp")
    
    compile_process = subprocess.run(
        [sys.executable, compile_script, generator_src],
        capture_output=True,
        text=True
    )
    
    if compile_process.returncode != 0:
        print("Lỗi: Biên dịch thất bại.")
        if compile_process.stderr:
            print(compile_process.stderr)
        sys.exit(1)
    
    if compile_process.stdout:
        print(compile_process.stdout)
    
    print("Biên dịch thành công! Bắt đầu sinh test...\n")
    print("-" * 50)

    # Lệnh chạy file thực thi tùy thuộc vào hệ điều hành
    exe_name = "gen.exe" if os.name == 'nt' else "./gen"
    exe_path = os.path.join(parent_dir, exe_name)

    # Tạo thư mục gốc "Test" nếu chưa có
    main_test_dir = os.path.join(parent_dir, "Test")
    os.makedirs(main_test_dir, exist_ok=True)

    # 2. Đọc script.txt và sinh test
    test_id = 1
    script_path = os.path.join(parent_dir, "script.txt")
    try:
        with open(script_path, "r", encoding="utf-8") as f:
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
                
                cmd = [exe_path] + args
                
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

if __name__ == "__main__":
    main()