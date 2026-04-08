Trong hệ thống mật mã học RSA, việc sinh ra các khóa bảo mật phụ thuộc rất nhiều vào việc tìm kiếm và xác nhận các số nguyên tố siêu lớn. Alice đang làm việc tại một trung tâm dữ liệu và được giao nhiệm vụ phân tích một luồng số liệu đầu vào. Hệ thống sẽ liên tục gửi đến các số nguyên $N$ khổng lồ, và Alice cần phải viết một chương trình để kiểm tra xem số $N$ đó có phải là số nguyên tố hay không.

Một số nguyên dương lớn hơn 1 được gọi là số nguyên tố nếu nó chỉ có đúng hai ước số dương là 1 và chính nó.

**Yêu cầu:** Cho một số nguyên dương $N$, hãy giúp Alice kiểm tra xem $N$ có phải là số nguyên tố hay không.

#### Input
- Một dòng duy nhất chứa một số nguyên dương $N$.
- **Giới hạn:** $1 \le N \le 10^{18}$.

#### Output
- In ra `YES` nếu $N$ là số nguyên tố. Ngược lại, in ra `NO`.

#### Example

!!! question "Test 1"
    ???+ "Input"
        ```sample
        11
        ```
    ???+ success "Output"
        ```sample
        YES
        ```
    ??? warning "Note"
        11 chỉ chia hết cho 1 và 11, do đó nó là số nguyên tố.

!!! question "Test 2"
    ???+ "Input"
        ```sample
        1
        ```
    ???+ success "Output"
        ```sample
        NO
        ```
    ??? warning "Note"
        Theo định nghĩa, 1 không phải là số nguyên tố vì nó không lớn hơn 1.

!!! question "Test 3"
    ???+ "Input"
        ```sample
        91
        ```
    ???+ success "Output"
        ```sample
        NO
        ```
    ??? warning "Note"
        91 có thể phân tích thành 7 × 13, do đó nó là hợp số.

#### Scoring
- **Subtask 1 (20 points):** $1 \le N \le 10^4$. (Có thể giải bằng vòng lặp kiểm tra từ 1 đến $N$).
- **Subtask 2 (30 points):** $1 \le N \le 10^9$. 
- **Subtask 3 (30 points):** $1 \le N \le 10^{14}$.
- **Subtask 4 (20 points):** $1 \le N \le 10^{18}$.