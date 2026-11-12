# Roadmap: Ethernet, 128-bit precision and better algorithms (DE25-Nano)

Status: plan, nothing below is implemented yet. Starting point is the `de25-nano-port` branch:
60 cores, FRAC 16 (19-bit fixed point), 198 MHz, HDMI output, UART control
(see [DE25NANO_PORT_REPORT.md](DE25NANO_PORT_REPORT.md)).

## Goals

1. **No HDMI.** The FPGA sends per-pixel results to a PC application, which does the colouring
   (smooth, histogram, LCH, distance estimation, ...) and displays the image.
2. **Ethernet, both ways.** The PC application sends tile requests and cancels,
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
 Mariani-Silver,                                │ lwhps2fpga (registers, AXI-Lite) + IRQ (UIO)
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
  | 0x008 | CAPS | RO | nCores, W (total bits), I (integer bits), feature bits (periodicity, cardioid), job queue depth |
  | 0x00C | ARITH_ID | RO | hash of the configuration that changes result bits (W, I, guard bits, bailout, format); used as part of the PC's tile cache key |
  | 0x010 | CONTROL | WO | bit 0 push the job registers into the job queue (ignored when the queue is full), bit 1 abort all jobs, bit 8 IRQ enable |
  | 0x014 | STATUS | RO | bit 0 busy (a job is queued or running), bit 1 DONE FIFO not empty (this is the interrupt). Errors are reported per job, in DONE. |
  | 0x018 | ABORT | WO | id of one queued or running job to abort (a cancel from the PC names single requests). Its pixels still in the pipelines are dropped, and the job is reported in the DONE FIFO as aborted. The same goes for every job of an "abort all". |
  | 0x01C | QUEUE | RO | free entries in the job queue, and the number of entries in the DONE FIFO |
  | 0x020-0x02C | X0[4] | RW | real part of the tile's top-left pixel, W-bit two's complement, low word first. Given directly by the PC: the FPGA no longer computes the top left from a centre (today's `Wrapper` setup stage goes away). |
  | 0x030-0x03C | Y0[4] | RW | imaginary part of the top-left pixel |
  | 0x040-0x04C | STEP[4] | RW | distance between pixels |
  | 0x050 | WIDTH, HEIGHT | RW | tile size in pixels, 1..256 each (16 + 16 bits). Tiles are full size on a global grid (see [PC_APP_PLAN.md](PC_APP_PLAN.md)); smaller ones are used for Mariani-Silver borders. |
  | 0x054 | MAX_IT | RW | 32 bits, at most 0xFFFFFFFD (the two values above are the interior codes) |
  | 0x058 | FLAGS | RW | periodicity check, cardioid/bulb test |
  | 0x05C | JOB_ID | RW | 16-bit id chosen by `mandelbrotd`. It comes back in DONE, and it is what ABORT names. |
  | 0x060-0x064 | RESULT_BASE | RW | physical address of the result area in HPS memory (64 bits, low word first). Set once by `mandelbrotd` at start. |
  | 0x068 | RESULT_SLOTS | RW | number of 512 KB slots in the result area. Set once at start. |
  | 0x06C | RESULT_SLOT | RW | index of the slot this job writes to |
  | 0x070 | DONE | RO, a write pops | head of the DONE FIFO: bit 31 valid, bits 17:16 status (0 complete, 1 aborted, 2 error), bits 15:0 job id. Any write removes the head. |
  | 0x074-0x078 | DONE_ITERATIONS | RO | 64-bit number of iterations the head job took |
  | 0x080-0x084 | TOTAL_ITERATIONS | RO | 64 bits, free running, all jobs. Reading the low word latches all three totals, so they belong to the same cycle. |
  | 0x088-0x08C | TOTAL_CYCLES | RO | 64 bits, free-running count of core clock cycles |
  | 0x090-0x094 | TOTAL_PIXELS | RO | 64 bits, free-running count of finished pixels |

  The registers X0..FLAGS, JOB_ID and RESULT_SLOT fill a **job queue**, not a single job. The cores
  can compute a 256x256 tile in about 0.5-1 ms at shallow zoom. With one job at a time they would
  idle while the HPS reacts to an interrupt and loads the next tile, and while the slowest pixels of
  a tile finish. The queue is 4 jobs deep. A DONE FIFO holds the finished jobs and raises the
  interrupt; it has 16 entries, more than `mandelbrotd` has result slots, so it can't overflow.
- **Statistics:** jobs overlap in the cores, so a cycle count per job means nothing. A job reports only
  its iterations. Utilisation comes from the free-running totals: Δiterations / (Δcycles × nCores).
- **Result area:** the FPGA writes only inside it. The address of a record is
  RESULT_BASE + RESULT_SLOT × 512 KB + 8 × pixel index (pixel index = row × WIDTH + column, so there
  is no stride register). A job whose slot is not below RESULT_SLOTS is refused and reported in DONE
  with status "error". RESULT_BASE and RESULT_SLOTS can't be changed while a job is queued or
  running. A bug in `mandelbrotd` can then damage a tile, but never the kernel's memory.
- **Pixel issuer:** walks the job rectangle and computes c = (X0 + col·STEP, Y0 − row·STEP) with W-bit
  adders, one pixel per cycle. It gives each pixel to whichever core has a free pipeline slot
  (dynamic dispatch, not fixed rows per core). Every pixel carries its job id, so the next job's
  pixels fill the pipelines while the slow pixels of the previous job finish: no draining between
  tiles.
- **Result per pixel: one 64-bit record,** count in the low 32 bits and |z|² in the high 32 bits:
  - u32 iteration count (defined in [PC_APP_PLAN.md](PC_APP_PLAN.md)), with two codes for pixels that
    did not escape:
    - 0xFFFFFFFF: reached MAX_IT. Not resolved: it may escape at a higher MAX_IT.
    - 0xFFFFFFFE: proven interior, by the periodicity or the cardioid check. Final at any MAX_IT.
  - f32 |z|² at escape. The fixed-point value is converted to a float with a leading-zero count and a
    shift, which is cheap. This is what smooth colouring needs. It is 0 for pixels that did not
    escape.
- **Result writer:** results come back out of order, so each one carries its pixel index and the
  writer computes the address from it.
  - **Write combining.** Pixels are issued in raster order and neighbours usually have close
    iteration counts, so their results arrive close together, and exactly in order where the count
    is constant over a run (the fast, shallow regions, which is where the write rate matters). The
    writer keeps a few open lines (for example 4 lines of 8 or 16 records, aligned in the slot). A
    result goes into its line; a line is written as one burst when it is full, or with byte strobes
    for the missing records when it is evicted or times out. A record that arrives after its line
    was written goes out as a single beat with strobes. Nothing waits on a slow pixel, so the cores
    never idle for the writer's sake.
  - **Back-pressure** works as in today's design, where a core waits in `UNLOAD` until its results
    are taken: a finished pipeline slot keeps its result, and stays occupied, until the writer
    accepts it.
  - **Target:** stay above what the link carries, about 14 M pixels/s raw at 8 B/px. Measure the
    share of full-line bursts and the rate on `f2sdram` in phase 1. First bring-up can use single
    beats only, which is the same writer with a line length of 1.
- **Integration:** use the GHRD's `qsys_top` (HPS + HPS EMIF), with `lwhps2fpga`, `f2sdram` and an
  `f2h_irq` exported to the top level. It becomes a BlackBox in Spinal, like `EMIF_Qsys` today. Clock
  crossing between the core clock and the bridge clocks uses `StreamFifoCC` in Spinal, or the
  Platform Designer adapters.

### HPS: `mandelbrotd` (C, Linux userspace)

- **Hardware access:** UIO for the register block and the interrupt, plus a reserved physical buffer
  for the results.
  - First bring-up: `mem=` on the kernel command line and `/dev/mem`.
  - Later: a device-tree `reserved-memory` node, or `u-dma-buf`.
  - `f2sdram` is not cache-coherent, so the buffer needs an uncached mapping, a cached one with an
    explicit sync (`u-dma-buf`), or the `fpga2hps` bridge, which is coherent through the CCU. See
    the risks.
- **Thin bridge:** each tile request from the PC becomes one FPGA job,
  with its parameters copied unchanged into the job registers (they are already in the hardware
  format). It keeps the FPGA job queue full, and sends each finished tile back with its request id.
- **Result buffers:** 8 slots of 256x256x8 B = 512 KB (4 MB in all) in the reserved memory. A request
  holds a slot from the moment its job is pushed until its tile is sent: up to 4 in the FPGA queue,
  the others being copied and sent. `mandelbrotd`
  writes RESULT_BASE and RESULT_SLOTS once at start, and gives each job a slot index.
- **Flow control:** at most as many requests in flight as there are result slots (the number is sent
  in INFO). The PC keeps that many outstanding, so the TCP round trip is hidden.
- **Planes:** while it copies a finished tile out of its result slot, it splits the 64-bit records
  into the two planes of the protocol (counts, then |z|²).
- **LZ4** compression of tiles. The count plane compresses very well, the f32 |z|² plane hardly at all.
- **Later:** computes the perturbation reference orbit with MPFR on the A76 cores.

### Network protocol and PC application

Planned in detail in [PC_APP_PLAN.md](PC_APP_PLAN.md):

- **Protocol:** TCP, binary. The PC sends self-contained tile requests (up to 256x256; the top-left
  pixel and step in the hardware's W-bit fixed-point format; max_it; flags). The board answers each
  with the count and |z|² planes.
- **Cancelling and flow control:** the PC cancels requests by id, and only the ones whose tile left
  the screen, so a pan doesn't restart the tiles that are still wanted. The board reports how many
  requests may be in flight, so the client can't overrun it.
- **PC application:** Python with Dear ImGui (imgui-bundle) and OpenGL (moderngl). Colouring runs in
  a fragment shader, so changing it costs no re-render. Zoom and pan with the mouse. The algorithm,
  palette and max_it are chosen in the UI.
- **Simulated server:** speaks the same protocol, so the app can be developed and tested before the
  board works. Its exact mode computes the FPGA arithmetic bit for bit, to verify tiles.

## 128-bit iteration core (`WideIteration`, replaces `SingleIteration`)

- **Format:** W-bit two's complement with I integer bits including the sign. With bailout radius
  R = 16 (a larger R gives better smooth colouring), z² + c reaches about R² + 2 = 258, so I = 10 and
  F = W − 10. For W = 128 that is **F = 118, a pixel step down to 2^-118 ≈ 3e-36**.
- **Use only squares:** x² − y² for the real part, and 2xy = (x+y)² − x² − y². All three products are
  squares of magnitudes (|x|, |y|, |x+y|), so they are unsigned and symmetric.
- **Limbs:** magnitudes are split into 26-bit limbs, which fit the 27x27 DSP mode whether it is
  signed or unsigned. W = 128 needs 5 limbs.
- **Symmetric squaring:** only the pairs i ≤ j are multiplied; the cross terms are doubled by a shift.
  That is 15 products instead of 25.
- **Truncated products:** only the top bits of the 2W-bit product are kept (W bits, plus the integer
  bits the escape test needs; see the risks). Partial products with
  i + j below the cut-off are dropped, keeping one guard limb, so about 11 products per square. The
  error must be modelled bit-exactly in the reference model, and bounded below 1 ulp after the final
  shift.
- **Budget per core:** 3 squares × about 11-12 = **about 35 DSP blocks, so 5 cores** (175 of 188).
  - W = 96 (4 limbs): about 24 DSP blocks, 7 cores.
  - W = 64 (3 limbs): about 14 DSP blocks, 13 cores.
- **Adders:** the column sums are about 260 bits wide. Use carry-save (compressor) trees, then a
  carry-propagate adder pipelined in 32-64-bit chunks so it meets 198 MHz. The escape test |x|² + |y|²
  ≥ R² only needs the top bits.
- **Pipeline:** about 12-16 stages, so each core has as many pixels in flight. The pipeline's
  output still feeds its input, as in the current `Core`.
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
| Rectangle checking (Mariani-Silver) | PC | 3 | Compute the border of a rectangle first; if it is all one count, fill the inside, otherwise split into four. A border is four thin tile requests (1 x n and n x 1), batched in one go so the queue stays full. Only regions whose border did not escape are filled: exterior bands aren't flat in smooth colouring (as the article notes), and the colouring can change after the render. The fill value is "proven interior" if the whole border is, otherwise "reached max_it". |
| Border-first fill in the pixel issuer | not planned (note) | | An alternative to Mariani-Silver on the PC. A flag on a normal tile: the issuer computes the 1020 border pixels of a 256x256 tile first. If none escaped, the job ends as "filled" and nothing else is iterated; otherwise the remaining pixels are issued as usual. While it waits for the border, the cores take the next job's pixels. An all-interior tile costs 1.6 % of its pixels, with no thin requests and no round trips. A partly interior tile gains nothing unless the test is repeated on sub-blocks (for example 64x64). It overlaps with the periodicity check, so look at it again only after measuring that one. |
| Border tracing | not planned | | Rectangle checking gets most of the benefit and fits the tile/job model. |
| Symmetry about the real axis | not planned | | The mirror of a tile is one row off the tile grid (row 0 is its own mirror), and the hardware's rounding isn't symmetric, so a flipped tile isn't bit-identical to a computed one. It only helps while the view crosses the real axis, and the cache covers revisits. |
| Parallelism (tiles, thread pool) | FPGA cores + PC tiles | 1 | Dynamic per-pixel dispatch inside and across jobs (job queue), tiles requested by the PC. |
| Exterior distance estimation | FPGA (optional) | 4+ | Needs the derivative dz' = 2·z·dz + 1 per iteration, another complex multiply (about 2× the DSPs). Not worth it at 128 bits. Natural in the perturbation core, where it is cheap at low precision. |
| Interior distance estimation | not planned | | Needs the period and four derivatives. |
| Perturbation ε' = 2zε + ε² + δ, series approximation (A_n, B_n, C_n) | HPS reference orbit + FPGA deltas | 4 | See phase 4. |

## Phases

### Phase 0: close the HDMI version

- The 60-core/198 MHz work is committed. Test it on the board. It stays as a reference
  (`De25NanoTop`).

### Phase 1: HPS + Ethernet with today's cores

The goal is the whole data path working end to end, with no new arithmetic yet.

1. Build the Terasic GHRD as it is, boot the SD image, check Ethernet and ssh.
2. Read and write a test register on `lwhps2fpga` from Linux (`devmem`). Write a test pattern into
   reserved HPS memory through `f2sdram`, read it back from Linux, and measure the read speed.
3. New Spinal top `De25NanoHpsTop` with `qsys_top` as a BlackBox, and `MandelbrotAccel` with the
   register map above, around the existing 19-bit cores (60 cores).
4. Rework `Core` from batches (LOAD, CALC, UNLOAD) to per-slot refill: a slot that finishes hands
   over its result (u32 count, |z|², pixel index, job id) and takes the next pixel from the pixel
   issuer. Add 2 integer bits (see the risks).
5. `mandelbrotd`: UIO, result slots, request queue, TCP protocol.
6. PC application (`pc/`), milestones 1-6 of [PC_APP_PLAN.md](PC_APP_PLAN.md). The board connection is
   milestone 4; the disk cache and the tools come after it.
7. A simulation testbench: `MandelbrotAccel` with `AxiMemorySim` as HPS memory and an AXI-Lite driver,
   compared against a Scala model of the whole image.

Steps 1-2 hold the biggest unknowns (the HPS bridges, `f2sdram`, the kernel), and the PC application
needs no board until its milestone 4. So start both at the same time.

### Phase 2: wide arithmetic

Keep this phase small. At 5 cores and about 1 G iterations/s, 128-bit fixed point is probably in the
range of a desktop CPU (the C++ benchmark will tell). Its purpose is to make the application usable
for exploring (W ≥ 64) and to build the wide multiplier and carry-save parts that perturbation
reuses. The speed comes in phases 3 and 4. So: one verified, parametric core and one honest number
per width, and no tuning for one more core.

1. Scala `BigInt` model of the truncated multi-limb squaring, with an error bound.
2. `WideSquare` (limbs, symmetric products, truncation, pipelined carry-save tree), tested on its own.
3. `WideIteration` / `WideCore` with the W and I parameters.
4. One build per W with the core count from the DSP budget above (13, 7, 5). If it misses 198 MHz,
   take cores out or lower the clock, and move on; update CAPS and the tools.

### Phase 3: algorithmic speedups

- Periodicity check (FPGA), cardioid/bulb test (FPGA), Mariani-Silver (PC).
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

- `f2sdram` data width and clock in the GHRD (not checked yet).
- Whether the SD image's kernel and device tree allow UIO and reserved memory without a rebuild.
  Fallback: `mem=` and `/dev/mem`.
- GHRD made with Quartus 25.1; we use Quartus 26, so the IP may need upgrading (`qsys-generate --upgrade`).
- Truncation error accumulated over many iterations: verify the error stays below the pixel step
  for the chosen guard bits.
- 260-bit adders at 198 MHz: pipeline depth vs. ALM use, to be checked at W = 64 first.
- `f2sdram` is not cache-coherent, and reading the result buffer through an uncached mapping may be
  slower than the link (110 MB/s), which would make the HPS copy the bottleneck. Measure it in
  phase 1 step 2. If it is too slow, use `u-dma-buf` from the start (a cached mapping, with an
  explicit sync before each read), or the coherent `fpga2hps` bridge.
- Integer bits of the escape test: z itself fits I = 10, but the z that escapes reaches about 258,
  so its squares reach about 66 000 (17 integer bits), and (x+y)² twice that. The truncated squarer
  has to keep those top bits for the escape test and for the |z|² output. Put it in the reference
  model first.
- Phase 1 can hardly zoom, and its smooth colouring is rough. With F = 16 the view runs out of
  precision about 3 octaves below the full set. Today's z has 3 integer bits and wraps at ±4. The
  stop test tolerates that, but the |z|² output doesn't, because the z that escapes reaches about 6.
  So phase 1 gets 2 more integer bits (21 bits, still one DSP block per multiply) and keeps
  bailout 2. The shader takes R² from INFO; R = 16 comes with the wide core in phase 2, and the
  application becomes useful for exploring at W = 64.
- Per-pixel dispatch to 60 cores, and the merge of their results, at 198 MHz. Today's dispatch
  sends 60 commands per frame through a half-rate pipeline; the new one moves a pixel per cycle. It
  needs pipelined distribution and merge trees, like the arbiter tree of today's `Wrapper`, and may
  cost clock frequency or cores.
- Two bit-exact models of the arithmetic (the Scala `BigInt` model and the Python exact mode of the
  simulated server) can drift apart. Make one the reference and check the other against test
  vectors exported from it.
