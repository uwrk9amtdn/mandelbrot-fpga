# Plan: communication protocol and PC application

Part of [ROADMAP.md](ROADMAP.md), phase 1. Status: milestone 1 is done (`pc/`: `protocol.py`,
`sim_server.py` in fast mode, `net.py`, `view.py`, `headless.py`, tests); the viewer is next.

The PC application (the client) tiles the screen, sends tile requests to the board, receives
iteration counts and does all the colouring. On the board, the HPS server `mandelbrotd` passes each
request to the FPGA as one job and returns the result. The server keeps no view or colouring state:
every request is self-contained.

## 1. Language choice: Python + Dear ImGui + OpenGL

| | Python (imgui-bundle + moderngl + numpy) | C++ (Dear ImGui + GLFW + OpenGL + asio) |
|---|---|---|
| Per-pixel work (colouring) | In a GLSL fragment shader: same speed as C++ | Same shader |
| Per-tile work (requests, decompression, texture upload) | About 50 tiles per screen, about 512 KB each: numpy and lz4 (GIL released) are fast enough | Faster, but this isn't the bottleneck |
| Coordinates at 128 bits and more | Python `int` is exact at any width, so it's trivial | `__int128` works up to 128 bits; perturbation needs Boost.Multiprecision or MPFR |
| Deep-zoom maths later (reference orbits) | `gmpy2` (MPFR) | MPFR |
| Development speed, sharing code with the simulated server and tests | High: one `protocol.py` for the client, the simulated server and the tests | Lower |
| Distribution | `pip install` the dependencies | A single binary |

**Decision: Python.**
- Libraries:
  - `imgui-bundle`: maintained Dear ImGui bindings, with GLFW, an OpenGL backend and ImPlot.
  - `moderngl` for textures and shaders.
  - `numpy` and `lz4`.
- C++ is only worth it for code that does heavy per-pixel work on the CPU. That is the planned
  **CPU benchmark** for the report's FPGA vs CPU comparison, which will be a separate small C++
  program (`pc/bench/`, AVX2/AVX-512).

## 2. Protocol (TCP, binary, little-endian), version 1

- **Transport:** one TCP connection, server port 5150, with `TCP_NODELAY` on both sides.
- **Message header, 16 bytes:**

  | Field | Type | Meaning |
  |---|---|---|
  | magic | 4 bytes | `MBRT`, in this order on the wire |
  | type | u16 | message type, see the table below |
  | flags | u16 | 0 for now |
  | length | u32 | payload size in bytes |
  | reserved | u32 | 0 |

- **Coordinates:** fixed point as W-bit two's complement with F fraction bits, the format of the
  FPGA registers. A coordinate is sent as N = ⌈W/32⌉ u32 words, low word first, sign-extended. Today's
  19-bit cores use 1 word, W = 128 uses 4. The client gets W and F from INFO.

### Messages

