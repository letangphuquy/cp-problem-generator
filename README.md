# 🚀 CP Automated Test Generator & Evaluator

Một hệ thống tự động hóa hoàn chỉnh dành cho việc sinh test, kiểm duyệt (validation) và chấm điểm (evaluation) các bài toán Lập trình thi đấu (Competitive Programming). Được thiết kế dựa trên các tiêu chuẩn công nghiệp của Codeforces, VNOI và Polygon.
## 🔧 Công cụ tiện ích (Utility Scripts)

### `compile.py` - Smart Compilation Utility
Tiện ích C++ biên dịch độc lập với hỗ trợ SHA256 hash caching. Có thể sử dụng từ bất kỳ dự án nào.

**Cách sử dụng:**
```bash
# Biên dịch một file
python compile.py gen.cpp
# Biên dịch nhiều file cùng lúc 
python compile.py gen.cpp validator.cpp sol/model.cpp

```
**Đặc điểm:**
- Flags chuẩn: `g++ -O3 -std=c++17`
- Output: đặt cùng thư mục với source file
### `generate_testdata.py` - Smart Testdata Generation

Tiện ích sinh test input với hỗ trợ caching thông minh. Bỏ qua sinh test nếu gen.cpp hash + generator args không thay đổi so với lần trước.
**Cách sử dụng:**
```bash
# Sinh tất cả test (mặc định)
python generate_testdata.py
# Sinh chỉ test 01-10
python generate_testdata.py --tests 01-10

```
**Output ví dụ:**
```
--- Phase: Generate Inputs ---
**Cache logic:**
- Nếu gen.cpp hash MATCH + args MATCH + file tồn tại → skip (✅ cached)
- Nếu gen.cpp hash MISMATCH hoặc args KHÁC → regen (⏳ Generated)
-----

## 🛠 Cách tùy biến cho bài toán mới
# 🚀 CP Automated Test Generator & Evaluator

Một hệ thống tự động hóa hoàn chỉnh dành cho việc sinh test, kiểm duyệt (validation) và chấm điểm (evaluation) các bài toán Lập trình thi đấu (Competitive Programming). Được thiết kế dựa trên các tiêu chuẩn công nghiệp của Codeforces, VNOI và Polygon.

Dự án này tuân thủ nguyên tắc **Separation of Concerns (Phân tách trách nhiệm)**:

  - `solution.h` chứa logic lời giải dùng chung (`read_input`, `solve`, `print_output`).
  - `gen.cpp` chỉ sinh Input.
  - `validator.cpp` rà soát lỗi Input.
  - `sol/model.cpp` là thin wrapper, gọi `solution::solve()` để sinh Output chuẩn.
  - `Bash/Batch Script` điều phối toàn bộ dây chuyền.

## ✨ Tính năng nổi bật

  * **Kiến trúc 4 Pha tách biệt (4-Phase Architecture):** Pipeline được chia thành 4 script độc lập (`phase_compile`, `phase_generate`, `phase_validate`, `phase_solve`) và được điều phối bởi 2 orchestrator tương đương nhau (`generate.sh` và `generate.bat`), giúp dễ debug, tái sử dụng và mở rộng.
  * **Smart Caching tích hợp:** 
    - **Compilation Caching** (`compile.py`): Theo dõi SHA256 của source file; bỏ qua compile nếu code không thay đổi.
    - **Testdata Caching** (`generate_testdata.py`): Theo dõi gen.cpp hash + generator args; skip sinh test nếu cả hai không đổi.
  * **CLI linh hoạt:** Chỉ định phase cần chạy, subset test cụ thể, hoặc chỉ retry các test bị lỗi — tất cả qua flag dòng lệnh.
  * **Log & Retry tự động:** Mỗi phase đều ghi trạng thái `ok|fail` theo test vào `tests/run.log` (ví dụ `test01 generate ok`). Dùng `--retry` để tự động tái chạy đúng các test đã thất bại ở lần chạy trước; mặc định sẽ bỏ qua `compile` nếu bạn không yêu cầu pha này một cách tường minh.
  * **Tích hợp Testlib.h:** Ngăn chặn tuyệt đối các rác (khoảng trắng thừa, ký tự ẩn, số ngoài giới hạn) lọt vào file input.
  * **Đa nền tảng (Cross-platform):** Hỗ trợ Native trên cả Windows (`generate.bat`) và Linux/macOS (`generate.sh`).
  * **Python Auto-Evaluator:** Tự động biên dịch và chấm điểm các file `.cpp` giải thuật khác với bảng Report trực quan (hiển thị Verdict AC, WA, TLE, RTE và thời gian chạy). Hỗ trợ batch judging cho nhiều lời giải cùng lúc, export CSV/PNG.
  * **Chống tràn số tuyệt đối:** Mã nguồn lõi (mặc định là bài toán Số nguyên tố) được cấu hình ép kiểu `__int128_t` và thuật toán Miller-Rabin để xử lý an toàn các số lên tới $10^{18}$.
  * **Shared Solver Core:** Logic lõi của bài toán được tập trung trong `solution.h`; các tool khác (`gen.cpp`, `evaluate.py`, `validator.cpp`) tái sử dụng cùng logic để tránh lệch kết quả.

## 🪟 Windows Native Support Matrix

Windows được support theo mức độ thực dụng, không ép mọi pipeline phải giống Linux 100%.

| Module | Windows native | Ghi chú |
|---|---:|---|
| `check-config` / `config_validator.py` | Có | Chạy native qua Python |
| Compile / Generate / Validate / Solve cho bài traditional | Có | Dùng `compile.py`, `generate_testdata.py`, `phase_*.bat` |
| Custom checker (`testlib.h`) | Có | Native được nếu checker không phụ thuộc POSIX-specific behavior |
| Interactive runner | Không cam kết v1 | Linux/WSL2 là acceptance target; Windows chỉ best-effort |
| Stress check model vs brute | Có | Chạy native được nếu solution/toolchain hỗ trợ |
| Git Bash smoke test | Có | Chỉ nên dùng để test nhanh CLI, không xem là môi trường interactive chuẩn |

**Nguyên tắc:** Nếu một tính năng phụ thuộc mạnh vào pipe semantics, async IO, hoặc `/proc`, thì ưu tiên Linux/WSL2 thay vì cố bảo đảm parity tuyệt đối trên Windows.

## ✅ Check Config (Bước gate đầu tiên)

Trước khi chạy compile/generate/validate/solve, hãy validate manifest:

```bash
# Cross-platform
python judge.py check-config problem.toml

