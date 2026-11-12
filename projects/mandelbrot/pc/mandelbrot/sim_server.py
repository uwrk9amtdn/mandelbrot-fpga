"""Simulated server: speaks the board's protocol and computes the tiles on the PC.

  python -m mandelbrot.sim_server                       # W = 64, F = 54, R = 16 on port 5150
  python -m mandelbrot.sim_server --w 21 --f 16 --r2 4  # the format of the phase 1 hardware

Fast mode only for now: numpy float64, which is not the FPGA's arithmetic (its arithmetic id says
so). The bit-exact mode comes with milestone 6 of PC_APP_PLAN.md.
"""

import argparse
import hashlib
import math
import socket
import threading
import time
from concurrent.futures import ThreadPoolExecutor

import numpy as np

from . import protocol as p

RESULT_FORMAT = 1


def arith_id(model: str, w: int, f: int, bailout_r2: int) -> int:
    """32-bit hash of everything that changes result bits."""
    text = f"{model}|{w}|{f}|{bailout_r2}|{RESULT_FORMAT}"
    return int.from_bytes(hashlib.sha256(text.encode()).digest()[:4], "little")


def compute_tile(req: p.TileReq, f_bits: int, bailout_r2: int, cancel: threading.Event | None = None):
    """Fast mode. Returns (counts u32, |z|^2 f32, iterations), or None if cancelled.

    The count of a pixel is the smallest n >= 1 with |z_n|^2 >= R^2, for z_0 = 0, z_n = z_(n-1)^2 + c.
    """
    # The coordinates are exact integers; each is rounded to a float once.
    xs = np.array([math.ldexp(req.x0 + i * req.step, -f_bits) for i in range(req.width)])
    ys = np.array([math.ldexp(req.y0 - j * req.step, -f_bits) for j in range(req.height)])
    cr = np.repeat(xs[None, :], req.height, axis=0).ravel()
    ci = np.repeat(ys[:, None], req.width, axis=1).ravel()

    counts = np.full(cr.size, p.UNRESOLVED, np.uint32)
    zz = np.zeros(cr.size, np.float32)
    index = np.arange(cr.size)  # the pixels still iterating

    if req.flags & p.FLAG_CARDIOID:
        q = (cr - 0.25) ** 2 + ci * ci
        inside = (q * (q + cr - 0.25) < 0.25 * ci * ci) | ((cr + 1.0) ** 2 + ci * ci < 0.0625)
        counts[inside] = p.INTERIOR
        keep = ~inside
        index, cr, ci = index[keep], cr[keep], ci[keep]

    zr, zi = np.zeros_like(cr), np.zeros_like(ci)
    iterations = 0
    r2 = float(bailout_r2)
    for n in range(1, req.max_it + 1):
        if index.size == 0:
            break
        if cancel is not None and n % 16 == 0 and cancel.is_set():
            return None
        iterations += index.size
        zr, zi = zr * zr - zi * zi + cr, 2.0 * zr * zi + ci
        m = zr * zr + zi * zi
        escaped = m >= r2
        if escaped.any():
            counts[index[escaped]] = n
            zz[index[escaped]] = m[escaped]
            keep = ~escaped
            index, cr, ci, zr, zi = index[keep], cr[keep], ci[keep], zr[keep], zi[keep]

    shape = (req.height, req.width)
    return counts.reshape(shape), zz.reshape(shape), iterations


