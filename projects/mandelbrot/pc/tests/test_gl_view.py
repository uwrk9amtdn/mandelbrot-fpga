"""The tile renderer in an off-screen OpenGL context (Mesa's software renderer is enough).
Skipped where no context can be created."""

import os

import numpy as np
import pytest

from mandelbrot import protocol as p
from mandelbrot.colouring import MODES, PALETTE_MODES, PALETTE_SIZE, PRESETS, Colouring, bake, histogram_cdf, reference
from mandelbrot.tiles import Quad, TileKey, TileStore
from mandelbrot.view import TILE


@pytest.fixture(scope="module")
def ctx():
    moderngl = pytest.importorskip("moderngl")
    os.environ.setdefault("EGL_PLATFORM", "surfaceless")
    os.environ.setdefault("LIBGL_ALWAYS_SOFTWARE", "1")  # Mesa's llvmpipe, no device needed
    try:
        c = moderngl.create_standalone_context(backend="egl")
    except Exception as e:
        pytest.skip(f"no OpenGL context: {e}")
    yield c
    c.release()


def render(ctx, quads, store, width, height, palette, colouring=None, smooth=False):
    from mandelbrot.gl_view import TileRenderer

    r = TileRenderer(ctx, capacity=8)
    r.set_palette(palette, smooth=smooth)
    # by default count n -> palette entry n
    r.colouring = colouring or Colouring(mode="escape", density=1.0 / PALETTE_SIZE, offset=0.5 / PALETTE_SIZE)
    r.upload(store.take_uploads())
    fbo = ctx.simple_framebuffer((width, height), components=3)
    fbo.use()
    fbo.clear(0.2, 0.2, 0.2)
    r.draw(quads, width, height)
    img = np.frombuffer(fbo.read(components=3), np.uint8).reshape(height, width, 3)[::-1]  # GL is bottom-up
    r.release()
    fbo.release()
    return img


def test_tiles_placed_and_coloured(ctx):
    rng = np.random.default_rng(1)
    palette = bake(PRESETS["ultra"])
    store = TileStore(capacity=8)
    counts = [rng.integers(1, 3000, (TILE, TILE), dtype=np.uint32) for _ in range(2)]
    counts[0][10:20, 30:40] = p.UNRESOLVED
    counts[1][100, :] = p.INTERIOR
    z = np.zeros((TILE, TILE), np.float32)
    t0 = store.put(TileKey(0, 0, 0, 10, 0), counts[0], z, 0)
    t1 = store.put(TileKey(0, 1, 0, 10, 0), counts[1], z, 0)
    width, height = 400, 300
    # tile 0 at (-50, -20), 1:1; tile 1 at (206, 10), scaled 2x and clipped
    img = render(ctx, [Quad(t0.layer, -50, -20, TILE), Quad(t1.layer, 206, 10, 2 * TILE)], store, width, height, palette)

    def expect(c):
        rgb = palette[c % PALETTE_SIZE]
        return np.where((c >= p.INTERIOR)[..., None], 0, rgb).astype(np.uint8)

    assert np.array_equal(img[0:236, 0:206], expect(counts[0][20:256, 50:256]))
    big = np.repeat(np.repeat(counts[1], 2, 0), 2, 1)  # 2x nearest
    assert np.array_equal(img[10:300, 206:400], expect(big[0:290, 0:194]))
    assert (img[236:300, 0:206] == 51).all()  # background, (0.2 * 255) where nothing is drawn


def wide_tile(rng):
    """Counts and |z|^2 as the wide formats give them (R^2 = 256: |z_n|^2 in (256, 256^2])."""
    counts = rng.integers(1, 2000, (TILE, TILE), dtype=np.uint32)
    zz = np.exp(rng.uniform(np.log(256.0), 2 * np.log(256.0), (TILE, TILE))).astype(np.float32)
    counts[:8, :] = p.INTERIOR
    counts[8:16, :] = p.UNRESOLVED
    return counts, zz


@pytest.mark.parametrize("mode", MODES)
def test_modes_match_reference(ctx, mode):
    rng = np.random.default_rng(2)
    counts, zz = wide_tile(rng)
    store = TileStore(capacity=8)
    t = store.put(TileKey(0, 0, 0, 2000, 0), counts, zz, 0)
    c = Colouring(mode=mode, density=0.013 if mode in PALETTE_MODES else 9.0, offset=0.3, interior=(0.1, 0.2, 0.3),
                  unresolved=(0.9, 0.8, 0.7), gamma=1.3, max_it=2000, bailout_r2=256.0)
    if mode == "histogram":
        c.cdf, c.cdf_lo, c.cdf_hi = histogram_cdf([(counts, zz)], 256.0)
    palette = bake(PRESETS["ultra"])
    img = render(ctx, [Quad(t.layer, 0, 0, TILE)], store, TILE, TILE, palette, c, smooth=True)
    want = np.round(reference(counts, zz, c, palette) * 255.0)
    diff = np.abs(img.astype(np.int32) - want.astype(np.int32)).max(axis=-1)
    # f32 on the GPU against f64: a pixel whose palette position lands on a steep part may differ more
    assert np.mean(diff <= 2) > 0.995, f"{np.mean(diff <= 2):.4f} of the pixels within 2"
    assert (diff[:16] == 0).all()  # interior and unresolved exactly
