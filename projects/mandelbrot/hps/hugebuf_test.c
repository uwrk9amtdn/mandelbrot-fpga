// hugebuf_test: can mandelbrotd use huge pages as the result buffer? (ROADMAP.md, "Result buffer")
//
//   sudo ./hugebuf_test [2|32]     page size in MB (default 32)
//
// Needs huge pages reserved first, e.g. for one 32 MB page:
//   echo 1 | sudo tee /sys/kernel/mm/hugepages/hugepages-32768kB/nr_hugepages
//
// Steps: map 4 MB of huge pages and lock them; find their physical addresses in /proc/self/pagemap;
// clean them out of the cache; let MandelbrotAccel write a 256x256 tile into slot 0 and slot 7
// through f2sdram (not coherent); invalidate the tile's cache lines (DC CIVAC) and read it; compare
// with the same tile written to the reserved memory at 0xBF000000 and read through /dev/mem; time
// the copy with and without the invalidate.

#define _GNU_SOURCE
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#ifndef MAP_HUGE_SHIFT
#define MAP_HUGE_SHIFT 26
#endif

#define REG_BASE 0x20000000u
#define RESERVED 0xBF000000u
#define SLOT_SIZE (512u << 10)
#define BUF_SIZE (8u * SLOT_SIZE)
#define LINE 64

enum { ID = 0x00, CONTROL = 0x10, STATUS = 0x14, QUEUE = 0x1C, X0 = 0x20, Y0 = 0x30, STEP = 0x40,
       SIZE = 0x50, MAX_IT = 0x54, JOB_ID = 0x5C, RESULT_BASE = 0x60, RESULT_SLOTS = 0x68,
       RESULT_SLOT = 0x6C, DONE = 0x70, CAPS = 0x08 };

static volatile uint32_t *regs;

static void die(const char *what) {
    perror(what);
    exit(1);
}
static double now(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1e-9;
}
static uint32_t rd(unsigned off) { return regs[off / 4]; }
static void wr(unsigned off, uint32_t v) { regs[off / 4] = v; }

static void *map_phys(uint64_t addr, size_t len) {
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) die("open /dev/mem");
    void *p = mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, addr);
    if (p == MAP_FAILED) die("mmap /dev/mem");
    close(fd);
    return p;
}

static uint64_t phys_of(void *virt) {
    int fd = open("/proc/self/pagemap", O_RDONLY);
    if (fd < 0) die("open pagemap");
    uint64_t e, page = sysconf(_SC_PAGESIZE);
    if (pread(fd, &e, 8, (uintptr_t)virt / page * 8) != 8) die("read pagemap");
    close(fd);
    if (!(e >> 63)) {
        fprintf(stderr, "page not present\n");
        exit(1);
    }
    uint64_t pfn = e & ((1ull << 55) - 1);
    if (!pfn) {
        fprintf(stderr, "pagemap gives PFN 0: not running as root?\n");
        exit(1);
    }
    return pfn * page + (uintptr_t)virt % page;
}

// Clean and invalidate the data cache lines of [p, p + len), to the point of coherency.
static void civac(void *p, size_t len) {
    for (uintptr_t a = (uintptr_t)p & ~(uintptr_t)(LINE - 1); a < (uintptr_t)p + len; a += LINE)
        __asm__ volatile("dc civac, %0" ::"r"(a) : "memory");
    __asm__ volatile("dsb sy" ::: "memory");
}

// One 256x256 tile over the whole set, into `slot` of the result area at `base`.
static void run_tile(uint32_t base, unsigned slots, unsigned slot, unsigned id) {
    unsigned w = (rd(CAPS) >> 8) & 0xFF, ibits = (rd(CAPS) >> 16) & 0x1F, f = w - ibits;
    uint32_t mask = (1u << w) - 1;
    wr(RESULT_BASE, base);
    wr(RESULT_BASE + 4, 0);
    wr(RESULT_SLOTS, slots);
    wr(X0, (uint32_t)(int32_t)(-2.25 * (1 << f)) & mask);
    wr(Y0, (uint32_t)(int32_t)(1.5 * (1 << f)) & mask);
    wr(STEP, (uint32_t)(3.0 / 256 * (1 << f)) & mask);
    wr(SIZE, (256u << 16) | 256);
    wr(MAX_IT, 256);
    wr(JOB_ID, id);
    wr(RESULT_SLOT, slot);
    wr(CONTROL, 1);
    double t = now();
    uint32_t d;
    while (!((d = rd(DONE)) >> 31))
        if (now() - t > 5) {
            fprintf(stderr, "job %u: no DONE, STATUS %#x\n", id, rd(STATUS));
            exit(1);
        }
    wr(DONE, 0);
    if ((d & 0xFFFF) != id || ((d >> 16) & 3)) {
        fprintf(stderr, "job %u: DONE %#x\n", id, d);
        exit(1);
    }
}

