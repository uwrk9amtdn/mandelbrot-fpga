"""Wire protocol between the PC application and the board, version 1.

Specified in PC_APP_PLAN.md, section 2. TCP, binary, little-endian. Shared by the application, the
simulated server and the tests; `hps/protocol.h` will hold the same layouts in C.

Every message is a 16-byte header followed by `length` payload bytes.
"""

import struct
from dataclasses import dataclass
from enum import IntEnum

import lz4.block
import numpy as np

VERSION = 1
PORT = 5150
MAGIC = b"MBRT"  # the bytes on the wire, in this order
MAX_PAYLOAD = 16 << 20  # sanity limit; the largest real message is a raw 256x256 tile (512 KB)

HEADER = struct.Struct("<4sHHII")  # magic, type, flags, length, reserved

# Count codes for pixels that did not escape.
UNRESOLVED = 0xFFFFFFFF  # reached max_it; may escape at a higher max_it
INTERIOR = 0xFFFFFFFE  # proven interior (periodicity or cardioid check); final at any max_it
MAX_MAX_IT = 0xFFFFFFFD

# Feature bits (INFO) and request flags (TILE_REQ) share their numbering.
FLAG_PERIODICITY = 1 << 0
FLAG_CARDIOID = 1 << 1
FLAG_LZ4 = 1 << 2
KNOWN_FLAGS = FLAG_PERIODICITY | FLAG_CARDIOID | FLAG_LZ4  # the request flags
FEATURE_BOARD_STATUS = 1 << 3  # INFO only: the server answers STATUS_REQ
RESULT_FLAGS = FLAG_PERIODICITY | FLAG_CARDIOID  # the ones that can change result bits

ENCODING_RAW, ENCODING_LZ4 = 0, 1
STATUS_COMPLETE, STATUS_ABORTED = 0, 1


class Msg(IntEnum):
    HELLO = 1
    INFO = 2
    TILE_REQ = 3
    TILE = 4
    CANCEL = 5
    ERROR = 6
    PING = 7
    PONG = 8
    STATUS_REQ = 9  # C->S, empty; only when INFO has FEATURE_BOARD_STATUS
    STATUS = 10  # S->C: temperatures and fan speed


class Err(IntEnum):
    VERSION = 1  # protocol version not supported
    TILE_SIZE = 2
    MAX_IT = 3
    FLAGS = 4  # unknown flag, or a feature the server doesn't have
    BUSY = 5  # more requests in flight than INFO allows
    REQUEST_ID = 6  # 0, or already in flight
    COORDINATE = 7  # the tile doesn't fit the W-bit format
    MESSAGE = 8  # malformed or unexpected message


class ProtocolError(Exception):
    """The peer sent something that is not valid protocol."""


# ---------------------------------------------------------------------------------------------
# Framing


def pack(msg_type: int, payload: bytes = b"") -> bytes:
    return HEADER.pack(MAGIC, msg_type, 0, len(payload), 0) + payload


def recv_exact(sock, n: int) -> bytes:
    """Read exactly n bytes. Raises ConnectionError if the peer closes first."""
    buf = bytearray(n)
    view = memoryview(buf)
    got = 0
    while got < n:
        k = sock.recv_into(view[got:])
        if k == 0:
            raise ConnectionError("connection closed by peer")
        got += k
    return bytes(buf)


def read_message(sock) -> tuple[int, bytes]:
    """Read one message; returns (type, payload). The type may be one this version doesn't know."""
    magic, msg_type, _flags, length, _reserved = HEADER.unpack(recv_exact(sock, HEADER.size))
    if magic != MAGIC:
        raise ProtocolError(f"bad magic {magic!r}")
    if length > MAX_PAYLOAD:
        raise ProtocolError(f"payload of {length} bytes is over the limit")
    return msg_type, recv_exact(sock, length)


# ---------------------------------------------------------------------------------------------
# Coordinates: W-bit two's complement fixed point, sent as ceil(W/32) u32 words, low word first,
# sign-extended.


def coord_words(w_bits: int) -> int:
    return (w_bits + 31) // 32


def fits(value: int, w_bits: int) -> bool:
    return -(1 << (w_bits - 1)) <= value < (1 << (w_bits - 1))


