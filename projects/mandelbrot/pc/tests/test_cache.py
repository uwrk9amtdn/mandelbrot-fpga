"""The disk cache (PC_APP_PLAN.md, milestone 5)."""

import os
import time

import numpy as np
import pytest

from mandelbrot import protocol as p
from mandelbrot.cache import CacheKey, DiskCache, decode, encode
from mandelbrot.net import Connection, OfflineConnection
from mandelbrot.sim_server import SimServer
from mandelbrot.tiles import TileManager, TileStore
from mandelbrot.view import TILE, View, visible_tiles

W, H = 600, 400


def key(**kw) -> CacheKey:
    base = dict(arith_id=0x1234ABCD, w=64, f=54, step=1 << 40, tx=3, ty=-2, width=TILE, height=TILE,
                max_it=100, flags=0)
    base.update(kw)
    return CacheKey(**base)


def tile(max_it=100, unresolved=True, seed=0):
    rng = np.random.default_rng(seed)
    counts = rng.integers(1, max_it + 1, (TILE, TILE)).astype(np.uint32)
    zz = rng.uniform(256, 1e4, (TILE, TILE)).astype(np.float32)
    counts[:10, :10] = p.INTERIOR
    zz[:10, :10] = 0
    if unresolved:
        counts[-10:, -10:] = p.UNRESOLVED
        zz[-10:, -10:] = 0
    return counts, zz


@pytest.fixture
def cache(tmp_path):
    c = DiskCache(tmp_path / "tiles", start=False)  # synchronous: read/write called directly
    yield c


def test_key_canonical():
    k = key(tx=-(1 << 120) - 7, step=12345678901234567890123)
    assert k.text() == f"{0x1234ABCD}|64|54|12345678901234567890123|{-(1 << 120) - 7}|-2|256|256|100|0"
    assert k.relpath() == key(tx=-(1 << 120) - 7, step=12345678901234567890123, max_it=5000).relpath()
    paths = {key(**{f: v}).relpath() for f, v in
             [("arith_id", 1), ("w", 128), ("f", 120), ("step", 7), ("tx", 4), ("ty", 2), ("flags", 1),
              ("width", 128)]}
    assert len(paths) == 8 and key().relpath() not in paths
    assert str(key().relpath()).startswith("1234abcd")


def test_roundtrip(cache):
    c, z = tile()
    cache.write(key(), c, z, 999)
    t = cache.read(key())
    assert np.array_equal(t.counts, c) and np.array_equal(t.zz, z) and t.iterations == 999