static unsigned compare(const uint64_t *a, const uint64_t *b, size_t n, const char *what) {
    unsigned bad = 0;
    for (size_t i = 0; i < n; i++)
        if (a[i] != b[i] && bad++ < 3)
            printf("  %s: record %zu is %016llx, want %016llx\n", what, i, (unsigned long long)a[i],
                   (unsigned long long)b[i]);
    printf("%s: %u of %zu records differ\n", what, bad, n);
    return bad;
}

int main(int argc, char **argv) {
    unsigned mb = argc > 1 ? atoi(argv[1]) : 32;
    if (mb != 2 && mb != 32) {
        fprintf(stderr, "usage: hugebuf_test [2|32]\n");
        return 2;
    }
    regs = map_phys(REG_BASE, 4096);
    if (rd(ID) != 0x4D414E44) {
        fprintf(stderr, "no accelerator (ID %#x)\n", rd(ID));
        return 1;
    }

    // ---- the buffer
    size_t page = (size_t)mb << 20, len = BUF_SIZE > page ? BUF_SIZE : page;
    int shift = mb == 2 ? 21 : 25;
    uint8_t *buf = mmap(NULL, len, PROT_READ | PROT_WRITE,
                        MAP_PRIVATE | MAP_ANONYMOUS | MAP_HUGETLB | (shift << MAP_HUGE_SHIFT) | MAP_POPULATE, -1, 0);
    if (buf == MAP_FAILED) die("mmap huge pages (reserved any? see the comment at the top)");
    if (mlock(buf, len)) die("mlock");
    uint64_t phys = phys_of(buf);
    int contiguous = 1;
    for (size_t off = 0; off < BUF_SIZE; off += 2u << 20)
        if (phys_of(buf + off) != phys + off) contiguous = 0;
    printf("%u MB pages: buffer at virtual %p, physical %#llx, 4 MB %s\n", mb, (void *)buf,
           (unsigned long long)phys, contiguous ? "contiguous" : "NOT contiguous");
    if (phys >> 32) {
        fprintf(stderr, "above 4 GB, f2sdram can't reach it\n");
        return 1;
    }
    unsigned slots = contiguous ? 8 : 4;

    // ---- fill with a marker and push it out of the cache, so stale data would show
    memset(buf, 0xA5, BUF_SIZE);
    civac(buf, BUF_SIZE);

    // ---- reference: the same tile into the reserved memory, read uncached
    uint64_t *ref = malloc(SLOT_SIZE), *got = malloc(SLOT_SIZE);
    volatile uint64_t *reserved = map_phys(RESERVED, SLOT_SIZE);
    run_tile(RESERVED, 8, 0, 1);
    for (size_t i = 0; i < SLOT_SIZE / 8; i++) ref[i] = reserved[i];

    // ---- into the huge pages
    unsigned last = slots - 1;
    run_tile((uint32_t)phys, slots, 0, 2);
    run_tile((uint32_t)phys, slots, last, 3);

    // without the invalidate first: shows whether stale lines can be read at all
    unsigned stale = 0;
    for (size_t i = 0; i < SLOT_SIZE / 8; i += LINE / 8)
        stale += ((uint64_t *)buf)[i] == 0xA5A5A5A5A5A5A5A5ull;
    printf("before the invalidate: %u of %u lines of slot 0 still show the marker\n", stale, SLOT_SIZE / LINE);

    double t = now();
    civac(buf, SLOT_SIZE);
    double t_inv = now() - t;
    t = now();
    memcpy(got, buf, SLOT_SIZE);
    double t_copy = now() - t;
    unsigned bad = compare(got, ref, SLOT_SIZE / 8, "slot 0 after the invalidate");

    civac(buf + last * SLOT_SIZE, SLOT_SIZE);
    memcpy(got, buf + last * SLOT_SIZE, SLOT_SIZE);
    bad += compare(got, ref, SLOT_SIZE / 8, last == 7 ? "slot 7 (second 2 MB)" : "slot 3");

    // ---- speed of a tile copy out of the cached buffer, 20 rounds
    double t_both = 0, t_warm = 0;
    for (int r = 0; r < 20; r++) {
        t = now();
        civac(buf, SLOT_SIZE);
        memcpy(got, buf, SLOT_SIZE);
        t_both += now() - t;
        t = now();
        memcpy(got, buf, SLOT_SIZE);
        t_warm += now() - t;
    }
    printf("512 KB tile: invalidate %.0f us + first copy %.0f us; invalidate+copy %.0f MB/s, "
           "copy from cache %.0f MB/s\n",
           t_inv * 1e6, t_copy * 1e6, 20 * SLOT_SIZE / t_both / 1e6, 20 * SLOT_SIZE / t_warm / 1e6);
    printf(bad ? "FAILED\n" : "passed\n");
    return bad != 0;
}
