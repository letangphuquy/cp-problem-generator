# 🚀 CP Automated Test Generator & Evaluator

Một hệ thống tự động hóa hoàn chỉnh dành cho việc sinh test, kiểm duyệt (validation) và chấm điểm (evaluation) các bài toán Lập trình thi đấu (Competitive Programming). Được thiết kế dựa trên các tiêu chuẩn công nghiệp của Codeforces, VNOI và Polygon.

Dự án này tuân thủ nguyên tắc **Separation of Concerns (Phân tách trách nhiệm)**:

  - `gen.cpp` chỉ sinh Input.
  - `validator.cpp` rà soát lỗi Input.
  - `model.cpp` tính toán Output chuẩn.
  - `Bash/Batch Script` điều phối toàn bộ dây chuyền.

## ✨ Tính năng nổi bật

  * **Kiến trúc 4 Pha tách biệt (4-Phase Architecture):** Pipeline được chia thành 4 script độc lập (`phase_compile`, `phase_generate`, `phase_validate`, `phase_solve`) và được điều phối bởi 2 orchestrator tương đương nhau (`generate.sh` và `generate.bat`), giúp dễ debug, tái sử dụng và mở rộng.
  * **CLI linh hoạt:** Chỉ định phase cần chạy, subset test cụ thể, hoặc chỉ retry các test bị lỗi — tất cả qua flag dòng lệnh.
  * **Log & Retry tự động:** Mỗi phase đều ghi trạng thái `ok|fail` theo test vào `tests/run.log` (ví dụ `test01 generate ok`). Dùng `--retry` để tự động tái chạy đúng các test đã thất bại ở lần chạy trước; mặc định sẽ bỏ qua `compile` nếu bạn không yêu cầu pha này một cách tường minh.
  * **Tích hợp Testlib.h:** Ngăn chặn tuyệt đối các rác (khoảng trắng thừa, ký tự ẩn, số ngoài giới hạn) lọt vào file input.
  * **Đa nền tảng (Cross-platform):** Hỗ trợ Native trên cả Windows (`generate.bat`) và Linux/macOS (`generate.sh`).
  * **Python Auto-Evaluator:** Tự động biên dịch và chấm điểm các file `.cpp` giải thuật khác với bảng Report trực quan (hiển thị Verdict AC, WA, TLE, RTE và thời gian chạy).
  * **Chống tràn số tuyệt đối:** Mã nguồn lõi (mặc định là bài toán Số nguyên tố) được cấu hình ép kiểu `__int128_t` và thuật toán Miller-Rabin để xử lý an toàn các số lên tới $10^{18}$.

## 📁 Cấu trúc dự án

```text
📦 prime-test-generator
├── 📜 README.md                    # File hướng dẫn này
├── 📜 .gitignore                   # Loại bỏ các file rác/binary khỏi Git
├── 📜 generate.bat                 # Script sinh test cho Windows
├── 📜 generate.sh                  # Orchestrator chính cho Linux/macOS
├── 📜 evaluate.py                  # Công cụ chấm điểm cục bộ (Local Judger)
├── 📜 script.txt                   # Kịch bản sinh test (Cấu hình số lượng, tham số)
├── 🛠️ gen.cpp                      # Mã nguồn sinh Input (.inp)
├── 🛠️ validator.cpp                # Mã nguồn kiểm duyệt Input (Dùng testlib.h)
├── 🛠️ testlib.h                    # Thư viện chuẩn của Codeforces (Cần tải về)
├── 📂 scripts/                     # Các script pha con (phase scripts)
│   ├── 📜 common.sh                # Tiện ích dùng chung (màu sắc, logging, parse spec, log)
│   ├── 📜 phase_compile.sh         # Pha 1: Biên dịch gen / val / sol/model
│   ├── 📜 phase_generate.sh        # Pha 2: Sinh file .inp
│   ├── 📜 phase_validate.sh        # Pha 3: Kiểm duyệt file .inp
│   └── 📜 phase_solve.sh           # Pha 4: Chạy model để sinh file .out
├── 📂 sol/                         # Thư mục chứa các lời giải
│   ├── 🏆 model.cpp                # Thuật chuẩn (Tối ưu nhất - Dùng để sinh .out)
│   └── 🐢 brute.cpp                # Thuật trâu (Dùng để test thử TLE/WA)
└── 📂 tests/                       # Thư mục chứa .inp / .out và run.log
    └── 📜 run.log                  # Log kết quả từng test (tự động sinh ra)
```

