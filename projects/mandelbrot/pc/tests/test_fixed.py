"""The bit-exact model of the wide arithmetic (fixed.py)."""

import math
import random
import struct
from fractions import Fraction

import numpy as np
import pytest

from mandelbrot.fixed import (FLAG_PERIODICITY, INTERIOR, LIMB, UNRESOLVED, WideFormat, cardioid_bulb,
                             period_refresh, wrap)


@pytest.mark.parametrize("w,products", [(64, 5), (96, 8), (128, 11)])
def test_squaring_scheme(w, products):
    fm = WideFormat(w)
    assert len(fm.products) == products  # the DSP budget in ROADMAP.md
    rnd = random.Random(w)
    top = 1 << (LIMB * fm.limbs)
    for m in [0, 1, top - 1, (1 << w) - 1] + [rnd.randrange(top) for _ in range(3000)]:
        exact = fm.square_exact_floor(m)
        assert exact - 1 <= fm.square(m) <= exact  # under a quarter ulp left out, then truncated


@pytest.mark.parametrize("w", [64, 128])
def test_no_overflow(w):
    """While a pixel iterates (|z| < 16), z^2 + c never needs the wrap, for any c of the format."""
    fm = WideFormat(w)
    rnd = random.Random(1)
    bail = fm.r2 << fm.f
    limit = 1 << (fm.w - 1)
    for _ in range(300):
        cx = rnd.randrange(-limit, limit) >> rnd.randrange(0, fm.i)  # all magnitudes of c
        cy = rnd.randrange(-limit, limit) >> rnd.randrange(0, fm.i)
        x = y = 0
        for _n in range(60):
            x2, y2, s2 = fm.square(abs(x)), fm.square(abs(y)), fm.square(abs(x + y))
            if x2 + y2 >= bail:
                break
            nx, ny = x2 - y2 + cx, s2 - x2 - y2 + cy
            assert (nx, ny) == (wrap(nx, fm.w), wrap(ny, fm.w)), "overflow"
            x, y = nx, ny


def test_counts_agree_with_float64_at_shallow_zoom():
    fm = WideFormat(64)
    same = total = 0
    for j in range(24):
        for i in range(32):
            re, im = -2.2 + i * 0.09, 1.2 - j * 0.1
            n, _ = fm.pixel(round(re * 2**fm.f), round(im * 2**fm.f), 200)
            zr = zi = 0.0
            ref = UNRESOLVED
            for k in range(1, 201):
                zr, zi = zr * zr - zi * zi + re, 2 * zr * zi + im
                if zr * zr + zi * zi >= 256:
                    ref = k
                    break
            same += n == ref
            total += 1
    assert same / total > 0.99


def test_f32_of_mag():
    fm = WideFormat(64)
    assert fm.mag_to_f32_bits(256 << fm.f) == 0x43800000  # 256.0
    rnd = random.Random(2)
    for _ in range(1000):
        mag = rnd.randrange(256 << fm.f, 1 << (fm.f + 19))
        got = struct.unpack("<f", struct.pack("<I", fm.mag_to_f32_bits(mag)))[0]
        exact = mag / 2**fm.f
        assert got <= exact and (exact - got) / exact < 2**-23  # truncated to 24 significant bits
    assert np.float32(fm.mag_to_f32_bits(0)) == 0


# --- cardioid/bulb test ---------------------------------------------------------------------------



def exact_inside(x: Fraction, y: Fraction) -> bool:
    q = (x - Fraction(1, 4)) ** 2 + y * y
    return q * (q + x - Fraction(1, 4)) <= y * y / 4 or (x + 1) ** 2 + y * y <= Fraction(1, 16)


def boundary_points(n: int, rng: random.Random):
    """Points within 3e-5 of the cardioid's and the bulb's boundaries."""
    for _ in range(n):
        t = rng.uniform(-math.pi, math.pi)
        if rng.random() < 0.7:  # cardioid: c = e^it/2 - e^2it/4
            bx, by = math.cos(t) / 2 - math.cos(2 * t) / 4, math.sin(t) / 2 - math.sin(2 * t) / 4
        else:  # bulb: c = -1 + e^it/4
            bx, by = -1 + math.cos(t) / 4, math.sin(t) / 4
        d = rng.uniform(-3e-5, 3e-5)
        yield bx + d * math.cos(t), by + d * math.sin(t)