# Windows wrapper
judge.bat check-config problem.toml

# Linux/macOS wrapper
./judge.sh check-config problem.toml
```

Nếu không truyền path, command sẽ mặc định dùng `problem.toml` tại thư mục hiện tại.

## 📁 Cấu trúc dự án

```text
📦 prime-test-generator
├── 📜 README.md                    # File hướng dẫn này
├── 📜 .gitignore                   # Loại bỏ các file rác/binary khỏi Git
├── 📜 generate.bat                 # Script sinh test cho Windows
├── 📜 generate.sh                  # Orchestrator chính cho Linux/macOS
├── 📜 evaluate.py                  # Công cụ chấm điểm cục bộ (Local Judger)
├── 📜 compile.py                   # Tiện ích biên dịch với smart caching
├── 📜 compile.bat                  # Wrapper biên dịch cho Windows
├── 📜 compile.sh                   # Wrapper biên dịch cho Linux/macOS
├── 📜 generate_testdata.py         # Tiện ích sinh test với smart caching
├── 📜 script.txt                   # Kịch bản sinh test (Cấu hình số lượng, tham số)
├── 📜 .eval_cache.json             # Cache biên dịch (tự động sinh, track file hash)
├── 📜 .testdata_cache.json         # Cache sinh test (tự động sinh, track args)
├── 🛠️ solution.h                   # Shared solver core (read_input / solve / print_output)
├── 🛠️ gen.cpp                      # Mã nguồn sinh Input (.inp)
├── 🛠️ validator.cpp                # Mã nguồn kiểm duyệt Input (Dùng testlib.h)
├── 🛠️ testlib.h                    # Thư viện chuẩn của Codeforces (Cần tải về)
├── 📂 scripts/                     # Các script pha con (phase scripts)
│   ├── 📜 common.bat               # Tiện ích dùng chung cho Windows batch
│   ├── 📜 common.sh                # Tiện ích dùng chung (màu sắc, logging, parse spec, log)
│   ├── 📜 phase_compile.bat        # Pha 1: Biên dịch gen / val / sol/model (Windows)
│   ├── 📜 phase_compile.sh         # Pha 1: Biên dịch gen / val / sol/model (Unix)
│   ├── 📜 phase_generate.bat       # Pha 2: Sinh file .inp với smart caching (Windows)
│   ├── 📜 phase_generate.sh        # Pha 2: Sinh file .inp với smart caching (Unix)
│   ├── 📜 phase_validate.bat       # Pha 3: Kiểm duyệt file .inp (Windows)
│   ├── 📜 phase_validate.sh        # Pha 3: Kiểm duyệt file .inp (Unix)
│   ├── 📜 phase_solve.bat          # Pha 4: Chạy model để sinh file .out (Windows)
│   └── 📜 phase_solve.sh           # Pha 4: Chạy model để sinh file .out (Unix)
├── 📂 sol/                         # Thư mục chứa các lời giải
│   ├── 🏆 model.cpp                # Thin wrapper: main() gọi solution::solve()
│   └── 🐢 brute.cpp                # Thuật trâu (Dùng để test thử TLE/WA)
├── 📂 lqdoj/                       # LQDOJ alternative generator
│   ├── 📜 generator.cpp            # Generator variant
│   ├── 📜 make.py                  # LQDOJ make script dùng compile utility
│   └── 📜 script.txt               # LQDOJ test configuration
└── 📂 tests/                       # Thư mục chứa .inp / .out và run.log
    └── 📜 run.log                  # Log kết quả từng test (tự động sinh ra)
