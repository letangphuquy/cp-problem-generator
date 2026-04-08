#include <iostream>
using namespace std;

// Thuật toán O(sqrt(N)) cơ bản, không tối ưu bước nhảy
bool is_prime(long long n) {
    if (n < 2) return false;
    for (long long i = 2; i * i <= n; i++) {
        if (n % i == 0) return false;
    }
    return true;
}

int main() {
    // Tối ưu I/O
    ios_base::sync_with_stdio(false);
    cin.tie(NULL);

    long long n;
    if (cin >> n) {
        cout << (is_prime(n) ? "YES" : "NO") << "\n";
    }
    
    return 0;
}