@pytest.mark.parametrize("f_bits", [16, 54, 118])
def test_cardioid_bulb_never_wrong(f_bits):
    rng = random.Random(f_bits)
    claimed = 0
    for bx, by in list(boundary_points(20000, rng)) + [(rng.uniform(-2, 1), rng.uniform(-1.2, 1.2))
                                                        for _ in range(20000)]:
        x = round(bx * 2**f_bits) + rng.randrange(-8, 9)
        y = round(by * 2**f_bits) + rng.randrange(-8, 9)
        if cardioid_bulb(x, y, f_bits):
            claimed += 1
            assert exact_inside(Fraction(x, 2**f_bits), Fraction(y, 2**f_bits)), (f_bits, x, y)
    assert claimed > 8000  # it does claim most interior points


def test_cardioid_bulb_margin_is_small():
    """Interior points further than 1e-4 from the boundary are all claimed."""
    rng = random.Random(1)
    for _ in range(5000):
        t = rng.uniform(-math.pi, math.pi)
        r = rng.uniform(0, 0.999)  # towards the origin, which is inside
        bx, by = math.cos(t) / 2 - math.cos(2 * t) / 4, math.sin(t) / 2 - math.sin(2 * t) / 4
        x, y = Fraction(bx) * Fraction(r), Fraction(by) * Fraction(r)
        fx, fy = round(x * 2**54), round(y * 2**54)
        X, Y = Fraction(fx, 2**54), Fraction(fy, 2**54)
        q = (X - Fraction(1, 4)) ** 2 + Y * Y
        if q * (q + X - Fraction(1, 4)) - Y * Y / 4 < -Fraction(1, 10**4):
            assert cardioid_bulb(fx, fy, 54)


def slow_points(fm, n, seed):
    """Points near the boundary (seahorse valley and the period-3 bulb): slow escapes and slow cycles."""
    rnd = random.Random(seed)
    out = []
    for cx, cy, r in [(-0.7436, 0.1318, 0.01), (-0.1225, 0.7449, 0.02), (-1.25, 0.0, 0.05)]:
        out += [(round((cx + rnd.uniform(-r, r)) * 2**fm.f), round((cy + rnd.uniform(-r, r)) * 2**fm.f))
                for _ in range(n)]
    return out


def test_period_refresh_schedule():
    assert [n for n in range(1, 41) if period_refresh(n)] == [*range(1, 9), 10, 12, 14, 16, 20, 24, 28, 32, 40]
    for j in range(1 << 14):  # the RTL's form, from j = n - 1
        assert period_refresh(j + 1) == ((((j ^ (j + 1)) << 2) | 3) >= j + 1)


def test_periodicity_never_wrong_and_changes_nothing_else():
    fm = WideFormat(64)
    proven = 0
    for cx, cy in slow_points(fm, 30, 1):
        rec = fm.record(cx, cy, 2000, FLAG_PERIODICITY)
        plain = fm.record(cx, cy, 2000)
        if rec & 0xFFFFFFFF == INTERIOR:
            proven += 1
            k = rec >> 32
            assert 1 <= k <= 2000 and plain == UNRESOLVED
            assert fm.record(cx, cy, 6000) == UNRESOLVED  # a real cycle: it never escapes
        else:
            assert rec == plain
    assert proven >= 10


def test_periodicity_does_not_depend_on_max_it():
    """The cache's rule (cache.py): a record at max_it M answers M' < M."""
    fm = WideFormat(64)
    for cx, cy in slow_points(fm, 12, 2):
        full = fm.record(cx, cy, 1500, FLAG_PERIODICITY)
        count, k = full & 0xFFFFFFFF, full >> 32
        for m in (1, 7, 64, 300, 1024, 1499):
            lower = fm.record(cx, cy, m, FLAG_PERIODICITY)
            if count == INTERIOR:
                assert lower == (full if k <= m else UNRESOLVED)
            elif count == UNRESOLVED or count > m:
                assert lower == UNRESOLVED
            else:
                assert lower == full


def test_periodicity_c_zero():
    fm = WideFormat(64)
    assert fm.record(0, 0, 10, FLAG_PERIODICITY) == (1 << 32) | INTERIOR  # z_1 = 0 = z_0
