# Roadmap: Ethernet, 128-bit precision and better algorithms (DE25-Nano)

Status: phase 1 in progress (PC application milestone 1 is done, see
[PC_APP_PLAN.md](PC_APP_PLAN.md)); the FPGA and HPS parts are not started. Starting point is the `de25-nano-port` branch:
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
| GHRD enables `lwhps2fpga` (32-bit data), `hps2fpga` (128), `fpga2hps` (256, ACE5-Lite, through a cache-coherency translator) and `f2sdram` (256-bit data, 32-bit address, through Terasic's `f2sdram_adapter`), all clocked at 100 MHz (`clk_100`, a PLL on CLOCK2_50). None is exported: inside `qsys_top` they go to PIOs, an on-chip RAM and JTAG masters. | `qsys_top.qsys`, `hps_subsys/ip/hps_subsys/agilex_hps.ip` (Quartus 25.1) | Registers go on `lwhps2fpga`, result writes on `f2sdram` (or the coherent `fpga2hps`). `qsys_top` has to be edited to export them (step 3). A 256-bit beat holds 4 result records. The GHRD's JTAG master on `f2sdram` and its PIOs on `lwhps2fpga` are enough for step 2, with no RTL of ours. |
| The package has a prebuilt GHRD (`output_files/golden_top_hps.sof` and `.jic`, with the U-Boot SPL inside) | `Demonstration/SoC_FPGA/GHRD/output_files` | Step 1 needs no Quartus build. |
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
  | 0x008 | CAPS | RO | bits 7:0 nCores, 15:8 W (total bits), 20:16 I (integer bits), 23:21 the FLAGS bits implemented (bit 21 periodicity, 22 cardioid/bulb test), 31:24 job queue depth |
  | 0x00C | ARITH_ID | RO | hash of the configuration that changes result bits (W, I, guard bits, bailout, format); used as part of the PC's tile cache key |
  | 0x010 | CONTROL | WO | bit 0 push the job registers into the job queue (ignored when the queue is full), bit 1 abort all jobs, bit 8 IRQ enable (every write sets or clears it) |
  | 0x014 | STATUS | RO | bit 0 busy (a job is queued or running), bit 1 DONE FIFO not empty (this is the interrupt). Errors are reported per job, in DONE. |
  | 0x018 | ABORT | WO | id of one queued or running job to abort (a cancel from the PC names single requests). Its pixels still in the pipelines are dropped, and the job is reported in the DONE FIFO as aborted. The same goes for every job of an "abort all". |
  | 0x01C | QUEUE | RO | bits 15:0 free entries in the job queue, 31:16 entries in the DONE FIFO |
  | 0x020-0x02C | X0[4] | RW | real part of the tile's top-left pixel, W-bit two's complement, low word first. Given directly by the PC: the FPGA no longer computes the top left from a centre (today's `Wrapper` setup stage goes away). |
  | 0x030-0x03C | Y0[4] | RW | imaginary part of the top-left pixel |
  | 0x040-0x04C | STEP[4] | RW | distance between pixels |
  | 0x050 | WIDTH, HEIGHT | RW | tile size in pixels, 1..256 each (16 + 16 bits). Tiles are full size on a global grid (see [PC_APP_PLAN.md](PC_APP_PLAN.md)); smaller ones are used for Mariani-Silver borders. |
  | 0x054 | MAX_IT | RW | 32 bits, at most 0xFFFFFFFD (the two values above are the interior codes) |
  | 0x058 | FLAGS | RW | bit 0 periodicity check, bit 1 cardioid/bulb test (the protocol's request flags 1:0) |
  | 0x05C | JOB_ID | RW | 16-bit id chosen by `mandelbrotd`. It comes back in DONE, and it is what ABORT names. |
  | 0x060-0x064 | RESULT_BASE | RW | physical address of the result area in HPS memory (64 bits, low word first). Set once by `mandelbrotd` at start. |
  | 0x068 | RESULT_SLOTS | RW | number of 512 KB slots in the result area. Set once at start. |
  | 0x06C | RESULT_SLOT | RW | index of the slot this job writes to |
  | 0x070 | DONE | RO, a write pops | head of the DONE FIFO: bit 31 valid, bits 17:16 status (0 complete, 1 aborted, 2 error), bits 15:0 job id. Any write removes the head. |
  | 0x074-0x078 | DONE_ITERATIONS | RO | 64-bit number of iterations the head job took |
  | 0x080-0x084 | TOTAL_ITERATIONS | RO | 64 bits, free running, all jobs. Reading the low word latches all three totals, so they belong to the same cycle. |
  | 0x088-0x08C | TOTAL_CYCLES | RO | 64 bits, free-running count of core clock cycles |
  | 0x090-0x094 | TOTAL_PIXELS | RO | 64 bits, free-running count of finished pixels |
  | 0x098 | BOARD_TEMP | RO | bits 15:0 FPGA temperature, bits 31:16 board temperature, both signed, in °C (from the fan controller) |
  | 0x09C | FAN_RPM | RO | bits 15:0 fan speed in RPM, bit 31 I2C ready (the readings are valid) |
  | 0xF00-0xF3C | TEST_* | | temporary: reads one 32-byte beat over `f2sdram` (bring-up only, see `MandelbrotAccel`) |

  Registers that are not plain storage (CONTROL, ABORT, DONE, RESULT_BASE, RESULT_SLOTS) take
  whole 32-bit writes; byte enables are ignored there. A job whose size is not 1..256, or whose
  RESULT_BASE high word is not 0, is refused like a bad slot (status "error").

  The registers X0..FLAGS, JOB_ID and RESULT_SLOT fill a **job queue**, not a single job. The cores
  can compute a 256x256 tile in about 0.5-1 ms at shallow zoom. With one job at a time they would
  idle while the HPS reacts to an interrupt and loads the next tile, and while the slowest pixels of
  a tile finish. The queue is 8 job contexts: a push copies the job registers into a free one, and
  the issuer takes them in push order. A DONE FIFO holds the finished jobs and raises the
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
    - 0xFFFFFFFE: proven interior, by the periodicity or the cardioid check. Final at any higher
      MAX_IT.
  - the high 32 bits depend on the count:
    - escaped: f32 |z|² at escape. The fixed-point value is converted to a float with a leading-zero
      count and a shift, which is cheap. This is what smooth colouring needs.
    - proven interior: u32 k, the iteration at which the proof was made (0 for the cardioid/bulb
      test, the iteration of the match for the periodicity check). The counter is already in the
      pipeline, so this costs nothing. The PC's cache needs it (PC_APP_PLAN.md, "Tile cache"): a tile
      computed at MAX_IT M answers M' < M only if it knows which proofs a run to M' would have reached
      (k <= M').
    - reached MAX_IT: 0.
    - Decided 2026-11-19. Tiles from before have proven-interior pixels only from the cardioid test,
      whose k is 0, the value already in the field, so the result-format version stays 1.
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

- **Hardware access:** UIO for the register block and the interrupt (bring-up uses `/dev/mem`).
- **Result buffer: huge pages** (decided 2026-11-13). The uncached `/dev/mem` mapping of reserved
  memory reads at 23-148 MB/s, too close to the 110 MB/s link, so the buffer is ordinary cached RAM:
  - `mandelbrotd` maps one 32 MB huge page (anonymous, `MAP_HUGETLB` with the 32 MB size; the
    kernel offers 64 KB, 2 MB, 32 MB and 1 GB pages), locks it, and finds its physical address in
    `/proc/self/pagemap` (as root). The first 4 MB are the 8 result slots, physically contiguous,
    so the single RESULT_BASE stays.
  - The page is reserved through sysfs before `mandelbrotd` starts
    (`echo 1 > /sys/kernel/mm/hugepages/hugepages-32768kB/nr_hugepages`), early in boot so that
    32 MB of contiguous memory are still free. Fallback if that fails: 2 MB pages, which are not
    contiguous with each other (seen in the test), so only 4 slots fit under one RESULT_BASE, or
    the accelerator takes a slot address per job instead of an index.
  - `f2sdram` is not cache-coherent: after DONE and before reading a tile, `mandelbrotd` cleans and
    invalidates its lines (`DC CIVAC` per 64-byte line, then `DSB`; allowed in userspace on arm64).
    Nothing writes the buffer from the CPU, so the clean never overwrites FPGA data. The coherent
    `fpga2hps` bridge would avoid the invalidate, but it costs only about 80 us per tile.
  - Tested on the board with `hps/hugebuf_test.c` (2026-11-13): tiles in slot 0 and slot 7 match the
    same tile written to reserved memory, for 32 MB and 2 MB pages. Reading a 512 KB tile, with the
    invalidate: 1.7 GB/s on an A55 core, 2.1 GB/s on an A76 (the uncached `/dev/mem` mapping: 23 to
    148 MB/s). So the copy is 15-20 times faster than the link.
  - Other options, kept in case huge pages fail:
    - `u-dma-buf`, the usual open-source module for exactly this: a cached buffer with explicit
      sync calls. It is not in this kernel (`CONFIG_UDMABUF` is off, and that is a different thing
      anyway) and would have to be built out of tree, which depends on the board's kernel build tree.
    - Reserved memory (the device-tree node at 0xBF00_0000, already in place) through `/dev/mem`,
      pinned to an A76 core with 128-bit loads: 148 MB/s, about 35 % above the link, with little
      margin for splitting the records into planes.
    - A small kernel driver of our own that maps the reserved memory cached and exposes a sync
      ioctl: the same as `u-dma-buf`, but more code to maintain.
- **Thin bridge:** each tile request from the PC becomes one FPGA job,
  with its parameters copied unchanged into the job registers (they are already in the hardware
  format). It keeps the FPGA job queue full, and sends each finished tile back with its request id.
- **Result buffers:** 8 slots of 256x256x8 B = 512 KB (4 MB in all) in the reserved memory. A request
  holds a slot from the moment its job is pushed until its tile is sent: up to 8 in the FPGA queue,
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
| Periodicity check | FPGA core | 3 | Per pipeline slot, store z_old (2×W bits, in MLAB/M20K) and compare \|x − x_old\| and \|y − y_old\| < ε. Brent's variant: refresh z_old at powers of 2, not every 20 iterations. Huge gain for interior pixels at high max_it. **Rule:** whether and when a pixel is proven may depend only on c and the iteration number, never on MAX_IT (ε and the refresh schedule don't scale with it), so a run to M' is a run to M stopped early, which the PC's cache relies on. The record carries the iteration of the proof (see "Result per pixel"). |
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

- Done: the 60-core/198 MHz work is committed and tested on the board. It stays as a reference
  (`De25NanoTop`).

### Phase 1: HPS + Ethernet with today's cores

The goal is the whole data path working end to end, with no new arithmetic yet.

1. Build the Terasic GHRD as it is, boot the SD image, check Ethernet and ssh.
2. Read and write a test register on `lwhps2fpga` from Linux (`devmem`). Write a test pattern into
   reserved HPS memory through `f2sdram`, read it back from Linux, and measure the read speed.
3. New Spinal top `De25NanoHpsTop` with `qsys_top` as a BlackBox, and `MandelbrotAccel` with the
   register map above, on per-slot cores (`SlotCore`): a slot that finishes hands over its result
   (u32 count, |z|², pixel index, job context) and takes the next pixel from the pixel issuer, with
   2 more integer bits (21 bits). This merges the old steps 3 and 4 (decided 2026-11-13: no
   wrapper around the batch `Core`).
   - **Fan control:** the AMC6821 fan controller (I2C address 0x5C on the HDMI I2C pins, FPGA side
     only, so Linux can't reach it) runs the fan at full speed until the FPGA configures it.
     Instantiate Terasic's `BOARD_MANAGEMENT` IP (`Demonstration/FPGA/Board_Info_RTL/board_management_ip`)
     as a BlackBox with `Auto_Fan_Speed` = 1: 3000 RPM at 35 °C rising to 10000 RPM at 90 °C. Its
     files are copied at build time, like the other Terasic files. Its temperature and RPM outputs
     go to BOARD_TEMP and FAN_RPM (they change slowly, so a plain two-flop crossing is enough).
     Not simulated: the testbench of step 7 ties these inputs off.
4. (merged into step 3)
5. `mandelbrotd`: UIO, result slots, request queue, TCP protocol.
6. PC application (`pc/`), milestones 1-6 of [PC_APP_PLAN.md](PC_APP_PLAN.md). The board connection is
   milestone 4; the disk cache and the tools come after it.
7. A simulation testbench: `MandelbrotAccel` with `AxiMemorySim` as HPS memory and an AXI-Lite driver,
   compared against a Scala model of the whole image.

**Step 1 is done (2026-11-13).** The prebuilt GHRD and the SD image (`de25_nano_sdcard_console_v1.1.zip`)
boot, with Ethernet and ssh. What the board showed:

- Kernel 6.12.11, 934 MB of RAM, command line `console=ttyS0,115200 root=/dev/mmcblk0p2 rw rootwait`.
- `/dev/mem` works for us without a rebuild: `CONFIG_DEVMEM=y`, and `STRICT_DEVMEM=y` without
  `IO_STRICT_DEVMEM` only blocks the kernel's own RAM, not the bridges or RAM removed with `mem=`.
- UIO is there as modules (`CONFIG_UIO=m`, `UIO_PDRV_GENIRQ=m`) but has no devices. It needs a
  device-tree node for our register block, so it waits for step 5.
- CMA is 32 MB (enough for the 4 MB of result slots if `u-dma-buf` is needed later).
- No `devmem`, `devmem2` or `gcc` on the board: tools are cross-built on the PC (`hps/`).

**Step 2 tools** are in `hps/`: `memtool` (peek, poke, pattern fill/check, read-speed benchmark over
`/dev/mem`) and `f2sdram_test.tcl` (writes the same pattern through the GHRD's JTAG master on
`f2sdram`). GHRD addresses, from `qsys_top.qsys`: `lwhps2fpga` holds sysid at +0x1_0000 (id
0xACD5CAFE), button PIO +0x1_0060, DIP switch PIO +0x1_0070, LED PIO +0x1_0080.

**Step 2 is done (2026-11-13).** Results, on the prebuilt GHRD:

- `lwhps2fpga` works from Linux at 0x2000_0000: sysid reads 0xACD5CAFE, the DIP switches read back.
- RAM is 0x8000_0000-0xBFFF_FFFF. 16 MB at 0xBF00_0000 are now reserved for us by a `no-map` node in
  the device tree (the boot script is a checksummed FIT image, so `mem=` was not used). Changes to
  the board's system are listed in [hps/BOARD_CHANGES.md](hps/BOARD_CHANGES.md).
- `f2sdram` works, and its addresses are HPS physical addresses: 64 KB written over JTAG at
  0xBF10_0000 read back from Linux without an error.
- **Reading the buffer through `/dev/mem` is too slow.** The mapping is device memory (uncached).
  Copying 4 MB out of it: 23 MB/s with 64-bit loads and 90 MB/s with 128-bit loads on an A55 core,
  73 and 148 MB/s on an A76 core. The link carries about 110 MB/s, and `mandelbrotd` has more to do
  per byte than a copy. So `mandelbrotd` needs a cached mapping of the result buffer; see the risks.
- For later: `/sys/kernel/config/device-tree` exists (overlays can add the UIO node), hugetlbfs is
  enabled, and `u-dma-buf` is not in the kernel (`CONFIG_UDMABUF` is off; it would be an
  out-of-tree module).

**Step 3 is done (2026-11-13): the accelerator works on the board.**

- `De25NanoHpsTop` (`spinal/.../De25NanoHps.scala`, built with `make hps` in `quartus/`): the GHRD's
  Platform Designer system reshaped by `quartus/hps_qsys.tcl`, its IP upgraded to Quartus 26.1, and
  the GHRD's boot loader. The platform alone was tested on the board: registers from Linux at
  0x2000_0000 (Avalon-MM out of the bridge, not AXI-Lite), the fan in auto mode (about 3600 RPM at
  32 °C instead of full speed), single beats on `f2sdram`. The HPS IP does not build with `f2sdram`
  enabled and nothing reading it. Terasic's `f2sdram_adapter` sets the AXI protection, cache and
  user bits.
- `MandelbrotAccel` (`MandelbrotAccel.scala`): 8 job contexts, the issuer, dispatch and result
  trees, `SlotCore`s (`SlotCore.scala`), and a writer that sends each record as one AXI beat with
  strobes (no write combining yet). `AccelPlatform` crosses the bus (`fpgalib.AvalonMMCC`) and the
  AXI channels (`StreamFifoCC`) from the 100 MHz bridge clock to the core clock (`core_pll` on
  CLOCK1_50). Interrupt on `f2h_irq0` bit 0, no Linux driver yet.
- Tests: `SlotCoreSim` and `AccelSim` against the bit-exact `AccelModel`; on the board,
  `hps/accel_test.py check` compares every record of 6 kinds of tiles with the same model in Python
  (all match, and abort works).
- Build: 60 cores at 198 MHz, setup slack +0.17 ns; 97 % of the ALMs, 180 of 376 DSP blocks, 76 % of
  the RAM blocks. Little room for more logic: write combining or new features may need fewer cores.
- Throughput (`accel_test.py bench`, 256x256 tiles over the whole set, Python polling DONE):

  | MAX_IT | tiles/s | M pixels/s | G iterations/s | utilisation |
  |---|---|---|---|---|
  | 16 | 646 | 42.3 | 0.25 | 2 % |
  | 256 | 696 | 45.6 | 2.16 | 18 % |
  | 4096 | 204 | 13.4 | 9.26 | 78 % |

  Shallow tiles stop at about 45 M pixels/s, which is the single-beat writes on `f2sdram`: 3 times
  the 14 M pixels/s the link carries, so write combining is not needed for phase 1. Deep tiles reach
  78 % of 60 x 198 M iterations/s (each pixel also takes one extra pass for its bailout test).
- The bitstream is loaded over JTAG, so a power cycle brings back the GHRD from the QSPI flash.

**Where step 5 stands (2026-11-13): `mandelbrotd` works on the board; LZ4, the interrupt and the
start at boot are missing.**

- `hps/mandelbrotd.c` (cross-built, protocol in `hps/protocol.h`): one client at a time, each
  TILE_REQ becomes one job, 8 result slots in a 32 MB huge page, `DC CIVAC` before reading a slot,
  DONE polled every 100 us while jobs are in flight, pinned to CPU 3 (an A76). Run as root:
  `sudo ./mandelbrotd [-v]`. It needs our bitstream loaded (`make program-hps`).
- `pc/tests/test_board.py` (with `MANDELBROT_BOARD=192.168.10.10`): tiles bit-exact against an
  integer model, errors, cancel, flow control, board status. All pass. `headless.py --host` renders
  from the board.
- Found on the board: a queued job that was aborted waited until the job ahead of it had issued all
  its pixels, which at depth is forever. The issuer now takes the oldest queued context that is
  not aborted (an age matrix instead of a FIFO), and an aborted queued job is done at once.
- To do: LZ4 in `mandelbrotd` (raw tiles cap the link at about 14 M pixels/s); the interrupt through
  UIO (a device-tree overlay) instead of polling; a systemd unit, once the bitstream is in the QSPI
  flash so that it is there at power-on; a throughput measurement over the direct 1 GbE link (from
  home, through Tailscale, the link gives about 6 MB/s).

Steps 1-2 hold the biggest unknowns (the HPS bridges, `f2sdram`, the kernel), and the PC application
needs no board until its milestone 4. So start both at the same time.

### Phase 2: wide arithmetic

Keep this phase small. At 5 cores and about 1 G iterations/s, 128-bit fixed point is probably in the
range of a desktop CPU (the C++ benchmark will tell). Its purpose is to make the application usable
for exploring (W ≥ 64) and to build the wide multiplier and carry-save parts that perturbation
reuses. The speed comes in phases 3 and 4. So: one verified, parametric core and one honest number
per width, and no tuning for one more core.

Decided 2026-11-13: phase 2 comes before the colouring work (PC milestone 3), because smooth
colouring needs the larger bailout radius of the wide format; LZ4, UIO and the flash wait.

1. Bit-exact model of the truncated multi-limb squaring and the iteration, in Python
   (`pc/mandelbrot/fixed.py`, also the simulated server's future exact mode) and in Scala (for the
   RTL tests). An error study before any RTL: the truncation against exact squares, and the counts
   against a much wider reference at the deepest level, to settle the guard bits.
2. `WideSquare` (limbs, symmetric products, truncation, pipelined carry-save tree), tested on its own.
3. `WideIteration` in the per-slot core, with the W and I parameters (I = 10, R = 16), and the |z|²
   output converted to f32 from the wide value.
4. The rest of the chain for W up to 128: `mandelbrotd` (coordinates of several words), `AccelModel`,
   `accel_test.py`, `test_board.py`. The 21-bit design stays as a build option (`WIDTH=21`): it is
   about 10 times faster at shallow zoom, and both don't fit one bitstream (5 wide cores take 175 of
   the 188 DSP blocks), so switching means programming the FPGA again.
5. One build per W, W = 64 first (it checks the wide adders at 198 MHz cheaply), with the core count
   from the DSP budget above. If it misses 198 MHz, take cores out or lower the clock, and move on;
   update CAPS and the tools.
6. **CPU benchmark** (`pc/bench/`, C++): the same escape-time loop on the PC's CPU, in double
   precision (AVX2/AVX-512) and in 64/128-bit fixed point (`__int128` and multi-word), on the same
   tiles, all cores. It gives the FPGA vs CPU numbers per width for the report, and says honestly
   whether 128-bit fixed point on 5 cores beats the CPU (the expectation is: about the same).

**Where phase 2 stands (2026-11-16): steps 1-6 done, all three widths on the board.**

- Step 1 done. `pc/mandelbrot/fixed.py` and `WideModel` (Scala) are the bit-exact model. Squares
  leave out the lowest diagonals while they are worth under a quarter ulp in total: 5 of 6 products
  at W = 64, 8 of 10 at 96, 11 of 15 at 128, so 12, 7 and 5 cores in 188 DSP blocks. No overflow is
  possible with I = 10, R = 16 (checked over random c in the whole format, `tests/test_fixed.py`).
- Error study (`pc/tools/precision_study.py`): tiles on the boundary at 16, 1024 and 65536 ulps per
  pixel, max_it 1500, against exact squares and against a format 64 bits wider. The left-out
  products change no more counts than exact squares do (same columns), so **no guard bits**. What
  remains is the format's own precision against max_it near hard boundaries: in the seahorse valley
  at W = 64, about 13 to 38 % of the counts differ from the wider reference even at 65536 ulps per
  pixel; at W = 128, 1 to 5 % at the deepest level; elsewhere almost none. The viewer's limit of 16
  ulps per pixel stays; noise at the deepest levels is the honest result of the format.
- Step 2 and 3 done in simulation: `WideSquare` (`WideSquareSim`, 64/96/128) and `WideIteration` in
  `SlotCore` (`AccelWideSim`: the whole accelerator at W = 64 and 128, record for record against
  the model). |z|² goes as 48-bit fixed point (29 fraction bits) to the f32 converter. A new
  register R2 (0x0A0) gives the bailout radius squared.
- Step 4: `mandelbrotd` takes coordinates up to 128 bits and reads R2; `accel_test.py` and
  `test_board.py` use `fixed.py` for wide designs.
- Step 5: `make hps WIDTH=64` (or 96, 128; 21 is the default) picks the core count from the DSP
  budget and keeps a copy of each width's bitstream; `make program-hps WIDTH=64` loads it.
  - W = 128 first missed 198 MHz by 0.8 ns, in the first stage of `WideIteration`; that stage is
    now split into 3 (pipeline 11 at W = 64 and 96, 12 at 128), and all three widths were rebuilt.
  - **All three work on the board at 198 MHz** (2026-11-16): `accel_test.py check` and all of
    `test_board.py` pass bit for bit against `fixed.py`. `accel_test.py bench`, 200 tiles of the
    whole set:

    | W | cores | setup slack | ALMs | DSP | max_it 256 | max_it 4096 |
    |---|---|---|---|---|---|---|
    | 64 | 12 | +0.647 ns | 59 % | 180 | 1.39 G it/s (58 %) | 2.27 G it/s (95 %) |
    | 96 | 7 | +0.544 ns | 54 % | 168 | 0.98 G it/s (71 %) | |
    | 128 | 5 | +0.218 ns | 56 % | 165 | 0.78 G it/s (78 %) | |

    (utilisation in brackets). At max_it 256 utilisation falls as cores are added, probably the
    pixel hand-over or the result path; not measured yet. The viewer goes to level 192 at W = 64
    (7.3e-12 per pixel at level 140, 3.4e10 magnification).
  - The core count stays at the DSP budget: 9 cores at W = 128 don't fit (Quartus put 188
    multipliers in DSP blocks and the other 109 in logic, 127k of 93.6k LUTs). The "376 DSP
    blocks" in the reports count 18x19 halves.
- Step 6: `pc/bench` (C++, OpenMP, all 24 threads of a Ryzen 9 9900X), 256x256 tiles of the whole
  set at max_it 4096: double (AVX-512) 11.2 G iterations/s, 64-bit fixed point 1.1 G, 128-bit fixed
  point 0.2 G. For comparison, the 21-bit FPGA design does 9.3 G, and W = 64 2.26 G: twice the
  CPU in the same format, and a fifth of the CPU in double, which only reaches about 1e-13 per pixel.

### Phase 3: algorithmic speedups

- Periodicity check (FPGA), cardioid/bulb test (FPGA), Mariani-Silver (PC).
- **Cardioid/bulb test (step 1).** `CardioidCheck` (`Cardioid.scala`) sits between the issuer and the
  dispatch tree, 5 pipeline stages, 4 multipliers of 27x27 bits. A pixel it proves goes to a core with
  a flag and finishes on its first pass (count 0xFFFFFFFE, proof iteration 0); the cores have far more
  slots than the issuer's one pixel per cycle, so this costs nothing and needs no second result path.
  The exact definition, shared by `fixed.py` (`cardioid_bulb`), `CardioidCheck.inside` and the RTL:
  - X, Y: c truncated to G = 24 fraction bits (floor). Only -1.25 <= X < 0.5, |Y| < 0.75 is tested.
  - Cardioid: a = X - 1/4, Q = floor((a² + Y²) / 2^G), S = Q + a; interior if 4QS - Y² <= -2^32
    (units of 2^-2G, so 4 · (-2^-18)).
  - Bulb: (X + 1)² + Y² <= 2^44 - 2^27 (1/16 - 2^-21).
  - Why the margins are enough: with F(x, y) = q(q + x - 1/4) - y²/4, q = (x - 1/4)² + y², the exact
    test is F <= 0. In the tested range |∂F/∂x| < 24.2 and |∂F/∂y| < 11.1, so truncating x and y
    (each by < 2^-24) changes F by < 35.3 · 2^-24, and truncating q (by < 2^-24) changes q(q + a) by
    < 7.2 · 2^-24: 42.5 · 2^-24 < 2^-18.4 in all. The bulb's sum changes by < (2·1.5 + 2·0.75) · 2^-24
    < 2^-21.8. `tests/test_fixed.py` checks 40 000 points near both boundaries against the exact
    rational tests.
  - It changes the arithmetic id ("cardioid-g24-v1"), so tiles of earlier builds don't mix with it.
- Benchmark views (shallow, a seahorse valley spiral, a deep zoom, an interior-heavy view): record
  iterations/s and frame times before and after each feature.

**Baseline before phase 3 (2026-11-19), W = 64, 12 cores, no flags.** `pc/tools/bench_views.py`,
1920x1080, run on the board against `mandelbrotd` on localhost (only the standard library, so it
runs there; `--help` says how), best of 2:

| view | level | max_it | tiles | it/px | wall s | Mpx/s | G it/s | FPGA busy | bound |
|---|---|---|---|---|---|---|---|---|---|
| link (all pixels escape at n = 1) | 29 | 256 | 40 | 1 | 0.19 | 14.0 | 0.01 | 1 % | transport, 112 MB/s |
| whole set | 29 | 256 | 48 | 52 | 0.23 | 13.5 | 0.70 | 32 % | transport |
| seahorse spiral | 60 | 4096 | 45 | 1034 | 1.32 | 2.2 | 2.32 | 98 % | compute |
| deep (7e-12 per pixel) | 138 | 10000 | 45 | 1069 | 1.34 | 2.2 | 2.36 | 100 % | compute |
| interior (main cardioid) | 36 | 4096 | 54 | 3716 | 5.55 | 0.6 | 2.37 | 100 % | compute |

- The cores reach their peak (12 x 198 MHz = 2.38 G it/s) whenever there is enough work per pixel;
  the low utilisation seen with `accel_test.py bench` at max_it 256 does not show up here, because
  the transport limits first.
- Raw tiles cap `mandelbrotd` at 14 M pixels/s (112 MB/s, about what Gigabit Ethernet carries), so
  shallow views at low max_it are transport-bound: LZ4 in `mandelbrotd` helps there, and more as
  phase 3 makes pixels cheaper.
- The interior view is what the cardioid test and the periodicity check should collapse.
**Cardioid/bulb test on the board (2026-11-19), same views, `--flags 2`.** Built at W = 64: 184
DSP blocks, 60 % ALMs, core clock slack +0.54 ns at 198 MHz (Fmax 221 MHz). `accel_test.py check`
and `tests/test_board.py` (with two cardioid tiles) match the model bit for bit.

| view | it/px | wall s | Mpx/s | G it/s | FPGA busy | bound | vs baseline |
|---|---|---|---|---|---|---|---|
| link | 1 | 0.15 | 18.0 | 0.02 | 1 % | transport | (noise) |
| whole set | 10.5 | 0.17 | 18.1 | 0.19 | 8 % | transport | 1.4x faster, 5x fewer iterations |
| seahorse spiral | 465 | 0.63 | 4.7 | 2.19 | 93 % | compute | 2.1x |
| deep | 1069 | 1.33 | 2.2 | 2.37 | 100 % | compute | 1.0x (no pixel in the cardioid) |
| interior | 24.7 | 0.20 | 17.5 | 0.43 | 19 % | transport | 28x |

- The interior view is now transport-bound (LZ4 would help it). The deep view is unchanged: how much
  of its time is pixels that reach max_it (what the periodicity check, step 2, can save) is still to
  be measured.

- The development PC is remote from the board: Ethernet goes through Tailscale (80 ms round trip,
  34 Mbit/s from the board by iperf3), JTAG and the console through usbip. The viewer gets about
  0.5 M pixels/s there whatever the FPGA does, which makes LZ4 and the PC's disk cache matter more.
  Benchmarks run on the board.

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

- The bridge clock is 100 MHz and the cores run at 198 MHz, so the result writer and the register
  block need a clock crossing. Whether `f2sdram` can be clocked at the core clock instead is not
  checked.
- GHRD made with Quartus 25.1; we use Quartus 26, so the IP may need upgrading (`qsys-generate --upgrade`).
- Truncation error accumulated over many iterations: verify the error stays below the pixel step
  for the chosen guard bits.
- 260-bit adders at 198 MHz: pipeline depth vs. ALM use, to be checked at W = 64 first.
- The uncached `/dev/mem` mapping of the result buffer is too slow (23-148 MB/s against a 110 MB/s
  link), hence huge pages (see `mandelbrotd`, "Result buffer"); tested, 1.7-2.1 GB/s. Remaining
  risk: a 32 MB page may not be available when memory is fragmented, so reserve it early in boot.
- Integer bits in phase 1: I = 5 with bailout 4 can't overflow before the bailout is seen (|c| < 2
  gives |z_n| < 6; any other c escapes at n = 1). |z|² at escape reaches 512 (for |c| near 16), so
  it is reported with 22 fraction bits in 32.
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
