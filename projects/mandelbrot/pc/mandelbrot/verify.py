"""Verify tile (PC_APP_PLAN.md, milestone 6): one tile from the server against the bit-exact model.

The end-to-end hardware check. The tile is requested from the server and computed with fixed.py
(`WideFormat.record`, which also has the cardioid test and the periodicity check), both fresh, never
from the disk cache, and compared bit for bit: counts and the second plane (f32 |z|^2, or the proof
iteration k of a proven-interior pixel).

The model is pure Python (about 300k iterations/s per core at W = 64), so the rows of a tile go to a
process pool. It only describes the wide FPGA arithmetic: `model_arith_id` must equal the server's
arithmetic id, or the comparison means nothing (a simulated server, the narrow phase 1 design).
"""

from __future__ import annotations

import os
import time
import zlib
from concurrent.futures import Future, ProcessPoolExecutor
from dataclasses import dataclass, field

import numpy as np

from . import protocol as p
from .fixed import WideFormat, wrap
from .view import TILE

I_BITS, R2 = 10, 256  # the wide format (fixed.py)


def model_arith_id(w: int) -> int:
    """The arithmetic id of a wide FPGA bitstream of W bits (MandelbrotAccel.arithId)."""
    k = WideFormat(w, I_BITS, R2).dropped_diagonals
    text = (f"fpga-wide|w={w}|i={I_BITS}|r2={R2}|limb=26|k={k}"
            "|records-v1|cardioid-g24-v1|period-exact-q4-v1")
    return zlib.crc32(text.encode())


def model_applies(info: p.Info) -> bool:
    return info.f == info.w - I_BITS and info.bailout_r2 == R2 and info.arith_id == model_arith_id(info.w)


def model_row(w: int, x0: int, y: int, step: int, width: int, max_it: int, flags: int) -> np.ndarray:
    """One row of records (u64: count low, second plane high)."""
    fm = WideFormat(w, I_BITS, R2)
    return np.array([fm.record(wrap(x0 + i * step, w), y, max_it, flags) for i in range(width)], np.uint64)


@dataclass
class Mismatch:
    x: int
    y: int
    got: int  # records, count low
    want: int


@dataclass
class Verification:
    """One tile being verified. Poll `update()` until `done`."""

    info: p.Info
    label: str  # which tile, for the user
    x0: int
    y0: int
    step: int
    max_it: int
    flags: int
    width: int = TILE
    height: int = TILE
    started: float = field(default_factory=time.monotonic)
    rows: list[Future] = field(default_factory=list)
    board: np.ndarray | None = None  # records from the server
    error: str | None = None
    result: str | None = None
    mismatches: list[Mismatch] = field(default_factory=list)
    n_wrong: int = 0

    @property
    def done(self) -> bool:
        return self.result is not None or self.error is not None

    @property
    def rows_done(self) -> int:
        return sum(f.done() for f in self.rows)

    def start_model(self, pool: ProcessPoolExecutor):
        w = self.info.w
        self.rows = [pool.submit(model_row, w, self.x0, wrap(self.y0 - j * self.step, w), self.step, self.width,
                                 self.max_it, self.flags) for j in range(self.height)]

    def on_tile(self, counts: np.ndarray | None, zz: np.ndarray | None, error: str | None = None):
        """The server's answer (from the tile manager's receive loop)."""
        if error or counts is None:
            self.error = error or "the server aborted the tile"
            self.cancel()
            return
        self.board = (zz.view(np.uint32).astype(np.uint64) << np.uint64(32)) | counts.astype(np.uint64)

    def cancel(self):
        for f in self.rows:
            f.cancel()
        if not self.done:
            self.error = "cancelled"

    def update(self):
        if self.done or self.board is None or self.rows_done < self.height:
            return
        try:
            model = np.stack([f.result() for f in self.rows])
        except Exception as e:  # noqa: BLE001 - a worker died: report it
            self.error = f"model failed: {e}"
            return
        wrong = np.argwhere(self.board != model)
        self.n_wrong = len(wrong)
        self.mismatches = [Mismatch(int(x), int(y), int(self.board[y, x]), int(model[y, x])) for y, x in wrong[:5]]
        dt = time.monotonic() - self.started
        n = self.width * self.height
        if self.n_wrong == 0:
            self.result = f"{self.label}: all {n} records identical ({dt:.1f} s)"
        else:
            self.result = f"{self.label}: {self.n_wrong} of {n} records differ ({dt:.1f} s)"


def describe(record: int) -> str:
    count, hi = record & 0xFFFFFFFF, record >> 32
    if count == p.INTERIOR:
        return f"interior, k = {hi}"
    if count == p.UNRESOLVED:
        return "reached max_it"
    zz = np.array([hi], np.uint32).view(np.float32)[0]
    return f"n = {count}, |z|^2 = {zz:.6g}"


_pool: ProcessPoolExecutor | None = None


def pool() -> ProcessPoolExecutor:
    """One pool for the application, created on first use (all cores but one)."""
    global _pool
    if _pool is None:
        _pool = ProcessPoolExecutor(max_workers=max(1, (os.cpu_count() or 2) - 1))
    return _pool


def shutdown():
    global _pool
    if _pool is not None:
        _pool.shutdown(wait=False, cancel_futures=True)
        _pool = None