@pytest.mark.parametrize("damage", ["truncate", "flip", "garbage", "empty"])
def test_damaged_is_a_miss_and_deleted(cache, damage):
    c, z = tile()
    cache.write(key(), c, z, 1)
    path = cache.path(key())
    blob = bytearray(path.read_bytes())
    if damage == "truncate":
        blob = blob[:len(blob) // 2]
    elif damage == "flip":
        blob[-100] ^= 0x10
    elif damage == "garbage":
        blob[:4] = b"XXXX"
    else:
        blob = b""
    path.write_bytes(bytes(blob))
    assert cache.read(key()) is None and cache.damaged == 1
    job = cache._jobs.get_nowait()  # the deletion goes through the writer
    assert job == ("delete", path)


def test_key_mismatch_is_damage(cache):
    c, z = tile()
    blob = encode(key(tx=99), c, z, 1)
    path = cache.path(key())
    path.parent.mkdir(parents=True)
    path.write_bytes(blob)
    assert cache.read(key()) is None and cache.damaged == 1


def test_lower_max_it(cache):
    c, z = tile(max_it=100)
    proof = z.view(np.uint32)  # proven-interior pixels carry the iteration of the proof
    proof[:10, :3] = 30
    proof[:10, 3:6] = 60  # proven after iteration 40: a run to 40 doesn't get there
    cache.write(key(max_it=100), c, z, 1)
    t = cache.read(key(max_it=40))
    above = ((c > 40) & (c != p.INTERIOR)) | ((c == p.INTERIOR) & (proof > 40))
    assert np.array_equal(t.counts[~above], c[~above]) and (t.counts[above] == p.UNRESOLVED).all()
    assert (t.zz[above] == 0).all() and np.array_equal(t.zz.view(np.uint32)[~above], proof[~above])
    assert (t.counts[:10, :3] == p.INTERIOR).all() and (t.counts[:10, 6:10] == p.INTERIOR).all()
    assert (t.counts[:10, 3:6] == p.UNRESOLVED).all()
    t = cache.read(key(max_it=60))  # k = 60 is reached by a run to 60
    assert (t.counts[:10, :10] == p.INTERIOR).all()


def test_higher_max_it(cache):
    c, z = tile(unresolved=True)
    cache.write(key(max_it=100), c, z, 1)
    assert cache.read(key(max_it=200)) is None  # has unresolved pixels
    assert cache.damaged == 0 and cache.path(key()).exists()
    c, z = tile(unresolved=False)
    cache.write(key(max_it=100, ty=5), c, z, 1)
    t = cache.read(key(max_it=100000, ty=5))  # no unresolved pixel: answers any max_it
    assert np.array_equal(t.counts, c)


def test_replace_only_upwards(cache):
    c1, z1 = tile(max_it=500, seed=1)
    cache.write(key(max_it=500), c1, z1, 1)
    c2, z2 = tile(max_it=100, seed=2)
    cache.write(key(max_it=100), c2, z2, 2)  # the file at 500 answers 100 already
    assert cache.read(key(max_it=500)).iterations == 1
    c3, z3 = tile(max_it=1000, seed=3)
    cache.write(key(max_it=1000), c3, z3, 3)
    assert cache.read(key(max_it=1000)).iterations == 3
    assert len(list(cache.root.glob("*/*/*"))) == 1


def test_eviction(cache):
    c, z = tile()
    one = len(encode(key(), c, z, 1))
    cache.limit = 10 * one + 100  # tx=10 has a longer key
    for i in range(10):
        cache.write(key(tx=i), c, z, 1)
        os.utime(cache.path(key(tx=i)), (1000 + i, 1000 + i))
    cache.read(key(tx=0))  # a hit makes tx=0 the most recent
    assert cache.size == 10 * one
    cache.write(key(tx=10), c, z, 1)  # 11 files: over the limit, down to 9
    left = {t for t in range(11) if cache.path(key(tx=t)).exists()}
    assert left == {0, 3, 4, 5, 6, 7, 8, 9, 10} and cache.size == 9 * one + 1


def test_scan_and_clear(tmp_path):
    root = tmp_path / "tiles"
    c, z = tile()
    sync = DiskCache(root, start=False)
    sync.write(key(), c, z, 1)
    sync.write(key(arith_id=7), c, z, 1)
    (sync.path(key()).parent / "junk.mbt.1.tmp").write_bytes(b"x")
    cache = DiskCache(root)
    cache.flush()
    one = sync.path(key()).stat().st_size
    seven = sync.path(key(arith_id=7)).stat().st_size
    assert cache.scanned and cache.sizes == {0x1234ABCD: one, 7: seven}
    assert not list(root.glob("*/*/*.tmp"))
    cache.clear(7)
    cache.flush()
    assert cache.sizes == {0x1234ABCD: one} and not (root / "00000007").exists()
    cache.clear()
    cache.flush()
    assert cache.size == 0 and not list(root.iterdir())
    cache.close()


def test_decode_refuses_wrong_size():
    c, z = tile()
    blob = encode(key(), c, z, 1)
    assert decode(key(), blob) is not None
    assert decode(key(max_it=101), blob) is None


# --- with the tile manager -----------------------------------------------------------------------


def run_until(mgr, view, cond, timeout=20.0):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        mgr.update(view, W, H)
        if cond():
            return
        time.sleep(0.005)
    raise AssertionError("timed out")


@pytest.fixture
def sim():
    with SimServer(port=0, w=64, f=54, bailout_r2=256) as s:
        yield s


def test_second_render_all_hits(sim, tmp_path):
    cache = DiskCache(tmp_path / "tiles")
    view = View.centred(54, 20, "-0.7", "0.1", W, H)
    n = len(visible_tiles(view, W, H))
    with Connection("127.0.0.1", sim.port) as conn:
        cache.save_info(conn.info)
        mgr = TileManager(conn, TileStore(), max_it=200, cache=cache)
        run_until(mgr, view, lambda: mgr.complete and mgr.idle)
        assert mgr.stats.received >= n and mgr.stats.from_cache == 0
        first = {t.key: t.counts.copy() for t in mgr.store.tiles()}
    cache.flush()
    assert cache.size > 0

    with Connection("127.0.0.1", sim.port) as conn:
        mgr = TileManager(conn, TileStore(), max_it=200, cache=cache)
        hits0 = cache.hits
        run_until(mgr, view, lambda: mgr.complete and mgr.idle)
        assert mgr.stats.requested == 0 and cache.hits - hits0 >= n
        for t in mgr.store.tiles():
            assert np.array_equal(t.counts, first[t.key])

        # a higher max_it: only tiles with unresolved pixels are requested again
        unresolved = sum(1 for t in mgr.store.tiles() if (t.counts == p.UNRESOLVED).any())  # with previews
        mgr.set_render(400, 0)
        run_until(mgr, view, lambda: mgr.complete and mgr.idle)
        current = [t for t in mgr.store.tiles() if t.key.level == view.level and t.key.max_it == 400]
        assert len(current) == n and 0 < unresolved < len(mgr.store.tiles()) // 2
        assert mgr.stats.received == unresolved

        # R (refresh): the visible tiles come from the server again, the previews from the cache
        received = mgr.stats.received
        mgr.refresh()
        run_until(mgr, view, lambda: mgr.complete and mgr.idle)
        assert mgr.stats.received - received == n

        # bypass: everything comes from the server again, previews too
        received, from_cache = mgr.stats.received, mgr.stats.from_cache
        mgr.store.clear()
        mgr.bypass = True
        run_until(mgr, view, lambda: mgr.complete and mgr.idle)
        assert mgr.stats.received - received > n and mgr.stats.from_cache == from_cache
    cache.close()


def test_offline(sim, tmp_path):
    root = tmp_path / "tiles"
    cache = DiskCache(root)
    view = View.centred(54, 20, "-0.7", "0.1", W, H)
    with Connection("127.0.0.1", sim.port) as conn:
        cache.save_info(conn.info)
        mgr = TileManager(conn, TileStore(), max_it=200, cache=cache)
        run_until(mgr, view, lambda: mgr.complete and mgr.idle)
    cache.flush()

    infos = DiskCache.known_servers(root)
    assert [i.arith_id for i in infos] == [sim.info.arith_id]
    off = OfflineConnection(infos[0])
    assert not off.info.features & p.FEATURE_BOARD_STATUS
    mgr = TileManager(off, TileStore(), max_it=200, cache=cache, offline=True)
    run_until(mgr, view, lambda: mgr.complete and mgr.idle)
    assert mgr.missing(view, W, H) == []

    moved = view.pan(-TILE, 0)  # one column of tiles never rendered
    run_until(mgr, moved, lambda: mgr.idle and mgr.missing(moved, W, H))
    assert mgr.stats.requested == 0 and not mgr.complete
    missing = mgr.missing(moved, W, H)
    assert 0 < len(missing) < len(visible_tiles(moved, W, H))
    cache.close()
