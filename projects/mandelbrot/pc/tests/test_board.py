"""The client against the real board (mandelbrotd). Skipped unless MANDELBROT_BOARD names it:

    MANDELBROT_BOARD=192.168.10.10 uv run pytest -q tests/test_board.py -s

Tiles are compared bit for bit with an exact integer model of the accelerator
(spinal/src/test/scala/mandelbrot/AccelModel.scala).
"""

import os
import time

import numpy as np
import pytest

from mandelbrot import protocol as p
from mandelbrot.net import Connection, ErrorResult, TileResult

HOST = os.environ.get("MANDELBROT_BOARD")
pytestmark = pytest.mark.skipif(not HOST, reason="set MANDELBROT_BOARD to the board's address")

MAG_FRAC = 22  # fraction bits of the |z|^2 the hardware converts to f32


def exact_tile(w, f, x0, y0, step, width, height, max_it):
    """Counts and |z|^2 (f32, truncated like the hardware), int64 fixed point."""
    half, mask = 1 << (w - 1), (1 << w) - 1
    wrap = lambda v: ((v + half) & mask) - half
    cx = (x0 + step * np.arange(width, dtype=np.int64))[None, :].repeat(height, 0).ravel()
    cy = (y0 - step * np.arange(height, dtype=np.int64))[:, None].repeat(width, 1).ravel()
    counts = np.full(cx.size, p.UNRESOLVED, np.uint32)
    zz = np.zeros(cx.size, np.float32)
    idx = np.arange(cx.size)
    a = np.zeros(cx.size, np.int64)
    b = np.zeros(cx.size, np.int64)
    for n in range(1, max_it + 1):
        if idx.size == 0:
            break
        a, b = wrap(((a * a - b * b) >> f) + cx), wrap(((a * b * 2) >> f) + cy)
        s = a * a + b * b
        esc = (s >> (2 * f + 2)) != 0
        if esc.any():
            mag = (s[esc] >> (2 * f - MAG_FRAC)) & 0xFFFFFFFF
            bits = np.frexp(mag.astype(np.float64))[1]  # bit length
            shift = np.maximum(bits - 24, 0)
            counts[idx[esc]] = n
            zz[idx[esc]] = (((mag >> shift) << shift).astype(np.float64) * 2.0 ** -MAG_FRAC).astype(np.float32)
            keep = ~esc
            idx, cx, cy, a, b = idx[keep], cx[keep], cy[keep], a[keep], b[keep]
    return counts.reshape(height, width), zz.reshape(height, width)


@pytest.fixture
def conn():
    with Connection(HOST) as c:
        yield c


def get(conn, timeout=10.0):
    return conn.results.get(timeout=timeout)


def test_info(conn):
    info = conn.info
    assert (info.version, info.w, info.f, info.bailout_r2, info.max_in_flight) == (1, 21, 16, 4, 8)
    assert info.features == p.FEATURE_BOARD_STATUS
    assert 150_000 < info.clock_khz < 250_000
    print(f"\nINFO: {info}")


@pytest.mark.parametrize("name,re0,im0,pitch,width,height,max_it", [
    ("whole set", -2.0, 1.25, 2.5 / 128, 160, 128, 300),
    ("boundary, deep", -0.7454, 0.1130, 0.00002, 64, 48, 2000),
    ("far outside", -15.9, 15.9, 0.4, 64, 64, 50),
    ("one pixel", 0.25, 0.0, 0.001, 1, 1, 5000),
    ("full tile", -1.0, 0.5, 1 / 256, 256, 256, 64),
])
def test_tile_is_exact(conn, name, re0, im0, pitch, width, height, max_it):
    f = conn.info.f
    x0, y0, step = round(re0 * 2**f), round(im0 * 2**f), max(1, round(pitch * 2**f))
    rid = conn.request(x0, y0, step, max_it, width, height)
    r = get(conn)
    assert isinstance(r, TileResult) and r.request_id == rid and r.complete
    counts, zz = exact_tile(conn.info.w, f, x0, y0, step, width, height, max_it)
    assert np.array_equal(r.counts, counts), f"{(r.counts != counts).sum()} counts differ"
    assert np.array_equal(r.zz.view(np.uint32), zz.view(np.uint32)), f"{(r.zz != zz).sum()} |z|^2 differ"
    want_it = int(np.where(counts == p.UNRESOLVED, max_it, counts).sum(dtype=np.int64))
    assert r.iterations == want_it


