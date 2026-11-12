"""Exact view maths on the global pixel lattice (PC_APP_PLAN.md, "View maths" and "Tiling").

Everything is an integer. Coordinates are in units of 2^-F, the hardware's fixed-point format.

- Zoom level L has the pixel step step(F, L) = round(2^(F - 2 - L/4)).
- Lattice pixel (X, Y) of level L is c = (X*step, -Y*step). Y grows down the screen.
- Tile (L, TX, TY) covers lattice pixels 256*TX .. 256*TX + 255 and 256*TY .. 256*TY + 255.
"""

from dataclasses import dataclass
from fractions import Fraction
from math import isqrt

TILE = 256
MIN_STEP = 16  # below this many ulps the levels get uneven and rounding error nears a pixel


def step(f_bits: int, level: int) -> int:
    """round(2^(F - 2 - L/4)), computed exactly as the rounded fourth root of 2^(4(F-2) - L)."""
    e = 4 * (f_bits - 2) - level
    if e < 0:
        return 0 if e < -4 else 1  # 2^(e/4) >= 1/2 rounds to 1
    x = 1 << e
    n = isqrt(isqrt(x))  # floor of the fourth root
    return n + 1 if (2 * n + 1) ** 4 <= 16 * x else n


def max_level(f_bits: int) -> int:
    """The deepest level whose step is still at least MIN_STEP ulps."""
    level = 4 * (f_bits - 2 - MIN_STEP.bit_length())
    while step(f_bits, level + 1) >= MIN_STEP:
        level += 1
    return level


def min_level(w_bits: int, f_bits: int, bailout_r2: int) -> int:
    """The shallowest usable level.

    The format holds |c| < 2^(I-1). Tiles that don't fit it are not requested: the client fills them
    in as "escaped at n = 1", which is right when every pixel has |c| >= R. That holds for any tile
    crossing the edge of the format if a tile is no wider than 2^(I-1) - R.
    """
    radius = isqrt(bailout_r2 - 1) + 1  # ceil(R)
    room = ((1 << (w_bits - f_bits - 1)) - radius) << f_bits
    level = 0
    while TILE * step(f_bits, level) > room:
        level += 1
    return level


def _round_div(a: int, b: int) -> int:
    """a / b rounded to the nearest integer (halves up), b > 0."""
    return (2 * a + b) // (2 * b)


@dataclass(frozen=True)
class View:
    """The screen's top-left pixel is lattice pixel (x0, y0) of `level`."""

    level: int
    x0: int
    y0: int

    def pan(self, dx: int, dy: int) -> "View":
        """Move the image by (dx, dy) screen pixels (a drag to the right is dx > 0)."""
        return View(self.level, self.x0 - dx, self.y0 - dy)

    def zoom(self, f_bits: int, levels: int, px: int, py: int) -> "View":
        """Change the level, keeping the point under screen pixel (px, py) there (within a pixel)."""
        old, new = step(f_bits, self.level), step(f_bits, self.level + levels)
        if new == 0:
            raise ValueError("zoom level beyond the format's precision")
        x = _round_div((self.x0 + px) * old, new)
        y = _round_div((self.y0 + py) * old, new)
        return View(self.level + levels, x - px, y - py)

    def centre(self, f_bits: int, width: int, height: int) -> tuple[Fraction, Fraction]:
        s = Fraction(step(f_bits, self.level), 1 << f_bits)
        return (2 * self.x0 + width) * s / 2, -(2 * self.y0 + height) * s / 2

    @staticmethod
    def centred(f_bits: int, level: int, re, im, width: int, height: int) -> "View":
        """The view of `level` whose centre is nearest to (re, im). They can be Fractions or strings."""
        s = Fraction(step(f_bits, level), 1 << f_bits)
        return View(level, round(Fraction(re) / s - Fraction(width, 2)),
                    round(-Fraction(im) / s - Fraction(height, 2)))


def visible_tiles(view: View, width: int, height: int) -> list[tuple[int, int]]:
    """(TX, TY) of the tiles a width x height screen shows, nearest to the screen centre first."""
    cx, cy = 2 * view.x0 + width, 2 * view.y0 + height  # twice the centre, in lattice pixels
    tiles = [(tx, ty)
             for ty in range(view.y0 // TILE, (view.y0 + height - 1) // TILE + 1)
             for tx in range(view.x0 // TILE, (view.x0 + width - 1) // TILE + 1)]
    tiles.sort(key=lambda t: (2 * TILE * t[0] + TILE - cx) ** 2 + (2 * TILE * t[1] + TILE - cy) ** 2)
    return tiles


def tile_origin(f_bits: int, level: int, tx: int, ty: int) -> tuple[int, int, int]:
    """(x0, y0, step) of a tile's request: its top-left pixel and the pixel step."""
    s = step(f_bits, level)
    return TILE * tx * s, -TILE * ty * s, s
