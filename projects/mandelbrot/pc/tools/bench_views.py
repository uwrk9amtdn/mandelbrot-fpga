"""Benchmark views, end to end through the protocol (ROADMAP.md, phase 3).

Renders fixed views from a server (the board's mandelbrotd, or a simulated server) the way the
viewer does, tiles centre-out, always "max requests in flight" outstanding, and reports where the
time goes:

  wall      seconds for the view (best of --repeat)
  Mpx/s     pixels per second; G it/s: iterations per second (the sum of the tiles' counts)
  MB/s      tile data on the link
  busy      FPGA utilisation over the render: delta total iterations / (delta total cycles x cores)
  compute   the time the cores need at 100 % utilisation: iterations / (cores x clock)
  link      the time the transport needs for this many tiles, from the "link" view, whose pixels all
            escape at n = 1 (so they cost no compute): tiles / (its tiles per second)

The larger of compute and link is the floor; wall far above both points at something else.

--outcomes adds where the iterations go, by pixel outcome (from the counts plane of raw tiles):
escaped pixels; pixels that reached max_it (each costs max_it, and only these can the periodicity
check save); pixels proven interior (cost 0). The time the cores spend on the max_it pixels is
about their share of the iterations.

Only the standard library is needed (the tile data is counted, not decoded), so it also runs on the
board against localhost, which measures mandelbrotd and the FPGA without the network:

    PYTHONPATH=. uv run python tools/bench_views.py --host 192.168.10.10 [--json out.jsonl]
    scp -r mandelbrot/protocol.py mandelbrot/view.py tools/bench_views.py board:bench/  # see --help
"""

import argparse
from array import array
import json
import os
import socket
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))  # mandelbrot/
try:
    from mandelbrot import protocol as p
    from mandelbrot.view import TILE, View, max_level, min_level, step, tile_origin, visible_tiles
except ImportError:  # on the board: protocol.py and view.py copied next to this file
    import protocol as p
    from view import TILE, View, max_level, min_level, step, tile_origin, visible_tiles

# name -> (re, im, pixel step in units, max_it). The level is the one whose step is nearest.
VIEWS = {
    "link": ("100", "100", 1.6e-3, 256),  # every pixel escapes at n = 1: transport only
    "whole set": ("-0.75", "0", 1.6e-3, 256),  # 3.1 across at 1920 pixels
    "seahorse spiral": ("-0.743643887", "0.131825904", 7.6e-6, 4096),
    "seahorse 16k": ("-0.743643887", "0.131825904", 7.6e-6, 16384),  # the periodicity check gains with max_it
    "deep": ("-0.743643887037158704752191506114774", "0.131825904205311970493132056385139", 1e-11, 10000),
    "interior": ("-0.3", "0", 5.2e-4, 4096),  # mostly the main cardioid: what phase 3 speeds up
}


def level_for(f_bits: int, units: float, lo: int, hi: int) -> int:
    target = units * 2**f_bits
    return min(range(lo, hi + 1), key=lambda lv: abs(step(f_bits, lv) - target))


