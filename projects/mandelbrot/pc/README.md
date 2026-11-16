# PC application

A viewer for the Mandelbrot set. It renders on the DE25-Nano board, which it reaches over TCP
through `mandelbrotd` on the HPS, or on a simulated server. Design, protocol and milestones:
[PC_APP_PLAN.md](../PC_APP_PLAN.md).

## Run

```sh
uv sync --extra gui                                    # once; the extra installs imgui-bundle and moderngl
uv run python -m mandelbrot.app --host 192.168.10.10   # the board (mandelbrotd must be running there)
uv run python -m mandelbrot.app --sim                  # a simulated server in this process, no board
uv run python -m mandelbrot.app                        # choose the server in the Connection panel
```

Options:

| Option | Default | Meaning |
|---|---|---|
| `--host`, `--port` | none, 5150 | server to connect to at start |
| `--sim`, `--sim-format` | `wide` | simulated server; `wide` is W=64/F=54, `board` is the phase 1 W=21/F=16 |
| `--re`, `--im`, `--level` | -0.75, 0, whole set | starting view |
| `--max-it` | 256 | iteration limit |
| `--size` | 1280x800 | window size |
| `--screenshot FILE`, `--wait S` | none, 30 | save a PNG once the view is complete, then exit |

## Controls

- Mouse: the wheel zooms at the cursor, left drag pans, right drag zooms into a box, and a double
  click centres on that point.
- Keys: `+` / `-` double or halve max_it, `R` requests the screen again (bypassing the cache),
  `Esc` stops requesting until the next move, `Backspace` goes back one view, `H` hides the panels.
- Panels:
  - Connection: the server, simulated or host/port, and what the server reports (W, F, cores).
  - View: level, magnification, a centre to type in (Go), Home, Back, max_it.
  - Colouring: palette, density, offset.
  - Statistics: tile rates, and the board's temperatures and fan speed.
  - Help.

## Tests

```sh
uv sync && uv run pytest -q                                          # no board needed
MANDELBROT_BOARD=192.168.10.10 uv run pytest -q tests/test_board.py  # against mandelbrotd
```

Other directories: `tools/precision_study.py` (the phase 2 error study) and `bench/` (a C++
reference benchmark).
