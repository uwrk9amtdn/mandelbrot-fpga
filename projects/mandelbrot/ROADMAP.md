# Roadmap: Ethernet, 128-bit precision and better algorithms (DE25-Nano)

Status: plan, nothing below is implemented yet. Starting point is the `de25-nano-port` branch:
60 cores, FRAC 16 (19-bit fixed point), 198 MHz, HDMI output, UART control
(see [DE25NANO_PORT_REPORT.md](DE25NANO_PORT_REPORT.md)).

## Goals

1. **No HDMI.** The FPGA sends per-pixel results to a PC application, which does the colouring
   (smooth, histogram, LCH, distance estimation, ...) and displays the image.
2. **Ethernet, both ways.** The PC application sends the commands (view, max iterations, render, cancel)
   and receives the results over the network. The UART protocol goes away.
3. **128-bit fixed-point precision** (zoom to about 1e-33), as a build parameter: 64/96/128 bits.
4. **Faster rendering**, through algorithms more than raw multiplier count, and later perturbation
   for zooms deeper than 128 bits.

## Facts that shape the plan

| Fact | Source | Consequence |
|---|---|---|
| Gigabit Ethernet PHY is wired to the HPS (EMAC0, RGMII) | user manual 3.8.2, GHRD `agilex_hps.ip` | Ethernet goes through Linux on the HPS. The FPGA talks to the HPS, not to the PHY. |
| FPGA UART (FT4232H) is at most 12 Mbaud, about 1.2 MB/s | manual 3.8.3 | 1080p x 8 B = 16.6 MB takes 14 s per frame. Debug use only. |
| HPS memory has to use LPDDR4A | manual 3.7.4 | The current design uses LPDDR4A for the framebuffer. Once the HPS is in, results go to HPS memory (shared with Linux), and the FPGA EMIF (EMIF_Qsys) is dropped. LPDDR4B stays free for later (reference orbits). |
| GHRD exports `lwhps2fpga`, `hps2fpga`, `fpga2hps`, `f2sdram` | `Demonstration/SoC_FPGA/GHRD` (Quartus 25.1) | Registers go on `lwhps2fpga`, result writes on `f2sdram` (or the coherent `fpga2hps`). |
| A Linux SD image exists | `de25_nano_sdcard_console_v1.1.zip` | No Yocto build needed to start. |
| 188 DSP blocks give 188 27x27 multipliers; 358 M20K blocks (7.3 Mbit) | fit report | 128-bit cores are DSP-limited (about 5 cores). On-chip RAM limits the reference-orbit length for perturbation. |
| 1 GbE is about 110 MB/s in practice | | About 6 frames/s of raw 1080p at 8 B/px, more with LZ4. At deep zoom the computation is far slower than that, so the link is not the bottleneck. |

## Target architecture

```
 PC application (Python)                        DE25-Nano
 ─────────────────────────                      ──────────────────────────────────────────────────────
 view, mouse zoom/pan          TCP over 1GbE    HPS (Cortex-A76/A55, Linux)
 splits the screen into  ───── tile requests ─> mandelbrotd: thin TCP <-> FPGA bridge, request queue,
 tiles (up to 256x256),  <──── tile results ─── LZ4
 Mariani-Silver, symmetry,                      │ lwhps2fpga (registers, AXI-Lite) + IRQ (UIO)
 colouring, display                             │                     ▲ f2sdram (AXI4 writes of results)
                                                ▼                     │
                                                FPGA: MandelbrotAccel
                                                job queue -> pixel issuer -> N cores (W-bit) ->
                                                result writer -> HPS LPDDR4A (reserved buffers)
```

### FPGA: `MandelbrotAccel` (SpinalHDL, replaces `MandelbrotSystem`)

- **Removed:** `DisplayDriver`, `ColorConverter`, `Adv7513Setup`/`I2cWriter`, `MemoryReader`,
  `UartControl`, `EmifCalibration`, the EMIF_Qsys BlackBox and the `sys_pll` pixel clock. The core
  clock stays (from `sys_pll`, CLOCK0_50).