class Client:
    def __init__(self, host: str, port: int):
        self.sock = socket.create_connection((host, port), timeout=60)
        self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.sock.sendall(p.encode_hello())
        t, payload = p.read_message(self.sock)
        if t != p.Msg.INFO:
            raise p.ProtocolError(f"expected INFO, got {t}")
        self.info = p.Info.decode(payload)
        self.next_id = 1

    def render(self, view: View, width: int, height: int, max_it: int, flags: int, outcomes=False) -> dict:
        info = self.info
        todo = []
        for tx, ty in visible_tiles(view, width, height):
            x0, y0, s = tile_origin(info.f, view.level, tx, ty)
            if p.TileReq(1, TILE, TILE, max_it, flags, x0, y0, s).fits(info.w):
                todo.append((x0, y0, s))
        todo.reverse()
        st = {"tiles": 0, "iterations": 0, "wire_bytes": 0, "totals": [], "max_it_px": 0, "interior_px": 0}
        waiting = 0
        while todo or waiting:
            while todo and waiting < info.max_in_flight:
                x0, y0, s = todo.pop()
                self.sock.sendall(p.TileReq(self.next_id, TILE, TILE, max_it, flags, x0, y0, s).encode(info.w))
                self.next_id += 1
                waiting += 1
            t, payload = p.read_message(self.sock)
            if t == p.Msg.ERROR:
                raise RuntimeError(f"server error: {p.decode_error(payload)}")
            if t != p.Msg.TILE:
                continue
            tile = p.Tile.decode(payload)
            waiting -= 1
            st["tiles"] += 1
            st["iterations"] += tile.iterations
            st["wire_bytes"] += len(tile.data)
            st["totals"].append((tile.total_iterations, tile.total_cycles))
            if outcomes:
                if tile.encoding != p.ENCODING_RAW:
                    raise RuntimeError("--outcomes needs raw tiles (no LZ4 flag)")
                counts = array("I")
                counts.frombytes(tile.data[:4 * tile.width * tile.height])
                if sys.byteorder != "little":
                    counts.byteswap()
                st["max_it_px"] += counts.count(p.UNRESOLVED)
                st["interior_px"] += counts.count(p.INTERIOR)
        return st


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--host", default="192.168.10.10")
    ap.add_argument("--port", type=int, default=p.PORT)
    ap.add_argument("--size", default="1920x1080")
    ap.add_argument("--repeat", type=int, default=2)
    ap.add_argument("--views", help="comma-separated subset of: " + ", ".join(VIEWS))
    ap.add_argument("--flags", type=int, default=0, help="request flags (1 periodicity, 2 cardioid, 4 LZ4)")
    ap.add_argument("--outcomes", action="store_true", help="split pixels and iterations by outcome")
    ap.add_argument("--json", help="append the results to this JSON-lines file")
    a = ap.parse_args()
    width, height = map(int, a.size.lower().split("x"))
    names = a.views.split(",") if a.views else list(VIEWS)

    c = Client(a.host, a.port)
    info = c.info
    clock = info.clock_khz * 1e3
    lo, hi = min_level(info.w, info.f, info.bailout_r2), max_level(info.f)
    flags = a.flags & info.features
    print(f"{a.host}: W={info.w} F={info.f} cores={info.n_cores} clock {clock / 1e6:.1f} MHz, arithmetic id "
          f"{info.arith_id:#010x}, flags {flags} (asked {a.flags}), {width}x{height}, "
          f"{info.max_in_flight} in flight")
    print(f"{'view':16} {'level':>5} {'max_it':>6} {'tiles':>5} {'it/px':>7} {'wall s':>7} {'Mpx/s':>6} "
          f"{'G it/s':>6} {'MB/s':>6} {'busy':>5} {'compute':>7} {'link':>6}  bound")
    results, link_rate = [], None
    for name in names:
        re, im, units, max_it = VIEWS[name]
        level = level_for(info.f, units, lo, hi)
        view = View.centred(info.f, level, re, im, width, height)
        best = None
        for _ in range(a.repeat):
            t0 = time.perf_counter()
            st = c.render(view, width, height, max_it, flags, a.outcomes)
            wall = time.perf_counter() - t0
            if best is None or wall < best[0]:
                best = (wall, st)
        wall, st = best
        pixels = st["tiles"] * TILE * TILE
        tot = sorted(st["totals"], key=lambda t: t[1])
        busy = None
        if len(tot) > 1 and tot[-1][1] > tot[0][1]:
            busy = (tot[-1][0] - tot[0][0]) / ((tot[-1][1] - tot[0][1]) * info.n_cores)
        compute = st["iterations"] / (info.n_cores * clock)
        if name == "link":
            link_rate = st["tiles"] / wall
        link = st["tiles"] / link_rate if link_rate else None
        floors = {"compute": compute, "link": link or 0.0}
        bound = max(floors, key=floors.get)
        if wall > 1.5 * floors[bound]:
            bound = f"other ({wall / floors[bound]:.1f}x the {bound} floor)"
        results.append({"view": name, "level": level, "max_it": max_it, "tiles": st["tiles"],
                        "iterations": st["iterations"], "wire_bytes": st["wire_bytes"], "wall": wall,
                        "busy": busy, "compute": compute, "link": link, "bound": bound})
        print(f"{name:16} {level:5} {max_it:6} {st['tiles']:5} {st['iterations'] / pixels:7.1f} {wall:7.2f} "
              f"{pixels / wall / 1e6:6.1f} {st['iterations'] / wall / 1e9:6.2f} "
              f"{st['wire_bytes'] / wall / 1e6:6.1f} {'' if busy is None else f'{100 * busy:4.0f}%':>5} "
              f"{compute:7.2f} {'' if link is None else f'{link:6.2f}':>6}  {bound}")
        if a.outcomes:
            stuck = st["max_it_px"] * max_it
            esc_px = pixels - st["max_it_px"] - st["interior_px"]
            esc_it = st["iterations"] - stuck
            results[-1].update(max_it_px=st["max_it_px"], interior_px=st["interior_px"])
            print(f"{'':16} escaped {100 * esc_px / pixels:5.1f} % of pixels, "
                  f"{100 * esc_it / max(st['iterations'], 1):5.1f} % of iterations "
                  f"({esc_it / max(esc_px, 1):.0f} per pixel); "
                  f"max_it {100 * st['max_it_px'] / pixels:5.1f} % / {100 * stuck / max(st['iterations'], 1):5.1f} %; "
                  f"interior {100 * st['interior_px'] / pixels:5.1f} %")
    if a.json:
        with open(a.json, "a") as f:
            f.write(json.dumps({"date": time.strftime("%Y-%m-%d %H:%M"), "host": a.host, "w": info.w,
                                "cores": info.n_cores, "flags": flags, "size": [width, height],
                                "results": results}) + "\n")


if __name__ == "__main__":
    main()