```

## ⚡ Tối ưu hóa thông minh (Smart Caching Features)

Hệ thống tự động phát hiện và bỏ qua những bước không cần thiết để tăng tốc độ chạy:

### 🔄 Smart Compilation Caching (`.eval_cache.json`)
- **Phút đầu tiên:** Biên dịch `gen.cpp`, `validator.cpp`, `sol/model.cpp` (tương ứng ~3 giây)
- **Lần tiếp theo (código không đổi):** Skip biên dịch, chỉ validate cache (~ms)
- **Khi code thay đổi:** Tự động phát hiện, biên dịch chỉ file thay đổi
- **Benefit:** Trong chu kỳ phát triển nhanh, tiết kiệm hàng phút

**Cách hoạt động:**
```python
# Hash SHA256 của file → cached hash = skip compile
# Hash SHA256 không match → compile + update cache
```

### ⚙️ Smart Testdata Caching (`.testdata_cache.json`)
- **Lần đầu sinh test:** Sinh 30 test (30 × 0.5s = 15 giây)
- **Nếu gen.cpp không đổi:** Cache miss → skip generate, dùng .inp cũ (~1 giây)
- **Nếu script.txt args đổi:** Cache hit cho unchanged test, chỉ gen lại test bị ảnh hưởng
- **Benefit:** Khi debug solver một mình (không thay generator), compile+validate+solve có thể chạy trong vài giây

**Console output ví dụ:**
```
--- Phase: Generate Inputs ---

✅ test01.inp (cached)
✅ test02.inp (cached)
⏳ Generated test03.inp (args: 100 50)
✅ test04.inp (cached)

Results: 1 generated, 3 cached
```

---

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

Nếu bạn muốn dùng bộ khung này để ra đề cho một bài toán khác, hãy làm theo 5 bước sau:

**Bước 1: Cập nhật `solution.h` (khuyến nghị)**

  - Viết logic lõi của bài toán vào `solution.h` với 3 hàm: `read_input()`, `solve()`, `print_output()`.
  - Mục tiêu là để cả `sol/model.cpp` và các tool khác (ví dụ `gen.cpp` cho QA in-place) có thể tái sử dụng cùng một logic.

**Bước 2: Giữ `sol/model.cpp` ở dạng thin wrapper**

  - `model.cpp` chỉ cần `#include "../solution.h"` và gọi `solution::solve()` trong `main()`.
  - Tránh đặt lại thuật toán đầy đủ trong file này để không bị duplicate logic.

**Bước 3: Viết lại `gen.cpp`**

  - Xóa logic sinh số nguyên tố cũ.
  - Viết các hàm sinh dữ liệu ngẫu nhiên (ví dụ sinh mảng, sinh đồ thị, sinh chuỗi) cho bài toán mới.
  - **Lưu ý:** Chỉ dùng `cout` để in ra chuẩn format đầu vào, KHÔNG in ra đáp án.
  - Sử dụng `argc` và `argv` để truyền tham số từ script vào.

**Bước 4: Viết lại `validator.cpp`**

  - Sử dụng các hàm của `testlib.h` như `inf.readInt()`, `inf.readSpace()`, `inf.readEoln()`, `inf.readEof()` để đảm bảo file Input sinh ra đúng 100% format cấu trúc bạn quy định.

**Bước 5: Thiết lập kịch bản `script.txt`**

  - Liệt kê các lệnh để định hướng `gen.cpp`.
  - Có thể dùng cú pháp `# Comment` ở cuối dòng để ghi chú mục đích của test case đó (ví dụ: test edge case, test array all zeros, v.v...).

## 💡 Best Practices được áp dụng

  - **Shared Solver Core:** Đặt logic lời giải trong `solution.h` để tránh lệch logic giữa model và các tool phụ trợ (generator/evaluator/QA script).
  - **Inline Comment Safe:** Các dòng trong `script.txt` có thể có comment cuối dòng bằng `#`; Bash script sẽ cắt phần comment trước khi gọi `gen`, còn `gen.cpp` cũng dừng parse tại token bắt đầu bằng `#`.
  - **Strict Validation:** Mọi file Input sinh ra đều phải đi qua chốt kiểm tra `validator`. Nếu sai format (dù chỉ là 1 khoảng trắng), phase validate sẽ báo fail; bạn có thể dùng `--continue-on-error` để ghi nhận toàn bộ lỗi trước khi dừng.
  - **No stderr hacking:** Không còn dùng `cerr` để luồn lách ghi output. Quy trình 1 chiều chuẩn mực: Input -\> Logic -\> Output.

  ## 📝 Chú ý về Cache Files

  Hệ thống tự động tạo ra hai file cache để tối ưu hóa performance:

  | File | Mục đích |
  |------|---------|
  | `.eval_cache.json` | Lưu trữ SHA256 hash của compiled files (từ `compile.py`) |
  | `.testdata_cache.json` | Lưu trữ hash của `gen.cpp` + generator args (từ `generate_testdata.py`) |

  Cả hai file đều **safe to delete** — sẽ tự động tái tạo khi cần thiết.