class SimServer:
    def __init__(self, host="127.0.0.1", port=p.PORT, w=64, f=54, bailout_r2=256, n_cores=60,
                 clock_khz=198_000, max_in_flight=8, workers=4, tile_delay=0.0):
        """`tile_delay` adds seconds to every tile, to test cancelling and flow control."""
        self.info = p.Info(
            version=p.VERSION, w=w, f=f, n_cores=n_cores, clock_khz=clock_khz,
            max_tile_width=256, max_tile_height=256, max_in_flight=max_in_flight,
            features=p.FLAG_CARDIOID | p.FLAG_LZ4, max_max_it=p.MAX_MAX_IT,
            bailout_r2=bailout_r2, arith_id=arith_id("sim-fast-float64", w, f, bailout_r2))
        self.tile_delay = tile_delay
        self._pool = ThreadPoolExecutor(workers, thread_name_prefix="sim-tile")
        self._listener = socket.create_server((host, port))
        self.port = self._listener.getsockname()[1]
        self._sessions: set[_Session] = set()
        self._lock = threading.Lock()
        self._total_iterations = 0
        self._start = time.monotonic()
        self._closed = False

    def start(self) -> "SimServer":
        threading.Thread(target=self.serve_forever, name="sim-accept", daemon=True).start()
        return self

    def serve_forever(self):
        while True:
            try:
                sock, _addr = self._listener.accept()
            except OSError:
                return  # closed
            session = _Session(self, sock)
            with self._lock:
                self._sessions.add(session)
            threading.Thread(target=session.run, name="sim-session", daemon=True).start()

    def close(self):
        self._closed = True
        self._listener.close()
        with self._lock:
            sessions = list(self._sessions)
        for s in sessions:
            s.close()
        self._pool.shutdown(wait=True, cancel_futures=True)

    def __enter__(self):
        return self.start()

    def __exit__(self, *exc):
        self.close()

    def totals(self, add_iterations=0) -> tuple[int, int]:
        """The free-running counters: (iterations, core clock cycles)."""
        with self._lock:
            self._total_iterations += add_iterations
            cycles = int((time.monotonic() - self._start) * self.info.clock_khz * 1000)
            return self._total_iterations, cycles


