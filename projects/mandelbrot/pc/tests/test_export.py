"""Export (PC_APP_PLAN.md, milestone 6)."""

import struct
import time
import zlib

import numpy as np
import pytest

from mandelbrot.colouring import PRESETS, Colouring, bake, reference
from mandelbrot.export import Export
from mandelbrot.headless import render
from mandelbrot.net import Connection
from mandelbrot.sim_server import SimServer
from mandelbrot.tiles import TileManager, TileStore
from mandelbrot.view import View

W, H = 600, 400


def read_png(path) -> np.ndarray:
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos, idat, size = 8, b"", None
    while pos < len(data):
        n, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        assert struct.unpack(">I", data[pos + 8 + n:pos + 12 + n])[0] == zlib.crc32(kind + body)
        if kind == b"IHDR":
            size = struct.unpack(">II", body[:8])
        elif kind == b"IDAT":
            idat += body
        pos += 12 + n
    w, h = size
    rows = np.frombuffer(zlib.decompress(idat), np.uint8).reshape(h, 3 * w + 1)
    assert (rows[:, 0] == 0).all()
    return rows[:, 1:].reshape(h, w, 3)


@pytest.fixture
def setup():
    with SimServer(port=0) as s, Connection("127.0.0.1", s.port) as conn:
        mgr = TileManager(conn, TileStore(), max_it=200)
        yield conn, mgr


def run(mgr, view, cond, timeout=60.0):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        mgr.update(view, W, H)
        if cond():
            return
        time.sleep(0.005)
    raise AssertionError("timed out")


def test_export_2x_matches_a_direct_render(setup, tmp_path):
    conn, mgr = setup
    view = View.centred(54, 12, "-0.7", "0.2", W, H)
    c = Colouring(mode="smooth", density=1 / 32, offset=0.3, max_it=200, bailout_r2=256.0)
    palette = bake(PRESETS["ultra"])
    mgr.stop()  # nothing for the screen: only the export's side requests
    ex = Export(mgr, view, W, H, 2, c, palette, tmp_path / "out.png", raw=True)
    assert (ex.width, ex.height) == (2 * W, 2 * H) and ex.view.level == view.level + 4
    run(mgr, view, lambda: ex.done)
    assert ex.finished, ex.error
    assert ex.wait(5)

    counts, zz, _ = render(conn, ex.view, ex.width, ex.height, 200)  # the same view, fetched directly
    want = (reference(counts, zz, c, palette) * 255.0 + 0.5).astype(np.uint8)
    assert np.array_equal(read_png(tmp_path / "out.png"), want)
    assert np.array_equal(np.load(tmp_path / "out.counts.npy"), counts)
    assert np.array_equal(np.load(tmp_path / "out.zz.npy").view(np.uint32), zz.view(np.uint32))
    assert len(mgr.store) == 0  # the side requests stay out of the store


def test_export_1x_uses_the_screens_tiles(setup, tmp_path):
    conn, mgr = setup
    view = View.centred(54, 12, "-0.7", "0.2", W, H)
    run(mgr, view, lambda: mgr.complete and mgr.idle)
    received = mgr.stats.received
    ex = Export(mgr, view, W, H, 1, Colouring(max_it=200), bake(PRESETS["ultra"]), tmp_path / "s.png")
    assert ex.received == ex.total  # nothing to request
    assert ex.wait(10) and ex.finished and mgr.stats.received == received
    assert read_png(tmp_path / "s.png").shape == (H, W, 3)


def test_cancel_removes_the_files(setup, tmp_path):
    conn, mgr = setup
    view = View.centred(54, 12, "-0.7", "0.2", W, H)
    ex = Export(mgr, view, W, H, 4, Colouring(max_it=200), bake(PRESETS["ultra"]), tmp_path / "c.png", raw=True)
    ex.cancel()
    assert ex.wait(10) and ex.error == "cancelled" and not ex.finished
    assert not list(tmp_path.iterdir())
