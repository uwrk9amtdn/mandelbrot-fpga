"""The viewer (PC_APP_PLAN.md, milestone 2).

  python -m mandelbrot.app                           # pick the server in the Connection panel
  python -m mandelbrot.app --host 192.168.10.10      # the board (mandelbrotd)
  python -m mandelbrot.app --sim                     # a simulated server in this process
  python -m mandelbrot.app --sim --sim-format board  # ... with the board's number format
  python -m mandelbrot.app --offline                 # browse the disk cache, without a server

Mouse: wheel zooms at the cursor, left drag pans, right drag zooms into a box, double click centres.
Keys: + / - double or halve max_it, R requests the screen again (bypassing the cache), Esc stops
requesting (any navigation resumes), Backspace goes back to the previous view, H hides the panels.

Tiles are drawn at physical pixels (one screen pixel is one lattice pixel). Tiles go to a disk cache
(cache.py; --no-cache turns it off); offline, tiles the cache doesn't have are hatched.
"""

import argparse
import math
import threading
import time
from fractions import Fraction
from pathlib import Path

import moderngl
from imgui_bundle import hello_imgui, imgui

from . import protocol as p
from .colouring import (DEFAULT_DENSITY, MODES, PALETTE_MODES, PRESETS, bake, histogram_cdf, load_palettes,
                        save_palettes)
from .gl_view import TileRenderer
from .headless import write_png
from .cache import DiskCache
from .net import Connection, OfflineConnection
from .tiles import TileManager, TileStore
from .view import TILE, View, step

SIM_FORMATS = {  # name -> (W, F, R^2)
    "wide": (64, 54, 256),  # the phase 2 format, smooth colouring works
    "board": (21, 16, 4),  # the phase 1 hardware
}
HELP = """mouse wheel     zoom at the cursor
left drag       pan
right drag      zoom into a box
double click    centre there
+ / -           max_it x2 / /2
R               request the screen again
Esc             stop requesting (moving resumes)
Backspace       previous view
H               hide the panels"""


def decimal(x: Fraction, digits: int) -> str:
    """x with `digits` digits after the point, rounded."""
    q = round(abs(x) * 10**digits)
    s = str(q).rjust(digits + 1, "0")
    return ("-" if x < 0 and q else "") + s[:-digits] + "." + s[-digits:] if digits else str(q)


