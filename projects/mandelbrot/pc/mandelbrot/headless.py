"""Render a view without a window: for tests, and to check a server or the board from a shell.

  python -m mandelbrot.headless out.png                          # the whole set, from a server on localhost
  python -m mandelbrot.headless out.png --host 192.168.1.50 --re -0.743 --im 0.131 --level 60
  python -m mandelbrot.headless out.png --sim                     # starts its own simulated server
"""

import argparse
import struct
import time
import zlib

import numpy as np

from . import protocol as p
from .net import Closed, Connection, ErrorResult
from .tiles import synth_tile
from .view import TILE, View, max_level, min_level, tile_origin, visible_tiles


def render(conn: Connection, view: View, width: int, height: int, max_it: int, flags: int = 0,
           timeout: float = 60.0):
    """Fetch the tiles of a view, nearest to the centre first, keeping to the server's flow control.

    Returns (counts u32, |z|^2 f32, statistics), the arrays of shape (height, width).
    """
    info = conn.info
    counts = np.zeros((height, width), np.uint32)
    zz = np.zeros((height, width), np.float32)
    stats = {"tiles": 0, "synthesized": 0, "iterations": 0, "wire_bytes": 0}

    def place(tx, ty, tile_counts, tile_zz):
        # the part of the tile that is on the screen
        left, top = TILE * tx - view.x0, TILE * ty - view.y0
        x_lo, x_hi = max(left, 0), min(left + TILE, width)
        y_lo, y_hi = max(top, 0), min(top + TILE, height)
        counts[y_lo:y_hi, x_lo:x_hi] = tile_counts[y_lo - top:y_hi - top, x_lo - left:x_hi - left]
        zz[y_lo:y_hi, x_lo:x_hi] = tile_zz[y_lo - top:y_hi - top, x_lo - left:x_hi - left]

    todo = []
    for tx, ty in visible_tiles(view, width, height):
        x0, y0, step = tile_origin(info.f, view.level, tx, ty)
        if p.TileReq(1, TILE, TILE, max_it, flags, x0, y0, step).fits(info.w):
            todo.append((tx, ty, x0, y0, step))
        else:
            place(tx, ty, *synth_tile(info.f, x0, y0, step))
            stats["synthesized"] += 1

    todo.reverse()  # pop() takes the nearest first
    waiting = {}  # request id -> (tx, ty)
    while todo or waiting:
        while todo and conn.free_slots > 0:
            tx, ty, x0, y0, step = todo.pop()
            waiting[conn.request(x0, y0, step, max_it, flags=flags)] = (tx, ty)
        result = conn.results.get(timeout=timeout)
        if isinstance(result, Closed):
            raise ConnectionError(result.reason)
        if isinstance(result, ErrorResult):
            raise RuntimeError(f"server error {result.code}: {result.text}")
        if result.request_id not in waiting:
            continue  # left over from an earlier, cancelled render
        tx, ty = waiting.pop(result.request_id)
        if not result.complete:
            raise RuntimeError("tile aborted")
        place(tx, ty, result.counts, result.zz)
        stats["tiles"] += 1
        stats["iterations"] += result.iterations
        stats["wire_bytes"] += result.wire_bytes
    return counts, zz, stats


def colour(counts: np.ndarray) -> np.ndarray:
    """A plain escape-time colouring, RGB u8. The real colouring lives in the viewer's shader."""
    t = np.log2(counts.astype(np.float64) + 1.0) * 0.9
    rgb = np.stack([0.5 + 0.5 * np.cos(t + phase) for phase in (3.3, 4.2, 5.2)], axis=-1)
    rgb[counts >= p.INTERIOR] = 0.0
    return (rgb * 255.0 + 0.5).astype(np.uint8)


def write_png(path: str, rgb: np.ndarray):
    height, width, _ = rgb.shape

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    rows = np.concatenate([np.zeros((height, 1), np.uint8), rgb.reshape(height, 3 * width)], axis=1)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(rows.tobytes(), 6)) + chunk(b"IEND", b""))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("output", help="PNG file to write")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=p.PORT)
    ap.add_argument("--sim", action="store_true", help="start a simulated server instead of connecting")
    ap.add_argument("--re", default="-0.75", help="centre, real part (decimal text or a fraction)")
    ap.add_argument("--im", default="0", help="centre, imaginary part")
    ap.add_argument("--level", type=int, help="zoom level: 4 levels halve the pixel step, which is 1/4 at 0 "
                    "(default: the whole set)")
    ap.add_argument("--size", default="1280x720", help="image size in pixels, WxH")
    ap.add_argument("--max-it", type=int, default=500)
    ap.add_argument("--raw", action="store_true", help="don't ask for LZ4")
    ap.add_argument("--npy", help="also save the count plane to this .npy file")
    a = ap.parse_args()
    width, height = map(int, a.size.lower().split("x"))

    server = None
    if a.sim:
        from .sim_server import SimServer
        server = SimServer(port=0).start()
        a.host, a.port = "127.0.0.1", server.port
    try:
        with Connection(a.host, a.port) as conn:
            info = conn.info
            lo, hi = min_level(info.w, info.f, info.bailout_r2), max_level(info.f)
            # default: 3.2 units across the image
            level = a.level if a.level is not None else lo
            if a.level is None:
                while level < hi and width * 2.0 ** (-2 - (level + 1) / 4) >= 3.2:
                    level += 1
            if not lo <= level <= hi:
                raise SystemExit(f"level {level} is outside {lo}..{hi}, the range of this server "
                                 f"(W={info.w}, F={info.f})")
            view = View.centred(info.f, level, a.re, a.im, width, height)
            flags = (0 if a.raw else p.FLAG_LZ4) & info.features
            start = time.perf_counter()
            counts, _zz, stats = render(conn, view, width, height, a.max_it, flags)
            seconds = time.perf_counter() - start
            board = None
            if info.features & p.FEATURE_BOARD_STATUS:
                conn.request_status()
                while not isinstance(board := conn.results.get(timeout=5), p.BoardStatus):
                    pass
    finally:
        if server:
            server.close()

    write_png(a.output, colour(counts))
    if a.npy:
        np.save(a.npy, counts)
    print(f"W={info.w} F={info.f} R^2={info.bailout_r2} cores={info.n_cores} "
          f"arithmetic id {info.arith_id:#010x}")
    print(f"level {level}: {stats['tiles']} tiles (+{stats['synthesized']} outside the format) in "
          f"{seconds:.2f} s, {stats['iterations'] / 1e6:.1f} M iterations, "
          f"{stats['wire_bytes'] / 1e6:.2f} MB received")
    if board is not None:
        print(f"board: FPGA {board.fpga_temp} °C, board {board.board_temp} °C, fan {board.fan_rpm} RPM"
              f"{'' if board.valid else ' (not valid)'}")
    print(f"wrote {a.output} ({width}x{height})")


if __name__ == "__main__":
    main()
