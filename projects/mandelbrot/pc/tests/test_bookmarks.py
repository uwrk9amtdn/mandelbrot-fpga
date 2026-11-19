"""Bookmarks (PC_APP_PLAN.md, milestone 6)."""

from fractions import Fraction

from mandelbrot import bookmarks
from mandelbrot.bookmarks import Bookmark
from mandelbrot.view import View, max_level, min_level, step

W, H = 1280, 800


def test_exact_round_trip_at_depth(tmp_path):
    f = 118  # W = 128
    lo, hi = min_level(128, f, 256), max_level(f)
    view = View.centred(f, hi - 2, "-0.7436438870371587047521915061147745", "0.131825904205311970493132056385139",
                        W, H)
    b = Bookmark.of(view, f, W, H, 50000, 3, {"mode": "smooth"}, "W=128")
    path = tmp_path / "bookmarks.json"
    bookmarks.save({"deep": b}, path)
    back = bookmarks.load(path)["deep"]
    assert back == b and back.exact_on(f, lo, hi)
    assert back.view(f, lo, hi, W, H) == view  # to the pixel
    assert back.max_it == 50000 and back.flags == 3


def test_other_format_takes_the_nearest_level():
    view = View.centred(54, 40, "-0.75", "0.1", W, H)
    b = Bookmark.of(view, 54, W, H, 256, 0, {})
    lo, hi = min_level(21, 16, 4), max_level(16)
    level = b.level(16, lo, hi)
    want = Fraction(step(54, 40), 1 << 54) * (1 << 16)
    assert all(abs(step(16, level) - want) <= abs(step(16, lv) - want) for lv in range(lo, hi + 1))
    v = b.view(16, lo, hi, W, H)
    re, im = v.centre(16, W, H)
    pixel = Fraction(step(16, level), 1 << 16)
    assert abs(re - Fraction("-0.75")) <= pixel and abs(im - Fraction("0.1")) <= pixel


def test_damaged_file(tmp_path):
    path = tmp_path / "bookmarks.json"
    assert bookmarks.load(path) == {}  # missing
    path.write_text("{not json")
    assert bookmarks.load(path) == {}
    good = Bookmark("-3/4", "0", "1/1024", 256)
    path.write_text('{"good": {"re": "-3/4", "im": "0", "pixel": "1/1024", "max_it": 256},'
                    ' "bad": {"re": "x", "im": "0", "pixel": "1", "max_it": 1}, "worse": 7}')
    assert bookmarks.load(path) == {"good": good}
