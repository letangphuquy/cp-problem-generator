#include <iostream>

using namespace std;

// Ép kiểu __int128_t để chống tràn số khi nhân 2 số 10^18
long long mul_mod(long long a, long long b, long long m) {
    return (long long)((__int128_t)a * b % m);
}

// Tính (base^exp) % mod O(log(exp))
long long power(long long base, long long exp, long long mod) {
    long long res = 1;
    base %= mod;
    while (exp > 0) {
        if (exp % 2 == 1) res = mul_mod(res, base, mod);
        base = mul_mod(base, base, mod);
        exp /= 2;
    }
    return res;
}

// Thuật toán Miller-Rabin xác suất - O(k * log^3 N)
bool is_prime(long long n) {
    if (n < 2) return false;
    if (n == 2 || n == 3) return true;
    if (n % 2 == 0) return false;

    // Tách n - 1 = d * 2^s
    long long d = n - 1;
    int s = 0;
    while (d % 2 == 0) {
        d /= 2;
        s++;
    }

    // Tập cơ số đủ để kiểm tra chính xác 100% mọi số N <= 2^64
    static const int bases[] = {2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37};
    
    for (int a : bases) {
        if (n <= a) break; // Nếu N nhỏ hơn cơ số thì bỏ qua
        
        long long x = power(a, d, n);
        if (x == 1 || x == n - 1) continue;
        
        bool composite = true;
        for (int r = 1; r < s; r++) {
            x = mul_mod(x, x, n);
            if (x == n - 1) {
                composite = false;
                break;
            }
        }
        if (composite) return false;
    }
    return true;
}

int main() {
    // Tối ưu tốc độ I/O
    ios_base::sync_with_stdio(false);
    cin.tie(NULL);

    long long n;
    if (cin >> n) {
        cout << (is_prime(n) ? "YES" : "NO") << "\n";
    }
    
    return 0;
}