- **Register slave (`lwhps2fpga`, AXI-Lite, 32-bit registers):**

  | Offset | Name | Access | Content |
  |---|---|---|---|
  | 0x000 | ID | RO | 'MAND' |
  | 0x004 | VERSION | RO | |
  | 0x008 | CAPS | RO | nCores, W (total bits), I (integer bits), feature bits (periodicity, cardioid) |
  | 0x010 | CONTROL | WO | bit 0 start job, bit 1 abort, bit 8 IRQ enable |
  | 0x014 | STATUS | RO/W1C | busy, done (W1C), error |
  | 0x020-0x02C | X0[4] | RW | real part of the tile's top-left pixel, W-bit two's complement, low word first. Given directly by the PC: the FPGA no longer computes the top left from a centre (today's `Wrapper` setup stage goes away). |
  | 0x030-0x03C | Y0[4] | RW | imaginary part of the top-left pixel |
  | 0x040-0x04C | STEP[4] | RW | distance between pixels |
  | 0x050 | WIDTH, HEIGHT | RW | tile size in pixels, 1..256 each (16 + 16 bits). Smaller tiles are allowed at the screen edges and for Mariani-Silver borders. |
  | 0x054 | MAX_IT | RW | 32 bits |
  | 0x058 | FLAGS | RW | periodicity check, cardioid/bulb test, subsample |
  | 0x060 | RESULT_ADDR | RW | physical address of the result buffer in HPS memory |
  | 0x064 | RESULT_STRIDE | RW | bytes per result row |
  | 0x080 | PIXELS_DONE | RO | progress |
  | 0x084-0x088 | ITERATIONS | RO | 64-bit count of iterations done (performance statistics) |
  | 0x08C | CYCLES | RO | core cycles spent on the job |

  The registers X0..RESULT_STRIDE fill a **job queue** (CONTROL bit 0 pushes a job), not a single job.
  A 256x256 tile is 65 536 pixels, about 0.5-1 ms at shallow zoom. With one job at a time the cores
  would idle while the HPS reacts to an interrupt and loads the next tile, and while the slowest pixels
  of a tile finish. The queue is 4 jobs deep. A DONE FIFO holds the ids of finished jobs and raises the interrupt. A descriptor ring in HPS
  memory can replace the register queue later if the register writes per job become the bottleneck.
- **Pixel issuer:** walks the job rectangle and computes c = (X0 + col·STEP, Y0 − row·STEP) with W-bit
  adders, one pixel per cycle. It gives each pixel to whichever core has a free pipeline slot
  (dynamic dispatch, not fixed rows per core). Every pixel carries its job id, so the next job's
  pixels fill the pipelines while the slow pixels of the previous job finish: no draining between
  tiles.
- **Result per pixel, 8 bytes:**
  - u32 iteration count. 0xFFFFFFFF means interior: reached MAX_IT, or found by the periodicity or
    cardioid check.
  - f32 |z|² at escape. The fixed-point value is converted to a float with a leading-zero count and a
    shift, which is cheap. This is what smooth colouring needs.
- **Result writer:** results come back out of order, so each one carries its pixel index. The writer
  computes the address and does single AXI writes with byte strobes. The rate is low: at most
  nCores × f / (pipeline latency) pixels/s, and usually far below that.
- **Integration:** use the GHRD's `qsys_top` (HPS + HPS EMIF), with `lwhps2fpga`, `f2sdram` and an
  `f2h_irq` exported to the top level. It becomes a BlackBox in Spinal, like `EMIF_Qsys` today. Clock
  crossing between the core clock and the bridge clocks uses `StreamFifoCC` in Spinal, or the
  Platform Designer adapters.

### HPS: `mandelbrotd` (C, Linux userspace)

- **Hardware access:** UIO for the register block and the interrupt, plus a reserved physical buffer
  for the results.
  - First bring-up: `mem=` on the kernel command line and `/dev/mem`.
  - Later: a device-tree `reserved-memory` node, or `u-dma-buf`.
  - `f2sdram` is not cache-coherent. Map the buffer uncached, or switch to `fpga2hps`, which is
    coherent through the CCU.
- **Thin bridge, no scheduling of its own:** each tile request from the PC becomes one FPGA job,
  with its parameters copied unchanged into the job registers (they are already in the hardware
  format). It keeps the FPGA job queue full, and sends each finished tile back with its request id.
- **Result buffers:** one result slot per queued job, 8 slots of 256x256x8 B = 512 KB (4 MB in all), in
  the reserved memory: 4 for the FPGA queue, 4 being sent or waiting to be sent.
- **Flow control:** at most a fixed number of requests in flight (sent in INFO). The PC keeps that many
  outstanding, so the TCP round trip is hidden.
- **LZ4** compression of tiles. Iteration counts compress very well.
- **Later:** computes the perturbation reference orbit with MPFR on the A76 cores.

### Network protocol (TCP, binary, little-endian)

Every message has a header: `u32 magic 'MBRT', u16 type, u16 flags, u32 length, u32 seq`, then the
payload.

| Direction | Type | Payload |
|---|---|---|
| C→S | GET_INFO | none |
| S→C | INFO | nCores, W, I (so F = W − I), features, core MHz, max tile size (256), max requests in flight |
| C→S | TILE_REQ | u32 request id; x0, y0 = the tile's **top-left pixel** and step, as W-bit two's complement fixed point with F fraction bits (W/32 u32 words each, low word first: exactly the register format); u16 width, u16 height (1..256); u32 max_it; u32 flags (periodicity, cardioid, compression) |
| S→C | TILE | u32 request id; encoding (raw/LZ4); pixel data, row-major, 8 B/px as above; statistics (cycles, iterations) |
| C→S | CANCEL | a request id, or all: drop the queued requests and abort the FPGA queue |
| S→C | ERROR | request id, code, text (for example a tile larger than allowed) |
| C→S / S→C | PING / PONG | keepalive |

- **Coordinates in binary, in the hardware's own format.** The PC reads W and F from INFO and converts
  with Python integers: x0 = round(x · 2^F), with any number of bits. The server doesn't need any
  arithmetic.
- **When perturbation comes (phase 4),** it gets its own message types (reference orbit upload, delta
  tiles). Those carry a float format with an explicit exponent, so the zoom depth is not limited by W.
- **The PC does the tiling.** It splits the screen into 256x256 tiles and computes each tile's
  top-left corner itself: x0 = left + col·256·step, y0 = top − row·256·step, exactly in integers. It
  sends the requests centre-out, so the middle of the screen appears first, and keeps the queue full.
  On pan or zoom it sends CANCEL(all) and starts again. Tiles that are still valid after a pan can be
  kept and shifted, but only if the pan is a whole number of pixels.
- **Per-tile overhead:** a 256x256 tile is 512 KB of results (raw). A 1080p screen is 8 x 5 = 40
  tiles, with the right column 128 and the bottom row 56 pixels high, so the per-message overhead is
  negligible. Much smaller tiles (< 32x32) would make the HPS and the register writes the bottleneck
  at shallow zoom.

### PC application: `tools/mandelbrot_view.py`

- **Stack:** Python + numpy + PySide6 (or pyqtgraph). View coordinates are Python integers scaled by
  2^F (exact, any width), or mpmath for user input.
- **Tiling and request queue:** see the protocol section. Mariani-Silver and symmetry run here too,
  on top of tile requests.
- **Navigation:** mouse wheel zoom, drag to pan, rectangle zoom, max_it control, saved views
  (bookmarks).
- **Display:** shows tiles as they arrive (progressive rendering).
- **Colouring:** done on the PC from the count and |z|², so it is instant and needs no re-render:
  - palette by escape time, n mod H
  - smooth: ν = n + 1 − log₂(log|z_n| / log 2), with log|z_n| = ½·log|z_n|², interpolated between
    palette[⌊ν⌋] and palette[⌊ν⌋+1]
  - histogram colouring (independent of max_it), alone or combined with smooth
  - HSV/LCH mappings from the Wikipedia article
  - distance estimation, once the FPGA computes the derivative (an optional later feature)
- Export to PNG and the raw count data (`.npy`).
- `tools/mandelbrot_ctl.py` (UART) is kept only as long as the HDMI build exists.

## 128-bit iteration core (`WideIteration`, replaces `SingleIteration`)

- **Format:** W-bit two's complement with I integer bits including the sign. With bailout radius
  R = 16 (a larger R gives better smooth colouring), z² + c reaches about R² + 2 = 258, so I = 10 and
  F = W − 10. For W = 128 that is **F = 118, a pixel step down to 2^-118 ≈ 3e-36**.
- **Use only squares:** x² − y² for the real part, and 2xy = (x+y)² − x² − y². All three products are
  squares of magnitudes (|x|, |y|, |x+y|), so they are unsigned and symmetric.
- **Limbs:** magnitudes are split into 26-bit limbs, which fit the 27x27 DSP mode. Check whether the
  Agilex 5 DSP has an unsigned 27x27 mode; if it does, 27-bit limbs work too. W = 128 needs 5 limbs.
- **Symmetric squaring:** only the pairs i ≤ j are multiplied; the cross terms are doubled by a shift.
  That is 15 products instead of 25.
- **Truncated products:** only the top W bits of the 2W-bit product are kept. Partial products with
  i + j below the cut-off are dropped, keeping one guard limb, so about 11 products per square. The
  error must be modelled bit-exactly in the reference model, and bounded below 1 ulp after the final
  shift.
- **Budget per core:** 3 squares × about 11-12 = **about 35 DSP blocks, so 5 cores** (175 of 188).
  - W = 96 (4 limbs): about 24 DSP blocks, 7 cores.
  - W = 64 (3 limbs): about 14 DSP blocks, 13 cores.
  - Soft-logic multipliers in the spare ALMs might add one more core.
- **Adders:** the column sums are about 260 bits wide. Use carry-save (compressor) trees, then a
  carry-propagate adder pipelined in 32-64-bit chunks so it meets 198 MHz. The escape test |x|² + |y|²
  ≥ R² only needs the top bits.
- **Pipeline:** about 12-16 stages, so each core has as many pixels in flight. The loop-back
  structure of the current `Core` stays.
- **Throughput:** 5 × 198 M ≈ **1 G iterations/s**, about 12 times less than today's 60 cores at
  19 bits. That is the price of 128 bits without perturbation.
- **Parameters:** `W` and `I`, so 64, 96 and 128 are build options (`make WIDTH=128`).
- **Verification:** a Scala `BigInt` reference model of the truncated arithmetic, compared bit for bit
  in simulation, plus a comparison against mpmath to check the error bound.

### About multiplier choices

- **Booth:** no use on the FPGA, because the DSP blocks are already hard multipliers. It is relevant
  for the ASIC flow ([LIBRELANE.md](LIBRELANE.md)): radix-4 Booth with a Dadda tree.
- **Karatsuba:** at 5 limbs it saves about 20%, but the pre-added operands are 27-28 bits and no longer
  fit the DSP inputs, and it doesn't combine with truncation. Symmetric squaring plus truncation saves
  more (75 → about 35 products) for less complexity. Reconsider Karatsuba only for W ≥ 256.
- **Cores in series vs. in parallel:** peak throughput is the same: multipliers × f / multiplies per
  iteration. A fixed chain of iteration stages wastes slots when pixels escape early, and can't adapt
  to a variable max_it. Keep looping cores with dynamic dispatch. With about 5 cores the arbiter costs
  nothing.

## Algorithms from the Wikipedia article and where they go

Source: <https://en.wikipedia.org/wiki/Plotting_algorithms_for_the_Mandelbrot_set>

| Algorithm | Where | Phase | Notes |
|---|---|---|---|
| Escape time, 3-multiplication loop | FPGA | 2 | Already used (x², y², xy). The squares-only variant w = (x+y)² is the one the 128-bit core uses. |
| Smooth colouring ν = n + 1 − log₂(log\|z\|/log 2) | FPGA sends \|z\|², PC computes | 1 | Needs a bailout radius much larger than 2 (the article uses 2^8). Hence I = 10 integer bits. |
| Histogram colouring | PC | 1 | Whole-image pass. Combine with smooth. |
| HSV/LCH/exponential mapping | PC | 1 | |
| Cardioid / period-2 bulb test | FPGA pixel issuer | 3 | q = (x−¼)² + y², interior if q(q + x − ¼) ≤ ¼y²; bulb: (x+1)² + y² ≤ 1/16. Computed in low precision (27 bits) with a conservative margin: a wrong "outside" only costs time, never a wrong pixel. Mostly helps shallow views. |
| Periodicity check | FPGA core | 3 | Per pipeline slot, store z_old (2×W bits, in MLAB/M20K) and compare \|x − x_old\| and \|y − y_old\| < ε. Brent's variant: refresh z_old at powers of 2, not every 20 iterations. Huge gain for interior pixels at high max_it. |
| Rectangle checking (Mariani-Silver) | PC | 3 | Compute the border of a rectangle first; if it is all one count, fill the inside, otherwise split into four. A border is four thin tile requests (1 x n and n x 1), batched in one go so the queue stays full. Use it only to fill interior (max_it) regions when smooth colouring is on, because exterior bands aren't flat in smooth colouring (as the article notes). |
| Border tracing | not planned | | Rectangle checking gets most of the benefit and fits the tile/job model. |
| Symmetry about the real axis | PC | 3 | Don't request the tiles that are the mirror image of tiles already requested when the view crosses y = 0. |
| Parallelism (tiles, thread pool) | FPGA cores + PC tiles | 1 | Dynamic per-pixel dispatch inside and across jobs (job queue), tiles requested by the PC. |
| Exterior distance estimation | FPGA (optional) | 4+ | Needs the derivative dz' = 2·z·dz + 1 per iteration, another complex multiply (about 2× the DSPs). Not worth it at 128 bits. Natural in the perturbation core, where it is cheap at low precision. |
| Interior distance estimation | not planned | | Needs the period and four derivatives. |
| Perturbation ε' = 2zε + ε² + δ, series approximation (A_n, B_n, C_n) | HPS reference orbit + FPGA deltas | 4 | See below. |

## Phases

### Phase 0: close the HDMI version

- Commit the current 60-core/198 MHz work and test it on the board. It stays as a reference
  (`De25NanoTop`).

### Phase 1: HPS + Ethernet with today's cores

The goal is the whole data path working end to end, with no new arithmetic yet.

1. Build the Terasic GHRD as it is, boot the SD image, check Ethernet and ssh.
2. Read and write a test register on `lwhps2fpga` from Linux (`devmem`).
3. New Spinal top `De25NanoHpsTop` with `qsys_top` as a BlackBox, and `MandelbrotAccel` with the
   register map above, around the existing 19-bit cores (60 cores).
4. Extend the cores' output to the u32 count, |z|² and pixel index. Add dynamic dispatch (the pixel
   issuer).
