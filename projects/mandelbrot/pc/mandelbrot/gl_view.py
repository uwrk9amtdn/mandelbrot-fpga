"""Tiles on the GPU and the colouring shader (PC_APP_PLAN.md, "Tiles on the GPU", "Drawing").

Two 2D array textures hold the tiles, one layer per tile: counts as R32UI, |z|^2 as R32F. Each frame
draws one instanced quad per tile of the draw list (tiles.Quad), positioned in screen pixels; the
fragment shader fetches the tile's texel with nearest sampling and colours it. All GL calls happen
on the thread that owns the context (the UI thread).
"""

import moderngl
import numpy as np

from .colouring import PALETTE_SIZE
from .tiles import Quad, Tile
from .view import TILE

VERTEX = """
#version 330
in vec2 corner;   // 0..1, the quad's corner
in vec3 rect;     // per tile: x, y, size, in screen pixels (y down)
in float layer;
uniform vec2 screen;
out vec2 uv;
flat out int v_layer;
void main() {
    vec2 pos = rect.xy + corner * rect.z;
    gl_Position = vec4(pos.x / screen.x * 2.0 - 1.0, 1.0 - pos.y / screen.y * 2.0, 0.0, 1.0);
    uv = corner;
    v_layer = int(layer + 0.5);
}
"""

FRAGMENT = """
#version 330
uniform usampler2DArray counts;
uniform sampler2D palette;
uniform float density;   // palette cycles per iteration
uniform float offset;    // palette shift, 0..1
uniform vec3 interior;   // pixels that did not escape
in vec2 uv;
flat in int v_layer;
out vec4 colour;
void main() {
    ivec2 p = clamp(ivec2(uv * 256.0), ivec2(0), ivec2(255));
    uint n = texelFetch(counts, ivec3(p, v_layer), 0).r;
    if (n >= 0xFFFFFFFEu) {
        colour = vec4(interior, 1.0);
        return;
    }
    float t = fract(float(n) * density + offset);
    colour = vec4(texture(palette, vec2(t, 0.5)).rgb, 1.0);
}
"""


class TileRenderer:
    def __init__(self, ctx: moderngl.Context, capacity: int = 256):
        self.ctx = ctx
        self.capacity = capacity
        self.counts = ctx.texture_array((TILE, TILE, capacity), 1, dtype="u4")
        self.zz = ctx.texture_array((TILE, TILE, capacity), 1, dtype="f4")
        for t in (self.counts, self.zz):
            t.filter = (moderngl.NEAREST, moderngl.NEAREST)
        self.palette = ctx.texture((PALETTE_SIZE, 1), 3, dtype="f1")
        self.palette.filter = (moderngl.LINEAR, moderngl.LINEAR)
        self.palette.repeat_x = True

        self.prog = ctx.program(vertex_shader=VERTEX, fragment_shader=FRAGMENT)
        self.prog["counts"] = 0
        self.prog["palette"] = 1
        self.density = 1.0 / 64
        self.offset = 0.0
        self.interior = (0.0, 0.0, 0.0)

        corners = np.array([0, 0, 1, 0, 0, 1, 1, 1], "f4")
        self.corner_buf = ctx.buffer(corners.tobytes())
        self.inst_buf = ctx.buffer(reserve=16 * capacity * 4, dynamic=True)
        self.vao = ctx.vertex_array(self.prog, [
            (self.corner_buf, "2f", "corner"),
            (self.inst_buf, "3f 1f/i", "rect", "layer"),
        ])

    def set_palette(self, rgb: np.ndarray, smooth: bool = True):
        """rgb: u8 (PALETTE_SIZE, 3)."""
        self.palette.write(np.ascontiguousarray(rgb, np.uint8).tobytes())
        f = moderngl.LINEAR if smooth else moderngl.NEAREST
        self.palette.filter = (f, f)

    def upload(self, tiles: list[Tile]):
        for t in tiles:
            vp = (0, 0, t.layer, TILE, TILE, 1)
            self.counts.write(np.ascontiguousarray(t.counts, "<u4").tobytes(), viewport=vp)
            self.zz.write(np.ascontiguousarray(t.zz, "<f4").tobytes(), viewport=vp)

    def draw(self, quads: list[Quad], width: int, height: int):
        """Draws into the framebuffer that is bound, over a viewport of width x height pixels."""
        if not quads:
            return
        data = np.array([(q.x, q.y, q.size, q.layer) for q in quads], "f4")
        if data.nbytes > self.inst_buf.size:
            self.inst_buf.orphan(data.nbytes)
        self.inst_buf.write(data.tobytes())
        self.prog["screen"] = (float(width), float(height))
        self.prog["density"] = float(self.density)
        self.prog["offset"] = float(self.offset)
        self.prog["interior"] = tuple(float(c) for c in self.interior)
        self.counts.use(0)
        self.palette.use(1)
        self.ctx.disable(moderngl.BLEND | moderngl.DEPTH_TEST | moderngl.CULL_FACE)
        self.vao.render(moderngl.TRIANGLE_STRIP, vertices=4, instances=len(quads))

    def release(self):
        for o in (self.vao, self.inst_buf, self.corner_buf, self.prog, self.palette, self.zz, self.counts):
            o.release()
