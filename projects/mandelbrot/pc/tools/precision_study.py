"""Error study for the wide arithmetic (ROADMAP.md, phase 2 step 1).

For each width, tiles on the boundary of the set at two depths (the deepest the viewer allows,
16 ulps per pixel, then 1024 and 65536 ulps per pixel) are computed three ways. The boundary points are found
by bisection along rays from the main cardioid outwards, with the wider reference, so a tile mixes
pixels that escape late with pixels that don't.

  hw     the hardware's truncated squares (fixed.WideFormat.square)
  floor  exact squares, truncated once (no left-out partial products)
  ref    the same algorithm 64 bits wider, from the same c: the effect of the number format itself

and the share of pixels whose count differs is reported.

    PYTHONPATH=. uv run python tools/precision_study.py [--size 24] [--max-it 1500]
"""

import argparse
import time
from multiprocessing import Pool

from mandelbrot.fixed import UNRESOLVED, WideFormat

RAYS = {  # name -> direction (degrees) of a ray from c = -0.1 (inside the main cardioid)
    "seahorse": 160,
    "top": 95,
    "elephant": 5,
}


def boundary(fm: WideFormat, angle: float, max_it: int) -> tuple[int, int]:
    """A point on the boundary along a ray, to within 1 ulp of fm (computed 64 bits wider)."""
    import math

    ref = WideFormat(fm.w + 64)
    inside = (round(-0.1 * 2**fm.f), 0)
    d = (math.cos(math.radians(angle)), math.sin(math.radians(angle)))
    outside = (round((-0.1 + 2.5 * d[0]) * 2**fm.f), round(2.5 * d[1] * 2**fm.f))

    def escapes(c):
        return ref.pixel(c[0] << 64, c[1] << 64, max_it, square=ref.square_exact_floor)[0] != UNRESOLVED

    for _ in range(fm.f + 2):
        mid = ((inside[0] + outside[0]) // 2, (inside[1] + outside[1]) // 2)
        if mid in (inside, outside):
            break
        if escapes(mid):
            outside = mid
        else:
            inside = mid
    return outside


def tile(job):
    w, place, step_ulps, size, max_it = job
    fm = WideFormat(w)
    ref = WideFormat(w + 64)
    cx0, cy0 = boundary(fm, RAYS[place], max_it)
    diff_floor = diff_ref = floor_ref = escaped = 0
    for j in range(size):
        for i in range(size):
            cx = cx0 + (i - size // 2) * step_ulps
            cy = cy0 - (j - size // 2) * step_ulps
            hw = fm.pixel(cx, cy, max_it)[0]
            fl = fm.pixel(cx, cy, max_it, square=fm.square_exact_floor)[0]
            rf = ref.pixel(cx << 64, cy << 64, max_it, square=ref.square_exact_floor)[0]
            diff_floor += hw != fl
            diff_ref += hw != rf
            floor_ref += fl != rf
            escaped += hw != UNRESOLVED
    return w, place, step_ulps, size * size, escaped, diff_floor, diff_ref, floor_ref


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--size", type=int, default=24, help="tile side in pixels")
    ap.add_argument("--max-it", type=int, default=1500)
    ap.add_argument("--widths", default="64,96,128")
    a = ap.parse_args()
    jobs = [(w, place, s, a.size, a.max_it) for w in map(int, a.widths.split(","))
            for place in RAYS for s in (16, 1024, 65536)]
    t = time.monotonic()
    with Pool() as pool:
        rows = pool.map(tile, jobs)
    print(f"{a.size}x{a.size} pixels per tile, max_it {a.max_it}, {time.monotonic() - t:.0f} s")
    print("hw: the hardware's squares; floor: exact squares at the same width; ref: 64 bits wider")
    print(f"{'W':>4} {'place':10} {'step':>6} {'escaped':>8} {'hw!=floor':>10} {'hw!=ref':>8} {'floor!=ref':>11}")
    for w, place, s, n, esc, df, dr, fr in rows:
        print(f"{w:>4} {place:10} {s:>6} {esc:>5}/{n:<4} {df:>10} {dr:>8} {fr:>11}")


if __name__ == "__main__":
    main()