## ⚙️ Yêu cầu hệ thống

1.  **C++ Compiler:** `g++` hỗ trợ chuẩn C++17 trở lên (MinGW trên Windows hoặc GCC/Clang trên Linux/macOS). Đã được thêm vào biến môi trường `PATH`.
2.  **Python 3.x:** (Tùy chọn) Cần thiết nếu muốn sử dụng công cụ chấm điểm `evaluate.py`.
3.  **Thư viện Testlib:** Tải file `testlib.h` từ [repo chính thức của MikeMirzayanov](https://www.google.com/search?q=https://raw.githubusercontent.com/MikeMirzayanov/testlib/master/testlib.h) và đặt vào thư mục gốc.

## 🚀 Hướng dẫn sử dụng nhanh (Quick Start)

### 1\. Sinh bộ Test

Hệ thống sẽ đọc cấu hình từ `script.txt`, tự động biên dịch các file cần thiết và tạo ra cặp file `.inp` / `.out` trong thư mục `tests/`.

  * **Trên Windows:** Mở CMD hoặc PowerShell tại thư mục dự án và chạy:

    ```cmd
    .\generate.bat
    ```

    *(Hoặc đơn giản là click đúp chuột vào file `generate.bat`)*

  * **Trên Linux / macOS:**
    Cấp quyền thực thi và chạy bash script:

    ```bash
    chmod +x generate.sh
    ./generate.sh
    ```

### 1b\. Tuỳ chỉnh pipeline với CLI (Linux/macOS)

`generate.sh` là một **orchestrator** hỗ trợ đầy đủ CLI flags để kiểm soát chính xác pha nào chạy, test nào được xử lý, và cách xử lý lỗi. `generate.bat` có cùng bộ flag và cùng luồng xử lý tương ứng trên Windows.

**Cú pháp:**

```bash
./generate.sh [--phases <list>] [--tests <spec>] [--retry] [--continue-on-error] [--clean]
```

| Flag | Mặc định | Mô tả |
|------|----------|-------|
| `--phases <list>` | `compile,generate,validate,solve` | Các pha cần chạy, phân cách bởi dấu phẩy |
| `--tests <spec>` | `all` | Subset test cần xử lý (xem cú pháp bên dưới). Chỉ áp dụng cho các phase `generate`, `validate`, `solve` |
| `--retry` | — | Tự động chỉ retry các test đã fail ở lần chạy trước |
| `--continue-on-error` | — | Không dừng khi gặp lỗi validate; log tất cả lỗi rồi tiếp tục |
| `--clean` | — | Xóa file `.inp` cũ của các test được chọn trước khi sinh lại |
| `-h`, `--help` | — | Hiển thị hướng dẫn sử dụng |

**Cú pháp `--tests <spec>`:**

| Ví dụ | Ý nghĩa |
|-------|---------|
| `all` | Tất cả test trong `script.txt` |
| `05` | Chỉ test số 5 |
| `01,03,07` | Test 01, 03 và 07 |
| `01-10` | Test 01 đến 10 |
| `01-05,07,10-12` | Kết hợp range và từng số |

**Ví dụ thực tế:**

```bash
# Chạy toàn bộ pipeline (mặc định)
./generate.sh

# Chỉ biên dịch lại (không đụng đến tests/)
./generate.sh --phases compile

# Sinh + validate + solve cho 10 test đầu (bỏ qua compile)
./generate.sh --phases generate,validate,solve --tests 01-10

# Chỉ validate lại test 03 và 07
./generate.sh --phases validate --tests 03,07

# Retry tự động: chỉ chạy lại các test đã fail trong lần trước
./generate.sh --retry

# Validate toàn bộ nhưng không dừng khi có lỗi (ghi log tất cả lỗi)
./generate.sh --phases validate --continue-on-error

# Sinh lại toàn bộ từ đầu (xóa file cũ)
./generate.sh --phases generate,validate,solve --clean
```

**Log file (`tests/run.log`):**

Mỗi lần chạy, kết quả từng test được ghi vào `tests/run.log` với định dạng:
```
test01 generate ok
test01 validate ok
test01 solve ok
test05 validate fail
```
Flag `--retry` đọc file này và tự động xác định test nào cần chạy lại.

### 1c\. Tuỳ chỉnh pipeline với CLI (Windows CMD)

`generate.bat` đồng bộ với `generate.sh`: cùng flag, cùng default phase, cùng luồng retry/log, và cùng các phase scripts khi gọi trực tiếp.

**Cú pháp:**

```cmd
generate.bat [--phases <list>] [--tests <spec>] [--retry] [--continue-on-error] [--clean]
```

Các phase scripts cũng có thể gọi trực tiếp từ thư mục gốc của dự án:

```cmd
:: Chỉ compile
generate.bat --phases compile

:: Sinh + validate + solve cho 10 test đầu
generate.bat --phases generate,validate,solve --tests 01-10

:: Retry tự động
generate.bat --retry

:: Validate toàn bộ, không dừng khi lỗi
generate.bat --phases validate --continue-on-error

:: Gọi trực tiếp một phase script (từ thư mục gốc)
scripts\phase_validate.bat --tests 03,07

:: Xem hướng dẫn
generate.bat /?
```

> **Lưu ý:** Luôn chạy `generate.bat` và các phase scripts từ thư mục gốc của dự án (nơi chứa `script.txt`). Các phase scripts trong `scripts\` tự động điều hướng về thư mục gốc khi được gọi trực tiếp, nên có thể dùng riêng lẻ để rerun từng pha.

### 2\. Chấm thử một lời giải (Local Evaluation)

Bạn có một file code giải thuật (ví dụ `sol/brute.cpp`) và muốn biết nó sẽ được bao nhiêu điểm, bị Time Limit hay Wrong Answer ở đâu trên bộ test vừa sinh?

Chỉ cần chạy lệnh sau:

```bash
python evaluate.py sol/brute.cpp
```

Tool sẽ **tự động biên dịch** file cpp đó, chạy qua toàn bộ test trong thư mục `tests/` và trả về bảng kết quả cực kỳ trực quan. Bạn cũng có thể judge nhiều lời giải trong một lần chạy:

```bash
python evaluate.py sol/brute.cpp sol/model.cpp
python evaluate.py sol
```

Khi truyền một thư mục, script sẽ quét tất cả file `.cpp` bên trong thư mục đó.

-----

## 🛠 Cách tùy biến cho bài toán mới

Nếu bạn muốn dùng bộ khung này để ra đề cho một bài toán khác, hãy làm theo 4 bước sau:

**Bước 1: Cập nhật `sol/model.cpp`**

  - Viết thuật toán chuẩn xác và tối ưu nhất của bạn vào file này.
  - Nó sẽ đọc từ `stdin` và in đáp án đúng ra `stdout`.

**Bước 2: Viết lại `gen.cpp`**

  - Xóa logic sinh số nguyên tố cũ.
  - Viết các hàm sinh dữ liệu ngẫu nhiên (ví dụ sinh mảng, sinh đồ thị, sinh chuỗi) cho bài toán mới.
  - **Lưu ý:** Chỉ dùng `cout` để in ra chuẩn format đầu vào, KHÔNG in ra đáp án.
  - Sử dụng `argc` và `argv` để truyền tham số từ script vào.

**Bước 3: Viết lại `validator.cpp`**

  - Sử dụng các hàm của `testlib.h` như `inf.readInt()`, `inf.readSpace()`, `inf.readEoln()`, `inf.readEof()` để đảm bảo file Input sinh ra đúng 100% format cấu trúc bạn quy định.

**Bước 4: Thiết lập kịch bản `script.txt`**

  - Liệt kê các lệnh để định hướng `gen.cpp`.
  - Có thể dùng cú pháp `# Comment` ở cuối dòng để ghi chú mục đích của test case đó (ví dụ: test edge case, test array all zeros, v.v...).

## 💡 Best Practices được áp dụng

  - **Inline Comment Safe:** Các dòng trong `script.txt` có thể có comment cuối dòng bằng `#`; Bash script sẽ cắt phần comment trước khi gọi `gen`, còn `gen.cpp` cũng dừng parse tại token bắt đầu bằng `#`.
  - **Strict Validation:** Mọi file Input sinh ra đều phải đi qua chốt kiểm tra `validator`. Nếu sai format (dù chỉ là 1 khoảng trắng), phase validate sẽ báo fail; bạn có thể dùng `--continue-on-error` để ghi nhận toàn bộ lỗi trước khi dừng.
  - **No stderr hacking:** Không còn dùng `cerr` để luồn lách ghi output. Quy trình 1 chiều chuẩn mực: Input -\> Logic -\> Output.