# 🚀 CP Automated Test Generator & Evaluator

Một hệ thống tự động hóa hoàn chỉnh dành cho việc sinh test, kiểm duyệt (validation) và chấm điểm (evaluation) các bài toán Lập trình thi đấu (Competitive Programming). Được thiết kế dựa trên các tiêu chuẩn công nghiệp của Codeforces, VNOI và Polygon.

Dự án này tuân thủ nguyên tắc **Separation of Concerns (Phân tách trách nhiệm)**:

  - `gen.cpp` chỉ sinh Input.
  - `validator.cpp` rà soát lỗi Input.
  - `model.cpp` tính toán Output chuẩn.
  - `Bash/Batch Script` điều phối toàn bộ dây chuyền.

## ✨ Tính năng nổi bật

  * **Kiến trúc 3 Pha (3-Phase Architecture):** Tối ưu hóa tốc độ sinh test bằng cách Xử lý lô (Bulk Processing), giảm thiểu hiện tượng Context Switching trên hệ điều hành.
  * **Tích hợp Testlib.h:** Ngăn chặn tuyệt đối các rác (khoảng trắng thừa, ký tự ẩn, số ngoài giới hạn) lọt vào file input.
  * **Đa nền tảng (Cross-platform):** Hỗ trợ Native trên cả Windows (`generate.bat`) và Linux/macOS (`generate.sh`).
  * **Python Auto-Evaluator:** Tự động biên dịch và chấm điểm các file `.cpp` giải thuật khác với bảng Report trực quan (hiển thị Verdict AC, WA, TLE, RTE và thời gian chạy).
  * **Chống tràn số tuyệt đối:** Mã nguồn lõi (mặc định là bài toán Số nguyên tố) được cấu hình ép kiểu `__int128_t` và thuật toán Miller-Rabin để xử lý an toàn các số lên tới $10^{18}$.

## 📁 Cấu trúc dự án

```text
📦 prime-test-generator
├── 📜 README.md          # File hướng dẫn này
├── 📜 .gitignore         # Loại bỏ các file rác/binary khỏi Git
├── 📜 generate.bat       # Script sinh test cho Windows
├── 📜 generate.sh        # Script sinh test cho Linux/macOS
├── 📜 evaluate.py        # Công cụ chấm điểm cục bộ (Local Judger)
├── 📜 script.txt         # Kịch bản sinh test (Cấu hình số lượng, tham số)
├── 🛠️ gen.cpp            # Mã nguồn sinh Input (.inp)
├── 🛠️ validator.cpp      # Mã nguồn kiểm duyệt Input (Dùng testlib.h)
├── 🛠️ testlib.h          # Thư viện chuẩn của Codeforces (Cần tải về)
├── 📂 sol/               # Thư mục chứa các lời giải
│   ├── 🏆 model.cpp      # Thuật chuẩn (Tối ưu nhất - Dùng để sinh .out)
│   └── 🐢 brute.cpp      # Thuật trâu (Dùng để test thử TLE/WA)
└── 📂 tests/             # Thư mục chứa các file .inp và .out (Tự động sinh ra)
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

### 2\. Chấm thử một lời giải (Local Evaluation)

Bạn có một file code giải thuật (ví dụ `sol/brute.cpp`) và muốn biết nó sẽ được bao nhiêu điểm, bị Time Limit hay Wrong Answer ở đâu trên bộ test vừa sinh?

Chỉ cần chạy lệnh sau:

```bash
python evaluate.py sol/brute.cpp
```

Tool sẽ **tự động biên dịch** file cpp đó, chạy qua toàn bộ test trong thư mục `tests/` và trả về bảng kết quả cực kỳ trực quan.

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

  - **Inline Comment Safe:** Script nhận diện và bỏ qua các comment bắt đầu bằng dấu `#` một cách thông minh, không làm crash C++ arguments.
  - **Strict Validation:** Mọi file Input sinh ra đều phải đi qua chốt kiểm tra `validator`. Nếu sai format (dù chỉ là 1 khoảng trắng), hệ thống sẽ Abort ngay lập tức.
  - **No stderr hacking:** Không còn dùng `cerr` để luồn lách ghi output. Quy trình 1 chiều chuẩn mực: Input -\> Logic -\> Output.