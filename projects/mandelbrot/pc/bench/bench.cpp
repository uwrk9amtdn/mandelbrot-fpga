// CPU benchmark for the FPGA vs CPU comparison (ROADMAP.md, phase 2 step 6).
//
//   make && ./bench [threads]
//
// The escape-time loop on every CPU thread (OpenMP), on the same 256x256 tiles as
// hps/accel_test.py bench, in three number formats:
//
//   double     8 pixels at a time (GCC vector extensions: AVX-512 or AVX2), bailout |z|^2 >= 4
//   fixed64    W = 64, I = 10 (F = 54), __int128 squares, bailout 256: the wide cores' format
//   fixed128   W = 128, I = 10 (F = 118), squares from 64-bit limbs, bailout 256
//
// The fixed-point loops do what the wide cores do (three squares: x^2, y^2, (x+y)^2) but with exact
// squares truncated once; the hardware leaves out partial products worth under a quarter ulp, which
// changes no count in practice (pc/tools/precision_study.py). The count of a pixel is the smallest
// n >= 1 with |z_n|^2 >= R^2, or max_it; the iterations of a tile are the sum of the counts, as the
// FPGA reports them.

#include <omp.h>

#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <vector>

using u64 = uint64_t;
using i128 = __int128;
using u128 = unsigned __int128;

constexpr int TILE = 256;

struct Tile {
    double x0, y0, step;  // top-left pixel and pixel step
    unsigned max_it;
};

// ------------------------------------------------------------------------------------- double

constexpr int LANES = 8;
typedef double vd __attribute__((vector_size(8 * LANES)));
typedef long long vl __attribute__((vector_size(8 * LANES)));

// 8 pixels of a row; returns the sum of their counts.
static u64 lanes_double(double cx0, double step, double cy, unsigned max_it) {
    vd cr, ci;
    for (int k = 0; k < LANES; k++) {
        cr[k] = cx0 + k * step;
        ci[k] = cy;
    }
    vd zr = {}, zi = {}, zr2 = {}, zi2 = {};
    vl count = {}, active = {};
    active -= 1;  // all lanes on
    for (unsigned n = 1; n <= max_it; n++) {
        zi = 2.0 * zr * zi + ci;
        zr = zr2 - zi2 + cr;
        zr2 = zr * zr;
        zi2 = zi * zi;
        vl esc = (zr2 + zi2 >= 4.0) & active;
        count |= esc & (long long)n;
        active &= ~esc;
        bool any = false;
        for (int k = 0; k < LANES; k++) any |= active[k] != 0;
        if (!any) break;
    }
    u64 sum = 0;
    for (int k = 0; k < LANES; k++) sum += active[k] ? max_it : (u64)count[k];
    return sum;
}

static u64 tile_double(const Tile &t) {
    u64 sum = 0;
    for (int j = 0; j < TILE; j++)
        for (int i = 0; i < TILE; i += LANES) sum += lanes_double(t.x0 + i * t.step, t.step, t.y0 - j * t.step, t.max_it);
    return sum;
}

// ------------------------------------------------------------------------------------- fixed64

constexpr int F64 = 54;

static inline i128 sq64(u64 m) { return (i128)(((u128)m * m) >> F64); }

static u64 pixel_fixed64(int64_t cx, int64_t cy, unsigned max_it) {
    const i128 bail = (i128)256 << F64;
    int64_t x = 0, y = 0;
    for (unsigned n = 1; n <= max_it; n++) {
        i128 x2 = sq64(x < 0 ? -(u64)x : x), y2 = sq64(y < 0 ? -(u64)y : y);
        i128 s = (i128)x + y;
        i128 s2 = sq64(s < 0 ? (u64)(-s) : (u64)s);
        x = (int64_t)(u64)(x2 - y2 + cx);  // wraps to 64 bits
        y = (int64_t)(u64)(s2 - x2 - y2 + cy);
        i128 nx2 = sq64(x < 0 ? -(u64)x : x), ny2 = sq64(y < 0 ? -(u64)y : y);
        if (nx2 + ny2 >= bail) return n;
    }
    return max_it;
}

static u64 tile_fixed64(const Tile &t) {
    const double one = std::ldexp(1.0, F64);
    int64_t x0 = std::llround(t.x0 * one), y0 = std::llround(t.y0 * one), st = std::llround(t.step * one);
    u64 sum = 0;
    for (int j = 0; j < TILE; j++)
        for (int i = 0; i < TILE; i++) sum += pixel_fixed64(x0 + i * st, y0 - j * st, t.max_it);
    return sum;
}

// ------------------------------------------------------------------------------------- fixed128

