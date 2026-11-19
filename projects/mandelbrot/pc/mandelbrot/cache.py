"""Disk tile cache (PC_APP_PLAN.md, "Tile cache").

  <root>/<arith id, 8 hex digits>/info.bin              the INFO of the last server with that id
  <root>/<arith id>/<2 hex digits>/<sha256>.mbt         one tile

- The file name is the SHA-256 of the key without max_it, so one file per tile answers several max_it
  values: a tile computed at max_it M answers M' <= M (counts above M' become "reached max_it", and so
  do proven-interior pixels whose proof iteration k, in the second plane, is above M'), and a tile
  without unresolved pixels answers any M'. Either way the result is what a fresh render gives.
- A file holds a header (magic, version, the full key, sizes, a CRC-32 of the raw data, iterations,
  the unresolved count, the date) and the two planes, LZ4-compressed as one block. A file whose key,
  sizes or CRC don't match counts as a miss and is deleted.
- Writes go to a temporary file that is then renamed, so a crash never leaves a tile that looks valid.
- LRU by modification time (set on every hit). No index: a scan at startup gives the sizes, a running
  total is kept after that; over the limit, the oldest files go until the total is at 90 %.
- Lookups run in one thread, writes, deletions and eviction in another, so the UI never waits on the
  disk. Results of lookups arrive on `results`.
"""

import hashlib
import io
import os
import queue
import shutil
import struct
import threading
import time
import zlib
from collections import deque
from dataclasses import dataclass
from pathlib import Path

import lz4.block
import numpy as np

from . import protocol as p

MAGIC = b"MBTC"
VERSION = 1
ENC_LZ4 = 1
# magic, version, key length, encoding, raw size, data size, CRC-32 of the raw data, unresolved pixels,
# iterations, date (Unix time)
_HEAD = struct.Struct("<4sHHB3xIIIIQd")
INFO_FILE = "info.bin"
DEFAULT_LIMIT = 4 << 30


def default_dir() -> Path:
    if os.name == "nt":
        base = Path(os.environ.get("LOCALAPPDATA") or Path.home() / "AppData" / "Local")
    else:
        base = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    return base / "mandelbrot-fpga" / "tiles"


@dataclass(frozen=True)
class CacheKey:
    """Everything a tile's result bits depend on. `flags` holds only the result-changing flags."""

    arith_id: int
    w: int
    f: int
    step: int
    tx: int
    ty: int
    width: int
    height: int
    max_it: int
    flags: int

    def text(self) -> str:
        """The canonical encoding: decimal fields joined with '|', in the field order above."""
        return "|".join(str(v) for v in (self.arith_id, self.w, self.f, self.step, self.tx, self.ty,
                                         self.width, self.height, self.max_it, self.flags))

    def base_text(self) -> str:
        """The key without max_it, which names the file."""
        return "|".join(str(v) for v in (self.arith_id, self.w, self.f, self.step, self.tx, self.ty,
                                         self.width, self.height, self.flags))

    def relpath(self) -> Path:
        h = hashlib.sha256(self.base_text().encode()).hexdigest()
        return Path(f"{self.arith_id:08x}") / h[:2] / f"{h}.mbt"


def _split_key(text: str) -> tuple[str, int]:
    """(key without max_it, max_it) of a stored key text."""
    fields = text.split("|")
    if len(fields) != 10:
        raise ValueError("bad key")
    return "|".join(fields[:8] + fields[9:]), int(fields[8])


@dataclass(frozen=True)
class Header:
    key_text: str
    raw_size: int
    data_size: int
    crc: int
    unresolved: int
    iterations: int
    date: float
    offset: int  # where the data starts

    @property
    def max_it(self) -> int:
        return _split_key(self.key_text)[1]


@dataclass(frozen=True)
class CachedTile:
    counts: np.ndarray  # u32 (height, width), already adjusted to the requested max_it
    zz: np.ndarray  # f32
    iterations: int
    stored_max_it: int


class Damaged(Exception):
    pass


def encode(key: CacheKey, counts: np.ndarray, zz: np.ndarray, iterations: int) -> bytes:
    raw = np.ascontiguousarray(counts, "<u4").tobytes() + np.ascontiguousarray(zz, "<f4").tobytes()
    data = lz4.block.compress(raw, store_size=False)
    unresolved = int(np.count_nonzero(counts == p.UNRESOLVED))
    k = key.text().encode()
    head = _HEAD.pack(MAGIC, VERSION, len(k), ENC_LZ4, len(raw), len(data), zlib.crc32(raw), unresolved,
                      iterations, time.time())
    return head + k + data