5. `mandelbrotd`: UIO, result slots, request queue, TCP protocol.
6. `mandelbrot_view.py`: navigation, smooth and histogram colouring.
7. A simulation testbench: `MandelbrotAccel` with `AxiMemorySim` as HPS memory and an AXI-Lite driver,
   compared against a Scala model of the whole image.

### Phase 2: wide arithmetic

1. Scala `BigInt` model of the truncated multi-limb squaring, with an error bound.
2. `WideSquare` (limbs, symmetric products, truncation, pipelined carry-save tree), tested on its own.
3. `WideIteration` / `WideCore` with the W and I parameters; Quartus runs at W = 64, 96, 128.
4. Find the largest core count that meets 198 MHz for each W; update CAPS and the tools.

### Phase 3: algorithmic speedups

- Periodicity check (FPGA), cardioid/bulb test (FPGA), Mariani-Silver and symmetry (PC).
- Benchmark views (shallow, a seahorse valley spiral, a deep zoom, an interior-heavy view): record
  iterations/s and frame times before and after each feature.

### Phase 4: perturbation, beyond 128 bits and much faster at depth

- **Reference orbit:** Z_n computed with MPFR on the HPS, at any precision, then rounded to the
  low-precision format.
- **FPGA iterates only the difference, rewritten as one complex multiply:**
  δ_{n+1} = (2Z_n + δ_n)·δ_n + δ_0.
  - Uses floating point with a 54-bit mantissa (2 limbs, so 3-4 DSP per real multiply) and an
    extended exponent, so zoom depth is not limited by the FPGA format.
  - Three real multiplies with Gauss's trick, or four: about 12-16 DSP blocks per core, so **about
    12-15 cores**, against 5 at W = 128 fixed point.
