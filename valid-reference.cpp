/**
 * TESTLIB VALIDATOR CHEATSHEET & REFERENCE
 * Tác giả: Gemini
 * Mục đích: Tổng hợp toàn bộ cú pháp thực chiến của testlib.h cho Validator.
 * Cách dùng: Copy các snippet tương ứng vào dự án thật, xóa những phần không cần thiết.
 */

#include "testlib.h"
#include <iostream>
#include <vector>
#include <set>
#include <string>

using namespace std;

int main(int argc, char* argv[]) {
    // 1. KHỞI TẠO (Bắt buộc)
    // Dòng này nạp bộ thư viện, thiết lập strict-mode mặc định.
    registerValidation(argc, argv);

    /* =========================================================================
       SECTION 1: SỐ NGUYÊN & BIẾN CƠ BẢN ĐƠN LẺ
       ========================================================================= */
    
    // Đọc 1 số nguyên chuẩn 32-bit (Int).
    // Cú pháp: readInt(min_value, max_value, variable_name_for_logging)
    int n = inf.readInt(1, 100000, "N");
    
    // BẮT BUỘC: Sau số N nếu cùng dòng phải có dấu cách.
    inf.readSpace();
    
    // Đọc số nguyên lớn 64-bit (Long / Long Long).
    long long m = inf.readLong(1LL, 1000000000000000000LL, "M");
    
    // BẮT BUỘC: Kết thúc một dòng phải gọi hàm này. Nó chặn không cho thí sinh
    // in thừa dấu cách ở cuối dòng (Trailing spaces).
    inf.readEoln();

    /* =========================================================================
       SECTION 2: MẢNG & DÃY SỐ (Xử lý Space chặt chẽ)
       ========================================================================= */
    
    // Giả sử dòng thứ 2 chứa N phần tử
    vector<int> a(n);
    for (int i = 0; i < n; i++) {
        // Đặt tên biến động trong log: a[1], a[2], ... để dễ debug khi lỗi
        a[i] = inf.readInt(-1000, 1000, format("a[%d]", i + 1));
        
        // Nếu chưa phải phần tử cuối, BẮT BUỘC đọc 1 dấu cách.
        // Nếu là phần tử cuối, BẮT BUỘC đọc dấu xuống dòng.
        if (i < n - 1) {
            inf.readSpace();
        } else {
            inf.readEoln();
        }
    }

    /* =========================================================================
       SECTION 3: CHUỖI, KÝ TỰ & REGULAR EXPRESSION (Regex)
       ========================================================================= */
    
    // Đọc 1 chuỗi với Regex: readWord(regex, name)
    // Ví dụ: Đọc chuỗi S gồm toàn chữ cái in thường, độ dài từ 1 đến N.
    // Regex "[a-z]{1, 100000}" đảm bảo cả giới hạn độ dài và tập ký tự.
    string s = inf.readWord(format("[a-z]{1,%d}", n), "S");
    inf.readEoln();

    // Đọc 1 chuỗi Token (chuỗi không chứa dấu cách, tab, newline) độ dài từ 1 đến 10
    string token = inf.readToken("[a-zA-Z0-9]{1,10}", "Token_ID");
    inf.readSpace();

    // Đọc chính xác 1 ký tự cụ thể (Ít dùng hơn readWord)
    char c = inf.readChar();
    
    // Custom check: Đảm bảo ký tự c là 'U', 'D', 'L', hoặc 'R'
    ensuref(c == 'U' || c == 'D' || c == 'L' || c == 'R', 
            "Ky tu phai la U, D, L, hoac R, nhung nhan duoc '%c'", c);
    inf.readEoln();

    /* =========================================================================
       SECTION 4: SỐ THỰC (Đòi hỏi format gắt gao)
       ========================================================================= */
    
    // Đọc số thực. Phải xác định rõ độ dài phần thập phân để tránh Floating-point lỏm.
    // min_value, max_value, variable_name
    double x = inf.readDouble(-100.0, 100.0, "X");
    
    // Nếu muốn cực kỳ khắt khe: Đọc số thực dưới dạng String (để bắt chuẩn format)
    // Ví dụ: readWord("-?[0-9]+\\.[0-9]{3}") ép buộc phải có đúng 3 chữ số sau dấu phẩy.
    inf.readSpace();
    string exact_float = inf.readWord("-?[0-9]+\\.[0-9]{3}", "Exact_Float");
    inf.readEoln();

    /* =========================================================================
       SECTION 5: ĐỒ THỊ & RÀNG BUỘC LOGIC PHỨC TẠP (Sử dụng ensuref)
       ========================================================================= */
    
    // Đọc M cạnh của đồ thị. Kiểm tra không có khuyên (Self-loop) 
    // và không có cạnh song song (Multiple edges).
    set<pair<int, int>> edges;
    for (int i = 0; i < m; i++) {
        int u = inf.readInt(1, n, format("u[%d]", i + 1));
        inf.readSpace();
        int v = inf.readInt(1, n, format("v[%d]", i + 1));
        inf.readEoln();

        // 5.1: Kiểm tra Self-loop
        ensuref(u != v, "Do thi co khuyen tai dinh %d (canh thu %d)", u, i + 1);

        // Chuẩn hóa cạnh vô hướng để check trùng
        if (u > v) swap(u, v);

        // 5.2: Kiểm tra Multiple edges
        ensuref(edges.find({u, v}) == edges.end(), 
                "Do thi co canh song song giua %d va %d (canh thu %d)", u, v, i + 1);
        
        edges.insert({u, v});
    }

    // 5.3 Kiểm tra đồ thị liên thông (Connectivity) - Minh họa logic
    // Thường Validator sẽ cài thêm cấu trúc DSU (Disjoint Set Union) ở ngoài
    // Sau khi duyệt hết M cạnh, dùng ensuref để check:
    // ensuref(dsu.components == 1, "Do thi khong lien thong! So tplt: %d", dsu.components);

    /* =========================================================================
       SECTION 6: BẢO VỆ CUỐI CÙNG (End of File)
       ========================================================================= */
    
    // BẮT BUỘC: Đảm bảo rằng sau dữ liệu cuối cùng, file hoàn toàn trống rỗng.
    // Nếu không có hàm này, test case có rác (hoặc sinh thừa số) ở cuối vẫn lọt qua!
    inf.readEof();

    return 0;
}