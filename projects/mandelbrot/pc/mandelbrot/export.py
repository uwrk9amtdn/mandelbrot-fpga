"""Export (PC_APP_PLAN.md, milestone 6): the view as a PNG, at the screen's size or larger, and the raw
planes as .npy.

A larger render is the same view at a deeper level: factor 2^(m/4) more pixels per side is m levels
deeper (each level is 2^(1/4)), with the same centre. Its tiles come from the tile manager's store when
it has them (the screen's own, at factor 1) and otherwise as side requests (tiles.py), which are also
written to the disk cache. A writer thread colours each band of tiles (one tile row) with
colouring.reference, what the shader draws, and appends it to the PNG as soon as the band is complete,
so an 8x render (about 10k x 6k pixels, 1000 tiles) needs only a band of memory. With `raw`, counts
(u32) and the second plane (f32 |z|^2, or u32 k for proven-interior pixels; protocol.py) go to .npy
files through memory maps.
"""

from __future__ import annotations

import struct
import threading
import time
import zlib
from dataclasses import replace
from pathlib import Path

import numpy as np

from . import protocol as p
from .colouring import Colouring, reference
from .tiles import TileKey, TileManager, synth_tile
from .view import TILE, View, tile_origin, visible_tiles

FACTORS = {1: 0, 2: 4, 4: 8, 8: 12}  # pixels per side -> levels deeper


class PngWriter:
    """An RGB PNG written band by band (8 bits, no filter, one zlib stream over IDAT chunks)."""

    def __init__(self, path: Path, width: int, height: int):
        self.f = open(path, "wb")
        self.width, self.height, self.rows = width, height, 0
        self.z = zlib.compressobj(6)
        self.f.write(b"\x89PNG\r\n\x1a\n" + self._chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))

    @staticmethod
    def _chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    def add(self, rgb: np.ndarray):
        """Rows of u8 RGB, shape (n, width, 3)."""
        n = rgb.shape[0]
        rows = np.concatenate([np.zeros((n, 1), np.uint8), rgb.reshape(n, 3 * self.width)], axis=1)
        data = self.z.compress(rows.tobytes())
        if data:
            self.f.write(self._chunk(b"IDAT", data))
        self.rows += n

    def close(self):
        assert self.rows == self.height, f"{self.rows} of {self.height} rows"
        self.f.write(self._chunk(b"IDAT", self.z.flush()) + self._chunk(b"IEND", b""))
        self.f.close()

    def abort(self):
        self.f.close()