def encode_coord(value: int, w_bits: int) -> bytes:
    if not fits(value, w_bits):
        raise ValueError(f"{value} does not fit {w_bits} bits")
    return value.to_bytes(4 * coord_words(w_bits), "little", signed=True)


def decode_coord(data: bytes) -> int:
    return int.from_bytes(data, "little", signed=True)


# ---------------------------------------------------------------------------------------------
# Messages

_HELLO = struct.Struct("<H")
_INFO = struct.Struct("<HHHHIHHHHIII")
_TILE_REQ = struct.Struct("<IHHII")
_TILE = struct.Struct("<IHHBBxxIQQQ")
_CANCEL = struct.Struct("<Hxx")
_ERROR = struct.Struct("<IHH")
_COOKIE = struct.Struct("<I")
_STATUS = struct.Struct("<hhHH")


def _unpack(layout: struct.Struct, payload: bytes, exact: bool = True) -> tuple:
    if len(payload) < layout.size or (exact and len(payload) != layout.size):
        raise ProtocolError(f"payload of {len(payload)} bytes, expected {layout.size}")
    return layout.unpack_from(payload)


def encode_hello(version: int = VERSION) -> bytes:
    return pack(Msg.HELLO, _HELLO.pack(version))


def decode_hello(payload: bytes) -> int:
    return _unpack(_HELLO, payload)[0]


@dataclass(frozen=True)
class Info:
    version: int
    w: int  # total bits of a coordinate
    f: int  # fraction bits
    n_cores: int
    clock_khz: int
    max_tile_width: int
    max_tile_height: int
    max_in_flight: int
    features: int
    max_max_it: int
    bailout_r2: int
    arith_id: int

    def encode(self) -> bytes:
        return pack(Msg.INFO, _INFO.pack(
            self.version, self.w, self.f, self.n_cores, self.clock_khz, self.max_tile_width,
            self.max_tile_height, self.max_in_flight, self.features, self.max_max_it,
            self.bailout_r2, self.arith_id))

    @staticmethod
    def decode(payload: bytes) -> "Info":
        return Info(*_unpack(_INFO, payload))


@dataclass(frozen=True)
class TileReq:
    """Pixel (i, j), column i and row j, is c = (x0 + i*step, y0 - j*step), in units of 2^-F."""

    request_id: int
    width: int
    height: int
    max_it: int
    flags: int
    x0: int
    y0: int
    step: int

    def fits(self, w_bits: int) -> bool:
        """True if every pixel coordinate of the tile fits the W-bit format."""
        return (self.step > 0 and fits(self.x0, w_bits) and fits(self.y0, w_bits)
                and fits(self.x0 + (self.width - 1) * self.step, w_bits)
                and fits(self.y0 - (self.height - 1) * self.step, w_bits))

    def encode(self, w_bits: int) -> bytes:
        return pack(Msg.TILE_REQ, _TILE_REQ.pack(
            self.request_id, self.width, self.height, self.max_it, self.flags)
            + encode_coord(self.x0, w_bits) + encode_coord(self.y0, w_bits)
            + encode_coord(self.step, w_bits))

    @staticmethod
    def decode(payload: bytes, w_bits: int) -> "TileReq":
        n = 4 * coord_words(w_bits)
        if len(payload) != _TILE_REQ.size + 3 * n:
            raise ProtocolError(f"TILE_REQ of {len(payload)} bytes, expected {_TILE_REQ.size + 3 * n}")
        base = _TILE_REQ.size
        x0, y0, step = (decode_coord(payload[base + k * n:base + (k + 1) * n]) for k in range(3))
        return TileReq(*_TILE_REQ.unpack_from(payload), x0, y0, step)


