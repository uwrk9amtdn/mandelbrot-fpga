// mandelbrotd: serves tiles computed by MandelbrotAccel to the PC application over TCP
// (ROADMAP.md, phase 1 step 5; protocol in protocol.h and PC_APP_PLAN.md).
//
//   sudo ./mandelbrotd [-p port] [-c cpu] [-v]
//
// A thin bridge: each TILE_REQ becomes one accelerator job, with its coordinates copied unchanged
// into the job registers. One client at a time.
//
// Result buffer: one 32 MB huge page (cached RAM), found in /proc/self/pagemap. Its first 4 MB are
// the 8 result slots, one per request in flight. The FPGA writes over f2sdram, which is not
// cache-coherent, so a slot's lines are cleaned and invalidated (DC CIVAC) before it is read.
// Registers are mapped through /dev/mem. Finished jobs are found by polling DONE every 100 us while
// jobs are in flight (the interrupt, through UIO, comes later).

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <poll.h>
#include <sched.h>
#include <signal.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

#include "protocol.h"

#ifndef MAP_HUGE_SHIFT
#define MAP_HUGE_SHIFT 26
#endif

#define REG_BASE 0x20000000u
#define SLOTS 8
#define SLOT_SIZE (512u << 10)
#define MAX_PIXELS (256 * 256)
#define HUGE_PAGE (32u << 20)
#define HUGE_SYSFS "/sys/kernel/mm/hugepages/hugepages-32768kB/nr_hugepages"
#define LINE 64

// Accelerator registers (spinal/.../MandelbrotAccel.scala, AccelRegs).
enum {
    R_ID = 0x000, R_CAPS = 0x008, R_ARITH_ID = 0x00C, R_CONTROL = 0x010, R_STATUS = 0x014,
    R_ABORT = 0x018, R_QUEUE = 0x01C, R_X0 = 0x020, R_Y0 = 0x030, R_STEP = 0x040, R_SIZE = 0x050,
    R_MAX_IT = 0x054, R_FLAGS = 0x058, R_JOB_ID = 0x05C, R_RESULT_BASE = 0x060,
    R_RESULT_SLOTS = 0x068, R_RESULT_SLOT = 0x06C, R_DONE = 0x070, R_DONE_ITERATIONS = 0x074,
    R_TOTAL_ITERATIONS = 0x080, R_TOTAL_CYCLES = 0x088, R_TOTAL_PIXELS = 0x090,
    R_BOARD_TEMP = 0x098, R_FAN_RPM = 0x09C, R_R2 = 0x0A0,
};
#define CTRL_PUSH 1u
#define CTRL_ABORT_ALL 2u
#define ACCEL_ID 0x4D414E44u

static int verbose;
static volatile uint32_t *regs;
static uint8_t *buf; // the huge page
static uint64_t buf_phys;
static struct msg_info info;
static unsigned n_words; // u32 words per coordinate

struct slot {
    int used;
    uint32_t request_id;
    uint16_t job_id;
    uint16_t width, height;
};
static struct slot slots[SLOTS];
static unsigned generation;
static unsigned in_flight;

// One message out: header, TILE header, two planes.
static uint8_t out[sizeof(struct msg_header) + sizeof(struct msg_tile) + 8 * MAX_PIXELS];

static void logf_(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    fputc('\n', stderr);
}
#define LOG(...) logf_(__VA_ARGS__)
#define DEBUG(...) do { if (verbose) logf_(__VA_ARGS__); } while (0)

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
static uint64_t rd64(unsigned off) { return rd(off) | (uint64_t)rd(off + 4) << 32; }

// ------------------------------------------------------------------------------------- memory

static void civac(void *p, size_t len) {
    for (uintptr_t a = (uintptr_t)p & ~(uintptr_t)(LINE - 1); a < (uintptr_t)p + len; a += LINE)
        __asm__ volatile("dc civac, %0" ::"r"(a) : "memory");
    __asm__ volatile("dsb sy" ::: "memory");
}

static uint64_t phys_of(void *virt) {
    int fd = open("/proc/self/pagemap", O_RDONLY);
    if (fd < 0) die("open /proc/self/pagemap");
    uint64_t e, page = sysconf(_SC_PAGESIZE);
    if (pread(fd, &e, 8, (uintptr_t)virt / page * 8) != 8) die("read pagemap");
    close(fd);
    uint64_t pfn = e & ((1ull << 55) - 1);
    if (!(e >> 63) || !pfn) {
        LOG("no physical address for the buffer (not running as root?)");
        exit(1);
    }
    return pfn * page + (uintptr_t)virt % page;
}

