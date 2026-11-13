"""The client against the simulated server, over a real socket."""

import queue
import socket

import numpy as np
import pytest

from mandelbrot import protocol as p
from mandelbrot.headless import render
from mandelbrot.net import Closed, Connection, ErrorResult, ServerError, TileResult
from mandelbrot.sim_server import SimServer, arith_id
from mandelbrot.view import View, step, visible_tiles


def reference(view: View, f_bits, width, height, max_it, r2):
    """The whole image at once, without tiles: counts and |z|^2 for every screen pixel."""
    s = step(f_bits, view.level)
    cr = np.array([float((view.x0 + i) * s) for i in range(width)])[None, :] * 2.0 ** -f_bits
    ci = np.array([float(-(view.y0 + j) * s) for j in range(height)])[:, None] * 2.0 ** -f_bits
    cr, ci = np.broadcast_to(cr, (height, width)), np.broadcast_to(ci, (height, width))
    zr, zi = np.zeros((height, width)), np.zeros((height, width))
    counts = np.full((height, width), p.UNRESOLVED, np.uint32)
    zz = np.zeros((height, width), np.float32)
    with np.errstate(over="ignore", invalid="ignore"):
        for n in range(1, max_it + 1):
            zr, zi = zr * zr - zi * zi + cr, 2.0 * zr * zi + ci
            m = zr * zr + zi * zi
            new = (counts == p.UNRESOLVED) & (m >= r2)
            counts[new], zz[new] = n, m[new]
    return counts, zz


@pytest.fixture
def server():
    with SimServer(port=0) as s:
        yield s


def get(conn, timeout=10.0):
    return conn.results.get(timeout=timeout)


def test_info(server):
    with Connection("127.0.0.1", server.port) as conn:
        info = conn.info
        assert (info.version, info.w, info.f, info.bailout_r2) == (1, 64, 54, 256)
        assert info.features == p.FLAG_CARDIOID | p.FLAG_LZ4 | p.FEATURE_BOARD_STATUS
        assert info.arith_id == arith_id("sim-fast-float64", 64, 54, 256)
        assert info.arith_id != arith_id("sim-fast-float64", 64, 54, 4)


@pytest.mark.parametrize("flags", [0, p.FLAG_LZ4])
def test_full_view_matches_reference(server, flags):
    width, height, max_it = 700, 450, 200
    with Connection("127.0.0.1", server.port) as conn:
        view = View.centred(conn.info.f, 23, "-0.7", "0.05", width, height)  # not tile-aligned
        counts, zz, stats = render(conn, view, width, height, max_it, flags)
        ref_counts, ref_zz = reference(view, conn.info.f, width, height, max_it, conn.info.bailout_r2)
        assert np.array_equal(counts, ref_counts)
        assert np.array_equal(zz, ref_zz)
        n = len(visible_tiles(view, width, height))
        assert stats["tiles"] == n >= 6 and stats["synthesized"] == 0
        escaped = ref_counts != p.UNRESOLVED
        assert 0.2 < escaped.mean() < 0.95  # the view shows both the set and its outside
        assert (zz[escaped] >= 256).all() and (zz[~escaped] == 0).all()
        # a tile's iterations: its count for escaped pixels, max_it for the others, over whole tiles
        assert stats["iterations"] >= int(ref_counts[escaped].sum()) + int((~escaped).sum()) * max_it
        if flags:
            assert stats["wire_bytes"] < n * 512 * 1024 * 0.8
        else:
            assert stats["wire_bytes"] == n * 512 * 1024
        assert conn.in_flight == 0


def test_tiles_outside_the_format_are_synthesized():
    with SimServer(port=0, w=21, f=16, bailout_r2=4) as server, Connection("127.0.0.1", server.port) as conn:
        width, height, max_it = 1200, 300, 50
        view = View.centred(16, 12, "13", "0", width, height)  # the format ends at re = 16
        counts, zz, stats = render(conn, view, width, height, max_it)
        assert stats["synthesized"] > 0 and stats["tiles"] > 0
        ref_counts, ref_zz = reference(view, 16, width, height, max_it, 4)
        assert np.array_equal(counts, ref_counts)
        assert np.allclose(zz, ref_zz, rtol=1e-6)


