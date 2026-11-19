#!/usr/bin/env python3
"""Bring-up test of MandelbrotAccel from the HPS, through /dev/mem (run as root on the board).

    sudo python3 accel_test.py check      tiles of several kinds, every record checked
    sudo python3 accel_test.py bench      256x256 tiles, all result slots busy: tiles/s, pixels/s

The models are bit-exact with the hardware: the narrow one below for the 21-bit phase 1 cores
(spinal/src/test/scala/mandelbrot/AccelModel.scala), fixed.py (copied next to this script by
`make install`) for the wide cores of phase 2.
Registers are accessed as 32-bit words through ctypes and results as 64-bit words: the mappings
are device memory, where unaligned or byte accesses fault or read wrong.
"""
import argparse
import ctypes
import mmap
import os
import time

REG_BASE = 0x2000_0000
RES_BASE = 0xBF00_0000  # reserved in the device tree (hps/BOARD_CHANGES.md)
SLOT_SIZE = 512 << 10
SLOTS = 8

ID, VERSION, CAPS, ARITH_ID, CONTROL, STATUS, ABORT, QUEUE = range(0, 0x20, 4)
X0, Y0, STEP, SIZE, MAX_IT, FLAGS, JOB_ID = 0x20, 0x30, 0x40, 0x50, 0x54, 0x58, 0x5C
RESULT_BASE, RESULT_SLOTS, RESULT_SLOT, DONE, DONE_ITERATIONS = 0x60, 0x68, 0x6C, 0x70, 0x74
TOTAL_ITERATIONS, TOTAL_CYCLES, TOTAL_PIXELS, BOARD_TEMP, FAN_RPM, R2 = 0x80, 0x88, 0x90, 0x98, 0x9C, 0xA0
UNRESOLVED = 0xFFFFFFFF
INTERIOR = 0xFFFFFFFE
PERIODICITY = 1 << 0  # FLAGS
CARDIOID = 1 << 1
MAG_FRAC = 22


