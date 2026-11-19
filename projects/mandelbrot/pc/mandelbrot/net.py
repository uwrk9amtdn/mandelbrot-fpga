"""Client connection to the board (`mandelbrotd`) or to the simulated server.

A reader thread receives messages, decompresses the tiles and puts them on `results`; a writer
thread sends what the caller queued. The caller (the UI thread) never blocks on the socket.
"""

import queue
import dataclasses
import socket
import threading
from dataclasses import dataclass

import numpy as np

from . import protocol as p


@dataclass(frozen=True)
class TileResult:
    """A finished request. `counts` and `zz` are None if it was aborted."""

    request_id: int
    width: int
    height: int
    status: int
    counts: np.ndarray | None  # u32, shape (height, width)
    zz: np.ndarray | None  # f32 |z|^2 at escape
    iterations: int
    total_iterations: int
    total_cycles: int
    wire_bytes: int  # size of the tile data as sent (compressed or raw)

    @property
    def complete(self) -> bool:
        return self.status == p.STATUS_COMPLETE


@dataclass(frozen=True)
class ErrorResult:
    """The server refused a request (request_id != 0), or reported a connection-level error."""

    request_id: int
    code: int
    text: str


@dataclass(frozen=True)
class Closed:
    """The connection ended; nothing follows it on the queue."""

    reason: str


class ServerError(Exception):
    pass


class Connection:
    def __init__(self, host: str, port: int = p.PORT, timeout: float = 5.0):
        self.sock = socket.create_connection((host, port), timeout=timeout)
        self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        try:
            self.sock.sendall(p.encode_hello())
            msg_type, payload = p.read_message(self.sock)
            if msg_type == p.Msg.ERROR:
                raise ServerError(p.decode_error(payload)[2])
            if msg_type != p.Msg.INFO:
                raise p.ProtocolError(f"expected INFO, got message type {msg_type}")
            self.info = p.Info.decode(payload)
        except BaseException:
            self.sock.close()
            raise
        self.sock.settimeout(None)

        self.results: queue.Queue[TileResult | ErrorResult | p.BoardStatus | Closed] = queue.Queue()
        self._outbox: queue.Queue[bytes | None] = queue.Queue()
        self._lock = threading.Lock()
        self._in_flight: set[int] = set()
        self._next_id = 1
        self._closed = False
        threading.Thread(target=self._reader, name="net-reader", daemon=True).start()
        threading.Thread(target=self._writer, name="net-writer", daemon=True).start()

    # --- for the caller ---------------------------------------------------------------------

    @property
    def in_flight(self) -> int:
        with self._lock:
            return len(self._in_flight)

    @property
    def free_slots(self) -> int:
        """How many more requests may be sent now (the server's flow-control limit)."""
        return self.info.max_in_flight - self.in_flight

    def request(self, x0: int, y0: int, step: int, max_it: int, width=256, height=256, flags=0) -> int:
        """Queue a tile request and return its id. The caller keeps to `free_slots`."""
        with self._lock:
            request_id = self._next_id  # never reused on this connection
            self._next_id += 1
            self._in_flight.add(request_id)
        req = p.TileReq(request_id, width, height, max_it, flags, x0, y0, step)
        self._outbox.put(req.encode(self.info.w))
        return request_id

    def request_status(self):
        """Ask for the board status; it arrives on `results` as a BoardStatus."""
        if not self.info.features & p.FEATURE_BOARD_STATUS:
            raise ServerError("the server has no board status")
        self._outbox.put(p.encode_status_req())

    def cancel(self, request_ids=()):
        """Cancel these requests, or all of them if none is given. Each still gets its result."""
        self._outbox.put(p.encode_cancel(request_ids))

    def close(self):
        self._closed = True
        self._outbox.put(None)
        try:
            self.sock.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        self.sock.close()

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    # --- threads ----------------------------------------------------------------------------

    def _writer(self):
        while (message := self._outbox.get()) is not None:
            try:
                self.sock.sendall(message)
            except OSError:
                return  # the reader reports it

    def _reader(self):
        reason = "closed"
        try:
            while True:
                msg_type, payload = p.read_message(self.sock)
                if msg_type == p.Msg.TILE:
                    tile = p.Tile.decode(payload)
                    counts, zz = tile.planes() if tile.status == p.STATUS_COMPLETE else (None, None)
                    self._done(tile.request_id)
                    self.results.put(TileResult(
                        tile.request_id, tile.width, tile.height, tile.status, counts, zz,
                        tile.iterations, tile.total_iterations, tile.total_cycles, len(tile.data)))
                elif msg_type == p.Msg.ERROR:
                    error = ErrorResult(*p.decode_error(payload))
                    self._done(error.request_id)
                    self.results.put(error)
                elif msg_type == p.Msg.STATUS:
                    self.results.put(p.BoardStatus.decode(payload))
                elif msg_type == p.Msg.PING:
                    self._outbox.put(p.encode_pong(p.decode_cookie(payload)))
                # PONG and types of a later protocol version are ignored
        except (ConnectionError, OSError) as e:
            if not self._closed:
                reason = str(e) or type(e).__name__
        except p.ProtocolError as e:
            reason = f"protocol error: {e}"
        self._outbox.put(None)
        self.results.put(Closed(reason))

    def _done(self, request_id: int):
        with self._lock:
            self._in_flight.discard(request_id)


class OfflineConnection:
    """Stands in for a server while browsing the disk cache: the INFO saved by an earlier connection,
    and no requests (`free_slots` is always 0)."""

    def __init__(self, info: p.Info):
        self.info = dataclasses.replace(info, features=info.features & ~p.FEATURE_BOARD_STATUS)
        self.results: queue.Queue = queue.Queue()

    in_flight = 0
    free_slots = 0

    def request(self, *args, **kwargs) -> int:
        raise ServerError("offline: no requests")

    def request_status(self):
        raise ServerError("offline: no board status")

    def cancel(self, request_ids=()):
        pass

    def close(self):
        pass

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        pass