def test_cardioid_flag(server):
    with Connection("127.0.0.1", server.port) as conn:
        s = step(conn.info.f, 28)
        args = (-128 * s, 128 * s, s, 300)  # 256x256 around the origin, step 2^-9: all in the cardioid
        plain, flagged = conn.request(*args), conn.request(*args, flags=p.FLAG_CARDIOID)
        results = {r.request_id: r for r in (get(conn), get(conn))}
        assert (results[plain].counts == p.UNRESOLVED).all()
        assert results[plain].iterations == 256 * 256 * 300
        assert (results[flagged].counts == p.INTERIOR).all()
        assert results[flagged].iterations == 0
        assert max(r.total_iterations for r in results.values()) == results[plain].iterations


def test_small_tiles_and_coordinates(server):
    with Connection("127.0.0.1", server.port) as conn:
        f = conn.info.f
        one = 1 << f
        conn.request(-2 * one, one, one, 100, width=5, height=3)  # re -2..2, im 1..-1
        result = get(conn)
        assert result.counts.shape == (3, 5)
        # c = 0 and c = -1 stay bounded; c = -2 stays at |z| = 2 < 16; c = 1: 1, 2, 5, 26; c = 2: 2, 6, 38
        assert list(result.counts[1]) == [p.UNRESOLVED, p.UNRESOLVED, p.UNRESOLVED, 4, 3]
        assert result.zz[1, 3] == 26.0 ** 2
        assert result.counts[0, 2] == p.UNRESOLVED and result.counts[2, 2] == p.UNRESOLVED  # c = +-i
        assert np.array_equal(result.counts[0], result.counts[2])  # mirror rows


def test_errors(server):
    with Connection("127.0.0.1", server.port) as conn:
        s = 1 << 40
        bad = {
            conn.request(0, 0, s, 100, width=257): p.Err.TILE_SIZE,
            conn.request(0, 0, s, 100, height=0): p.Err.TILE_SIZE,
            conn.request(0, 0, s, 0): p.Err.MAX_IT,
            conn.request(0, 0, s, 0xFFFFFFFE): p.Err.MAX_IT,
            conn.request(0, 0, s, 100, flags=p.FLAG_PERIODICITY): p.Err.FLAGS,  # not a feature here
            conn.request(0, 0, s, 100, flags=1 << 9): p.Err.FLAGS,
            conn.request((1 << 63) - 100 * s, 0, s, 100): p.Err.COORDINATE,
            conn.request(0, 0, 0, 100): p.Err.COORDINATE,
        }
        for _ in bad:
            result = get(conn)
            assert isinstance(result, ErrorResult) and result.code == bad[result.request_id], result
        assert conn.in_flight == 0  # an ERROR frees its slot
        conn.request(0, 0, s, 10, width=1, height=1)
        assert get(conn).complete  # and the connection still works


def test_flow_control_limit():
    with SimServer(port=0, max_in_flight=3, tile_delay=0.3) as server, \
            Connection("127.0.0.1", server.port) as conn:
        assert conn.free_slots == 3
        ids = [conn.request(0, 0, 1 << 40, 10, width=4, height=4) for _ in range(5)]
        assert conn.free_slots == -2  # the caller overran the limit...
        results = [get(conn) for _ in ids]
        errors = [r for r in results if isinstance(r, ErrorResult)]
        assert sorted(r.request_id for r in errors) == ids[3:]  # ...and the server refuses the excess
        assert all(r.code == p.Err.BUSY for r in errors)
        assert sum(isinstance(r, TileResult) and r.complete for r in results) == 3


