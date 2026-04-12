#ifndef SOLUTION_H
#define SOLUTION_H

#include <iostream>
#include <string>

namespace solution {

inline long long mul_mod(long long a, long long b, long long m) {
    return static_cast<long long>((__int128_t)a * b % m);
}

inline long long power(long long base, long long exp, long long mod) {
    long long res = 1;
    base %= mod;
    while (exp > 0) {
        if (exp % 2 == 1) {
            res = mul_mod(res, base, mod);
        }
        base = mul_mod(base, base, mod);
        exp /= 2;
    }
    return res;
}

inline bool is_prime(long long n) {
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

inline long long read_input(std::istream& in = std::cin) {
    long long n = 0;
    in >> n;
    return n;
}

inline std::string solve(long long n) {
    return is_prime(n) ? "YES" : "NO";
}

inline void print_output(const std::string& ans, std::ostream& out = std::cout) {
    out << ans << '\n';
}

inline void solve(std::istream& in = std::cin, std::ostream& out = std::cout) {
    const long long n = read_input(in);
    print_output(solve(n), out);
}

}  // namespace solution

#endif  // SOLUTION_H
