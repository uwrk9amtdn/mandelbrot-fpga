"""Tiles on the GPU and the colouring shader (PC_APP_PLAN.md, "Tiles on the GPU", "Drawing").

Two 2D array textures hold the tiles, one layer per tile: counts as R32UI, |z|^2 as R32F. Each frame
draws one instanced quad per tile of the draw list (tiles.Quad), positioned in screen pixels; the
fragment shader fetches the tile's texel with nearest sampling and colours it. All GL calls happen
on the thread that owns the context (the UI thread).
"""

import moderngl
import numpy as np

from .colouring import CDF_SIZE, MODES, PALETTE_SIZE, Colouring
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
uniform sampler2DArray zz;
uniform sampler2D palette;
uniform sampler2D cdf;
uniform int mode;          // index in colouring.MODES
uniform float density;     // palette cycles per unit of v
uniform float offset;      // palette shift (hue shift in hsv and lch), 0..1
uniform vec3 interior;     // proven interior
uniform vec3 unresolved;   // reached max_it
uniform float gamma;
uniform float max_it;
uniform float log_r2;      // ln R^2
uniform vec2 cdf_range;    // nu at the first and the last CDF entry
in vec2 uv;
flat in int v_layer;
out vec4 colour;

vec3 hsv_to_rgb(float h, float s, float v) {  // h in degrees
    vec3 k = mod(vec3(5.0, 3.0, 1.0) + h / 60.0, 6.0);
    return v - v * s * clamp(min(k, 4.0 - k), 0.0, 1.0);
}

vec3 lch_to_srgb(float L, float C, float H) {  // CIE LCh(ab), D65
    float h = radians(H);
    float fy = (L + 16.0) / 116.0;
    vec3 f = vec3(fy + C * cos(h) / 500.0, fy, fy - C * sin(h) / 200.0);
    vec3 cube = f * f * f;
    vec3 lin3 = 3.0 * (6.0 / 29.0) * (6.0 / 29.0) * (f - 4.0 / 29.0);
    vec3 xyz = mix(lin3, cube, step(6.0 / 29.0 + 1e-7, f)) * vec3(0.95047, 1.0, 1.08883);
    vec3 lin = clamp(mat3(3.2406, -0.9689, 0.0557,      // columns
                          -1.5372, 1.8758, -0.2040,
                          -0.4986, 0.0415, 1.0570) * xyz, 0.0, 1.0);
    return mix(1.055 * pow(lin, vec3(1.0 / 2.4)) - 0.055, 12.92 * lin, step(lin, vec3(0.0031308)));
}

void main() {
    ivec2 p = clamp(ivec2(uv * 256.0), ivec2(0), ivec2(255));
    uint n = texelFetch(counts, ivec3(p, v_layer), 0).r;
    vec3 rgb;
    if (n == 0xFFFFFFFEu) {
        rgb = interior;
    } else if (n == 0xFFFFFFFFu) {
        rgb = unresolved;
    } else {
        float z2 = texelFetch(zz, ivec3(p, v_layer), 0).r;
        float nu = float(n) + 1.0 - log2(log(max(z2, exp(log_r2))) / log_r2);
        if (mode <= 3) {
            float v;
            if (mode == 0) v = float(n);
            else if (mode == 1) v = nu;
            else if (mode == 2) v = log2(1.0 + max(nu, 0.0));
            else {
                float x = clamp((nu - cdf_range.x) / max(cdf_range.y - cdf_range.x, 1e-9), 0.0, 1.0);
                float size = float(textureSize(cdf, 0).x);
                v = texture(cdf, vec2((x * (size - 1.0) + 0.5) / size, 0.5)).r;
            }
            rgb = texture(palette, vec2(fract(v * density + offset), 0.5)).rgb;
        } else {
            float s = max(nu, 0.0) / max(max_it, 1.0) * density;
            float hue = mod(pow(360.0 * s, 1.5) + 360.0 * offset, 360.0);
            if (mode == 4) rgb = hsv_to_rgb(hue, 1.0, 1.0);
            else {
                float c = cos(3.14159265 * s);
                float vv = 1.0 - c * c;
                rgb = lch_to_srgb(75.0 - 75.0 * vv, 28.0 + 75.0 - 75.0 * vv, hue);
            }
        }
    }
    colour = vec4(pow(clamp(rgb, 0.0, 1.0), vec3(1.0 / gamma)), 1.0);
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

        self.cdf = ctx.texture((CDF_SIZE, 1), 1, dtype="f4")
        self.cdf.filter = (moderngl.LINEAR, moderngl.LINEAR)
        self.cdf.repeat_x = self.cdf.repeat_y = False

        self.prog = ctx.program(vertex_shader=VERTEX, fragment_shader=FRAGMENT)
        for unit, name in enumerate(("counts", "zz", "palette", "cdf")):
            self.prog[name] = unit
        self.colouring = Colouring()
        self._cdf = None  # the array in the texture

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
        c = self.colouring
        if c.mode == "histogram" and self._cdf is not c.cdf:  # a new CDF is a new array
            self.cdf.write(np.ascontiguousarray(c.cdf, "<f4").tobytes())
            self._cdf = c.cdf
        self.prog["mode"] = MODES.index(c.mode)
        self.prog["density"] = float(c.density)
        self.prog["offset"] = float(c.offset)
        self.prog["interior"] = tuple(float(x) for x in c.interior)
        self.prog["unresolved"] = tuple(float(x) for x in c.unresolved)
        self.prog["gamma"] = float(c.gamma)
        self.prog["max_it"] = float(c.max_it)
        self.prog["log_r2"] = float(np.log(c.bailout_r2))
        self.prog["cdf_range"] = (float(c.cdf_lo), float(c.cdf_hi))
        for unit, tex in enumerate((self.counts, self.zz, self.palette, self.cdf)):
            tex.use(unit)
        self.ctx.disable(moderngl.BLEND | moderngl.DEPTH_TEST | moderngl.CULL_FACE)
        self.vao.render(moderngl.TRIANGLE_STRIP, vertices=4, instances=len(quads))

    def release(self):
        for o in (self.vao, self.inst_buf, self.corner_buf, self.prog, self.cdf, self.palette, self.zz,
                  self.counts):
            o.release()