def test_errors(conn):
    f = conn.info.f
    cases = [
        (dict(x0=0, y0=0, step=1, max_it=10, width=257, height=1), p.Err.TILE_SIZE),
        (dict(x0=0, y0=0, step=1, max_it=0, width=4, height=4), p.Err.MAX_IT),
        (dict(x0=0, y0=0, step=1, max_it=10, width=4, height=4, flags=p.FLAG_LZ4), p.Err.FLAGS),
        (dict(x0=(1 << 20) - 2, y0=0, step=1, max_it=10, width=4, height=1), p.Err.COORDINATE),
        (dict(x0=0, y0=0, step=0, max_it=10, width=4, height=1), p.Err.COORDINATE),
    ]
    for kw, code in cases:
        rid = conn.request(**kw)
        r = get(conn)
        assert isinstance(r, ErrorResult) and (r.request_id, r.code) == (rid, code), r
    # still serving
    rid = conn.request(0, 0, 1 << (f - 4), 20, 8, 8)
    assert get(conn).request_id == rid


def test_cancel(conn):
    f = conn.info.f
    deep = dict(x0=round(-0.3 * 2**f), y0=round(0.2 * 2**f), step=8, max_it=p.MAX_MAX_IT, width=256, height=256)
    ids = [conn.request(**deep) for _ in range(3)]
    time.sleep(0.2)
    conn.cancel([ids[1]])
    r = get(conn)
    assert r.request_id == ids[1] and r.status == p.STATUS_ABORTED and r.counts is None
    conn.cancel()  # all
    rest = {get(conn).request_id, get(conn).request_id}
    assert rest == {ids[0], ids[2]}
    assert conn.in_flight == 0


def test_flow_control(conn):
    f = conn.info.f
    deep = dict(x0=round(-0.3 * 2**f), y0=round(0.2 * 2**f), step=8, max_it=p.MAX_MAX_IT, width=16, height=16)
    ids = [conn.request(**deep) for _ in range(conn.info.max_in_flight + 1)]
    r = get(conn)
    assert isinstance(r, ErrorResult) and r.code == p.Err.BUSY and r.request_id == ids[-1]
    conn.cancel()
    for _ in range(conn.info.max_in_flight):
        assert get(conn).status == p.STATUS_ABORTED


def test_status_and_ping(conn):
    conn.request_status()
    st = get(conn)
    assert isinstance(st, p.BoardStatus) and st.valid and 15 <= st.fpga_temp <= 95 and st.fan_rpm > 1000
    print(f"\nboard: {st}")


def test_throughput(conn):
    """Shallow 256x256 tiles, the window full. Over a slow link this measures the link."""
    f = conn.info.f
    step = round(3.0 / 1024 * 2**f)
    grid = [(round(-2.25 * 2**f) + c * 256 * step, round(1.5 * 2**f) - r * 256 * step) for r in range(4) for c in range(4)]
    n, sent, done, t0, nbytes = 48, 0, 0, time.monotonic(), 0
    while done < n:
        while sent < n and conn.free_slots > 0:
            x0, y0 = grid[sent % len(grid)]
            conn.request(x0, y0, step, 256)
            sent += 1
        r = get(conn, 30)
        assert isinstance(r, TileResult) and r.complete
        nbytes += r.wire_bytes
        done += 1
    dt = time.monotonic() - t0
    print(f"\n{n} tiles in {dt:.2f} s: {n / dt:.1f} tiles/s, {nbytes / dt / 1e6:.1f} MB/s, "
          f"{n * 65536 / dt / 1e6:.2f} M pixels/s")