class Export:
    """One export. Call update() every frame until `done`; cancel() stops it and removes the files."""

    def __init__(self, mgr: TileManager, view: View, width: int, height: int, factor: int,
                 colouring: Colouring, palette: np.ndarray, path: Path, raw: bool = False):
        info = mgr.info
        self.mgr, self.factor = mgr, factor
        self.width, self.height = width * factor, height * factor
        level = view.level + FACTORS[factor]
        if level > mgr.hi:
            raise ValueError(f"{factor}x is deeper than the format allows (level {level} > {mgr.hi})")
        re, im = view.centre(info.f, width, height)
        self.view = View.centred(info.f, level, re, im, self.width, self.height)
        self.max_it, self.flags = mgr.max_it, mgr.flags
        self.colouring = replace(colouring, cdf=colouring.cdf.copy())
        self.palette = palette.copy()
        self.path = Path(path)
        self.raw_paths = [self.path.with_suffix(".counts.npy"), self.path.with_suffix(".zz.npy")] if raw else []
        self.started = time.monotonic()
        self.error: str | None = None
        self.finished = False
        self.elapsed = 0.0

        tiles = sorted(visible_tiles(self.view, self.width, self.height), key=lambda t: (t[1], t[0]))
        self.total = len(tiles)
        self.bands = sorted({ty for _, ty in tiles})
        self.band_tiles = {ty: [tx for tx, t in tiles if t == ty] for ty in self.bands}
        self.got: dict[tuple[int, int], tuple[np.ndarray, np.ndarray]] = {}
        self.received = 0
        self.cond = threading.Condition()
        self.cancelled = False

        for tx, ty in tiles:  # the store's tiles, those outside the format, the rest from the server
            key = TileKey(level, tx, ty, self.max_it, self.flags & p.RESULT_FLAGS)
            x0, y0, s = tile_origin(info.f, level, tx, ty)
            tile = mgr.store.get(key)
            if tile is not None:
                self._put(tx, ty, tile.counts, tile.zz)
            elif not p.TileReq(1, TILE, TILE, self.max_it, self.flags, x0, y0, s).fits(info.w):
                self._put(tx, ty, *synth_tile(info.f, x0, y0, s))
            else:
                mgr.request_side(x0, y0, s, self.max_it, self.flags, self._answer(key))

        self.png = PngWriter(self.path, self.width, self.height)
        self.raw = [np.lib.format.open_memmap(self.raw_paths[0], "w+", np.uint32, (self.height, self.width)),
                    np.lib.format.open_memmap(self.raw_paths[1], "w+", np.float32, (self.height, self.width))] \
            if raw else []
        self.bands_written = 0
        self.thread = threading.Thread(target=self._write, name="export", daemon=True)
        self.thread.start()

    # ---------------------------------------------------------------- tiles in

    def _put(self, tx: int, ty: int, counts: np.ndarray, zz: np.ndarray):
        with self.cond:
            self.got[(tx, ty)] = (counts, zz)
            self.received += 1
            self.cond.notify()

    def _answer(self, key: TileKey):
        def answer(r):
            if r is None or not hasattr(r, "counts"):
                self._fail("the connection closed" if r is None else f"server error {r.code}: {r.text}")
            elif not r.complete:
                self._fail("the server aborted a tile")
            else:
                if self.mgr.cache:
                    self.mgr.cache.store(self.mgr.cache_key(key), r.counts, r.zz, r.iterations)
                self._put(key.tx, key.ty, r.counts, r.zz)
        return answer

    def _fail(self, why: str):
        with self.cond:
            if self.error is None:
                self.error = why
            self.cond.notify()

    # ---------------------------------------------------------------- bands out

    def _write(self):
        try:
            for ty in self.bands:
                with self.cond:
                    while not (self.cancelled or self.error) and any((tx, ty) not in self.got
                                                                    for tx in self.band_tiles[ty]):
                        self.cond.wait()
                    if self.cancelled or self.error:
                        break
                    parts = [self.got.pop((tx, ty)) for tx in self.band_tiles[ty]]
                self._band(ty, parts)
                self.bands_written += 1
            else:
                self.png.close()
                for a in self.raw:
                    a.flush()
                self.elapsed = time.monotonic() - self.started
                self.finished = True
                return
        except Exception as e:  # noqa: BLE001 - a full disk, say: report it
            self.error = f"export failed: {e}"
        self._remove()

    def _band(self, ty: int, parts: list[tuple[np.ndarray, np.ndarray]]):
        """Crop one tile row to the image and write it."""
        v = self.view
        top = TILE * ty - v.y0
        y_lo, y_hi = max(top, 0), min(top + TILE, self.height)
        counts = np.concatenate([c for c, _ in parts], axis=1)
        zz = np.concatenate([z for _, z in parts], axis=1)
        left = TILE * self.band_tiles[ty][0] - v.x0  # the band's first tile, left of or at x = 0
        counts = counts[y_lo - top:y_hi - top, -left:-left + self.width]
        zz = zz[y_lo - top:y_hi - top, -left:-left + self.width]
        rgb = reference(counts, zz, self.colouring, self.palette)
        self.png.add((rgb * 255.0 + 0.5).astype(np.uint8))
        if self.raw:
            self.raw[0][y_lo:y_hi] = counts
            self.raw[1][y_lo:y_hi] = zz

    def _remove(self):
        self.png.abort()
        self.raw = []
        for path in [self.path, *self.raw_paths]:
            path.unlink(missing_ok=True)

    # ---------------------------------------------------------------- control

    @property
    def done(self) -> bool:
        return self.finished or self.error is not None

    def cancel(self):
        with self.cond:
            self.cancelled = True
            if self.error is None and not self.finished:
                self.error = "cancelled"
            self.cond.notify()

    def wait(self, timeout: float | None = None) -> bool:
        self.thread.join(timeout)
        return not self.thread.is_alive()

    def status(self) -> str:
        if self.finished:
            return f"saved {self.path.name} ({self.width}x{self.height}, {self.elapsed:.1f} s)"
        if self.error:
            return self.error
        return (f"{self.width}x{self.height}: tiles {self.received}/{self.total}, "
                f"bands {self.bands_written}/{len(self.bands)}")
