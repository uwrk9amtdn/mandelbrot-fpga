// memtool: physical memory access through /dev/mem, for the phase 1 step 2 bring-up tests.
//
//   memtool r <addr> [count]       read 32-bit words
//   memtool w <addr> <value>       write one 32-bit word
//   memtool fill <addr> <bytes>    write the test pattern (each 32-bit word holds its own address)
//   memtool check <addr> <bytes>   verify the test pattern
//   memtool bench <addr> <bytes>   time copying the region into ordinary memory
//
// The same pattern is written over f2sdram by f2sdram_test.tcl (System Console).
//
// Memory outside the kernel's RAM (bridges, or RAM removed with mem=) is mapped as device memory
// on arm64. Unaligned accesses fault there, so nothing here uses memcpy on the mapping.

#define _FILE_OFFSET_BITS 64
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#ifdef __aarch64__
#include <arm_neon.h>
#endif

static void die(const char *what) {
    perror(what);
    exit(1);
}

static double now(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1e-9;
}

static volatile void *map(uint64_t addr, uint64_t len) {
    uint64_t page = sysconf(_SC_PAGESIZE);
    uint64_t base = addr & ~(page - 1);
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) die("open /dev/mem");
    void *p = mmap(NULL, addr - base + len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, base);
    if (p == MAP_FAILED) die("mmap");
    return (char *)p + (addr - base);
}

static void bench(uint64_t addr, uint64_t len) {
    volatile uint64_t *src = map(addr, len);
    uint64_t *dst = malloc(len);
    if (!dst) die("malloc");
    memset(dst, 0, len); // fault the pages in before timing

    double t = now();
    for (uint64_t i = 0; i < len / 8; i++) dst[i] = src[i];
    t = now() - t;
    printf("64-bit loads : %.1f MB/s\n", len / t / 1e6);

#ifdef __aarch64__
    const uint8_t *s = (const uint8_t *)src;
    uint8_t *d = (uint8_t *)dst;
    t = now();
    for (uint64_t i = 0; i + 64 <= len; i += 64) {
        uint8x16_t a = vld1q_u8(s + i), b = vld1q_u8(s + i + 16);
        uint8x16_t c = vld1q_u8(s + i + 32), e = vld1q_u8(s + i + 48);
        vst1q_u8(d + i, a);
        vst1q_u8(d + i + 16, b);
        vst1q_u8(d + i + 32, c);
        vst1q_u8(d + i + 48, e);
    }
    t = now() - t;
    printf("128-bit loads: %.1f MB/s\n", len / t / 1e6);
#endif
}

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "usage: memtool r|w|fill|check|bench <addr> [count|value|bytes]\n");
        return 2;
    }
    const char *cmd = argv[1];
    uint64_t addr = strtoull(argv[2], NULL, 0);
    uint64_t arg = argc > 3 ? strtoull(argv[3], NULL, 0) : 1;
    if (addr & 3) {
        fprintf(stderr, "address must be a multiple of 4\n");
        return 2;
    }

    if (!strcmp(cmd, "r")) {
        volatile uint32_t *p = map(addr, arg * 4);
        for (uint64_t i = 0; i < arg; i++)
            printf("%#010llx: %08x\n", (unsigned long long)(addr + 4 * i), p[i]);
    } else if (!strcmp(cmd, "w") && argc > 3) {
        volatile uint32_t *p = map(addr, 4);
        p[0] = (uint32_t)arg;
    } else if (!strcmp(cmd, "fill")) {
        volatile uint32_t *p = map(addr, arg);
        for (uint64_t i = 0; i < arg / 4; i++) p[i] = (uint32_t)(addr + 4 * i);
    } else if (!strcmp(cmd, "check")) {
        volatile uint32_t *p = map(addr, arg);
        uint64_t bad = 0;
        for (uint64_t i = 0; i < arg / 4; i++) {
            uint32_t got = p[i], want = (uint32_t)(addr + 4 * i);
            if (got != want && bad++ < 8)
                printf("%#010llx: got %08x, want %08x\n", (unsigned long long)(addr + 4 * i), got, want);
        }
        printf("%llu of %llu words wrong\n", (unsigned long long)bad, (unsigned long long)(arg / 4));
        return bad != 0;
    } else if (!strcmp(cmd, "bench")) {
        bench(addr, arg);
    } else {
        fprintf(stderr, "unknown command\n");
        return 2;
    }
    return 0;
}