class _Session:
    """One client connection."""

    def __init__(self, server: SimServer, sock: socket.socket):
        self.server = server
        self.sock = sock
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self._send_lock = threading.Lock()
        self._lock = threading.Lock()
        self._pending: dict[int, threading.Event] = {}  # request id -> its cancel flag
        self._started: set[int] = set()  # the pending requests a worker has taken

    def send(self, message: bytes):
        try:
            with self._send_lock:
                self.sock.sendall(message)
        except OSError:
            pass  # the client is gone; the reader notices

    def close(self):
        try:
            self.sock.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass

    def run(self):
        try:
            self._serve()
        except (ConnectionError, OSError):
            pass
        except p.ProtocolError as e:
            self.send(p.encode_error(0, p.Err.MESSAGE, str(e)))
        finally:
            with self._lock:
                for cancel in self._pending.values():
                    cancel.set()
            self.sock.close()
            with self.server._lock:
                self.server._sessions.discard(self)

    def _serve(self):
        msg_type, payload = p.read_message(self.sock)
        if msg_type != p.Msg.HELLO:
            raise p.ProtocolError("expected HELLO")
        version = p.decode_hello(payload)
        if version != p.VERSION:
            self.send(p.encode_error(0, p.Err.VERSION, f"version {version} not supported, {p.VERSION} is"))
            return
        self.send(self.server.info.encode())

        while True:
            msg_type, payload = p.read_message(self.sock)
            if msg_type == p.Msg.TILE_REQ:
                self._on_request(p.TileReq.decode(payload, self.server.info.w))
            elif msg_type == p.Msg.CANCEL:
                self._on_cancel(p.decode_cancel(payload))
            elif msg_type == p.Msg.PING:
                self.send(p.encode_pong(p.decode_cookie(payload)))
            elif msg_type == p.Msg.PONG:
                pass
            else:
                raise p.ProtocolError(f"unexpected message type {msg_type}")

    def _on_cancel(self, ids: list[int]):
        dropped = []
        with self._lock:
            for request_id in ids or list(self._pending):
                if request_id not in self._pending:
                    continue  # already answered
                if request_id in self._started:
                    self._pending[request_id].set()  # its worker answers
                else:
                    del self._pending[request_id]  # still queued: answer now
                    dropped.append(request_id)
        for request_id in dropped:
            self._send_aborted(request_id)

    def _send_aborted(self, request_id: int):
        total_it, total_cycles = self.server.totals()
        self.send(p.Tile(request_id, 0, 0, p.ENCODING_RAW, p.STATUS_ABORTED, 0, 0,
                         total_it, total_cycles).encode())

    def _on_request(self, req: p.TileReq):
        info = self.server.info
        error = None
        if req.request_id == 0:
            error = (p.Err.REQUEST_ID, "request id 0")
        elif not (1 <= req.width <= info.max_tile_width and 1 <= req.height <= info.max_tile_height):
            error = (p.Err.TILE_SIZE, f"tile size {req.width}x{req.height}")
        elif not 1 <= req.max_it <= info.max_max_it:
            error = (p.Err.MAX_IT, f"max_it {req.max_it}")
        elif req.flags & ~info.features:
            error = (p.Err.FLAGS, f"flags {req.flags:#x} not supported (features {info.features:#x})")
        elif not req.fits(info.w):
            error = (p.Err.COORDINATE, f"tile doesn't fit {info.w} bits")
        cancel = threading.Event()
        if error is None:
            with self._lock:
                if req.request_id in self._pending:
                    error = (p.Err.REQUEST_ID, "request id already in flight")
                elif len(self._pending) >= info.max_in_flight:
                    error = (p.Err.BUSY, f"more than {info.max_in_flight} requests in flight")
                else:
                    self._pending[req.request_id] = cancel
        if error is not None:
            self.send(p.encode_error(req.request_id, *error))
            return
        try:
            self.server._pool.submit(self._work, req, cancel)
        except RuntimeError:  # the server is shutting down
            pass

    def _work(self, req: p.TileReq, cancel: threading.Event):
        info = self.server.info
        with self._lock:
            if self._pending.get(req.request_id) is not cancel:
                return  # cancelled while it was queued, and answered then
            self._started.add(req.request_id)
        delay = self.server.tile_delay
        cancelled = cancel.wait(delay) if delay else cancel.is_set()
        result = None if cancelled else compute_tile(req, info.f, info.bailout_r2, cancel)
        # Free the slot before answering: the client may send its next request right away.
        with self._lock:
            del self._pending[req.request_id]
            self._started.discard(req.request_id)
        if result is None:
            self._send_aborted(req.request_id)
        else:
            counts, zz, iterations = result
            encoding, raw_size, data = p.encode_planes(counts, zz, bool(req.flags & p.FLAG_LZ4))
            total_it, total_cycles = self.server.totals(iterations)
            self.send(p.Tile(req.request_id, req.width, req.height, encoding, p.STATUS_COMPLETE,
                             raw_size, iterations, total_it, total_cycles, data).encode())


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--host", default="127.0.0.1", help="address to listen on (0.0.0.0 for all)")
    ap.add_argument("--port", type=int, default=p.PORT)
    ap.add_argument("--w", type=int, default=64, help="total bits of a coordinate")
    ap.add_argument("--f", type=int, default=54, help="fraction bits")
    ap.add_argument("--r2", type=int, default=256, help="bailout radius squared")
    ap.add_argument("--cores", type=int, default=60, help="core count to report")
    ap.add_argument("--in-flight", type=int, default=8, help="max requests in flight")
    ap.add_argument("--workers", type=int, default=4, help="tiles computed at the same time")
    ap.add_argument("--delay", type=float, default=0.0, help="seconds added to every tile")
    a = ap.parse_args()
    server = SimServer(a.host, a.port, a.w, a.f, a.r2, a.cores, max_in_flight=a.in_flight,
                       workers=a.workers, tile_delay=a.delay)
    print(f"simulated server on {a.host}:{server.port}  W={a.w} F={a.f} R^2={a.r2} "
          f"arithmetic id {server.info.arith_id:#010x}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.close()


if __name__ == "__main__":
    main()
