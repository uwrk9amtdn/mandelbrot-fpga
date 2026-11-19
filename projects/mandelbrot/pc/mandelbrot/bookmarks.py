"""Bookmarks (PC_APP_PLAN.md, milestone 6): named views with their colouring, in a JSON file.

A view is stored exactly: its centre and its pixel size as fractions ("num/den"), so a deep view
comes back to the pixel. On a server whose F differs (another bitstream), the level whose pixel
size is nearest is used. The file is `~/.config/mandelbrot-fpga/bookmarks.json`, next to the palettes:

  {"name": {"re": "-3/4", "im": "0", "pixel": "1/1024", "max_it": 256, "flags": 3,
            "colouring": {"mode": "smooth", "palette": "ultra", "density_log": -6.0, ...},
            "saved": "2026-11-19 16:30", "server": "W=64 F=54 id 0xab210ae1"}, ...}
"""

from __future__ import annotations

import json
import time
from dataclasses import asdict, dataclass, field
from fractions import Fraction
from pathlib import Path

from .colouring import palette_file
from .view import View, step


def bookmark_file() -> Path:
    return palette_file().with_name("bookmarks.json")


@dataclass
class Bookmark:
    re: str  # the centre, exact ("num/den")
    im: str
    pixel: str  # the pixel size, exact
    max_it: int
    flags: int = 0  # the result-changing request flags
    colouring: dict = field(default_factory=dict)  # see App.colouring_state
    saved: str = ""
    server: str = ""

    @staticmethod
    def of(view: View, f_bits: int, width: int, height: int, max_it: int, flags: int, colouring: dict,
           server: str = "") -> "Bookmark":
        re, im = view.centre(f_bits, width, height)
        return Bookmark(str(re), str(im), str(Fraction(step(f_bits, view.level), 1 << f_bits)), max_it, flags,
                        dict(colouring), time.strftime("%Y-%m-%d %H:%M"), server)

    def level(self, f_bits: int, lo: int, hi: int) -> int:
        """The level of this pixel size on a server with F = f_bits (the nearest one, in lo..hi)."""
        target = Fraction(self.pixel) * (1 << f_bits)
        return min(range(lo, hi + 1), key=lambda lv: abs(step(f_bits, lv) - target))

    def view(self, f_bits: int, lo: int, hi: int, width: int, height: int) -> View:
        return View.centred(f_bits, self.level(f_bits, lo, hi), Fraction(self.re), Fraction(self.im), width, height)

    def exact_on(self, f_bits: int, lo: int, hi: int) -> bool:
        """Whether this server has the bookmark's pixel size exactly."""
        return Fraction(step(f_bits, self.level(f_bits, lo, hi)), 1 << f_bits) == Fraction(self.pixel)


def load(path: Path | None = None) -> dict[str, Bookmark]:
    """The bookmarks; a missing or damaged file gives none, a damaged entry is left out."""
    path = path or bookmark_file()
    try:
        data = json.loads(path.read_text())
    except (OSError, ValueError):
        return {}
    out = {}
    for name, d in data.items() if isinstance(data, dict) else ():
        try:
            b = Bookmark(**d)
            Fraction(b.re), Fraction(b.im), Fraction(b.pixel)  # noqa: B018 - validates
            out[str(name)] = b
        except (TypeError, ValueError, ZeroDivisionError):
            continue
    return out


def save(bookmarks: dict[str, Bookmark], path: Path | None = None):
    path = path or bookmark_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps({n: asdict(b) for n, b in bookmarks.items()}, indent=1) + "\n")
    tmp.replace(path)
