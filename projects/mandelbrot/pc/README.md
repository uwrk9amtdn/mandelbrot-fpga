# PC application

A viewer for the Mandelbrot set. It renders on the DE25-Nano board, which it reaches over TCP
through `mandelbrotd` on the HPS, or on a simulated server. Design, protocol and milestones:
[PC_APP_PLAN.md](../PC_APP_PLAN.md).

## Run

```sh
uv sync --extra gui                                    # once; the extra installs imgui-bundle and moderngl
uv run python -m mandelbrot.app --host 192.168.10.10   # the board (mandelbrotd must be running there)
uv run python -m mandelbrot.app --sim                  # a simulated server in this process, no board
uv run python -m mandelbrot.app --offline              # browse the disk cache, no server
uv run python -m mandelbrot.app                        # choose the server in the Connection panel
```

Options:

| Option | Default | Meaning |
|---|---|---|
| `--host`, `--port` | none, 5150 | server to connect to at start |
| `--sim`, `--sim-format` | `wide` | simulated server; `wide` is W=64/F=54, `board` is the phase 1 W=21/F=16 (both float64), `exact` the W=64 bitstream's arithmetic bit for bit (slow; `python -m mandelbrot.sim_server --exact` standalone) |
| `--re`, `--im`, `--level` | -0.75, 0, whole set | starting view |
| `--max-it` | 256 | iteration limit |
| `--no-checks` | | don't request the periodicity check and cardioid test (requested by default when the server has them) |
| `--colouring`, `--palette` | `smooth`, `ultra` | colouring mode, and a preset or saved palette |
| `--size` | 1280x800 | window size |
| `--screenshot FILE`, `--wait S` | none, 30 | save a PNG once the view is complete, then exit |
| `--offline [ARITH_ID]` | the last server | no server: show cached tiles, hatch the missing ones |
| `--cache-dir`, `--cache-limit GB`, `--no-cache` | `~/.cache/mandelbrot-fpga/tiles`, 4 | the disk cache |

## Controls

- Mouse: the wheel zooms at the cursor, left drag pans, right drag zooms into a box, and a double
  click centres on that point.
- Keys: `+` / `-` double or halve max_it, `R` requests the screen again (bypassing the cache),
  `Esc` stops requesting until the next move, `Backspace` goes back one view, `H` hides the panels.
- Panels:
  - Connection: board (host/port), simulated server or offline (the cache of an earlier server,
    by arithmetic id), and what the server reports (W, F, cores).
  - View: level, magnification, a centre to type in (Go), Home, Back, max_it, and the hardware
    checks (periodicity, cardioid/bulb; exact, so the picture is the same, only faster).
  - Colouring: the mode (escape, smooth, log-smooth, histogram, hsv, lch); palette and gradient
    editor (Edit); density, offset, cycling (animates the offset), gamma; the colours of interior
    and of unresolved (max_it reached) pixels. Smooth values need the wide formats' R² = 256; at
    R² = 4 (the 21-bit design) they show bands. Saved palettes are in
    `~/.config/mandelbrot-fpga/palettes.json`.
  - Statistics: tile rates, frame time, the shares of escaped, max_it and interior pixels on screen
    (and which check proved the interior ones), and the board's temperatures and fan speed.
  - Bookmarks: named views (exact centre and pixel size, max_it, checks, colouring) in
    `~/.config/mandelbrot-fpga/bookmarks.json`; Go, delete (press x twice).
  - Tools: Verify tile: the tile at the centre of the screen from the server (not the cache) and from
    the bit-exact model (`fixed.py`, on all cores but one), compared bit for bit; the tile is outlined,
    green or red, with the first wrong pixels circled. Only for servers whose arithmetic id is the
    wide FPGA's (the board, `--sim-format exact`).
    Export PNG: the view at 1x, 2x, 4x or 8x the window's size (the same view, 4, 8 or 12 levels
    deeper), coloured on the CPU like the shader, written band by band; optionally the raw planes as
    `.npy` (counts, and |z|^2 or the proof iteration k). New tiles also go to the disk cache.
  - Cache: size, hits and misses; bypass (request every tile, still write the cache); offline / cache
    only; clear everything or the current arithmetic id. Tiles are only shown as results of the
    build (arithmetic id) that computed them.
  - Help.

## Tests

```sh
uv sync && uv run pytest -q                                          # no board needed
MANDELBROT_BOARD=192.168.10.10 uv run pytest -q tests/test_board.py  # against mandelbrotd
```

Modules in `mandelbrot/`: `protocol.py` (wire format), `net.py` (client, `OfflineConnection`),
`sim_server.py`, `view.py` (lattice maths), `tiles.py` (tile manager, in-memory LRU), `cache.py`
(disk cache), `verify.py` (verify tile, the exact model on a process pool), `bookmarks.py`, `export.py` (PNG and .npy), `colouring.py`, `gl_view.py` (textures, shader), `app.py` (viewer), `headless.py`
(render to PNG from the shell).

Other directories: `tools/precision_study.py` (the phase 2 error study), `tools/bench_views.py` (phase 3
benchmark views; runs on the board too) and `bench/` (a C++
reference benchmark).