@dataclass(frozen=True)
class Tile:
    request_id: int
    width: int
    height: int
    encoding: int
    status: int
    raw_size: int
    iterations: int  # iterations this tile took
    total_iterations: int  # the FPGA's free-running counters, read when the tile finished
    total_cycles: int
    data: bytes = b""  # as sent: the two planes, raw or one LZ4 block. Empty if aborted.

    def encode(self) -> bytes:
        return pack(Msg.TILE, _TILE.pack(
            self.request_id, self.width, self.height, self.encoding, self.status, self.raw_size,
            self.iterations, self.total_iterations, self.total_cycles) + self.data)

    @staticmethod
    def decode(payload: bytes) -> "Tile":
        return Tile(*_unpack(_TILE, payload, exact=False), payload[_TILE.size:])

    def planes(self) -> tuple[np.ndarray, np.ndarray]:
        """The counts (u32) and |z|^2 at escape (f32), each of shape (height, width)."""
        if self.status != STATUS_COMPLETE:
            raise ValueError("an aborted tile has no data")
        n = self.width * self.height
        if self.raw_size != 8 * n:
            raise ProtocolError(f"raw size {self.raw_size} for a {self.width}x{self.height} tile")
        if self.encoding == ENCODING_LZ4:
            try:
                raw = lz4.block.decompress(self.data, uncompressed_size=self.raw_size)
            except lz4.block.LZ4BlockError as e:
                raise ProtocolError(f"bad LZ4 data: {e}") from None
        elif self.encoding == ENCODING_RAW:
            raw = self.data
        else:
            raise ProtocolError(f"unknown encoding {self.encoding}")
        if len(raw) != self.raw_size:
            raise ProtocolError(f"{len(raw)} bytes of tile data, expected {self.raw_size}")
        shape = (self.height, self.width)
        return (np.frombuffer(raw, "<u4", n).reshape(shape),
                np.frombuffer(raw, "<f4", n, offset=4 * n).reshape(shape))


def encode_planes(counts: np.ndarray, zz: np.ndarray, use_lz4: bool) -> tuple[int, int, bytes]:
    """Tile data from the two planes; returns (encoding, raw size, data)."""
    raw = counts.astype("<u4", copy=False).tobytes() + zz.astype("<f4", copy=False).tobytes()
    if use_lz4:
        return ENCODING_LZ4, len(raw), lz4.block.compress(raw, store_size=False)
    return ENCODING_RAW, len(raw), raw


def encode_cancel(request_ids=()) -> bytes:
    """No ids cancels every outstanding request."""
    ids = list(request_ids)
    return pack(Msg.CANCEL, _CANCEL.pack(len(ids)) + struct.pack(f"<{len(ids)}I", *ids))


def decode_cancel(payload: bytes) -> list[int]:
    (count,) = _unpack(_CANCEL, payload, exact=False)
    if len(payload) != _CANCEL.size + 4 * count:
        raise ProtocolError("CANCEL length doesn't match its count")
    return list(struct.unpack_from(f"<{count}I", payload, _CANCEL.size))


def encode_error(request_id: int, code: int, text: str) -> bytes:
    raw = text.encode()
    return pack(Msg.ERROR, _ERROR.pack(request_id, code, len(raw)) + raw)


def decode_error(payload: bytes) -> tuple[int, int, str]:
    request_id, code, n = _unpack(_ERROR, payload, exact=False)
    if len(payload) != _ERROR.size + n:
        raise ProtocolError("ERROR length doesn't match its text length")
    return request_id, code, payload[_ERROR.size:].decode(errors="replace")


def encode_ping(cookie: int) -> bytes:
    return pack(Msg.PING, _COOKIE.pack(cookie))


def encode_pong(cookie: int) -> bytes:
    return pack(Msg.PONG, _COOKIE.pack(cookie))


def decode_cookie(payload: bytes) -> int:
    return _unpack(_COOKIE, payload)[0]


def encode_status_req() -> bytes:
    return pack(Msg.STATUS_REQ)


@dataclass(frozen=True)
class BoardStatus:
    fpga_temp: int  # °C
    board_temp: int  # °C
    fan_rpm: int
    valid: bool  # the readings come from the fan controller

    def encode(self) -> bytes:
        return pack(Msg.STATUS, _STATUS.pack(self.fpga_temp, self.board_temp, self.fan_rpm, int(self.valid)))

    @staticmethod
    def decode(payload: bytes) -> "BoardStatus":
        fpga, board, rpm, flags = _unpack(_STATUS, payload)
        return BoardStatus(fpga, board, rpm, bool(flags & 1))