class App:
    def __init__(self, args):
        self.args = args
        self.host = args.host or "192.168.10.10"
        self.port = args.port
        self.source = "offline" if args.offline else "sim" if args.sim or not args.host else "board"
        self.sim_format = args.sim_format
        self.store = TileStore(256)
        self.cache = None if args.no_cache else DiskCache(args.cache_dir, int(args.cache_limit * 2**30))
        self.offline_servers: list[p.Info] = []  # what offline mode can browse
        self.offline_id = None if args.offline in (None, "latest") else int(args.offline, 16)
        self.confirm_clear = None  # "all" or an arithmetic id, while asking
        self.conn: Connection | None = None
        self.mgr: TileManager | None = None
        self.server = None
        self.connecting = False
        self.conn_result = None  # (conn, server) or an error message, from the connect thread
        self.conn_error = ""
        self.view: View | None = None
        self.history: list[View] = []
        self.last_push = 0.0
        self.max_it = args.max_it
        # colouring (PC_APP_PLAN.md, "Colouring")
        self.mode = args.colouring
        self.density_log = {m: math.log2(d) for m, d in DEFAULT_DENSITY.items()}  # per mode, a power of 2
        self.offset = 0.0
        self.cycle = 0.0  # palette cycles per second
        self.interior = [0.0, 0.0, 0.0]
        self.unresolved = [0.0, 0.0, 0.0]
        self.gamma = 1.0
        self.user_palettes = load_palettes()
        self.palette = args.palette if args.palette in self.palettes() else "ultra"
        self.editing = False  # the gradient editor is open, on self.edit_points
        self.edit_points: list[list] = []
        self.edit_name = ""
        self.cdf_key = None  # what the histogram was computed from
        self.cdf_time = 0.0
        self.frame_time = time.monotonic()
        self.ctx = None
        self.renderer = None
        self.size = (0, 0)  # framebuffer, physical pixels
        self.drag = [0.0, 0.0]  # fractional part of a pan
        self.box_start = None
        self.show_panels = True
        self.message = ""
        self.message_until = 0.0
        self.status_time = 0.0
        self.centre_text = ["", ""]
        self.started = time.monotonic()

    # ------------------------------------------------------------------------------- connection

    def connect(self):
        self.connecting, self.conn_error = True, ""
        threading.Thread(target=self._connect_worker, daemon=True).start()

    def _connect_worker(self):
        server = None
        try:
            if self.source == "offline":
                infos = DiskCache.known_servers(self.cache.root if self.cache else None)
                info = next((i for i in infos if self.offline_id in (None, i.arith_id)), None)
                if info is None:
                    raise ValueError("no cached tiles of that arithmetic id" if infos else "the cache is empty")
                self.conn_result = (OfflineConnection(info), None)
                return
            if self.source == "sim":
                from .sim_server import SimServer

                w, f, r2 = SIM_FORMATS[self.sim_format]
                server = SimServer(port=0, w=w, f=f, bailout_r2=r2).start()
                host, port = "127.0.0.1", server.port
            else:
                host, port = self.host, self.port
            self.conn_result = (Connection(host, port), server)
        except Exception as e:  # shown in the panel
            if server:
                server.close()
            self.conn_result = f"{type(e).__name__}: {e}"

    def _take_connection(self):
        r, self.conn_result = self.conn_result, None
        if r is None:
            return
        self.connecting = False
        if isinstance(r, str):
            self.conn_error = r
            return
        self.conn, self.server = r
        self.store.clear()
        offline = isinstance(self.conn, OfflineConnection)
        if self.cache and not offline:
            self.cache.save_info(self.conn.info)
        self.mgr = TileManager(self.conn, self.store, self.max_it, cache=self.cache, offline=offline)
        self.max_it = self.mgr.max_it
        self.history.clear()
        self.view = self.initial_view()

    def disconnect(self, reason=""):
        if self.conn:
            self.conn.close()
        if self.server:
            self.server.close()
        self.conn = self.mgr = self.server = self.view = None
        self.store.clear()
        self.conn_error = reason

    # ------------------------------------------------------------------------------- views

    def initial_view(self) -> View:
        info, (w, h) = self.conn.info, self.size
        if self.args.level is not None:
            level = self.args.level
        else:  # 3.2 units across the width
            level = self.mgr.lo
            while level < self.mgr.hi and w * step(info.f, level + 1) >= 3.2 * 2**info.f:
                level += 1
        level = max(self.mgr.lo, min(level, self.mgr.hi))
        return View.centred(info.f, level, self.args.re, self.args.im, w, h)

    def set_view(self, view: View, remember=True):
        if remember and view.level != self.view.level and time.monotonic() - self.last_push > 0.4:
            self.history.append(self.view)
            del self.history[:-100]
        if remember:
            self.last_push = time.monotonic()
        self.view = view
        self.mgr.resume()

    def zoom(self, levels: int, px: int, py: int):
        target = max(self.mgr.lo, min(self.view.level + levels, self.mgr.hi))
        if target == self.view.level:
            self.say(f"hardware precision limit (W = {self.conn.info.w} bits)" if levels > 0
                     else "zoomed out as far as the number format allows")
            return
        self.set_view(self.view.zoom(self.conn.info.f, target - self.view.level, px, py))

    def say(self, text: str, seconds=3.0):
        self.message, self.message_until = text, time.monotonic() + seconds

    # ------------------------------------------------------------------------------- per frame

    def post_init(self):
        self.ctx = moderngl.create_context()
        self.renderer = TileRenderer(self.ctx, self.store.capacity)
        self.renderer.set_palette(bake(self.palettes()[self.palette]))
        if self.args.sim or self.args.host or self.args.offline:
            self.connect()

    def background(self):
        """Before the panels: tiles into the default framebuffer."""
        io = imgui.get_io()
        w = max(1, int(io.display_size.x * io.display_framebuffer_scale.x))
        h = max(1, int(io.display_size.y * io.display_framebuffer_scale.y))
        if self.view and (w, h) != self.size and self.size != (0, 0):  # keep the centre on a resize
            self.view = View(self.view.level, self.view.x0 - (w - self.size[0]) // 2,
                             self.view.y0 - (h - self.size[1]) // 2)
        self.size = (w, h)
        self._take_connection()

        self.ctx.screen.use()
        self.ctx.viewport = (0, 0, w, h)
        self.ctx.clear(0.08, 0.08, 0.1)
        if not (self.mgr and self.view):
            return
        if self.mgr.closed:
            self.disconnect(f"connection closed: {self.mgr.closed}")
            return
        self.mgr.update(self.view, w, h)
        self.renderer.upload(self.store.take_uploads())
        self._update_colouring(w, h)
        self.renderer.draw(self.mgr.draw_list(self.view, w, h), w, h)

        now = time.monotonic()
        if self.conn.info.features & p.FEATURE_BOARD_STATUS and now - self.status_time > 1.0:
            self.conn.request_status()
            self.status_time = now

    def _update_colouring(self, w: int, h: int):
        now = time.monotonic()
        dt, self.frame_time = now - self.frame_time, now
        if self.cycle:
            self.offset = (self.offset + self.cycle * dt) % 1.0
        c = self.renderer.colouring
        c.mode, c.offset, c.gamma = self.mode, self.offset, self.gamma
        c.density = 2.0 ** self.density_log.get(self.mode, 0.0)
        c.interior, c.unresolved = tuple(self.interior), tuple(self.unresolved)
        c.max_it, c.bailout_r2 = self.max_it, float(self.conn.info.bailout_r2)
        if self.mode == "histogram":  # recomputed when the screen changed, at most 4 times a second
            st = self.mgr.stats
            key = (self.view, w, h, self.max_it, st.received, st.synthesized)
            if key != self.cdf_key and (now - self.cdf_time > 0.25 or self.cdf_key is None):
                c.cdf, c.cdf_lo, c.cdf_hi = histogram_cdf(self.mgr.on_screen(self.view, w, h), c.bailout_r2)
                self.cdf_key, self.cdf_time = key, now

    def before_swap(self):
        if not self.args.screenshot:
            return
        done = self.mgr is not None and self.mgr.idle and (self.mgr.complete or self.mgr.offline)
        if done or time.monotonic() - self.started > self.args.wait:
            w, h = self.size
            data = self.ctx.screen.read(viewport=(0, 0, w, h), components=3)
            import numpy as np

            write_png(self.args.screenshot, np.frombuffer(data, np.uint8).reshape(h, w, 3)[::-1])
            print(f"screenshot {self.args.screenshot} ({w}x{h}), "
                  f"{'complete' if done else 'timed out'}")
            hello_imgui.get_runner_params().app_shall_exit = True

    def gui(self):
        if self.mgr and self.view:
            self._mouse()
            self._keys()
        if self.mgr and self.view:
            self._hatch_missing()
        if self.show_panels:
            self._panels()
        if self.message and time.monotonic() < self.message_until:
            io = imgui.get_io()
            dl = imgui.get_foreground_draw_list()
            size = imgui.calc_text_size(self.message)
            pos = imgui.ImVec2((io.display_size.x - size.x) / 2, io.display_size.y - 40)
            dl.add_rect_filled(imgui.ImVec2(pos.x - 8, pos.y - 4), imgui.ImVec2(pos.x + size.x + 8, pos.y + size.y + 4),
                               imgui.get_color_u32(imgui.ImVec4(0, 0, 0, 0.7)))
            dl.add_text(pos, imgui.get_color_u32(imgui.ImVec4(1, 1, 0.6, 1)), self.message)

    def _hatch_missing(self):
        """Offline: diagonal lines over the current tiles the cache doesn't have."""
        io = imgui.get_io()
        sx, sy = io.display_framebuffer_scale.x, io.display_framebuffer_scale.y
        w, h = self.size
        dl = imgui.get_background_draw_list()
        line = imgui.get_color_u32(imgui.ImVec4(0.6, 0.6, 0.65, 0.6))
        shade = imgui.get_color_u32(imgui.ImVec4(0.1, 0.1, 0.12, 0.8))
        for left, top in self.mgr.missing(self.view, w, h):
            x0, y0, x1, y1 = left / sx, top / sy, (left + TILE) / sx, (top + TILE) / sy
            dl.push_clip_rect(imgui.ImVec2(x0, y0), imgui.ImVec2(x1, y1), True)
            dl.add_rect_filled(imgui.ImVec2(x0, y0), imgui.ImVec2(x1, y1), shade)
            for k in range(0, 2 * TILE, 16):
                dl.add_line(imgui.ImVec2((left + k) / sx, y0), imgui.ImVec2((left + k - TILE) / sx, y1), line)
            dl.pop_clip_rect()

    # ------------------------------------------------------------------------------- input

    def _mouse(self):
        io = imgui.get_io()
        sx, sy = io.display_framebuffer_scale.x, io.display_framebuffer_scale.y
        mx, my = int(io.mouse_pos.x * sx), int(io.mouse_pos.y * sy)
        w, h = self.size
        on_image = not io.want_capture_mouse

        if on_image and io.mouse_wheel:
            self.zoom(1 if io.mouse_wheel > 0 else -1, mx, my)
        if on_image and imgui.is_mouse_double_clicked(imgui.MouseButton_.left):
            self.set_view(self.view.pan(w // 2 - mx, h // 2 - my))
        elif imgui.is_mouse_down(imgui.MouseButton_.left) and (on_image or self.drag != [0.0, 0.0]):
            self.drag[0] += io.mouse_delta.x * sx
            self.drag[1] += io.mouse_delta.y * sy
            dx, dy = int(self.drag[0]), int(self.drag[1])
            if dx or dy:
                self.drag[0] -= dx
                self.drag[1] -= dy
                self.set_view(self.view.pan(dx, dy), remember=False)
        else:
            self.drag = [0.0, 0.0]

        right = imgui.MouseButton_.right
        if on_image and imgui.is_mouse_clicked(right):
            self.box_start = (mx, my)
        if self.box_start is not None:
            x0, y0 = self.box_start
            if imgui.is_mouse_down(right):
                dl = imgui.get_foreground_draw_list()
                dl.add_rect(imgui.ImVec2(x0 / sx, y0 / sy), imgui.ImVec2(mx / sx, my / sy),
                            imgui.get_color_u32(imgui.ImVec4(1, 1, 1, 0.9)), rounding=0.0, thickness=1.5)
            else:
                self.box_start = None
                bw, bh = abs(mx - x0), abs(my - y0)
                if bw > 8 and bh > 8:
                    levels = round(4 * math.log2(min(w / bw, h / bh)))
                    cx, cy = (x0 + mx) // 2, (y0 + my) // 2
                    target = max(self.mgr.lo, min(self.view.level + levels, self.mgr.hi))
                    v = self.view.zoom(self.conn.info.f, target - self.view.level, cx, cy)
                    self.set_view(v.pan(w // 2 - cx, h // 2 - cy))

    def _keys(self):
        if imgui.get_io().want_capture_keyboard:
            return
        k = imgui.Key
        if imgui.is_key_pressed(k.equal) or imgui.is_key_pressed(k.keypad_add):
            self._set_max_it(self.max_it * 2)
        if imgui.is_key_pressed(k.minus) or imgui.is_key_pressed(k.keypad_subtract):
            self._set_max_it(self.max_it // 2)
        if imgui.is_key_pressed(k.r):
            self.mgr.refresh()
        if imgui.is_key_pressed(k.escape):
            self.mgr.stop()
            self.say("stopped: no more requests until you move")
        if imgui.is_key_pressed(k.backspace) and self.history:
            self.view = self.history.pop()
            self.mgr.resume()
        if imgui.is_key_pressed(k.h):
            self.show_panels = not self.show_panels

    def _set_max_it(self, value: int):
        self.mgr.set_render(max(1, value), self.mgr.flags)
        self.max_it = self.mgr.max_it
        self.mgr.resume()

    # ------------------------------------------------------------------------------- panels

    def _panels(self):
        imgui.set_next_window_pos(imgui.ImVec2(10, 10), imgui.Cond_.first_use_ever)
        imgui.set_next_window_bg_alpha(0.85)
        imgui.begin("Mandelbrot", None, imgui.WindowFlags_.always_auto_resize)
        if imgui.collapsing_header("Connection", imgui.TreeNodeFlags_.default_open if not self.conn else 0):
            self._connection_panel()
        if self.mgr and self.view:
            if imgui.collapsing_header("View", imgui.TreeNodeFlags_.default_open):
                self._view_panel()
            if imgui.collapsing_header("Colouring", imgui.TreeNodeFlags_.default_open):
                self._colour_panel()
            if imgui.collapsing_header("Statistics", imgui.TreeNodeFlags_.default_open):
                self._stats_panel()
        if self.cache and imgui.collapsing_header("Cache"):
            self._cache_panel()
        if imgui.collapsing_header("Help"):
            imgui.text_disabled(HELP)
        imgui.end()

    def _connection_panel(self):
        if self.conn:
            info = self.conn.info
            where = ("offline (disk cache only)" if isinstance(self.conn, OfflineConnection)
                     else f"simulated ({self.sim_format})" if self.server else f"{self.host}:{self.port}")
            imgui.text(f"connected: {where}")
            imgui.text(f"W = {info.w}, F = {info.f}, R^2 = {info.bailout_r2}, {info.n_cores} cores at "
                       f"{info.clock_khz / 1000:.1f} MHz")
            imgui.text(f"{info.max_in_flight} requests in flight, arithmetic id {info.arith_id:#010x}")
            if imgui.button("Disconnect"):
                self.disconnect()
            return
        for name, label in (("board", "board"), ("sim", "simulated server"), ("offline", "offline (cache)")):
            if imgui.radio_button(label, self.source == name):
                self.source = name
                if name == "offline":
                    self.offline_servers = DiskCache.known_servers(self.cache.root if self.cache else None)
            imgui.same_line()
        imgui.new_line()
        if self.source == "offline":
            servers = self.offline_servers
            if not servers:
                imgui.text_disabled("no cached tiles yet")
            else:
                ids = [i.arith_id for i in servers]
                cur = ids.index(self.offline_id) if self.offline_id in ids else 0
                labels = [f"{i.arith_id:08x}: W={i.w} F={i.f} R^2={i.bailout_r2}, "
                          f"{self.cache.sizes.get(i.arith_id, 0) / 2**20:.0f} MB" for i in servers]
                _, cur = imgui.combo("arithmetic", cur, labels)
                self.offline_id = ids[cur]
        elif self.source == "sim":
            names = list(SIM_FORMATS)
            _, i = imgui.combo("format", names.index(self.sim_format), [
                f"{n}: W={w} F={f} R^2={r}" for n, (w, f, r) in SIM_FORMATS.items()])
            self.sim_format = names[i]
        else:
            _, self.host = imgui.input_text("host", self.host)
            _, self.port = imgui.input_int("port", self.port)
        imgui.begin_disabled(self.connecting or (self.source == "offline" and not self.cache))
        if imgui.button("Connecting..." if self.connecting else "Connect"):
            self.connect()
        imgui.end_disabled()
        if self.conn_error:
            imgui.text_colored(imgui.ImVec4(1, 0.5, 0.4, 1), self.conn_error)

    def _view_panel(self):
        info, v, (w, h) = self.conn.info, self.view, self.size
        s = step(info.f, v.level)
        re, im = v.centre(info.f, w, h)
        digits = max(2, math.ceil(math.log10(2**info.f / s)) + 2)
        imgui.text(f"level {v.level} (of {self.mgr.lo}..{self.mgr.hi}), pixel step {s} x 2^-{info.f}"
                   f" = {s / 2**info.f:.3g}")
        imgui.text(f"magnification {2.0 ** ((v.level - self.mgr.lo) / 4):.4g}, "
                   f"{math.log2(2**info.f / s):.1f} of {info.f} fraction bits in use")
        if not any(self.centre_text) or not imgui.is_any_item_active():
            self.centre_text = [decimal(re, digits), decimal(im, digits)]
        _, self.centre_text[0] = imgui.input_text("re", self.centre_text[0])
        _, self.centre_text[1] = imgui.input_text("im", self.centre_text[1])
        if imgui.button("Go"):
            try:
                self.set_view(View.centred(info.f, v.level, Fraction(self.centre_text[0]),
                                           Fraction(self.centre_text[1]), w, h))
                self.centre_text = ["", ""]
            except (ValueError, ZeroDivisionError):
                self.say("not a number")
        imgui.same_line()
        if imgui.button("Home"):
            self.set_view(View.centred(info.f, self.initial_view().level, "-0.75", "0", w, h))
        imgui.same_line()
        imgui.begin_disabled(not self.history)
        if imgui.button("Back"):
            self.view = self.history.pop()
        imgui.end_disabled()

        changed, value = imgui.input_int("max_it", self.max_it, 0, 0, imgui.InputTextFlags_.enter_returns_true)
        if changed:
            self._set_max_it(value)
        imgui.same_line()
        if imgui.button("x2"):
            self._set_max_it(self.max_it * 2)
        imgui.same_line()
        if imgui.button("/2"):
            self._set_max_it(self.max_it // 2)
        if self.mgr.paused:
            imgui.text_colored(imgui.ImVec4(1, 0.8, 0.3, 1), "stopped (move or press R to resume)")

    # ------------------------------------------------------------------------------- colouring

    def palettes(self) -> dict:
        return {**PRESETS, **self.user_palettes}

    def _set_palette(self, name: str):
        self.palette = name
        self.renderer.set_palette(bake(self.palettes()[name]))

    def _colour_panel(self):
        _, i = imgui.combo("colouring", MODES.index(self.mode), MODES)
        if MODES[i] != self.mode:
            self.mode, self.cdf_key = MODES[i], None
        r2 = self.conn.info.bailout_r2
        if self.mode != "escape" and r2 < 256:
            imgui.text_colored(imgui.ImVec4(1, 0.8, 0.3, 1), f"R^2 = {r2}: smooth values show bands "
                               "(the wide formats have R^2 = 256)")
        if self.mode in PALETTE_MODES:
            names = list(self.palettes())
            imgui.begin_disabled(self.editing)
            changed, i = imgui.combo("palette", names.index(self.palette), names)
            imgui.end_disabled()
            if changed:
                self._set_palette(names[i])
            imgui.same_line()
            if imgui.button("Close editor" if self.editing else "Edit"):
                self._toggle_editor()
        unit = {"escape": "cycles per iteration", "smooth": "cycles per iteration",
                "log-smooth": "cycles per doubling of nu", "histogram": "cycles per screen",
                "hsv": "x nu / max_it", "lch": "x nu / max_it"}[self.mode]
        _, self.density_log[self.mode] = imgui.slider_float(
            "density", self.density_log[self.mode], -12.0, 6.0, f"2^%.1f {unit}")
        _, self.offset = imgui.slider_float("offset", self.offset, 0.0, 1.0)
        _, self.cycle = imgui.slider_float("cycling", self.cycle, -1.0, 1.0, "%.2f cycles/s")
        imgui.same_line()
        if imgui.button("stop"):
            self.cycle = 0.0
        _, self.gamma = imgui.slider_float("gamma", self.gamma, 0.3, 3.0, "%.2f")
        _, self.interior = imgui.color_edit3("interior", self.interior, imgui.ColorEditFlags_.no_inputs)
        imgui.same_line()
        _, self.unresolved = imgui.color_edit3("unresolved (max_it)", self.unresolved,
                                               imgui.ColorEditFlags_.no_inputs)
        if self.editing and self.mode in PALETTE_MODES:
            self._gradient_editor()

    def _toggle_editor(self):
        self.editing = not self.editing
        if self.editing:
            self.edit_points = [[pos, list(rgb)] for pos, rgb in self.palettes()[self.palette]]
            self.edit_name = self.palette if self.palette in self.user_palettes else self.palette + " 2"
        else:
            self._set_palette(self.palette)  # drop unsaved edits

    def _gradient_editor(self):
        imgui.separator()
        pts = self.edit_points
        changed = False
        # the gradient, as 128 bars
        rgb = bake([(pos, tuple(c)) for pos, c in pts], 128)
        dl, origin = imgui.get_window_draw_list(), imgui.get_cursor_screen_pos()
        width, height = 320.0, 18.0
        for i, c in enumerate(rgb):
            x0 = origin.x + width * i / len(rgb)
            dl.add_rect_filled(imgui.ImVec2(x0, origin.y), imgui.ImVec2(x0 + width / len(rgb) + 1, origin.y + height),
                               imgui.get_color_u32(imgui.ImVec4(*(float(x) / 255.0 for x in c), 1.0)))
        for pos, _ in pts:  # control point marks
            x = origin.x + width * pos
            dl.add_triangle_filled(imgui.ImVec2(x, origin.y + height), imgui.ImVec2(x - 4, origin.y + height + 7),
                                   imgui.ImVec2(x + 4, origin.y + height + 7), imgui.get_color_u32(imgui.ImVec4(1, 1, 1, 1)))
        imgui.dummy(imgui.ImVec2(width, height + 8))
        remove = None
        for i, pt in enumerate(pts):
            imgui.push_id(i)
            c1, pt[1] = imgui.color_edit3("##c", pt[1], imgui.ColorEditFlags_.no_inputs)
            imgui.same_line()
            imgui.set_next_item_width(200)
            c2, pt[0] = imgui.slider_float("##pos", pt[0], 0.0, 0.999, "at %.3f")
            changed |= c1 or c2
            if len(pts) > 1:
                imgui.same_line()
                if imgui.small_button("remove"):
                    remove = i
            imgui.pop_id()
        if remove is not None:
            del pts[remove]
            changed = True
        if imgui.button("Add point"):  # in the middle of the widest gap, with the colour there
            order = sorted(p[0] for p in pts)
            gaps = [((order[(k + 1) % len(order)] - order[k]) % 1.0 or 1.0, order[k]) for k in range(len(order))]
            gap, start = max(gaps)
            pos = (start + gap / 2) % 1.0
            pts.append([pos, list(bake([(q, tuple(c)) for q, c in pts], 1024)[int(pos * 1024)] / 255.0)])
            changed = True
        if changed:
            self.renderer.set_palette(bake([(pos, tuple(c)) for pos, c in pts]))
        imgui.set_next_item_width(200)
        _, self.edit_name = imgui.input_text("name", self.edit_name)
        imgui.same_line()
        name = self.edit_name.strip()
        imgui.begin_disabled(not name or name in PRESETS)
        if imgui.button("Save"):
            self.user_palettes[name] = sorted((pos, tuple(c)) for pos, c in pts)
            self._save_palettes(f"saved palette {name!r}")
            self.palette, self.editing = name, False
        imgui.end_disabled()
        if self.palette in self.user_palettes:
            imgui.same_line()
            if imgui.button("Delete"):
                del self.user_palettes[self.palette]
                self._save_palettes(f"deleted palette {self.palette!r}")
                self.editing = False
                self._set_palette("ultra")
        if name in PRESETS:
            imgui.text_disabled("presets can't be overwritten; choose another name")

    def _save_palettes(self, what: str):
        try:
            save_palettes(self.user_palettes)
            self.say(what)
        except OSError as e:
            self.say(f"could not save the palettes: {e}")

    def _stats_panel(self):
        m = self.mgr
        st = m.stats
        imgui.text(f"in flight {len(m.pending)}, tiles in memory {len(self.store)}/{self.store.capacity}")
        imgui.text(f"received {st.received}, from the cache {st.from_cache}, aborted {st.aborted}, "
                   f"outside the format {st.synthesized}, errors {st.errors}")
        r = st.rates(self.conn.info.n_cores)
        if r:
            line = f"{r['tiles/s']:.1f} tiles/s, {r['MB/s']:.1f} MB/s, {r['G it/s']:.2f} G iterations/s"
            if "utilisation" in r:
                line += f", FPGA {100 * r['utilisation']:.0f} % busy"
            imgui.text(line)
        if m.board:
            b = m.board
            imgui.text(f"board: FPGA {b.fpga_temp} C, board {b.board_temp} C, fan {b.fan_rpm} RPM"
                       + ("" if b.valid else " (not valid)"))
        if m.last_error:
            imgui.text_colored(imgui.ImVec4(1, 0.5, 0.4, 1), m.last_error)

    def _cache_panel(self):
        c = self.cache
        home = str(Path.home())
        root = str(c.root)
        imgui.push_text_wrap_pos(imgui.get_font_size() * 30)
        imgui.text_wrapped("~" + root[len(home):] if root.startswith(home) else root)
        imgui.pop_text_wrap_pos()
        used = f"{c.size / 2**30:.2f} GB" if c.scanned else "scanning..."
        imgui.text(f"{used} of {c.limit / 2**30:.1f} GB")
        looked = c.hits + c.misses
        rate = f", hit rate {100 * c.hits / looked:.0f} %" if looked else ""
        imgui.text(f"hits {c.hits}, misses {c.misses}{rate}" + (f", damaged {c.damaged}" if c.damaged else ""))
        if self.mgr:
            imgui.begin_disabled(isinstance(self.conn, OfflineConnection))
            _, self.mgr.bypass = imgui.checkbox("bypass (request every tile, still write)", self.mgr.bypass)
            changed, off = imgui.checkbox("offline / cache only", self.mgr.offline)
            if changed:
                if off:
                    self.mgr.stop()  # cancel what is in flight
                self.mgr.offline = off
                self.mgr.resume()
            imgui.end_disabled()
        if self.confirm_clear is None:
            if imgui.button("Clear the cache"):
                self.confirm_clear = "all"
            if self.conn:
                imgui.same_line()
                if imgui.button(f"Clear {self.conn.info.arith_id:08x}"):
                    self.confirm_clear = self.conn.info.arith_id
        else:
            what = "every tile" if self.confirm_clear == "all" else f"the tiles of {self.confirm_clear:08x}"
            imgui.text_colored(imgui.ImVec4(1, 0.8, 0.3, 1), f"delete {what}?")
            imgui.same_line()
            if imgui.button("Yes, delete"):
                c.clear(None if self.confirm_clear == "all" else self.confirm_clear)
                if self.mgr:
                    self.mgr.missed.clear()
                self.confirm_clear = None
            imgui.same_line()
            if imgui.button("No"):
                self.confirm_clear = None
        if c.last_error:
            imgui.text_colored(imgui.ImVec4(1, 0.5, 0.4, 1), c.last_error)

    def shutdown(self):
        self.disconnect()
        if self.cache:
            self.cache.close()  # finishes the queued writes
        if self.renderer:
            self.renderer.release()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--host", help="the board (or a simulated server) to connect to at start")
    ap.add_argument("--port", type=int, default=p.PORT)
    ap.add_argument("--sim", action="store_true", help="start a simulated server in this process")
    ap.add_argument("--sim-format", choices=list(SIM_FORMATS), default="wide")
    ap.add_argument("--offline", nargs="?", const="latest", metavar="ARITH_ID",
                    help="browse the disk cache without a server (default: the last server's arithmetic id)")
    ap.add_argument("--cache-dir", help="disk cache directory (default ~/.cache/mandelbrot-fpga/tiles)")
    ap.add_argument("--cache-limit", type=float, default=4.0, help="disk cache size limit in GB")
    ap.add_argument("--no-cache", action="store_true", help="no disk cache")
    ap.add_argument("--re", default="-0.75", help="centre, real part")
    ap.add_argument("--im", default="0", help="centre, imaginary part")
    ap.add_argument("--level", type=int, help="zoom level (default: the whole set)")
    ap.add_argument("--max-it", type=int, default=256)
    ap.add_argument("--colouring", choices=MODES, default="smooth")
    ap.add_argument("--palette", default="ultra", help="a preset or a saved palette")
    ap.add_argument("--size", default="1280x800", help="window size, WxH")
    ap.add_argument("--screenshot", help="save the window to this PNG once the view is complete, then exit")
    ap.add_argument("--wait", type=float, default=30.0, help="with --screenshot: give up after this many seconds")
    a = ap.parse_args()
    app = App(a)

    params = hello_imgui.RunnerParams()
    params.app_window_params.window_title = "Mandelbrot FPGA"
    params.app_window_params.window_geometry.size = tuple(int(v) for v in a.size.lower().split("x"))
    params.app_window_params.restore_previous_geometry = False
    params.ini_folder_type = hello_imgui.IniFolderType.app_user_config_folder  # not the current directory
    params.ini_filename = "mandelbrot-fpga/viewer.ini"
    params.imgui_window_params.default_imgui_window_type = hello_imgui.DefaultImGuiWindowType.no_default_window
    params.fps_idling.enable_idling = False  # tiles keep arriving without input events
    params.callbacks.post_init = app.post_init
    params.callbacks.custom_background = app.background
    params.callbacks.show_gui = app.gui
    params.callbacks.before_swap = app.before_swap
    params.callbacks.before_exit = app.shutdown
    hello_imgui.run(params)


if __name__ == "__main__":
    main()
