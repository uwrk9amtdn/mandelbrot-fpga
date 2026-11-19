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
| `--sim`, `--sim-format` | `wide` | simulated server; `wide` is W=64/F=54, `board` is the phase 1 W=21/F=16 |
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
  - Statistics: tile rates, and the board's temperatures and fan speed.
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
(disk cache), `colouring.py`, `gl_view.py` (textures, shader), `app.py` (viewer), `headless.py`
(render to PNG from the shell).

Other directories: `tools/precision_study.py` (the phase 2 error study) and `bench/` (a C++
reference benchmark).
