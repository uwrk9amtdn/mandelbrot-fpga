"""Tile management for the viewer (PC_APP_PLAN.md, "Tiling and display").

No OpenGL here, so all of it can be tested: the store hands out layers of the GPU texture arrays and
records which tiles need uploading; gl_view.py does the uploads and the drawing.

- Visible tiles of the current level are requested centre-out, keeping to the server's flow control.
- Previews: while the screen is not complete, the tiles of level L - 12 covering it go first. They
  are about 1/64 of the work and are drawn scaled underneath.
- Tiles of other levels already in the store are drawn underneath too, scaled, so a zoom or a
  change of max_it shows something at once.
- Requests whose tile is no longer wanted (it left the screen, or the level or max_it changed) are
  cancelled; the others keep running.
- Tiles outside the W-bit format are filled in here: every pixel escapes at n = 1 with z = c.
"""

import time
from collections import OrderedDict
from dataclasses import dataclass, field
from fractions import Fraction

import numpy as np

from . import protocol as p
from .net import Closed, Connection, ErrorResult, TileResult
from .view import TILE, View, max_level, min_level, step, tile_origin, visible_tiles

PREVIEW_LEVELS = 12  # previews come from level L - 12: a step about 8 times larger
DRAW_LEVELS = 12  # tiles of other levels are drawn underneath up to this many levels away


@dataclass(frozen=True)
class TileKey:
    level: int
    tx: int
    ty: int
    max_it: int
    flags: int  # the result-changing request flags


@dataclass
class Tile:
    key: TileKey
    layer: int  # in the GPU texture arrays
    counts: np.ndarray  # u32 (256, 256)
    zz: np.ndarray  # f32 (256, 256)
    iterations: int


@dataclass(frozen=True)
class Quad:
    """A tile on the screen: its layer, and its top-left corner and size in screen pixels."""

    layer: int
    x: float
    y: float
    size: float


def synth_tile(f_bits: int, x0: int, y0: int, step_: int) -> tuple[np.ndarray, np.ndarray]:
    """A tile outside the W-bit format: every pixel has |c| >= R, so it escapes at n = 1 with z = c."""
    xs = np.array([float(x0 + i * step_) for i in range(TILE)]) * 2.0 ** -f_bits
    ys = np.array([float(y0 - j * step_) for j in range(TILE)]) * 2.0 ** -f_bits
    zz = (xs[None, :] ** 2 + ys[:, None] ** 2).astype(np.float32)
    return np.ones((TILE, TILE), np.uint32), zz


class TileStore:
    """In-memory LRU of tiles; each owns one layer of the texture arrays."""

    def __init__(self, capacity: int = 256):
        self.capacity = capacity
        self._tiles: OrderedDict[TileKey, Tile] = OrderedDict()
        self._free = list(range(capacity - 1, -1, -1))
        self._uploads: list[Tile] = []

    def __len__(self):
        return len(self._tiles)

    def __contains__(self, key: TileKey) -> bool:
        return key in self._tiles

    def get(self, key: TileKey) -> Tile | None:
        tile = self._tiles.get(key)
        if tile is not None:
            self._tiles.move_to_end(key)
        return tile

    def touch(self, key: TileKey):
        if key in self._tiles:
            self._tiles.move_to_end(key)

    def put(self, key: TileKey, counts: np.ndarray, zz: np.ndarray, iterations: int) -> Tile:
        tile = self._tiles.pop(key, None)
        if tile is None:
            if self._free:
                layer = self._free.pop()
            else:
                _old_key, old = self._tiles.popitem(last=False)  # least recently used
                layer = old.layer
            tile = Tile(key, layer, counts, zz, iterations)
        else:
            tile.counts, tile.zz, tile.iterations = counts, zz, iterations
        self._tiles[key] = tile
        self._uploads.append(tile)
        return tile

    def tiles(self) -> list[Tile]:
        return list(self._tiles.values())

    def take_uploads(self) -> list[Tile]:
        """The tiles stored since the last call, for the GPU (a layer reused since is skipped)."""
        uploads, self._uploads = self._uploads, []
        return [t for t in uploads if self._tiles.get(t.key) is t]

    def clear(self):
        self._tiles.clear()
        self._free = list(range(self.capacity - 1, -1, -1))
        self._uploads = []


