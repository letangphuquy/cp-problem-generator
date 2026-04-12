#include <bits/stdc++.h>
using namespace std;

mt19937_64 rng;

// ========== SOLUTION (for generating answers) ==========
// Precompute để mỗi query trả lời trong O(log N)
struct FastSolver {
    int n;
    vector<long long> sorted_A;
    vector<long long> cost;

    FastSolver(const vector<long long>& A) {
        n = A.size();
        sorted_A = A;
        sort(sorted_A.begin(), sorted_A.end());
        
        vector<long long> prefix(n + 1, 0);
        for (int i = 0; i < n; i++) {
            prefix[i + 1] = prefix[i] + sorted_A[i];
        }
        
        // cost[i] = chi phí để nâng i phần tử đầu tiên lên mức sorted_A[i-1]
        cost.assign(n + 1, 0);
        for (int i = 1; i <= n; i++) {
            cost[i] = 1LL * i * sorted_A[i - 1] - prefix[i];
        }
    }

    long long query(long long K) {
        // Tìm số lượng phần tử tối đa (p) có thể san lấp
        int p = upper_bound(cost.begin() + 1, cost.end(), K) - cost.begin() - 1;
        long long rem = K - cost[p];
        return sorted_A[p - 1] + rem / p;
    }
};

// ========== GENERATORS ==========

// random: sinh N, Q ngẫu nhiên trong [1, max_n], A_i trong [0, max_a], K trong [1, max_k]
void generate_random(long long max_n, long long max_a, long long max_k) {
    long long n = uniform_int_distribution<long long>(1, max_n)(rng);
    long long q = uniform_int_distribution<long long>(1, max_n)(rng);
    cout << n << " " << q << "\n";

    vector<long long> A(n);
    for (int i = 0; i < n; i++)
        A[i] = uniform_int_distribution<long long>(0, max_a)(rng);
    for (int i = 0; i < n; i++)
        cout << A[i] << " \n"[i == n - 1];

    FastSolver solver(A);
    for (int j = 0; j < q; j++) {
        long long k = uniform_int_distribution<long long>(1, max_k)(rng);
        cout << k << "\n";
        cerr << solver.query(k) << "\n";
    }
}

// max: N = Q = max_n (stress test kích thước tối đa)
void generate_max(long long max_n, long long max_a, long long max_k) {
    long long n = max_n, q = max_n;
    cout << n << " " << q << "\n";

    vector<long long> A(n);
    for (int i = 0; i < n; i++)
        A[i] = uniform_int_distribution<long long>(0, max_a)(rng);
    for (int i = 0; i < n; i++)
        cout << A[i] << " \n"[i == n - 1];

    FastSolver solver(A);
    for (int j = 0; j < q; j++) {
        long long k = uniform_int_distribution<long long>(1, max_k)(rng);
        cout << k << "\n";
        cerr << solver.query(k) << "\n";
    }
}

// equal: tất cả A_i bằng nhau — test edge case
void generate_equal(long long max_n, long long max_a, long long max_k) {
    long long n = max_n, q = max_n;
    cout << n << " " << q << "\n";

    long long val = uniform_int_distribution<long long>(0, max_a)(rng);
    vector<long long> A(n, val);
    for (int i = 0; i < n; i++)
        cout << A[i] << " \n"[i == n - 1];

    FastSolver solver(A);
    for (int j = 0; j < q; j++) {
        long long k = uniform_int_distribution<long long>(1, max_k)(rng);
        cout << k << "\n";
        cerr << solver.query(k) << "\n";
    }
}

// sorted: mảng A tăng dần — stress test
void generate_sorted(long long max_n, long long max_a, long long max_k) {
    long long n = max_n, q = max_n;
    cout << n << " " << q << "\n";

    vector<long long> A(n);
    for (int i = 0; i < n; i++)
        A[i] = uniform_int_distribution<long long>(0, max_a)(rng);
    sort(A.begin(), A.end());
    for (int i = 0; i < n; i++)
        cout << A[i] << " \n"[i == n - 1];

    FastSolver solver(A);
    for (int j = 0; j < q; j++) {
        long long k = uniform_int_distribution<long long>(1, max_k)(rng);
        cout << k << "\n";
        cerr << solver.query(k) << "\n";
    }
}

// bigk: K rất lớn (gần 10^18) để test overflow
void generate_bigk(long long max_n, long long max_a) {
    long long n = max_n, q = max_n;
    cout << n << " " << q << "\n";

    vector<long long> A(n);
    for (int i = 0; i < n; i++)
        A[i] = uniform_int_distribution<long long>(0, max_a)(rng);
    for (int i = 0; i < n; i++)
        cout << A[i] << " \n"[i == n - 1];

    FastSolver solver(A);
    for (int j = 0; j < q; j++) {
        long long k = uniform_int_distribution<long long>((long long)9e17, (long long)1e18)(rng);
        cout << k << "\n";
        cerr << solver.query(k) << "\n";
    }
}

// min: N = Q = 1, trường hợp nhỏ nhất
void generate_min() {
    cout << "1 1\n";
    vector<long long> A = {0};
    cout << "0\n";
    long long k = 1;
    cout << k << "\n";
    
    FastSolver solver(A);
    cerr << solver.query(k) << "\n";
}

int main(int argc, char* argv[]) {
    if (argc < 3) {
        cerr << "Usage: ./gen <mode> <args...> <seed>" << endl;
        return 1;
    }

    string mode = argv[1];
    int seed = stoi(argv[argc - 1]);
    rng.seed(seed);

    if (mode == "random") {
        long long max_n = stoll(argv[2]);
        long long max_a = stoll(argv[3]);
        long long max_k = stoll(argv[4]);
        generate_random(max_n, max_a, max_k);
    } else if (mode == "max") {
        long long max_n = stoll(argv[2]);
        long long max_a = stoll(argv[3]);
        long long max_k = stoll(argv[4]);
        generate_max(max_n, max_a, max_k);
    } else if (mode == "equal") {
        long long max_n = stoll(argv[2]);
        long long max_a = stoll(argv[3]);
        long long max_k = stoll(argv[4]);
        generate_equal(max_n, max_a, max_k);
    } else if (mode == "sorted") {
        long long max_n = stoll(argv[2]);
        long long max_a = stoll(argv[3]);
        long long max_k = stoll(argv[4]);
        generate_sorted(max_n, max_a, max_k);
    } else if (mode == "bigk") {
        long long max_n = stoll(argv[2]);
        long long max_a = stoll(argv[3]);
        generate_bigk(max_n, max_a);
    } else if (mode == "min") {
        generate_min();
    }

    return 0;
}