from fractions import Fraction

import pytest

from mandelbrot.view import MIN_STEP, TILE, View, max_level, min_level, step, tile_origin, visible_tiles


@pytest.mark.parametrize("f_bits", [16, 54, 118])
def test_step(f_bits):
    for q in range(f_bits - 1):
        assert step(f_bits, 4 * q) == 1 << (f_bits - 2 - q)  # every 4 levels halve it exactly
    for level in range(4 * (f_bits - 8)):
        exact = Fraction(2) ** (4 * (f_bits - 2) - level)  # step^4, unrounded
        s = step(f_bits, level)
        assert (2 * s - 1) ** 4 <= 16 * exact < (2 * s + 1) ** 4  # nearest integer to the 4th root
        assert step(f_bits, level + 1) < s


def test_step_runs_out():
    assert step(16, 56) == 1 and step(16, 60) == 1 and step(16, 61) == 0


def test_level_limits():
    for f_bits in (16, 54, 118):
        top = max_level(f_bits)
        assert step(f_bits, top) >= MIN_STEP > step(f_bits, top + 1)
    assert min_level(64, 54, 256) == 0  # I = 10: a 64-unit tile fits beside R = 16
    lo = min_level(21, 16, 4)  # I = 5: +-16, R = 2, so a tile is at most 14 units
    assert TILE * step(16, lo) <= 14 << 16 < TILE * step(16, lo - 1)


def test_pan():
    assert View(8, 100, -50).pan(30, -5) == View(8, 70, -45)


@pytest.mark.parametrize("levels", [1, -1, 4, -7, 13])
def test_zoom_keeps_the_cursor_point(levels):
    f_bits, view, (px, py) = 54, View(40, -123_457, 98_765), (700, 311)
    zoomed = view.zoom(f_bits, levels, px, py)
    assert zoomed.level == 40 + levels
    old, new = step(f_bits, 40), step(f_bits, zoomed.level)
    for before, after in (((view.x0 + px) * old, (zoomed.x0 + px) * new),
                          ((view.y0 + py) * old, (zoomed.y0 + py) * new)):
        assert 2 * abs(before - after) <= new  # within half a new pixel


def test_zoom_in_and_out_returns():
    view = View(20, 4096, -8192)  # multiples of the level-16 step ratio survive the trip exactly
    assert view.zoom(54, 4, 0, 0).zoom(54, -4, 0, 0) == view


def test_centred():
    view = View.centred(54, 12, "-0.75", "0.1", 1920, 1080)
    re, im = view.centre(54, 1920, 1080)
    pixel = Fraction(step(54, 12), 1 << 54)
    assert abs(re - Fraction("-0.75")) <= pixel / 2 and abs(im - Fraction("0.1")) <= pixel / 2


def test_visible_tiles():
    view = View(10, -300, 250)
    tiles = visible_tiles(view, 1000, 500)
    assert sorted(tiles) == [(tx, ty) for tx in range(-2, 3) for ty in range(0, 3)]
    assert len(set(tiles)) == len(tiles)
    assert tiles[0] == (0, 1)  # the tile under the screen centre, lattice (200, 500)
    assert len(visible_tiles(View(0, 0, 0), 1920, 1080)) == 8 * 5  # aligned
    assert len(visible_tiles(View(0, 255, 255), 1920, 1080)) == 9 * 6
    assert visible_tiles(View(0, -256, -256), 256, 256) == [(-1, -1)]


def test_tile_origin():
    s = step(54, 9)
    assert tile_origin(54, 9, -3, 2) == (-768 * s, -512 * s, s)