def test_cancel():
    with SimServer(port=0, tile_delay=5.0, workers=2) as server, Connection("127.0.0.1", server.port) as conn:
        ids = [conn.request(0, 0, 1 << 40, 10, width=4, height=4) for _ in range(6)]  # 2 running, 4 queued
        conn.cancel([ids[0], ids[4], 999])  # one running, one queued, one unknown
        first = [get(conn, 2.0) for _ in range(2)]
        assert sorted(r.request_id for r in first) == [ids[0], ids[4]]
        assert all(r.status == p.STATUS_ABORTED and r.counts is None for r in first)
        assert conn.in_flight == 4
        with pytest.raises(queue.Empty):
            conn.results.get(timeout=0.2)  # the others keep running
        conn.cancel()  # everything
        rest = [get(conn, 2.0) for _ in range(4)]
        assert sorted(r.request_id for r in rest) == sorted(set(ids) - {ids[0], ids[4]})
        assert all(not r.complete for r in rest) and conn.in_flight == 0


def test_cancel_stops_a_long_computation(server):
    with Connection("127.0.0.1", server.port) as conn:
        s = step(conn.info.f, 28)
        request_id = conn.request(-128 * s, 128 * s, s, 50_000_000)  # all interior: would take hours
        with pytest.raises(queue.Empty):
            conn.results.get(timeout=0.3)
        conn.cancel([request_id])
        result = get(conn, 5.0)
        assert result.request_id == request_id and result.status == p.STATUS_ABORTED


def test_request_ids_are_never_reused(server):
    with Connection("127.0.0.1", server.port) as conn:
        ids = []
        for _ in range(20):
            ids.append(conn.request(0, 0, 1 << 40, 5, width=2, height=2))
            assert get(conn).request_id == ids[-1]
        assert len(set(ids)) == 20 and 0 not in ids


def test_version_mismatch(server):
    with socket.create_connection(("127.0.0.1", server.port)) as sock:
        sock.sendall(p.encode_hello(99))
        msg_type, payload = p.read_message(sock)
        assert msg_type == p.Msg.ERROR and p.decode_error(payload)[1] == p.Err.VERSION
        with pytest.raises(ConnectionError):
            p.read_message(sock)  # and the server hangs up


def test_ping_and_garbage(server):
    with socket.create_connection(("127.0.0.1", server.port)) as sock:
        sock.sendall(p.encode_hello())
        assert p.read_message(sock)[0] == p.Msg.INFO
        sock.sendall(p.encode_ping(0xABCD1234))
        assert p.read_message(sock) == (p.Msg.PONG, bytes.fromhex("3412cdab"))
        sock.sendall(b"not a message at all")
        msg_type, payload = p.read_message(sock)
        assert msg_type == p.Msg.ERROR and p.decode_error(payload)[1] == p.Err.MESSAGE


def test_server_going_away_is_reported():
    server = SimServer(port=0, tile_delay=5.0).start()
    conn = Connection("127.0.0.1", server.port)
    conn.request(0, 0, 1 << 40, 10, width=4, height=4)
    server.close()
    results = [get(conn, 5.0)]
    if not isinstance(results[0], Closed):  # the aborted tile may still get through first
        results.append(get(conn, 5.0))
    assert isinstance(results[-1], Closed)
    conn.close()


def test_connect_refused():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        port = s.getsockname()[1]
    with pytest.raises(OSError):
        Connection("127.0.0.1", port, timeout=1.0)
    assert ServerError  # raised by Connection when the server answers HELLO with an ERROR


def test_board_status(server):
    with Connection("127.0.0.1", server.port) as conn:
        conn.request_status()
        st = get(conn)
        assert st == p.BoardStatus(40, 35, 3000, True)


def test_feature_bit_is_not_a_request_flag(server):
    with Connection("127.0.0.1", server.port) as conn:
        request_id = conn.request(0, 0, 1 << 40, 10, 4, 4, flags=p.FEATURE_BOARD_STATUS)
        err = get(conn)
        assert isinstance(err, ErrorResult) and (err.request_id, err.code) == (request_id, p.Err.FLAGS)