static void *map_huge(void) {
    return mmap(NULL, HUGE_PAGE, PROT_READ | PROT_WRITE,
                MAP_PRIVATE | MAP_ANONYMOUS | MAP_HUGETLB | (25 << MAP_HUGE_SHIFT) | MAP_POPULATE, -1, 0);
}

static void setup_memory(void) {
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) die("open /dev/mem");
    regs = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, fd, REG_BASE);
    if (regs == MAP_FAILED) die("mmap registers");
    close(fd);
    if (rd(R_ID) != ACCEL_ID) {
        LOG("no accelerator at %#x (ID reads %#x): is the FPGA programmed?", REG_BASE, rd(R_ID));
        exit(1);
    }

    void *p = map_huge();
    if (p == MAP_FAILED) { // reserve one more 32 MB page and try again
        FILE *f = fopen(HUGE_SYSFS, "r+");
        unsigned n = 0;
        if (!f || fscanf(f, "%u", &n) != 1) die(HUGE_SYSFS);
        rewind(f);
        fprintf(f, "%u\n", n + 1);
        fclose(f);
        p = map_huge();
        if (p == MAP_FAILED) die("no 32 MB huge page (memory too fragmented? reserve one at boot)");
    }
    buf = p;
    if (mlock(buf, HUGE_PAGE)) die("mlock");
    buf_phys = phys_of(buf);
    if (buf_phys >> 32) {
        LOG("buffer at %#llx, above 4 GB", (unsigned long long)buf_phys);
        exit(1);
    }
    // Nothing of it may be dirty in the cache: a clean would overwrite what the FPGA wrote.
    memset(buf, 0, SLOTS * SLOT_SIZE);
    civac(buf, SLOTS * SLOT_SIZE);
}

// ------------------------------------------------------------------------------------- accelerator

// Abort everything and drop what the DONE FIFO holds (left over from a client or a test).
static void reset_jobs(void) {
    wr(R_CONTROL, CTRL_ABORT_ALL);
    double t = now();
    while (rd(R_STATUS) & 1)
        if (now() - t > 2) {
            LOG("the accelerator stays busy after an abort");
            exit(1);
        }
    while (rd(R_DONE) >> 31) wr(R_DONE, 0);
    memset(slots, 0, sizeof slots);
    in_flight = 0;
}

static void setup_accel(void) {
    reset_jobs();
    wr(R_RESULT_BASE, (uint32_t)buf_phys);
    wr(R_RESULT_BASE + 4, 0);
    wr(R_RESULT_SLOTS, SLOTS);
    if (rd(R_RESULT_BASE) != (uint32_t)buf_phys) {
        LOG("RESULT_BASE did not take");
        exit(1);
    }

    uint32_t caps = rd(R_CAPS);
    unsigned w = (caps >> 8) & 0xFF, ibits = (caps >> 16) & 0x1F;
    if (w > 128) {
        LOG("W = %u: at most 128 bits (4 words per coordinate)", w);
        exit(1);
    }
    n_words = (w + 31) / 32;
    uint32_t r2 = rd(R_R2);

    rd(R_TOTAL_ITERATIONS); // latches the totals
    uint64_t c0 = rd64(R_TOTAL_CYCLES);
    double t0 = now();
    usleep(100000);
    rd(R_TOTAL_ITERATIONS);
    uint64_t c1 = rd64(R_TOTAL_CYCLES);
    double t1 = now();

    info = (struct msg_info){
        .version = PROTO_VERSION, .w = w, .f = w - ibits, .n_cores = caps & 0xFF,
        .clock_khz = (uint32_t)((c1 - c0) / (t1 - t0) / 1000 + 0.5),
        .max_tile_width = 256, .max_tile_height = 256, .max_in_flight = SLOTS,
        .features = FEATURE_BOARD_STATUS, .max_max_it = MAX_MAX_IT,
        .bailout_r2 = r2 ? r2 : 4, // bitstreams before the R2 register have R^2 = 4
        .arith_id = rd(R_ARITH_ID),
    };
    LOG("accelerator: %u cores at %.1f MHz, W = %u, F = %u, arithmetic id %#010x; buffer at %#llx",
        info.n_cores, info.clock_khz / 1000.0, info.w, info.f, info.arith_id,
        (unsigned long long)buf_phys);
}

// ------------------------------------------------------------------------------------- sending