def read_header(f) -> Header:
    b = f.read(_HEAD.size)
    if len(b) != _HEAD.size:
        raise Damaged("truncated header")
    magic, version, klen, enc, raw_size, data_size, crc, unresolved, iterations, date = _HEAD.unpack(b)
    if magic != MAGIC or version != VERSION or enc != ENC_LZ4:
        raise Damaged("not a tile file of this version")
    k = f.read(klen)
    if len(k) != klen:
        raise Damaged("truncated key")
    try:
        text = k.decode()
        _split_key(text)
    except ValueError as e:
        raise Damaged("bad key") from e
    return Header(text, raw_size, data_size, crc, unresolved, iterations, date, _HEAD.size + klen)


def decode(key: CacheKey, blob: bytes) -> CachedTile | None:
    """The tile in `blob` as an answer to `key`, or None if it can't answer it (computed at a lower
    max_it with unresolved pixels). Raises Damaged if the file is not a valid tile for this key."""
    h = read_header(io.BytesIO(blob))
    base, stored = _split_key(h.key_text)
    if base != key.base_text():
        raise Damaged("another key (hash collision or a misplaced file)")
    if key.max_it > stored and h.unresolved:
        return None
    n = key.width * key.height
    if h.raw_size != 8 * n or len(blob) != h.offset + h.data_size:
        raise Damaged("wrong size")
    try:
        raw = lz4.block.decompress(blob[h.offset:], uncompressed_size=h.raw_size)
    except lz4.block.LZ4BlockError as e:
        raise Damaged("bad LZ4 data") from e
    if len(raw) != h.raw_size or zlib.crc32(raw) != h.crc:
        raise Damaged("CRC mismatch")
    counts = np.frombuffer(raw, "<u4", n).reshape(key.height, key.width).astype(np.uint32)
    zz = np.frombuffer(raw, "<f4", n, 4 * n).reshape(key.height, key.width).astype(np.float32)
    if key.max_it < stored:  # what a run stopped at the new max_it would not have reached
        proof = zz.view(np.uint32)  # for proven-interior pixels: the iteration of the proof
        cut = np.where(counts == p.INTERIOR, proof > key.max_it, counts > key.max_it)
        counts[cut] = p.UNRESOLVED
        zz[cut] = 0.0
    return CachedTile(counts, zz, h.iterations, stored)