| Type | Name | Direction | Payload |
|---|---|---|---|
| 1 | HELLO | C→S | u16 protocol version (1) |
| 2 | INFO | S→C | u16 protocol version; u16 W; u16 F; u16 nCores; u32 core clock in kHz; u16 max tile width (256); u16 max tile height (256); u16 max requests in flight; u16 feature bits (bit 0 periodicity check, 1 cardioid test, 2 LZ4); u32 max max_it; u32 bailout R²; u32 **arithmetic id** |
| 3 | TILE_REQ | C→S | u32 request id (unique for the connection, never reused, not 0); u16 width; u16 height; u32 max_it; u32 flags (bit 0 periodicity, 1 cardioid, 2 LZ4 wanted); x0, y0 (the **top-left pixel**), step: N words each |
| 4 | TILE | S→C | u32 request id; u16 width; u16 height; u8 encoding (0 raw, 1 LZ4); u8 status (0 complete, 1 aborted by a cancel); 2 bytes padding; u32 raw size; u64 iterations of this tile; u64 total iterations and u64 total cycles (the FPGA's free-running counters, read when the tile finished); then the data |
| 5 | CANCEL | C→S | u16 count; 2 bytes padding; count × u32 request id. Count 0 cancels every outstanding request. |
| 6 | ERROR | S→C | u32 request id (0 if none); u16 code; u16 text length; UTF-8 text |
| 7 | PING | either | u32 cookie |
| 8 | PONG | either | the same u32 cookie |

- **Pixel coordinates:** pixel (i, j) of a tile, with i the column and j the row, is
  c = (x0 + i·step, y0 − j·step). The rows go down the screen, so imaginary values decrease.
- **Iteration count:** with z_0 = 0 and z_n = z_(n−1)² + c, the count of a pixel is the smallest
  n ≥ 1 with |z_n|² ≥ R². A pixel with no such n up to max_it did not escape.
- **Tile data, in two planes:**
  - the counts: u32 per pixel, row-major, width × height. Two codes mark pixels that did not escape:
    0xFFFFFFFF reached max_it (not resolved), and 0xFFFFFFFE is proven interior by the periodicity
    or the cardioid check (final at any max_it). So max_it is at most 0xFFFFFFFD.
  - |z_n|² at escape: f32 per pixel, in the same order. 0 for pixels that did not escape.

  The FPGA writes one 64-bit record per pixel (count and |z|² together), which takes one AXI write
  instead of two. `mandelbrotd` splits the records into the two planes while it copies the tile out
  of the result slot, a pass it has to make anyway. Planes compress better than records, and they
  upload to the GPU as two textures without conversion. With LZ4, both planes are compressed as one
  block.
- **Cancelling, by request id:**
  - Tiles sit on a global grid, so after a pan most of the requests in flight are still wanted. The
    client cancels only the requests whose tile left the visible set, and lets the others finish.
    That way a continuous drag at deep zoom, where a tile takes seconds, still makes progress.
  - A change of max_it or of a result-changing flag cancels everything (count 0).
  - For each id in a CANCEL, the server drops the request if it is still queued on the HPS, or
    aborts its FPGA job, and answers at once with a TILE of status "aborted", no data, and width and
    height 0. Ids it doesn't know (already answered) are ignored.
  - Request ids are never reused, so there is no race between a CANCEL and a TILE already on the
    way, and no acknowledgement is needed: a complete TILE that arrives after its cancel is still a
    valid tile, and goes into the cache.
- **Flow control:** the client keeps at most the "max requests in flight" from INFO outstanding. That
  number is the board's count of result slots, 8 for now. Each TILE or ERROR frees one. A cancelled
  request still returns a TILE (aborted, without data), so the count always matches.
- **Arithmetic id:** a 32-bit hash of everything that changes the result bits: W, I, the truncation
  guard bits, the bailout radius, the result-format version, and the arithmetic model (FPGA or
  simulated fast/exact mode). The FPGA has it as a constant register, computed by the generator from
  the configuration. The cache uses it, so tiles from one build or from the simulated server are
  never shown as results of another.
- **Errors,** by code: 1 protocol version not supported (in reply to HELLO; the server then closes),
  2 bad tile size, 3 bad max_it, 4 unknown flag or a feature the server lacks, 5 more requests in
  flight than INFO allows, 6 request id 0 or already in flight, 7 the tile doesn't fit W bits,
  8 malformed message. An ERROR that names a request ends that request.
- **A future version** adds message types for perturbation (reference orbit upload, delta tiles).
  HELLO/INFO negotiate the version.

### Shared definition

- `pc/mandelbrot/protocol.py`: struct layouts, encoding and decoding. It is used by the app, the
  simulated server and the tests.
- `hps/protocol.h`: the same layouts in C for `mandelbrotd`. A test runs the Python client against the
  C server to check they agree.

## 3. Simulated server (needed before the board works)

`pc/mandelbrot/sim_server.py` speaks the same protocol and computes the tiles on the PC:

- **Fast mode:** numpy float64, for developing the app at shallow zoom.
- **Exact mode:** a bit-exact integer model of the FPGA arithmetic at W bits (slow, for small tiles).
  The app can then send one tile to both the board and the model and compare them bit for bit (a
  "verify tile" button). This is the end-to-end hardware check.
- It reports a configurable W, F, nCores and max in-flight count, so all the client code paths can be
  tested without the board.

## 4. PC application

### Structure (`projects/mandelbrot/pc/`)

```
pc/
  pyproject.toml           dependencies: imgui-bundle, moderngl, numpy, lz4 (gmpy2 later)
  mandelbrot/
    protocol.py            messages (shared with the simulated server and the tests)
    net.py                 connection thread: socket, receive, LZ4, queue of finished tiles
    view.py                exact view maths (integers), zoom/pan, zoom history
    tiles.py               tile grid, previews, centre-out request order, cancelling, flow control
    cache.py               disk tile cache (eviction) and the in-memory LRU
    colouring.py           palettes, gradients, histogram (numpy), presets
    gl_view.py             tile texture arrays, shaders, drawing
    shaders/               view.vert, colour.frag
    app.py                 ImGui window, panels, mouse and keyboard
    sim_server.py          simulated server
  tests/                   protocol round trip, view maths, tiling, client against simulated server
  bench/                   C++ CPU benchmark (separate)
```

### Threads

- **UI thread:** ImGui and OpenGL. All GL calls happen here.
- **Network thread:**
  - reads messages and decompresses the tiles
  - puts finished tiles (numpy arrays) on a queue
  - writes the requests that the UI thread queued

  Socket and lz4 calls release the GIL, so the UI stays at 60 fps while the data streams in.
- **Each UI frame:** takes the finished tiles off the queue, uploads each with `texture.write` into a
  free layer of the tile texture arrays, and sends new requests as slots become free.

### View maths (exact, on a global pixel lattice)

Everything is placed on a global lattice, so a tile has the same coordinates and the same cache key
no matter how the view got there.

- **Zoom levels:** the pixel step comes only from a discrete set, step(L) = round(2^(F − 2 − L/4)) in
  units of 2^-F, for level L = 0, 1, 2, ... At L = 0 a pixel is 1/4, so 1920 pixels span 480; every 4
  levels halve the step. step(L) is a fixed integer function of F and L, so the same level always
  gives exactly the same step.
- **Pixel lattice:** at level L, pixel (X, Y) with X, Y unbounded integers is c = (X·step, −Y·step).
  Y grows downwards.
- **The view** is (L, X0, Y0): the integer lattice position of the screen's top-left pixel. Screen
  pixel (px, py) is lattice pixel (X0 + px, Y0 + py).
- **Pan:** X0 −= dx, Y0 −= dy, in whole pixels. Nothing has to be recomputed, only the newly exposed
  tiles are needed.
- **Zoom at the mouse:** one wheel notch is L ± 1. The lattice pixel under the cursor is converted to
  the new level and rounded, and X0, Y0 are chosen so that it stays under the cursor (to within one
  pixel).
  - Rectangle zoom and typed coordinates snap to the nearest level and the nearest pixel. The
    magnification error is at most 2^(1/8) ≈ 9 %, and the position error under one pixel.
- **Zoom limit:** when step(L) reaches a few ulps, for example step < 2^4, the view shows "hardware
  precision limit (W bits)" and stops zooming. Below that, the rounding of step(L) makes the levels uneven, and the
  arithmetic's own rounding error approaches the pixel size.
- **Zoom-out limit and tiles outside the format:** the format holds |c| < 2^(I−1), and a tile whose
  pixels don't all fit can't be requested (the server answers with error 7). The client fills such
  a tile in itself: every pixel escapes at n = 1 with |z|² = |c|², which is right as long as all
  of the tile has |c| ≥ R. That holds if a tile is no wider than 2^(I−1) − R, which sets the
  lowest level: 0 for I = 10, but 9 for the phase 1 hardware (I = 5, R = 2), whose levels are
  9..40.
- **Zoom history:** Backspace returns to the previous view.

### Tiling and display

- **Global tile grid:** tile (L, TX, TY) covers lattice pixels X = 256·TX ... 256·TX + 255 and
  Y = 256·TY ... 256·TY + 255. Its request is x0 = 256·TX·step, y0 = −256·TY·step, at 256×256.
  - Tiles are always full size. The ones at the screen edges are clipped on display. A 1920×1080 view
    needs 9×6 tiles at most (8×5 when aligned), a few percent extra computation, in exchange for cache
    hits and simpler code.
  - Smaller requests are still used for Mariani-Silver borders (phase 3).
- **Getting a tile** (`tiles.py`):
  1. the in-memory LRU
  2. the disk cache (in a worker thread: read and LZ4 decode)
  3. a request to the board

  Requests go out centre-out (spiral order), so the area being looked at appears first.
- **Previews:** when the visible tiles are not all there yet (and L ≥ 12), the tiles of level L − 12
  covering the screen are requested first. Their step is about 8 times larger, so a 1080p view is 240×135 pixels
  there: one to four tiles, about 1/64 of the work. They are drawn scaled until the real tiles
  cover them, by the same code that draws the previous level during a zoom. A preview is an
  ordinary tile on the lattice, so it needs nothing from the FPGA or the protocol, and it is cached
  like any other. (The ratio is exactly 8 only where step(L) isn't rounded; that doesn't matter for
  a preview.)
- **Tiles on the GPU:** two 2D array textures of 256×256 layers, counts as R32UI and |z|² as R32F. A
  tile is one layer in each. The arrays are the GPU side of the in-memory LRU: 256 layers take
  128 MB and hold a 1080p screen (54 tiles at most) several times over, which leaves room for the
  previous level and the previews.
- **Drawing:** one quad per visible tile (instanced), carrying its layer and its position on the
  screen. The colouring shader samples the arrays with nearest filtering. The positions are computed
  on the CPU in exact integers relative to the view's top-left pixel, so the GPU only sees small
  screen coordinates, whatever the zoom depth.
- **During a pan,** only the quads move. Newly exposed tiles are fetched, mostly from the cache when
  going back. Requests in flight for tiles that are still visible keep running; only the ones that
  left the screen are cancelled.
- **During a zoom,** the tiles of the previous level are still in the arrays. They are drawn scaled,
  under the tiles of the new level, until those cover them. That gives immediate feedback with the
  same drawing code.
- **Resizing the window** changes only which tiles are visible. No texture is reallocated.

### Tile cache

**Key:** a tile's result depends only on

  (arithmetic id, W, F, step, TX, TY, width, height, max_it, result-changing flags)

- The result-changing flags are periodicity and cardioid, and from phase 3 a flag for tiles filled
  by Mariani-Silver on the PC. LZ4 isn't one.
- The key's canonical encoding is decimal text joined with `|`. TX and TY can have about 120 bits at
  deep zoom, which Python handles natively.
- The SHA-256 of the key **without max_it** names the file, so the lookup can reuse a tile computed
  at another max_it (see below).

**Files:**
- **Location:** `~/.cache/mandelbrot-fpga/tiles/<first 2 hex digits>/<sha256>.mbt`. The directory is
  configurable; on Windows use `%LOCALAPPDATA%`.
- **Header:** magic `'MBTC'`, a format version, the full key, encoding, raw size, iterations, the
  number of unresolved pixels (count 0xFFFFFFFF), and the date.
- **Data:** the tile data, LZ4-compressed (as received from the board, or compressed by the app).
- **On read,** the header's key is compared with the requested one. A mismatch, or a damaged or
  truncated file, counts as a miss and the file is deleted.
- **Writes** are atomic: write to `*.tmp`, then rename. A crash never leaves a half-written tile that
  looks valid. Writing happens in a writer thread, so the UI never waits on the disk.

**What gets cached:**
- Only TILEs with status "complete", including the ones that arrive after their cancel. Aborted
  tiles carry no data.
- Tiles from the simulated server are cached too. Their arithmetic id differs, so they never mix with
  hardware tiles.

**Reuse at another max_it:** a cached tile computed with max_it M answers a request with max_it M',
everything else in the key being the same, in two cases.
- **M' ≤ M.** Counts up to M' are identical. Pixels with a count above M' become "reached max_it"
  (0xFFFFFFFF) and their |z|² isn't used. Proven-interior pixels stay as they are.
- **The tile has no unresolved pixel,** for any M'. Every pixel either escaped, with a count that
  no higher max_it changes, or is proven interior. Most tiles away from the set are like this, so
  raising max_it recomputes only the tiles that still have unresolved pixels.

When the board
computes a tile again at a higher max_it, the new entry replaces the old one.

**Size limit and eviction:**
- Default 4 GB, configurable. A 256×256 tile is 512 KB raw. With LZ4 the count plane shrinks a lot
  and the f32 |z|² plane hardly at all, so expect about 300 KB: over ten thousand tiles.
- LRU by file modification time, which is updated on every hit.
- No separate index: the files are the only state. At startup a scan of the directory (a `stat` of
  ten to twenty thousand files) gives the total size, and the app keeps a running total after
  that. Over the limit, it deletes the oldest files until it is back at 90 %. A lookup opens the
  file named by the key's hash and reads max_it and the unresolved count from its header. Add an
  index only if the startup scan turns out to be slow.

**In-memory LRU:** 256 tiles, configurable. Each is a layer of the tile texture arrays (128 MB on the
GPU in all) and a pair of numpy arrays for the histogram and the export (another 128 MB). Panning
back and forth doesn't touch the disk. It exists from milestone 2; the disk cache is added in
milestone 5.

**Cache panel in the UI:**
- the directory, the size used and the limit
- hits, misses, and hit rate this session
- buttons: "clear the cache" and "clear this arithmetic id"
- **Bypass cache:** always request from the board, but still update the cache. For benchmarks and
  hardware checks.
- **Offline / cache only:** never request. Missing tiles are drawn hatched. This lets you browse
  earlier renders without the board.

**Later:** prefetching while the board is idle: the ring of tiles just outside the screen, and the
level above and below around the cursor.

### Colouring (fragment shader, so a change costs no re-render)

| Algorithm | Inputs | Notes |
|---|---|---|
| Escape time | count | palette[n mod H] |
| Smooth | count, \|z\|² | ν = n + 1 − log₂(log\|z_n\| / log R), with log\|z_n\| = ½ log\|z_n\|² and R² from INFO; interpolated between palette[⌊ν⌋] and palette[⌊ν⌋+1]. Looks right only with a large bailout radius (R = 16, from phase 2). |
| Log-smooth | count, \|z\|² | colour from log(ν): keeps deep zooms with large counts readable |
| Histogram | count (or ν), CDF texture | numpy `bincount` of the visible tiles' counts gives the CDF, uploaded as a 1D texture. It is recomputed when tiles arrive, at most a few times per second. Independent of max_it. |
| HSV / LCH (from the Wikipedia article) | count or ν | h = (ν/max · 360)^1.5 mod 360, and so on |
| Distance estimate | later | once the FPGA sends the derivative |

- **Common parameters:** palette, density (colours per iteration), offset (with palette cycling as an
  animation), interior colour (and optionally a second one for unresolved pixels), gamma.
- **Palettes:** presets, and a gradient editor (ImGui colour pickers for the control points) baked
  into a 1D RGBA texture of 1024 entries.
- Colouring settings are saved with bookmarks.

### Controls and panels

- **Mouse:**
  - wheel: zoom at the cursor
  - left drag: pan
  - right drag: rectangle zoom
  - double click: centre on that point
- **Keys:**
  - `+` / `−`: max_it × 2 / ÷ 2
  - `R`: re-render (request the visible tiles again from the board, bypassing the cache)
  - `Esc`: cancel all outstanding requests
  - `Backspace`: zoom back
  - `H`: hide the panels
- **Connection panel:** host and port (or "simulated" mode), connect/disconnect, INFO contents,
  protocol version.
- **View panel:**
  - centre (re, im) as decimal text, editable, for precise jumps (converted to integers)
  - zoom as a magnification and as 2^k
  - pixel step
  - precision used (bits of F in use)
- **Render panel:**
  - max_it (input, with an "auto" option that raises it with zoom depth)
  - periodicity check, cardioid test, Mariani-Silver (the hardware ones enabled only when INFO reports
    them)
- **Colouring panel:** algorithm, palette and its parameters.
- **Statistics:** tiles/s, MB/s, G iterations/s, frame render time, the share of unresolved pixels on
  screen, and FPGA utilisation: Δ total iterations / (Δ total cycles · nCores), from the totals of
  two TILEs.
- **Bookmarks:** named views with their colouring, in a JSON file.
- **Export:**
  - PNG of the screen
  - a high-resolution PNG (for example 8K, rendered as tiles off screen)
  - the raw count and |z|² planes as `.npy` for offline colouring

## 5. Milestones

1. **Protocol and simulated server (done):** `protocol.py`, `sim_server.py` (fast mode), and a
   headless client test that renders a full view and compares it with numpy. `headless.py` also
   renders a view to a PNG from the shell, which is the first thing to run against the board.
2. **Viewer:** window, textures, escape-time colouring, the global lattice and tile grid, previews,
   cancelling and flow control, zoom and pan with the mouse.
3. **Colouring:** smooth, log-smooth, histogram, HSV/LCH, palettes and the gradient editor, panels.
4. **Board:** connect to `mandelbrotd` as soon as the FPGA and HPS side of phase 1 is ready; compare
   with the simulated server; measure throughput. Nothing below is needed for this.
5. **Cache:** disk cache with eviction, reuse at another max_it, the cache panel, offline mode.
   Tests: key canonicalisation, a damaged file counts as a miss, eviction at the size limit, a
   second render of a view is 100 % hits, a tile without unresolved pixels answers a higher max_it.
6. **Tools:** statistics, bookmarks, export, high-resolution render, the exact mode and "verify
   tile".
7. **Phase 3 features:** Mariani-Silver in `tiles.py`, the hardware flags in the UI.

## Open questions

- Window size vs. screen size on a HiDPI display: render at physical pixels (default) or at a scaled
  size to render faster.
- Auto max_it: a simple rule (for example 100 + 50·log₂(magnification)) to start. Then use the share
  of unresolved pixels on screen: raise max_it while that share is still falling.