static int send_all(int fd, const void *p, size_t n) {
    const uint8_t *b = p;
    while (n) {
        ssize_t k = send(fd, b, n, MSG_NOSIGNAL);
        if (k < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        b += k;
        n -= k;
    }
    return 0;
}

static size_t put_header(uint8_t *p, uint16_t type, uint32_t length) {
    struct msg_header h = {.type = type, .length = length};
    memcpy(h.magic, PROTO_MAGIC, 4);
    memcpy(p, &h, sizeof h);
    return sizeof h;
}

static int send_msg(int fd, uint16_t type, const void *payload, uint32_t length) {
    uint8_t m[sizeof(struct msg_header) + 256];
    if (length > sizeof m - sizeof(struct msg_header)) return -1;
    size_t n = put_header(m, type, length);
    memcpy(m + n, payload, length);
    return send_all(fd, m, n + length);
}

static int send_error(int fd, uint32_t request_id, uint16_t code, const char *text) {
    struct msg_error e = {.request_id = request_id, .code = code, .text_length = strlen(text)};
    uint8_t p[sizeof e + 200];
    if (e.text_length > 200) e.text_length = 200;
    memcpy(p, &e, sizeof e);
    memcpy(p + sizeof e, text, e.text_length);
    DEBUG("request %u: error %u, %s", request_id, code, text);
    return send_msg(fd, MSG_ERROR, p, sizeof e + e.text_length);
}

// A finished job: its tile, or an aborted TILE without data.
static int send_tile(int fd, unsigned s, int complete, uint64_t iterations) {
    struct slot *sl = &slots[s];
    unsigned n = complete ? sl->width * sl->height : 0;
    struct msg_tile t = {
        .request_id = sl->request_id, .width = complete ? sl->width : 0,
        .height = complete ? sl->height : 0, .encoding = ENCODING_RAW,
        .status = complete ? STATUS_COMPLETE : STATUS_ABORTED, .raw_size = 8 * n,
        .iterations = iterations,
    };
    t.total_iterations = rd64(R_TOTAL_ITERATIONS); // latches the totals
    t.total_cycles = rd64(R_TOTAL_CYCLES);

    size_t h = put_header(out, MSG_TILE, sizeof t + 8 * n);
    memcpy(out + h, &t, sizeof t);
    if (n) {
        uint64_t *rec = (uint64_t *)(buf + s * SLOT_SIZE);
        civac(rec, 8 * n);
        uint32_t *counts = (uint32_t *)(out + h + sizeof t), *mags = counts + n;
        for (unsigned i = 0; i < n; i++) {
            uint64_t r = rec[i];
            counts[i] = (uint32_t)r;
            mags[i] = (uint32_t)(r >> 32);
        }
    }
    return send_all(fd, out, h + sizeof t + 8 * n);
}

// ------------------------------------------------------------------------------------- requests

typedef __int128 i128;

// A coordinate: n_words u32 words, low first, sign-extended from the top word.
static i128 coord(const uint8_t *p) {
    unsigned __int128 u = 0;
    for (unsigned k = 0; k < n_words; k++) {
        uint32_t word;
        memcpy(&word, p + 4 * k, 4);
        u |= (unsigned __int128)word << (32 * k);
    }
    unsigned bits = 32 * n_words;
    if (bits < 128 && (u >> (bits - 1)) & 1) u |= ~(unsigned __int128)0 << bits;
    return (i128)u;
}

static int fits(i128 v) {
    if (info.w >= 128) return 1;
    i128 lim = (i128)1 << (info.w - 1);
    return v >= -lim && v < lim;
}

// a + k * step fits the W-bit format, without overflowing 128 bits on the way.
static int fits_at(i128 a, i128 k, i128 step) {
    i128 prod, sum;
    return !__builtin_mul_overflow(k, step, &prod) && !__builtin_add_overflow(a, prod, &sum) && fits(sum);
}

static int on_tile_req(int fd, const uint8_t *p, uint32_t len) {
    struct msg_tile_req q;
    size_t cw = 4 * n_words;
    if (len != sizeof q + 3 * cw) return send_error(fd, 0, ERR_MESSAGE, "TILE_REQ of the wrong length");
    memcpy(&q, p, sizeof q);
    i128 x0 = coord(p + sizeof q), y0 = coord(p + sizeof q + cw), step = coord(p + sizeof q + 2 * cw);
    uint32_t id = q.request_id;

    if (id == 0) return send_error(fd, id, ERR_REQUEST_ID, "request id 0");
    if (q.width < 1 || q.width > 256 || q.height < 1 || q.height > 256)
        return send_error(fd, id, ERR_TILE_SIZE, "tile size out of range");
    if (q.max_it < 1 || q.max_it > MAX_MAX_IT) return send_error(fd, id, ERR_MAX_IT, "max_it out of range");
    if (q.flags & ~(info.features & REQUEST_FLAGS))
        return send_error(fd, id, ERR_FLAGS, "flags not supported");
    if (!(step > 0 && fits(x0) && fits(y0) && fits(step) && fits_at(x0, q.width - 1, step) &&
          fits_at(y0, -(i128)(q.height - 1), step)))
        return send_error(fd, id, ERR_COORDINATE, "the tile doesn't fit the W-bit format");
    for (unsigned s = 0; s < SLOTS; s++)
        if (slots[s].used && slots[s].request_id == id)
            return send_error(fd, id, ERR_REQUEST_ID, "request id already in flight");
    if (in_flight >= SLOTS) return send_error(fd, id, ERR_BUSY, "more requests in flight than INFO allows");
    if (!(rd(R_QUEUE) & 0xFFFF)) return send_error(fd, id, ERR_BUSY, "the accelerator's queue is full");

    unsigned s = 0;
    while (slots[s].used) s++;
    generation = (generation + 1) & 0x1FFF;
    struct slot *sl = &slots[s];
    *sl = (struct slot){.used = 1, .request_id = id, .job_id = (uint16_t)(generation << 3 | s),
                        .width = q.width, .height = q.height};
    in_flight++;

    // The coordinates go in unchanged, the words of each low first.
    for (unsigned k = 0; k < n_words; k++) {
        uint32_t wx, wy, ws;
        memcpy(&wx, p + sizeof q + 4 * k, 4);
        memcpy(&wy, p + sizeof q + cw + 4 * k, 4);
        memcpy(&ws, p + sizeof q + 2 * cw + 4 * k, 4);
        wr(R_X0 + 4 * k, wx);
        wr(R_Y0 + 4 * k, wy);
        wr(R_STEP + 4 * k, ws);
    }
    wr(R_SIZE, (uint32_t)q.height << 16 | q.width);
    wr(R_MAX_IT, q.max_it);
    wr(R_FLAGS, 0);
    wr(R_JOB_ID, sl->job_id);
    wr(R_RESULT_SLOT, s);
    wr(R_CONTROL, CTRL_PUSH);
    DEBUG("request %u: %ux%u max_it %u -> job %#06x, slot %u", id, q.width, q.height, q.max_it, sl->job_id, s);
    return 0;
}

static int on_cancel(int fd, const uint8_t *p, uint32_t len) {
    struct msg_cancel c;
    if (len < sizeof c) return send_error(fd, 0, ERR_MESSAGE, "short CANCEL");
    memcpy(&c, p, sizeof c);
    if (len != sizeof c + 4u * c.count) return send_error(fd, 0, ERR_MESSAGE, "CANCEL length doesn't match its count");
    if (c.count == 0) {
        if (in_flight) wr(R_CONTROL, CTRL_ABORT_ALL);
        DEBUG("cancel all");
        return 0;
    }
    for (unsigned i = 0; i < c.count; i++) {
        uint32_t id;
        memcpy(&id, p + sizeof c + 4 * i, 4);
        for (unsigned s = 0; s < SLOTS; s++)
            if (slots[s].used && slots[s].request_id == id) {
                wr(R_ABORT, slots[s].job_id); // answered by its DONE, as aborted
                DEBUG("cancel request %u (job %#06x)", id, slots[s].job_id);
            }
    }
    return 0;
}

static int on_status_req(int fd) {
    uint32_t t = rd(R_BOARD_TEMP), f = rd(R_FAN_RPM);
    struct msg_status st = {.fpga_temp = (int16_t)(t & 0xFFFF), .board_temp = (int16_t)(t >> 16),
                            .fan_rpm = f & 0xFFFF, .flags = f >> 31};
    return send_msg(fd, MSG_STATUS, &st, sizeof st);
}

// Every finished job in the DONE FIFO.
static int poll_done(int fd) {
    uint32_t d;
    while ((d = rd(R_DONE)) >> 31) {
        uint64_t iterations = rd64(R_DONE_ITERATIONS);
        wr(R_DONE, 0);
        unsigned job = d & 0xFFFF, status = (d >> 16) & 3, s = job % SLOTS;
        if (!slots[s].used || slots[s].job_id != job) {
            LOG("DONE for unknown job %#06x (status %u)", job, status);
            continue;
        }
        int r;
        if (status == 2)
            r = send_error(fd, slots[s].request_id, ERR_MESSAGE, "the accelerator refused the job");
        else
            r = send_tile(fd, s, status == 0, iterations);
        DEBUG("request %u: %s", slots[s].request_id, status == 0 ? "done" : status == 1 ? "aborted" : "error");
        slots[s].used = 0;
        in_flight--;
        if (r) return -1;
    }
    return 0;
}

// ------------------------------------------------------------------------------------- connection

static int recv_all(int fd, void *p, size_t n) {
    uint8_t *b = p;
    while (n) {
        ssize_t k = recv(fd, b, n, 0);
        if (k == 0) return -1;
        if (k < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        b += k;
        n -= k;
    }
    return 0;
}

// Reads one message into `payload` (at most `cap` bytes). Returns its type, or -1.
static int read_msg(int fd, uint8_t *payload, size_t cap, uint32_t *len) {
    struct msg_header h;
    if (recv_all(fd, &h, sizeof h)) return -1;
    if (memcmp(h.magic, PROTO_MAGIC, 4) || h.length > cap) {
        send_error(fd, 0, ERR_MESSAGE, memcmp(h.magic, PROTO_MAGIC, 4) ? "bad magic" : "message too long");
        return -1;
    }
    if (recv_all(fd, payload, h.length)) return -1;
    *len = h.length;
    return h.type;
}

static void serve(int fd) {
    uint8_t payload[4 + 4 * 65536 + 64]; // the longest message: a CANCEL of 65535 ids
    uint32_t len;

    int type = read_msg(fd, payload, sizeof payload, &len);
    if (type != MSG_HELLO || len != 2) {
        if (type >= 0) send_error(fd, 0, ERR_MESSAGE, "expected HELLO");
        return;
    }
    uint16_t version;
    memcpy(&version, payload, 2);
    if (version != PROTO_VERSION) {
        send_error(fd, 0, ERR_VERSION, "protocol version not supported");
        return;
    }
    if (send_msg(fd, MSG_INFO, &info, sizeof info)) return;

    for (;;) {
        if (in_flight && poll_done(fd)) return;
        struct pollfd pfd = {.fd = fd, .events = POLLIN};
        struct timespec tick = {0, 100000}; // 100 us
        int r = ppoll(&pfd, 1, in_flight ? &tick : NULL, NULL);
        if (r < 0 && errno != EINTR) return;
        if (r <= 0) continue;
        if (pfd.revents & (POLLERR | POLLNVAL)) return;

        type = read_msg(fd, payload, sizeof payload, &len);
        int err = 0;
        switch (type) {
        case -1: return;
        case MSG_TILE_REQ: err = on_tile_req(fd, payload, len); break;
        case MSG_CANCEL: err = on_cancel(fd, payload, len); break;
        case MSG_PING:
            if (len != 4) return (void)send_error(fd, 0, ERR_MESSAGE, "PING of the wrong length");
            err = send_msg(fd, MSG_PONG, payload, 4);
            break;
        case MSG_PONG: break;
        case MSG_STATUS_REQ: err = on_status_req(fd); break;
        default: send_error(fd, 0, ERR_MESSAGE, "unexpected message type"); return;
        }
        if (err) return;
    }
}

int main(int argc, char **argv) {
    int port = PROTO_PORT, cpu = 3, opt; // CPUs 2 and 3 are the A76 cores
    while ((opt = getopt(argc, argv, "p:c:v")) != -1) switch (opt) {
        case 'p': port = atoi(optarg); break;
        case 'c': cpu = atoi(optarg); break;
        case 'v': verbose = 1; break;
        default: fprintf(stderr, "usage: mandelbrotd [-p port] [-c cpu] [-v]\n"); return 2;
        }
    if (cpu >= 0) {
        cpu_set_t set;
        CPU_ZERO(&set);
        CPU_SET(cpu, &set);
        if (sched_setaffinity(0, sizeof set, &set)) perror("sched_setaffinity (continuing)");
    }
    signal(SIGPIPE, SIG_IGN);

    setup_memory();
    setup_accel();

    int ls = socket(AF_INET6, SOCK_STREAM, 0), one = 1, zero = 0;
    if (ls < 0) die("socket");
    setsockopt(ls, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
    setsockopt(ls, IPPROTO_IPV6, IPV6_V6ONLY, &zero, sizeof zero); // IPv4 too
    struct sockaddr_in6 a = {.sin6_family = AF_INET6, .sin6_port = htons(port), .sin6_addr = in6addr_any};
    if (bind(ls, (struct sockaddr *)&a, sizeof a) || listen(ls, 4)) die("bind/listen");
    LOG("listening on port %d", port);

    for (;;) {
        int fd = accept(ls, NULL, NULL);
        if (fd < 0) {
            if (errno == EINTR) continue;
            die("accept");
        }
        setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof one);
        int sz = 4 << 20;
        setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &sz, sizeof sz);
        LOG("client connected");
        serve(fd);
        close(fd);
        reset_jobs(); // what the client left in flight
        LOG("client gone");
    }
}
