#include "testlib.h"
#include <iostream>

using namespace std;

int main(int argc, char* argv[]) {
    // Khởi tạo testlib cho Validator
    registerValidation(argc, argv);
    
    // Đọc số nguyên N, giới hạn từ 1 đến 10^18. 
    // Chuỗi "N" ở cuối dùng để in ra log nếu bị lỗi.
    long long n = inf.readLong(1LL, 1000000000000000000LL, "N");
    
    // Đảm bảo ngay sau N là ký tự xuống dòng (tránh thừa dấu cách)
    inf.readEoln();
    
    // Đảm bảo đã kết thúc file (tránh trường hợp gen nhầm ra 2 số)
    inf.readEof();
    
    return 0;
}