constexpr int F128 = 118;

// floor(m^2 / 2^118) for m < 2^128, from 64-bit limbs; the result must fit 128 bits (m < 2^123).
static inline u128 sq128(u128 m) {
    u64 h = (u64)(m >> 64), l = (u64)m;
    u128 l2 = (u128)l * l, hl = (u128)h * l, h2 = (u128)h * h;
    // total = h2 * 2^128 + hl * 2^65 + l2, as (hi, lo)
    u128 lo = l2, hi = h2;
    u128 add = hl << 65;
    lo += add;
    hi += (hl >> 63) + (lo < add);
    return (hi << (128 - F128)) | (lo >> F128);
}

static inline u128 mag128(i128 v) { return v < 0 ? (u128)(-v) : (u128)v; }

static u64 pixel_fixed128(i128 cx, i128 cy, unsigned max_it) {
    const u128 sixteen = (u128)16 << F128, bail = (u128)256 << F128;
    i128 x = 0, y = 0;
    for (unsigned n = 1; n <= max_it; n++) {
        u128 ax = mag128(x), ay = mag128(y);
        // |z| < 16 here (else it escaped), so the squares fit 128 bits
        u128 x2 = sq128(ax), y2 = sq128(ay), s2 = sq128(mag128(x + y));
        x = (i128)(x2 - y2 + (u128)cx);
        y = (i128)(s2 - x2 - y2 + (u128)cy);
        ax = mag128(x);
        ay = mag128(y);
        if (ax >= sixteen || ay >= sixteen || sq128(ax) + sq128(ay) >= bail) return n;
    }
    return max_it;
}

static u64 tile_fixed128(const Tile &t) {
    // the coordinates are coarse enough here to go through 2^64 scaling in long double
    auto fix = [](double v) { return (i128)std::llround(v * std::ldexp(1.0, 60)) << (F128 - 60); };
    i128 x0 = fix(t.x0), y0 = fix(t.y0), st = fix(t.step);
    u64 sum = 0;
    for (int j = 0; j < TILE; j++)
        for (int i = 0; i < TILE; i++) sum += pixel_fixed128(x0 + i * st, y0 - j * st, t.max_it);
    return sum;
}

// ------------------------------------------------------------------------------------- driver

struct Result {
    double seconds;
    u64 iterations;
};

// The load repeated until it has run for at least a second; the result is per round.
template <class F>
static Result run(const std::vector<Tile> &tiles, F tile_fn) {
    auto t0 = std::chrono::steady_clock::now();
    u64 total = 0;
    int rounds = 0;
    double s = 0;
    do {
#pragma omp parallel for schedule(dynamic, 1) reduction(+ : total)
        for (size_t k = 0; k < tiles.size(); k++) total += tile_fn(tiles[k]);
        rounds++;
        s = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
    } while (s < 1.0);
    return {s / rounds, total / rounds};
}

int main(int argc, char **argv) {
    if (argc > 1) omp_set_num_threads(std::atoi(argv[1]));
    std::printf("%d threads\n", omp_get_max_threads());

    struct Load {
        const char *name;
        std::vector<Tile> tiles;
    };
    std::vector<Load> loads;
    for (unsigned max_it : {256u, 4096u}) {  // the whole set, as in accel_test.py bench
        Load l{max_it == 256 ? "whole set, max_it 256" : "whole set, max_it 4096", {}};
        double step = 3.0 / 1024;
        for (int r = 0; r < 4; r++)
            for (int c = 0; c < 4; c++) l.tiles.push_back({-2.25 + c * 256 * step, 1.5 - r * 256 * step, step, max_it});
        loads.push_back(l);
    }
    {
        Load l{"seahorse valley, max_it 2000", {}};
        double step = 1e-6;
        for (int k = 0; k < 4; k++) l.tiles.push_back({-0.7437 + k * 256 * step, 0.1319, step, 2000});
        loads.push_back(l);
    }

    std::printf("%-30s %-9s %9s %12s %10s\n", "load", "format", "seconds", "G it/s", "M px/s");
    for (auto &l : loads) {
        double pixels = (double)l.tiles.size() * TILE * TILE;
        auto show = [&](const char *fmt, Result r) {
            std::printf("%-30s %-9s %9.3f %12.3f %10.1f   (%llu iterations)\n", l.name, fmt, r.seconds,
                        r.iterations / r.seconds / 1e9, pixels / r.seconds / 1e6, (unsigned long long)r.iterations);
        };
        show("double", run(l.tiles, tile_double));
        show("fixed64", run(l.tiles, tile_fixed64));
        show("fixed128", run(l.tiles, tile_fixed128));
    }
}