class Accel:
    def __init__(self):
        fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
        self._regs_map = mmap.mmap(fd, 4096, offset=REG_BASE)
        self._res_map = mmap.mmap(fd, SLOTS * SLOT_SIZE, offset=RES_BASE)
        os.close(fd)
        self.regs = (ctypes.c_uint32 * 1024).from_buffer(self._regs_map)
        self.res = (ctypes.c_uint64 * (SLOTS * SLOT_SIZE // 8)).from_buffer(self._res_map)
        assert self.rd(ID) == 0x4D414E44, f"no accelerator: ID = {self.rd(ID):#x}"
        caps = self.rd(CAPS)
        self.n_cores, self.w, self.i_bits, self.n_ctx = caps & 0xFF, (caps >> 8) & 0xFF, (caps >> 16) & 0x1F, caps >> 24
        self.f = self.w - self.i_bits
        self.wide = self.w > 32
        self.words = (self.w + 31) // 32
        self.wr(RESULT_BASE, RES_BASE)
        self.wr(RESULT_BASE + 4, 0)
        self.wr(RESULT_SLOTS, SLOTS)

    def rd(self, off):
        return self.regs[off // 4]

    def wr(self, off, value):
        self.regs[off // 4] = value & 0xFFFFFFFF

    def rd64(self, off):
        return self.rd(off) | (self.rd(off + 4) << 32)

    def fix(self, v):
        return round(v * (1 << self.f))

    def push(self, job_id, slot, x0, y0, step, width, height, max_it, flags=0):
        for reg, v in ((X0, x0), (Y0, y0), (STEP, step)):  # sign-extended words, low first
            for k in range(self.words):
                self.wr(reg + 4 * k, (v >> (32 * k)) & 0xFFFFFFFF)
        self.wr(SIZE, (height << 16) | width)
        self.wr(MAX_IT, max_it)
        self.wr(FLAGS, flags)
        self.wr(JOB_ID, job_id)
        self.wr(RESULT_SLOT, slot)
        self.wr(CONTROL, 1)

    def pop_done(self):
        """(job id, status, iterations) of the next finished job, or None."""
        d = self.rd(DONE)
        if not d >> 31:
            return None
        it = self.rd64(DONE_ITERATIONS)
        self.wr(DONE, 0)
        return d & 0xFFFF, (d >> 16) & 3, it

    def records(self, slot, n):
        base = slot * SLOT_SIZE // 8
        return [self.res[base + i] for i in range(n)]

    def totals(self):
        it = self.rd64(TOTAL_ITERATIONS)  # latches the three
        return it, self.rd64(TOTAL_CYCLES), self.rd64(TOTAL_PIXELS)


def wrap(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


def model_record(w, f, cx, cy, max_it, periodicity=False):
    from fixed import period_refresh

    a = b = sa = sb = 0
    for n in range(1, max_it + 1):
        a, b = wrap(((a * a - b * b) >> f) + cx, w), wrap(((a * b * 2) >> f) + cy, w)
        if periodicity:  # as fixed.WideFormat.pixel
            if a == sa and b == sb:
                return (n << 32) | INTERIOR
            if period_refresh(n):
                sa, sb = a, b
        s = a * a + b * b
        if s >> (2 * f + 2):
            mag = (s >> (2 * f - MAG_FRAC)) if 2 * f >= MAG_FRAC else (s << (MAG_FRAC - 2 * f))
            mag &= 0xFFFFFFFF
            top = mag.bit_length() - 1
            mant = (mag >> (top - 23)) if top >= 23 else (mag << (23 - top))
            f32 = ((top - MAG_FRAC + 127) << 23) | (mant & 0x7FFFFF)
            return (f32 << 32) | n
    return UNRESOLVED


def model(acc):
    """record(cx, cy, max_it, flags) for this accelerator's arithmetic."""
    from fixed import FLAG_CARDIOID, FLAG_PERIODICITY, WideFormat, cardioid_bulb

    if acc.wide:
        return WideFormat(acc.w, acc.i_bits).record

    def record(cx, cy, max_it, flags=0):
        if flags & FLAG_CARDIOID and cardioid_bulb(cx, cy, acc.f):
            return INTERIOR
        return model_record(acc.w, acc.f, cx, cy, max_it, bool(flags & FLAG_PERIODICITY))
    return record


def run_job(acc, job_id, slot, x0, y0, step, width, height, max_it, flags=0, timeout=10.0):
    acc.push(job_id, slot, x0, y0, step, width, height, max_it, flags)
    t = time.monotonic()
    while (d := acc.pop_done()) is None:
        if time.monotonic() - t > timeout:
            raise TimeoutError(f"job {job_id}: no DONE after {timeout} s, STATUS = {acc.rd(STATUS):#x}")
    assert d[0] == job_id, f"DONE names job {d[0]}, expected {job_id}"
    return d


def check(acc):
    print(f"accelerator: {acc.n_cores} cores, W = {acc.w}, I = {acc.i_bits}, R^2 = {acc.rd(R2) or 4}, "
          f"{acc.n_ctx} contexts, arith id {acc.rd(ARITH_ID):#010x}")
    fx = acc.fix
    record = model(acc)
    tiles = [  # name, x0, y0, step, width, height, max_it
        ("whole set", fx(-2.0), fx(1.25), fx(2.5 / 64), 96, 64, 200),
        ("boundary, deep", fx(-0.7454), fx(0.1130), fx(0.00002), 32, 32, 3000),
        ("far outside", fx(-15.9), fx(15.9), fx(1.0), 32, 32, 50),
        ("very far", fx(-500), fx(500), fx(31), 32, 32, 20),
        ("max_it 0", fx(-0.5), fx(0.5), fx(0.1), 8, 8, 0),
        ("one pixel", fx(0.25), 0, 1, 1, 1, 5000),
        ("256 wide", fx(-2.0), fx(0.01), fx(2.5 / 256), 256, 2, 100),
        ("cardioid test", fx(-1.4), fx(0.8), fx(0.1), 20, 17, 300, CARDIOID),
        ("cardioid edge", fx(0.2499), fx(0.5001), fx(0.000004), 64, 64, 1000, CARDIOID),
        ("period, seahorse", fx(-0.76), fx(0.14), fx(0.004), 16, 12, 2000, PERIODICITY),
        ("period, bulb 3", fx(-0.16), fx(0.80), fx(0.012), 8, 8, 600, PERIODICITY),
        ("period + cardioid", fx(-1.4), fx(0.8), fx(0.1), 20, 17, 400, PERIODICITY | CARDIOID),
    ]
    tiles = [t if len(t) == 8 else t + (0,) for t in tiles]
    failed = 0
    if acc.wide:  # the wide model is slow in Python: smaller tiles, fewer iterations
        tiles = [(n, x0, y0, s, min(wd, 24), min(ht, 16), min(mi, 500), fl) for n, x0, y0, s, wd, ht, mi, fl in tiles]
        tiles.append(("deepest level", fx(-0.743643887037151), fx(0.131825904205330), 16, 16, 8, 500, 0))
    else:
        tiles = [t for t in tiles if t[0] != "very far"]  # outside the narrow format
    for job_id, (name, x0, y0, step, wd, ht, max_it, flags) in enumerate(tiles, start=1):
        slot = job_id % SLOTS
        _, status, it = run_job(acc, job_id, slot, x0, y0, step, wd, ht, max_it, flags)
        got = acc.records(slot, wd * ht)
        bad = 0
        want_it = 0
        for i, r in enumerate(got):
            cx = wrap(x0 + (i % wd) * step, acc.w)
            cy = wrap(y0 - (i // wd) * step, acc.w)
            want = record(cx, cy, max_it, flags)
            low = want & 0xFFFFFFFF  # a proven pixel counts its proof iteration (0 for the cardioid)
            want_it += max_it if low == UNRESOLVED else want >> 32 if low == INTERIOR else low
            if r != want:
                if bad < 3:
                    print(f"  pixel {i} ({i % wd}, {i // wd}): got {r:#018x}, want {want:#018x}")
                bad += 1
        ok = bad == 0 and status == 0 and it == want_it
        failed += not ok
        print(f"{'ok  ' if ok else 'FAIL'} {name:15} {wd}x{ht} max_it {max_it}: status {status}, "
              f"{bad} wrong records, iterations {it} (model {want_it})")

    # abort a job that would run for a long time
    acc.push(99, 0, fx(-0.3), fx(0.2), fx(0.001), 64, 64, 0xFFFFFFF0)
    time.sleep(0.05)
    acc.wr(ABORT, 99)
    t = time.monotonic()
    while (d := acc.pop_done()) is None and time.monotonic() - t < 2:
        pass
    ok = d is not None and d[0] == 99 and d[1] == 1
    failed += not ok
    print(f"{'ok  ' if ok else 'FAIL'} abort: DONE {d}")
    print("all passed" if failed == 0 else f"{failed} FAILED")
    return failed == 0


def bench(acc, n_tiles=200, max_it=256, flags=0):
    """256x256 tiles over the whole set, keeping every slot busy."""
    fx = acc.fix
    step = fx(3.0 / 1024)
    grid = [(fx(-2.25) + col * 256 * step, fx(1.5) - row * 256 * step) for row in range(4) for col in range(4)]
    it0, cy0, px0 = acc.totals()
    t0 = time.monotonic()
    free = list(range(SLOTS))
    in_flight = {}
    sent = done = 0
    while done < n_tiles:
        while free and sent < n_tiles and (acc.rd(QUEUE) & 0xFFFF):
            slot = free.pop()
            x0, y0 = grid[sent % len(grid)]
            acc.push(sent & 0xFFFF, slot, x0, y0, step, 256, 256, max_it, flags)
            in_flight[sent & 0xFFFF] = slot
            sent += 1
        d = acc.pop_done()
        if d is not None:
            assert d[1] == 0, f"job {d[0]} status {d[1]}"
            free.append(in_flight.pop(d[0]))
            done += 1
    dt = time.monotonic() - t0
    it1, cy1, px1 = acc.totals()
    clk = (cy1 - cy0) / dt
    print(f"{n_tiles} tiles of 256x256, max_it {max_it}: {dt:.2f} s, {n_tiles / dt:.1f} tiles/s, "
          f"{(px1 - px0) / dt / 1e6:.1f} M pixels/s, {(it1 - it0) / dt / 1e9:.2f} G iterations/s")
    print(f"core clock {clk / 1e6:.1f} MHz, utilisation {(it1 - it0) / ((cy1 - cy0) * acc.n_cores):.1%} "
          f"(iterations / (cycles x cores))")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", choices=["check", "bench", "status"])
    ap.add_argument("--tiles", type=int, default=200)
    ap.add_argument("--max-it", type=int, default=256)
    ap.add_argument("--flags", type=int, default=0, help="bench: FLAGS (2 = cardioid/bulb test)")
    a = ap.parse_args()
    acc = Accel()
    if a.mode == "check":
        raise SystemExit(0 if check(acc) else 1)
    if a.mode == "bench":
        bench(acc, a.tiles, a.max_it, a.flags)
    t, rpm = acc.rd(BOARD_TEMP), acc.rd(FAN_RPM)
    print(f"FPGA {wrap(t & 0xFFFF, 16)} °C, board {wrap(t >> 16, 16)} °C, fan {rpm & 0xFFFF} RPM"
          f"{'' if rpm >> 31 else ' (not valid)'}")


if __name__ == "__main__":
    main()
