"""The bit-exact model of the wide arithmetic (fixed.py)."""

import random
import struct

import numpy as np
import pytest

from mandelbrot.fixed import LIMB, UNRESOLVED, WideFormat, wrap


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
