import io
import struct

import numpy as np
import pytest

from mandelbrot import protocol as p


class FakeSock:
    """recv_into over a byte string, in small pieces."""

    def __init__(self, data: bytes, piece=7):
        self.buf, self.piece = io.BytesIO(data), piece

    def recv_into(self, view):
        return self.buf.readinto(view[:self.piece])


def roundtrip(message: bytes) -> tuple[int, bytes]:
    return p.read_message(FakeSock(message))


def test_header_layout():
    message = p.encode_ping(0x11223344)
    assert message[:4] == b"MBRT"
    assert struct.unpack("<HHII", message[4:16]) == (p.Msg.PING, 0, 4, 0)
    assert message[16:] == bytes.fromhex("44332211")


def test_framing_errors():
    with pytest.raises(p.ProtocolError):
        roundtrip(b"XXXX" + bytes(12))
    with pytest.raises(ConnectionError):
        roundtrip(p.encode_ping(1)[:-1])
    with pytest.raises(p.ProtocolError):
        roundtrip(p.HEADER.pack(p.MAGIC, 1, 0, p.MAX_PAYLOAD + 1, 0))


@pytest.mark.parametrize("w_bits, words", [(19, 1), (21, 1), (32, 1), (33, 2), (64, 2), (96, 3), (128, 4)])
def test_coordinates(w_bits, words):
    assert p.coord_words(w_bits) == words
    lo, hi = -(1 << (w_bits - 1)), (1 << (w_bits - 1)) - 1
    for value in (0, 1, -1, lo, hi, hi // 3, lo // 3):
        data = p.encode_coord(value, w_bits)
        assert len(data) == 4 * words
        assert p.decode_coord(data) == value
    for value in (lo - 1, hi + 1):
        with pytest.raises(ValueError):
            p.encode_coord(value, w_bits)
    # low word first, sign-extended
    assert p.encode_coord(-2, w_bits) == b"\xfe" + b"\xff" * (4 * words - 1)


def test_info():
    info = p.Info(1, 128, 118, 5, 198_000, 256, 256, 8, p.FLAG_LZ4, p.MAX_MAX_IT, 256, 0xDEADBEEF)
    msg_type, payload = roundtrip(info.encode())
    assert msg_type == p.Msg.INFO and len(payload) == 32
    assert p.Info.decode(payload) == info


@pytest.mark.parametrize("w_bits", [21, 64, 128])
def test_tile_req(w_bits):
    req = p.TileReq(7, 256, 1, 1000, p.FLAG_CARDIOID, -(1 << (w_bits - 2)), (1 << (w_bits - 2)) - 5, 3)
    msg_type, payload = roundtrip(req.encode(w_bits))
    assert msg_type == p.Msg.TILE_REQ
    assert len(payload) == 16 + 12 * p.coord_words(w_bits)
    assert p.TileReq.decode(payload, w_bits) == req
    with pytest.raises(p.ProtocolError):
        p.TileReq.decode(payload[:-4], w_bits)


def test_tile_req_fits():
    top = 1 << 20  # W = 21: coordinates in [-2^20, 2^20)
    assert p.TileReq(1, 256, 256, 1, 0, top - 256, -top + 255, 1).fits(21)
    assert not p.TileReq(1, 256, 256, 1, 0, top - 255, 0, 1).fits(21)  # last column overflows
    assert not p.TileReq(1, 256, 256, 1, 0, 0, -top + 254, 1).fits(21)  # last row overflows
    assert not p.TileReq(1, 256, 256, 1, 0, 0, 0, 0).fits(21)


@pytest.mark.parametrize("use_lz4", [False, True])
def test_tile_planes(use_lz4):
    rng = np.random.default_rng(1)
    counts = rng.integers(1, 50, (5, 9), dtype=np.uint32)
    counts[0, 0], counts[4, 8] = p.UNRESOLVED, p.INTERIOR
    zz = rng.random((5, 9), dtype=np.float32) * 300
    encoding, raw_size, data = p.encode_planes(counts, zz, use_lz4)
    assert raw_size == 8 * 45
    tile = p.Tile(3, 9, 5, encoding, p.STATUS_COMPLETE, raw_size, 123, 1 << 40, 1 << 41, data)
    msg_type, payload = roundtrip(tile.encode())
    assert msg_type == p.Msg.TILE and len(payload) == 40 + len(data)
    back = p.Tile.decode(payload)
    assert back == tile
    got_counts, got_zz = back.planes()
    assert np.array_equal(got_counts, counts) and np.array_equal(got_zz, zz)


def test_tile_bad_data():
    counts, zz = np.ones((2, 2), np.uint32), np.ones((2, 2), np.float32)
    _, raw_size, data = p.encode_planes(counts, zz, False)
    for tile in (p.Tile(1, 2, 2, p.ENCODING_RAW, 0, raw_size, 0, 0, 0, data[:-1]),
                 p.Tile(1, 2, 2, p.ENCODING_LZ4, 0, raw_size, 0, 0, 0, b"\xff\xff\xff"),
                 p.Tile(1, 2, 2, 9, 0, raw_size, 0, 0, 0, data),
                 p.Tile(1, 3, 2, p.ENCODING_RAW, 0, raw_size, 0, 0, 0, data)):
        with pytest.raises(p.ProtocolError):
            tile.planes()
    with pytest.raises(ValueError):
        p.Tile(1, 2, 2, 0, p.STATUS_ABORTED, 0, 0, 0, 0).planes()


def test_cancel_error_ping():
    assert p.decode_cancel(roundtrip(p.encode_cancel())[1]) == []
    assert p.decode_cancel(roundtrip(p.encode_cancel([5, 9, 0xFFFFFFFF]))[1]) == [5, 9, 0xFFFFFFFF]
    assert p.decode_error(roundtrip(p.encode_error(4, p.Err.MAX_IT, "max_it ö"))[1]) == (4, 3, "max_it ö")
    assert p.decode_cookie(roundtrip(p.encode_pong(77))[1]) == 77
    with pytest.raises(p.ProtocolError):
        p.decode_cancel(p.encode_cancel([1, 2])[16:-1])


def test_board_status_roundtrip():
    st = p.BoardStatus(-5, 41, 3600, True)
    msg_type, payload = roundtrip(st.encode())
    assert msg_type == p.Msg.STATUS and p.BoardStatus.decode(payload) == st
    msg_type, payload = roundtrip(p.encode_status_req())
    assert (msg_type, payload) == (p.Msg.STATUS_REQ, b"")