@dataclass
class Stats:
    requested: int = 0
    received: int = 0  # complete tiles
    aborted: int = 0
    synthesized: int = 0
    errors: int = 0
    iterations: int = 0
    wire_bytes: int = 0
    # (monotonic time, total iterations, total cycles, wire bytes so far) of recent tiles, for rates
    history: list = field(default_factory=list)

    def rates(self, n_cores: int, window: float = 2.0) -> dict:
        """tiles/s, MB/s, G iterations/s and FPGA utilisation over the last `window` seconds."""
        now = time.monotonic()
        recent = [h for h in self.history if now - h[0] <= window]
        if len(recent) < 2 or recent[-1][0] <= recent[0][0]:
            return {}
        (t0, it0, cy0, b0, n0), (t1, it1, cy1, b1, n1) = recent[0], recent[-1]
        dt = t1 - t0
        out = {"tiles/s": (n1 - n0) / dt, "MB/s": (b1 - b0) / dt / 1e6, "G it/s": (it1 - it0) / dt / 1e9}
        if cy1 > cy0:
            out["utilisation"] = (it1 - it0) / ((cy1 - cy0) * n_cores)
        return out


class TileManager:
    """Keeps the tiles of a view coming from one connection. Call `update` once per frame."""

    def __init__(self, conn: Connection, store: TileStore, max_it: int = 256, flags: int = 0):
        self.conn = conn
        self.info = conn.info
        self.store = store
        self.max_it = max_it
        self.flags = flags & p.KNOWN_FLAGS
        self.lo = min_level(self.info.w, self.info.f, self.info.bailout_r2)
        self.hi = max_level(self.info.f)
        self.pending: dict[int, TileKey] = {}  # request id -> tile
        self.requested: dict[TileKey, int] = {}  # tile -> request id
        self.cancelled: set[int] = set()  # cancelled, result not back yet
        self.failed: set[TileKey] = set()  # the server refused them; not asked again
        self.stats = Stats()
        self.board: p.BoardStatus | None = None
        self.last_error: str | None = None
        self.closed: str | None = None
        self.complete = False  # every visible tile of the current view is there
        self.paused = False  # no new requests (Esc in the viewer); a view change or refresh resumes

    def key(self, level: int, tx: int, ty: int) -> TileKey:
        return TileKey(level, tx, ty, self.max_it, self.flags & p.RESULT_FLAGS)

    def set_render(self, max_it: int, flags: int):
        self.max_it = max(1, min(max_it, self.info.max_max_it))
        self.flags = flags & p.KNOWN_FLAGS & self.info.features
        self.failed.clear()

    def refresh(self):
        """Drop every tile, so the visible ones are requested again."""
        self.store.clear()
        self.failed.clear()
        self.paused = False

    def stop(self):
        """Cancel everything in flight and request nothing more until `resume`."""
        self.paused = True
        if self.pending:
            self.conn.cancel()
            self.cancelled.update(self.pending)

    def resume(self):
        self.paused = False

    # ------------------------------------------------------------------------------- per frame

    def update(self, view: View, width: int, height: int):
        self._receive()
        if self.closed:
            return
        current = [self.key(view.level, tx, ty) for tx, ty in visible_tiles(view, width, height)]
        self.complete = all(k in self.store for k in current)
        wanted = current if self.complete else self._previews(view, width, height) + current
        wanted_set = set(wanted)

        stale = [rid for rid, key in self.pending.items() if key not in wanted_set and rid not in self.cancelled]
        if stale:
            self.conn.cancel(stale)
            self.cancelled.update(stale)
        if self.paused:
            return

        for key in wanted:
            if key in self.store or key in self.requested or key in self.failed:
                continue
            x0, y0, s = tile_origin(self.info.f, key.level, key.tx, key.ty)
            if not p.TileReq(1, TILE, TILE, key.max_it, self.flags, x0, y0, s).fits(self.info.w):
                self.store.put(key, *synth_tile(self.info.f, x0, y0, s), iterations=0)
                self.stats.synthesized += 1
                continue
            if self.conn.free_slots <= 0:
                break
            rid = self.conn.request(x0, y0, s, key.max_it, flags=self.flags)
            self.pending[rid] = key
            self.requested[key] = rid
            self.stats.requested += 1

    def _previews(self, view: View, width: int, height: int) -> list[TileKey]:
        level = view.level - PREVIEW_LEVELS
        if level < self.lo:
            return []
        ratio = Fraction(step(self.info.f, view.level), step(self.info.f, level))
        x_lo, y_lo = view.x0 * ratio, view.y0 * ratio
        pview = View(level, x_lo.__floor__(), y_lo.__floor__())
        pw = ((view.x0 + width) * ratio).__ceil__() - pview.x0
        ph = ((view.y0 + height) * ratio).__ceil__() - pview.y0
        return [self.key(level, tx, ty) for tx, ty in visible_tiles(pview, max(pw, 1), max(ph, 1))]

    def _receive(self):
        while True:
            try:
                r = self.conn.results.get_nowait()
            except Exception:
                return
            if isinstance(r, TileResult):
                key = self.pending.pop(r.request_id, None)
                self.cancelled.discard(r.request_id)
                if key is None:
                    continue
                self.requested.pop(key, None)
                if r.complete:
                    self.store.put(key, r.counts, r.zz, r.iterations)
                    s = self.stats
                    s.received += 1
                    s.iterations += r.iterations
                    s.wire_bytes += r.wire_bytes
                    s.history.append((time.monotonic(), r.total_iterations, r.total_cycles, s.wire_bytes, s.received))
                    del s.history[:-200]
                else:
                    self.stats.aborted += 1
            elif isinstance(r, ErrorResult):
                self.stats.errors += 1
                self.last_error = f"error {r.code}: {r.text}"
                key = self.pending.pop(r.request_id, None)
                self.cancelled.discard(r.request_id)
                if key is not None:
                    self.requested.pop(key, None)
                    self.failed.add(key)
            elif isinstance(r, p.BoardStatus):
                self.board = r
            elif isinstance(r, Closed):
                self.closed = r.reason
                return

    # ------------------------------------------------------------------------------- drawing

    def draw_list(self, view: View, width: int, height: int) -> list[Quad]:
        """Quads to draw, back to front: tiles of other levels and other max_it underneath, scaled,
        and the current tiles on top."""
        f = self.info.f
        cur = step(f, view.level)
        steps: dict[int, int] = {}
        order = []
        for tile in self.store.tiles():
            k = tile.key
            dl = k.level - view.level
            if abs(dl) > DRAW_LEVELS:
                continue
            s = steps.setdefault(k.level, step(f, k.level))
            if dl == 0:
                left, top, size = TILE * k.tx - view.x0, TILE * k.ty - view.y0, TILE
            else:
                left = Fraction(TILE * k.tx * s, cur) - view.x0
                top = Fraction(TILE * k.ty * s, cur) - view.y0
                size = Fraction(TILE * s, cur)
            if left >= width or top >= height or left + size <= 0 or top + size <= 0:
                continue
            same = k.max_it == self.max_it and k.flags == (self.flags & p.RESULT_FLAGS)
            # drawn later = on top: the current level and settings last, then the nearest levels
            priority = (dl == 0 and same, same, -abs(dl), dl < 0)
            order.append((priority, Quad(tile.layer, float(left), float(top), float(size)), k))
        order.sort(key=lambda o: o[0])
        for _, _, k in order:
            self.store.touch(k)
        return [q for _, q, _ in order]
