"""TileManager and TileStore against the simulated server."""

import time

import numpy as np
import pytest

from mandelbrot import protocol as p
from mandelbrot.net import Connection
from mandelbrot.sim_server import SimServer
from mandelbrot.tiles import PREVIEW_LEVELS, TileKey, TileManager, TileStore
from mandelbrot.view import TILE, View, step, visible_tiles

W, H = 700, 450


def run_until(mgr, view, cond, timeout=20.0, width=W, height=H):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        mgr.update(view, width, height)
        if cond():
            return
        time.sleep(0.01)
    raise AssertionError("timed out")


@pytest.fixture
def sim():
    with SimServer(port=0, w=64, f=54, bailout_r2=256) as s:
        yield s


@pytest.fixture
def slow_sim():
    with SimServer(port=0, w=64, f=54, bailout_r2=256, tile_delay=0.3, workers=8) as s:
        yield s


def test_store_lru():
    store = TileStore(capacity=3)
    z = np.zeros((TILE, TILE), np.float32)
    keys = [TileKey(0, i, 0, 10, 0) for i in range(4)]
    for k in keys[:3]:
        store.put(k, np.zeros((TILE, TILE), np.uint32), z, 0)
    assert sorted(t.layer for t in store.tiles()) == [0, 1, 2]
    store.get(keys[0])  # now the most recent
    t3 = store.put(keys[3], np.zeros((TILE, TILE), np.uint32), z, 0)
    assert keys[1] not in store and keys[0] in store and t3.layer == 1  # the LRU one's layer
    ups = store.take_uploads()
    assert [t.key for t in ups] == [keys[0], keys[2], keys[3]]  # keys[1] was evicted
    assert store.take_uploads() == []


def test_view_completes_and_draws(sim):
    with Connection("127.0.0.1", sim.port) as conn:
        mgr = TileManager(conn, TileStore(), max_it=100)
        view = View.centred(conn.info.f, 20, "-0.7", "0", W, H)
        run_until(mgr, view, lambda: mgr.complete)
        quads = [q for q in mgr.draw_list(view, W, H) if q.size == TILE]  # without the previews
        n = len(visible_tiles(view, W, H))
        assert len(quads) == n
        # the quads cover the screen
        cover = np.zeros((H, W), bool)
        for q in quads:
            x, y = int(q.x), int(q.y)
            cover[max(y, 0):max(y + TILE, 0), max(x, 0):max(x + TILE, 0)] = True
        assert cover.all()
        assert not mgr.pending


def test_previews_first(slow_sim):
    with Connection("127.0.0.1", slow_sim.port) as conn:
        mgr = TileManager(conn, TileStore(), max_it=50)
        level = mgr.lo + PREVIEW_LEVELS + 3
        view = View.centred(conn.info.f, level, "-0.75", "0.1", W, H)
        mgr.update(view, W, H)
        levels = [k.level for k in mgr.pending.values()]
        assert levels[0] == level - PREVIEW_LEVELS  # previews go first
        assert level in levels
        run_until(mgr, view, lambda: mgr.complete)
        quads = mgr.draw_list(view, W, H)
        previews = [q for q in quads if q.size != TILE]
        assert previews and quads[: len(previews)] == previews  # drawn underneath
        ratio = step(conn.info.f, level - PREVIEW_LEVELS) / step(conn.info.f, level)
        assert previews[0].size == pytest.approx(TILE * ratio)


def test_pan_cancels_only_what_left(slow_sim):
    with Connection("127.0.0.1", slow_sim.port) as conn:
        mgr = TileManager(conn, TileStore(), max_it=50)
        view = View(40, 0, 0)
        mgr.update(view, W, H)
        before = set(mgr.pending.values())
        moved = view.pan(-3 * TILE, 0)  # 3 tiles to the right
        mgr.update(moved, W, H)
        still = {mgr.key(40, tx, ty) for tx, ty in visible_tiles(moved, W, H)}
        still |= set(mgr._previews(moved, W, H))  # a preview tile can cover both views
        cancelled = {mgr.pending[r] for r in mgr.cancelled}
        assert cancelled == {k for k in before if k not in still}
        assert all(k in mgr.pending.values() for k in before & still)  # these keep running
        run_until(mgr, moved, lambda: mgr.complete and not mgr.pending, width=W, height=H)
        assert mgr.stats.aborted + mgr.stats.received >= len(before)


def test_max_it_change_keeps_old_tiles_underneath(sim):
    with Connection("127.0.0.1", sim.port) as conn:
        mgr = TileManager(conn, TileStore(), max_it=30)
        view = View.centred(conn.info.f, 18, "-0.5", "0", W, H)
        run_until(mgr, view, lambda: mgr.complete)
        old = {t.key for t in mgr.store.tiles()}
        mgr.set_render(60, 0)
        mgr.update(view, W, H)
        assert not mgr.complete
        assert len(mgr.draw_list(view, W, H)) >= len(old)  # the max_it 30 tiles are still drawn
        run_until(mgr, view, lambda: mgr.complete)
        assert all(k.max_it == 60 for k in mgr.pending.values())


def test_tiles_outside_the_format_are_synthesized():
    # the hardware format: W = 21, F = 16 (|c| < 16), R^2 = 4
    with SimServer(port=0, w=21, f=16, bailout_r2=4) as s, Connection("127.0.0.1", s.port) as conn:
        mgr = TileManager(conn, TileStore(), max_it=20)
        view = View.centred(conn.info.f, mgr.lo, "-14", "0", W, H)  # near the edge of the format
        run_until(mgr, view, lambda: mgr.complete)
        assert mgr.stats.synthesized > 0 and mgr.stats.errors == 0
        synth = [t for t in mgr.store.tiles() if t.iterations == 0]
        assert all((t.counts == 1).all() for t in synth)


def test_refused_tile_is_not_requested_again(sim):
    with Connection("127.0.0.1", sim.port) as conn:
        mgr = TileManager(conn, TileStore(), max_it=20)
        mgr.flags = p.FLAG_PERIODICITY  # the simulated server doesn't have it
        view = View.centred(conn.info.f, 20, "0", "0", 300, 300)
        run_until(mgr, view, lambda: not mgr.pending and mgr.failed, width=300, height=300)
        n = mgr.stats.requested
        for _ in range(5):
            mgr.update(view, 300, 300)
        assert mgr.stats.requested == n and mgr.last_error.startswith("error 4")
