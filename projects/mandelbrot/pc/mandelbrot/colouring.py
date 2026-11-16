"""Colouring (PC_APP_PLAN.md, "Colouring"): palettes, the colouring modes and their settings, the
histogram CDF, and a numpy reference of the shader in gl_view.py (the tests compare the two).

A palette is a list of control points (position in [0, 1), RGB in [0, 1]) on a cycle: the colour
after the last point blends back into the first. It is baked into a 1024-entry texture.

Every mode first turns a pixel into a value v, then into a colour:
  escape      v = n                                   palette[fract(v * density + offset)]
  smooth      v = nu = n + 1 - log2(ln|z_n| / ln R)   same, nu is continuous across the bands
  log-smooth  v = log2(1 + nu)                        same; deep zooms with large counts stay readable
  histogram   v = CDF(nu) over the pixels on screen   same, independent of max_it
  hsv, lch    s = nu / max_it * density (Wikipedia, "Plotting algorithms for the Mandelbrot set", at
              density 1); no palette
nu needs a large bailout radius (R = 16, the wide formats) to look smooth; with R = 2 it shows bands.
"""

import json
import math
import os
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

from . import protocol as p

PALETTE_SIZE = 1024
CDF_SIZE = 4096

MODES = ["escape", "smooth", "log-smooth", "histogram", "hsv", "lch"]
PALETTE_MODES = MODES[:4]  # the others compute the colour directly
DEFAULT_DENSITY = {  # palette cycles per unit of v
    "escape": 1 / 64,
    "smooth": 1 / 64,
    "log-smooth": 1 / 4,
    "histogram": 1.0,
    "hsv": 1.0,  # times nu / max_it
    "lch": 1.0,
}

Points = list[tuple[float, tuple[float, float, float]]]

PRESETS: dict[str, Points] = {
    "ultra": [  # the classic dark blue - white - orange cycle
        (0.0, (0.0, 0.03, 0.39)),
        (0.16, (0.13, 0.42, 0.80)),
        (0.42, (0.93, 1.0, 1.0)),
        (0.64, (1.0, 0.67, 0.0)),
        (0.86, (0.0, 0.01, 0.0)),
    ],
    "fire": [
        (0.0, (0.0, 0.0, 0.0)),
        (0.3, (0.7, 0.05, 0.0)),
        (0.6, (1.0, 0.7, 0.1)),
        (0.8, (1.0, 1.0, 0.8)),
    ],
    "ice": [
        (0.0, (0.02, 0.02, 0.1)),
        (0.4, (0.1, 0.5, 0.8)),
        (0.7, (0.8, 0.95, 1.0)),
    ],
    "grey": [
        (0.0, (0.0, 0.0, 0.0)),
        (0.5, (1.0, 1.0, 1.0)),
    ],
}


@dataclass
class Colouring:
    """What the shader needs besides the tiles and the palette texture."""

    mode: str = "smooth"
    density: float = 1 / 64
    offset: float = 0.0
    interior: tuple[float, float, float] = (0.0, 0.0, 0.0)  # proven interior (INTERIOR)
    unresolved: tuple[float, float, float] = (0.0, 0.0, 0.0)  # reached max_it (UNRESOLVED)
    gamma: float = 1.0
    max_it: int = 256  # for hsv and lch
    bailout_r2: float = 256.0
    cdf: np.ndarray = field(default_factory=lambda: np.zeros(CDF_SIZE, np.float32))
    cdf_lo: float = 0.0  # the CDF covers nu in [cdf_lo, cdf_hi]
    cdf_hi: float = 1.0


# ------------------------------------------------------------------------------- palettes