class DiskCache:
    def __init__(self, root: str | Path | None = None, limit: int = DEFAULT_LIMIT, start: bool = True):
        self.root = Path(root) if root else default_dir()
        self.limit = limit
        self.results: queue.Queue[tuple[CacheKey, CachedTile | None]] = queue.Queue()
        self.hits = 0  # this session
        self.misses = 0
        self.damaged = 0
        self.sizes: dict[int, int] = {}  # bytes per arithmetic id, once the startup scan is done
        self.scanned = False
        self.last_error: str | None = None
        self._lock = threading.Lock()
        self._cond = threading.Condition(self._lock)
        self._lookups: deque[CacheKey] = deque()
        self._wanted: set[CacheKey] = set()
        self._jobs: queue.Queue = queue.Queue()
        self._closed = False
        self._threads = []
        if start:
            self._jobs.put(("scan",))
            for target, name in ((self._reader, "cache-reader"), (self._writer, "cache-writer")):
                t = threading.Thread(target=target, name=name, daemon=True)
                t.start()
                self._threads.append(t)

    # --- for the caller ---------------------------------------------------------------------

    @property
    def size(self) -> int:
        return sum(self.sizes.values())

    def path(self, key: CacheKey) -> Path:
        return self.root / key.relpath()

    def lookup(self, key: CacheKey):
        """Look the tile up; (key, CachedTile or None) arrives on `results`."""
        with self._cond:
            if key not in self._wanted:
                self._wanted.add(key)
                self._lookups.append(key)
                self._cond.notify()

    def drop(self, keys):
        """These lookups are no longer wanted: ones not started yet are skipped, without a result."""
        with self._lock:
            self._wanted.difference_update(keys)

    def store(self, key: CacheKey, counts: np.ndarray, zz: np.ndarray, iterations: int):
        self._jobs.put(("store", key, counts, zz, iterations))

    def clear(self, arith_id: int | None = None):
        """Delete every tile, or those of one arithmetic id."""
        self._jobs.put(("clear", arith_id))

    def save_info(self, info: p.Info):
        self._jobs.put(("info", info))

    def flush(self):
        """Wait until every queued write is done (for tests and the end of a session)."""
        self._jobs.join()

    def close(self):
        if self._closed:
            return
        self._closed = True
        self._jobs.put(None)
        with self._cond:
            self._cond.notify_all()
        for t in self._threads:
            t.join(timeout=5.0)

    @staticmethod
    def known_servers(root: str | Path | None = None) -> list[p.Info]:
        """The INFOs saved in the cache, most recent first: what offline mode can browse."""
        root = Path(root) if root else default_dir()
        found = []
        for d in root.glob("*/" + INFO_FILE) if root.is_dir() else ():
            try:
                found.append((d.stat().st_mtime, p.Info.decode(d.read_bytes())))
            except (OSError, p.ProtocolError, struct.error):
                pass
        return [info for _, info in sorted(found, key=lambda x: -x[0])]

    # --- synchronous parts, run by the threads (and the tests) --------------------------------

    def read(self, key: CacheKey) -> CachedTile | None:
        path = self.path(key)
        try:
            blob = path.read_bytes()
        except OSError:
            return None
        try:
            tile = decode(key, blob)
        except Damaged:
            self.damaged += 1
            self._jobs.put(("delete", path))
            return None
        if tile is not None:
            try:
                os.utime(path)  # LRU
            except OSError:
                pass
        return tile

    def write(self, key: CacheKey, counts: np.ndarray, zz: np.ndarray, iterations: int):
        path = self.path(key)
        old_size = 0
        try:
            with open(path, "rb") as f:
                old_size = os.fstat(f.fileno()).st_size
                old = read_header(f)
            if _split_key(old.key_text)[0] == key.base_text() and old.max_it > key.max_it:
                return  # the file already answers this max_it, and higher ones
        except (OSError, Damaged):
            pass
        blob = encode(key, counts, zz, iterations)
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_name(f"{path.name}.{os.getpid()}.tmp")
        tmp.write_bytes(blob)
        os.replace(tmp, path)
        self._add(key.arith_id, len(blob) - old_size)
        if self.size > self.limit:
            self.evict()

    def scan(self):
        sizes: dict[int, int] = {}
        for d in self.root.iterdir() if self.root.is_dir() else ():
            try:
                arith_id = int(d.name, 16)
            except ValueError:
                continue
            total = 0
            for f in d.glob("*/*"):
                try:
                    if f.name.endswith(".tmp"):  # left by a crash
                        f.unlink()
                    elif f.suffix == ".mbt":
                        total += f.stat().st_size
                except OSError:
                    pass
            sizes[arith_id] = total
        with self._lock:
            for k, v in sizes.items():  # writes queued during the scan are added on top
                self.sizes[k] = self.sizes.get(k, 0) + v
            self.scanned = True

    def evict(self):
        """Delete the least recently used files until the total is at 90 % of the limit."""
        files = []
        for f in self.root.glob("*/*/*.mbt"):
            try:
                st = f.stat()
                files.append((st.st_mtime, st.st_size, f))
            except OSError:
                pass
        files.sort(key=lambda x: x[0])
        target = 0.9 * self.limit
        total = sum(s for _, s, _ in files)
        for _, size, f in files:
            if total <= target:
                break
            try:
                f.unlink()
                total -= size
            except OSError:
                pass
        sizes: dict[int, int] = {}
        for _, size, f in files:
            if f.exists():
                aid = int(f.parent.parent.name, 16)
                sizes[aid] = sizes.get(aid, 0) + size
        with self._lock:
            self.sizes = sizes

    # --- threads ------------------------------------------------------------------------------

    def _add(self, arith_id: int, delta: int):
        with self._lock:
            self.sizes[arith_id] = max(0, self.sizes.get(arith_id, 0) + delta)

    def _reader(self):
        while True:
            with self._cond:
                while not self._closed and not self._lookups:
                    self._cond.wait()
                if self._closed:
                    return
                key = self._lookups.popleft()
                if key not in self._wanted:
                    continue
            tile = self.read(key)
            with self._lock:
                if key not in self._wanted:
                    continue  # dropped while it was read
                self._wanted.discard(key)
                if tile is None:
                    self.misses += 1
                else:
                    self.hits += 1
            self.results.put((key, tile))

    def _writer(self):
        while (job := self._jobs.get()) is not None:
            try:
                kind = job[0]
                if kind == "store":
                    self.write(*job[1:])
                elif kind == "scan":
                    self.scan()
                elif kind == "delete":
                    path = job[1]
                    try:
                        size = path.stat().st_size
                        path.unlink()
                        self._add(int(path.parent.parent.name, 16), -size)
                    except (OSError, ValueError):
                        pass
                elif kind == "clear":
                    arith_id = job[1]
                    dirs = [self.root / f"{arith_id:08x}"] if arith_id is not None else (
                        [d for d in self.root.iterdir() if d.is_dir()] if self.root.is_dir() else [])
                    for d in dirs:
                        shutil.rmtree(d, ignore_errors=True)
                    with self._lock:
                        if arith_id is None:
                            self.sizes.clear()
                        else:
                            self.sizes.pop(arith_id, None)
                elif kind == "info":
                    info = job[1]
                    d = self.root / f"{info.arith_id:08x}"
                    d.mkdir(parents=True, exist_ok=True)
                    tmp = d / f"{INFO_FILE}.{os.getpid()}.tmp"
                    tmp.write_bytes(info.encode()[p.HEADER.size:])
                    os.replace(tmp, d / INFO_FILE)
            except OSError as e:
                self.last_error = f"{type(e).__name__}: {e}"
            finally:
                self._jobs.task_done()
        self._jobs.task_done()
