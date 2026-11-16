"""The numpy side of the colouring: smooth nu, the histogram CDF, LCH, the palette file."""

import math

import numpy as np

from mandelbrot import protocol as p
from mandelbrot.colouring import (PRESETS, bake, histogram_cdf, lch_to_srgb, load_palettes, save_palettes,
                                  smooth_nu)


def test_nu_is_continuous_across_bands():
    r2 = 256.0
    # escaping just past R at n, and at n + 1 from |z_n| just under R (|z_{n+1}| ~ R^2): both near n + 1
    nu = smooth_nu(np.array([10, 11], np.uint32), np.array([r2 * 1.0001, r2**2 * 0.9999], np.float32), r2)
    assert abs(nu[0] - 11.0) < 1e-3 and abs(nu[1] - 11.0) < 1e-3
    assert np.isnan(smooth_nu(np.array([p.INTERIOR, p.UNRESOLVED], np.uint32), np.ones(2, np.float32), r2)).all()


def test_nu_is_in_its_band():
    rng = np.random.default_rng(0)
    n = rng.integers(1, 1000, 1000).astype(np.uint32)
    zz = np.exp(rng.uniform(math.log(256), 2 * math.log(256), 1000)).astype(np.float32)
    nu = smooth_nu(n, zz, 256.0)
    assert (nu >= n - 1e-6).all() and (nu <= n + 1 + 1e-6).all()


def test_histogram_cdf():
    counts = np.array([[5, 5, 6, p.INTERIOR], [8, p.UNRESOLVED, 5, 6]], np.uint32)
    cdf, lo, hi = histogram_cdf([(counts, None)], 256.0, size=9)  # samples at nu = 5, 5.5, .., 9
    assert (lo, hi) == (5.0, 9.0)
    # 6 escaped pixels: 3 at 5, 2 at 6, 1 at 8
    assert np.allclose(cdf[[0, 2, 4, 6, 8]], [0, 3 / 6, 5 / 6, 5 / 6, 1])
    assert np.isclose(cdf[1], 1.5 / 6)
    assert (np.diff(cdf) >= 0).all()
    empty, lo, hi = histogram_cdf([(np.full((2, 2), p.INTERIOR, np.uint32), None)], 256.0)
    assert not empty.any() and hi > lo


def test_lch_known_values():
    assert np.allclose(lch_to_srgb(np.float64(100.0), 0.0, 0.0), 1.0, atol=2e-3)  # white
    assert np.allclose(lch_to_srgb(np.float64(0.0), 0.0, 0.0), 0.0, atol=1e-6)  # black
    grey = lch_to_srgb(np.float64(50.0), 0.0, 0.0)
    assert np.allclose(grey, 119 / 255, atol=2 / 255)  # L* 50 is sRGB 119
    red = lch_to_srgb(np.float64(53.24), 104.55, 39.99)  # sRGB red in LCh
    assert np.allclose(red, [1, 0, 0], atol=0.01)


def test_bake_wraps_and_sorts():
    pal = bake([(0.5, (1.0, 1.0, 1.0)), (0.0, (0.0, 0.0, 0.0))], size=4)
    assert pal[:, 0].tolist() == [64, 191, 191, 64]  # t = 1/8, 3/8, 5/8, 7/8 on the cycle black-white


def test_palette_file_roundtrip(tmp_path):
    f = tmp_path / "sub" / "palettes.json"
    pals = {"mine": PRESETS["fire"], "two": [(0.25, (0.5, 0.5, 0.5))]}
    save_palettes(pals, f)
    assert load_palettes(f) == pals
    f.write_text("{not json")
    assert load_palettes(f) == {}
    assert load_palettes(tmp_path / "missing.json") == {}