def bake(points: Points, size: int = PALETTE_SIZE) -> np.ndarray:
    """RGB u8 of shape (size, 3), linear between the control points, wrapping around."""
    points = sorted(points, key=lambda pt: pt[0])
    pos = np.array([pt[0] for pt in points] + [points[0][0] + 1.0])
    rgb = np.array([pt[1] for pt in points] + [points[0][1]], dtype=np.float64)
    t = (np.arange(size) + 0.5) / size
    t = np.where(t < pos[0], t + 1.0, t)
    out = np.stack([np.interp(t, pos, rgb[:, c]) for c in range(3)], axis=1)
    return (np.clip(out, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)


def palette_file() -> Path:
    base = os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config"
    return Path(base) / "mandelbrot-fpga" / "palettes.json"  # beside the viewer's viewer.ini


def load_palettes(path: Path | None = None) -> dict[str, Points]:
    """The user's palettes; a missing or damaged file gives none."""
    path = path or palette_file()
    try:
        data = json.loads(path.read_text())
        return {name: [(float(pos), tuple(float(c) for c in rgb)) for pos, rgb in pts]
                for name, pts in data.items() if len(pts) >= 1}
    except (OSError, ValueError, TypeError):
        return {}


def save_palettes(palettes: dict[str, Points], path: Path | None = None):
    path = path or palette_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    r = lambda x: round(float(x), 4)  # noqa: E731  (ImGui gives f32: 0.16 comes back as 0.1599999964)
    lines = [f"  {json.dumps(n)}: [" + ", ".join(json.dumps([r(pos), [r(c) for c in rgb]]) for pos, rgb in pts) + "]"
             for n, pts in palettes.items()]
    tmp.write_text("{\n" + ",\n".join(lines) + "\n}\n")
    tmp.replace(path)


# ------------------------------------------------------------------------------- values


def smooth_nu(counts: np.ndarray, zz: np.ndarray, bailout_r2: float) -> np.ndarray:
    """nu = n + 1 - log2(ln|z_n| / ln R), f64; NaN where the pixel did not escape."""
    n = counts.astype(np.float64)
    ratio = np.log(np.maximum(zz.astype(np.float64), bailout_r2)) / math.log(bailout_r2)  # ln|z|^2 / ln R^2
    nu = n + 1.0 - np.log2(ratio)
    return np.where(counts >= p.INTERIOR, np.nan, nu)


def histogram_cdf(arrays: list[tuple[np.ndarray, np.ndarray]], bailout_r2: float,
                  size: int = CDF_SIZE) -> tuple[np.ndarray, float, float]:
    """The CDF of nu over the escaped pixels of (counts, zz) pairs, sampled at `size` points from
    lo to hi (f32), with lo, hi. Counts are binned per iteration and the CDF is linear inside an
    iteration, so it follows nu."""
    counts = np.concatenate([c[c < p.INTERIOR].ravel() for c, _ in arrays]) if arrays else np.zeros(0, np.uint32)
    if counts.size == 0:
        return np.zeros(size, np.float32), 0.0, 1.0
    lo, hi = int(counts.min()), int(counts.max()) + 1  # nu of count n is in (n, n + 1]
    h = np.bincount(counts - lo, minlength=hi - lo)  # pixels per count, lo .. hi - 1
    edges = np.concatenate([[0], np.cumsum(h)]) / counts.size  # CDF at lo, lo + 1, .., hi
    x = np.linspace(lo, hi, size)
    return np.interp(x, np.arange(lo, hi + 1), edges).astype(np.float32), float(lo), float(hi)


# ------------------------------------------------------------------------------- reference


def _hsv_to_rgb(h, s, v):
    """h in degrees."""
    k = lambda n: (n + h / 60.0) % 6.0  # noqa: E731
    f = lambda n: v - v * s * np.clip(np.minimum(k(n), 4.0 - k(n)), 0.0, 1.0)  # noqa: E731
    return np.stack([f(5.0), f(3.0), f(1.0)], axis=-1)


def lch_to_srgb(L, C, H):
    """CIE LCh(ab), D65, to sRGB in [0, 1] (clipped)."""
    a, b = C * np.cos(np.radians(H)), C * np.sin(np.radians(H))
    fy = (L + 16.0) / 116.0
    fx, fz = fy + a / 500.0, fy - b / 200.0
    finv = lambda t: np.where(t > 6 / 29, t**3, 3 * (6 / 29) ** 2 * (t - 4 / 29))  # noqa: E731
    xyz = np.stack([0.95047 * finv(fx), finv(fy), 1.08883 * finv(fz)], axis=-1)
    m = np.array([[3.2406, -1.5372, -0.4986], [-0.9689, 1.8758, 0.0415], [0.0557, -0.2040, 1.0570]])
    lin = np.clip(xyz @ m.T, 0.0, 1.0)
    return np.where(lin <= 0.0031308, 12.92 * lin, 1.055 * lin ** (1 / 2.4) - 0.055)


def _sample_palette(palette: np.ndarray, t: np.ndarray) -> np.ndarray:
    """Like the GL texture with linear filtering and repeat."""
    u = t * len(palette) - 0.5
    i0 = np.floor(u).astype(np.int64)
    w = (u - i0)[..., None]
    pal = palette.astype(np.float64) / 255.0
    return pal[i0 % len(palette)] * (1 - w) + pal[(i0 + 1) % len(palette)] * w


def reference(counts: np.ndarray, zz: np.ndarray, c: Colouring, palette: np.ndarray) -> np.ndarray:
    """RGB in [0, 1] (f64, shape (..., 3)) of what the shader draws."""
    nu = smooth_nu(counts, zz, c.bailout_r2)
    nu0 = np.nan_to_num(nu)
    if c.mode in PALETTE_MODES:
        if c.mode == "escape":
            v = counts.astype(np.float64)
        elif c.mode == "smooth":
            v = nu0
        elif c.mode == "log-smooth":
            v = np.log2(1.0 + np.maximum(nu0, 0.0))
        else:
            span = max(c.cdf_hi - c.cdf_lo, 1e-9)
            x = np.clip((nu0 - c.cdf_lo) / span, 0.0, 1.0) * (len(c.cdf) - 1)
            v = np.interp(x, np.arange(len(c.cdf)), c.cdf.astype(np.float64))
        rgb = _sample_palette(palette, np.mod(v * c.density + c.offset, 1.0))
    else:
        s = np.maximum(nu0, 0.0) / max(c.max_it, 1) * c.density
        hue = np.mod((360.0 * s) ** 1.5 + 360.0 * c.offset, 360.0)
        if c.mode == "hsv":
            rgb = _hsv_to_rgb(hue, 1.0, 1.0)
        else:
            vv = 1.0 - np.cos(np.pi * s) ** 2
            rgb = lch_to_srgb(75.0 - 75.0 * vv, 28.0 + 75.0 - 75.0 * vv, hue)
    rgb = np.where((counts == p.INTERIOR)[..., None], np.array(c.interior), rgb)
    rgb = np.where((counts == p.UNRESOLVED)[..., None], np.array(c.unresolved), rgb)
    return np.clip(rgb, 0.0, 1.0) ** (1.0 / c.gamma)
