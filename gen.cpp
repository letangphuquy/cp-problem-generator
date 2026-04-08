#include <bits/stdc++.h>
using namespace std;

mt19937_64 rng;

// ===== HÀM BỔ TRỢ ĐỂ SINH SỐ (Vẫn cần Miller-Rabin để filter số) =====
long long mul_mod(long long a, long long b, long long m) {
    return (long long)((__int128_t)a * b % m);
}

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

bool is_prime(long long n) {
    if (n < 2) return false;
    if (n == 2 || n == 3) return true;
    if (n % 2 == 0) return false;

    long long d = n - 1;
    int s = 0;
    while (d % 2 == 0) {
        d /= 2;
        s++;
    }

    static const int bases[] = {2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37};
    for (int a : bases) {
        if (n <= a) break;
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

// ===== CÁC CHẾ ĐỘ SINH TEST (CHỈ IN RA INPUT) =====

void gen_random(long long max_n) {
    long long n = 1 + rng() % max_n;
    cout << n << "\n";
}

void gen_prime(long long max_n) {
    long long n;
    do { n = 2 + rng() % (max_n - 1); } while (!is_prime(n));
    cout << n << "\n";
}

void gen_composite(long long max_n) {
    long long n;
    do { n = 4 + rng() % (max_n - 3); } while (is_prime(n));
    cout << n << "\n";
}

void gen_hard_composite(long long max_n) {
    long long limit = sqrt(max_n);
    long long p1, p2;
    do { p1 = 2 + rng() % limit; } while (!is_prime(p1));
    do { p2 = 2 + rng() % limit; } while (!is_prime(p2));
    
    long long n = p1 * p2;
    if (n > max_n || n < 2) gen_composite(max_n);
    else cout << n << "\n";
}

void gen_exact(long long val) {
    cout << val << "\n";
}

// ===== MAIN =====
int main(int argc, char* argv[]) {
    ios_base::sync_with_stdio(false); cin.tie(NULL);

    // XỬ LÝ LỖI INLINE COMMENT: Bỏ qua mọi tham số từ dấu '#' trở đi
    int valid_argc = argc;
    for (int i = 1; i < argc; i++) {
        string arg = argv[i];
        if (arg.length() > 0 && arg[0] == '#') {
            valid_argc = i;
            break;
        }
    }

    if (valid_argc < 3) {
        cerr << "Usage: ./gen <mode> <args...> <seed>\n";
        return 1;
    }

    string mode = argv[1];
    
    // Bây giờ seed luôn là tham số hợp lệ cuối cùng trước comment
    long long seed = stoll(argv[valid_argc - 1]);
    rng.seed(seed);

    if (mode == "exact") gen_exact(stoll(argv[2]));
    else if (mode == "random") gen_random(stoll(argv[2]));
    else if (mode == "prime") gen_prime(stoll(argv[2]));
    else if (mode == "composite") gen_composite(stoll(argv[2]));
    else if (mode == "hard_composite") gen_hard_composite(stoll(argv[2]));

    return 0;
}