"""Verify tile and the exact simulated server (PC_APP_PLAN.md, milestone 6)."""

import time

import numpy as np
import pytest

from mandelbrot import protocol as p
from mandelbrot import verify
from mandelbrot.cache import DiskCache
from mandelbrot.net import Connection, TileResult
from mandelbrot.sim_server import SimServer
from mandelbrot.tiles import TileManager, TileStore
from mandelbrot.view import TILE, View, tile_origin

W, H = 600, 400
FLAGS = p.FLAG_PERIODICITY | p.FLAG_CARDIOID


def test_arith_id_is_the_bitstreams():
    assert verify.model_arith_id(64) == 0xAB210AE1  # what the W = 64 board reports (2026-11-19)


@pytest.fixture(scope="module")
def exact():
    with SimServer(port=0, w=64, f=54, bailout_r2=256, exact=True) as s:
        yield s
    verify.shutdown()


def run(mgr, view, cond, timeout=60.0):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        mgr.update(view, W, H)
        if cond():
            return
        time.sleep(0.01)
    raise AssertionError("timed out")


def verification(conn, mgr, view, max_it, flags, tamper=None):
    tx, ty = (view.x0 + W // 2) // TILE, (view.y0 + H // 2) // TILE
    x0, y0, s = tile_origin(conn.info.f, view.level, tx, ty)
    v = verify.Verification(conn.info, "test", x0, y0, s, max_it, flags)
    v.start_model(verify.pool())

    def answer(r):
        assert isinstance(r, TileResult) and r.complete
        counts = r.counts.copy()
        if tamper:
            tamper(counts)
        v.on_tile(counts, r.zz)
    mgr.request_side(x0, y0, s, max_it, flags, answer)
    end = time.monotonic() + 120
    while not v.done and time.monotonic() < end:
        mgr.update(view, W, H)
        v.update()
        time.sleep(0.01)
    assert v.done, "verification timed out"
    return v


def test_exact_server_and_verify(exact, tmp_path):
    cache = DiskCache(tmp_path / "tiles")
    view = View.centred(54, 24, "-1.2", "0.2", W, H)  # bulbs: escaping, cardioid and periodic pixels
    with Connection("127.0.0.1", exact.port) as conn:
        info = conn.info
        assert verify.model_applies(info) and info.features & FLAGS == FLAGS
        mgr = TileManager(conn, TileStore(), max_it=60, flags=FLAGS, cache=cache)
        mgr.stop()  # only the side request: nothing for the screen
        v = verification(conn, mgr, view, 60, FLAGS)
        assert v.error is None and v.n_wrong == 0, v.result
        counts = (v.board & np.uint64(0xFFFFFFFF)).astype(np.uint32)
        assert (counts == p.INTERIOR).any() and (counts < 61).any()
        assert ((v.board >> np.uint64(32))[counts == p.INTERIOR] > 0).any()  # proven by period
        # the side request went to neither the store nor the cache
        assert len(mgr.store) == 0 and mgr.stats.received == 0
        cache.flush()
        assert cache.size == 0

        def flip(c):
            c[3, 5] = 7
        v = verification(conn, mgr, view, 60, FLAGS, tamper=flip)
        assert v.n_wrong == 1 and (v.mismatches[0].x, v.mismatches[0].y) == (5, 3)
        assert verify.describe(v.mismatches[0].got).startswith("n = 7")
    cache.close()


def test_fast_server_is_not_the_model():
    with SimServer(port=0) as s:
        assert not verify.model_applies(s.info)
        assert not s.info.features & p.FLAG_PERIODICITY