- **Rebasing:** when |Z_n + δ_n| < |δ_n|, set δ := Z_n + δ_n and n := 0. This avoids most glitches
  with a single reference orbit, and in hardware it is a comparison and a counter reset. It is not on
  the Wikipedia page; it is from the deep-zoom community (Zhuoran, Kalles Fraktaler, Imagina).
- **Reference orbit storage:** each core reads Z at its own n. Replicate the orbit in M20K, with one
  copy per pair of cores using dual-port RAM. At 2×64 bits per entry and 358 M20K blocks this limits
  the orbit length to about 4-8 K entries per copy. Longer orbits need streaming from LPDDR4B, with a
  small window per core.
- **Series approximation / bilinear approximation (BLA):** the HPS computes the coefficients and the
  FPGA starts each pixel at iteration k instead of 0. Use it to skip the start of very deep zooms.
- The derivative for distance estimation becomes cheap here, as one more low-precision complex
  multiply.

## Open questions and risks

- `f2sdram` data width and clock in the GHRD (not checked yet). Coherence: uncached buffer or
  `fpga2hps`.
- Whether the SD image's kernel and device tree allow UIO and reserved memory without a rebuild.
  Fallback: `mem=` and `/dev/mem`.
- GHRD made with Quartus 25.1; we use Quartus 26, so the IP may need upgrading (`qsys-generate --upgrade`).
- Whether the Agilex 5 DSP has an unsigned 27x27 mode (27-bit limbs instead of 26).
- Truncation error accumulated over many iterations: verify the error stays below the pixel step
  for the chosen guard bits.
- 260-bit adders at 198 MHz: pipeline depth vs. ALM use, to be checked at W = 64 first.
