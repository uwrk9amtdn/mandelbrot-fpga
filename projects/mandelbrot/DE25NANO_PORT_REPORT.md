# DE25-Nano port: status report

Date: 2026-11-11

The mandelbrot design is ported from the Xilinx AC701 to the Terasic DE25-Nano (Agilex 5,
A5EB013BB23BE4SCS), entirely in SpinalHDL. It passes all simulation tests and compiles in Quartus
Pro 26 (`module load quartus_26`) with timing met. It was **tested on the board and works** (2026-11-12).

- RTL: `projects/mandelbrot/spinal/`
- Quartus flow: `projects/mandelbrot/quartus/`
- PC control tool: `projects/mandelbrot/tools/mandelbrot_ctl.py`
- Full documentation (register map, LEDs, build steps): the "DE25-Nano" section of `spinal/README.md`

## Next step

```bash
cd projects/mandelbrot/quartus
make          # Verilog + IP + Quartus project + compile -> build/output_files/mandelbrot.sof
make program
../tools/mandelbrot_ctl.py -p /dev/ttyUSBx status    # or COMx on Windows
```

`DE25_DIR` defaults to `~/Desktop/fpga/de25nano/DE25-Nano_revB_v.1.0.0_ResourcePackage`.

## VIO replacement

The VIO is replaced by a register file on the FPGA UART pins. That UART reaches the PC as one of the
serial ports on the board's USB-C cable (through the USB-Blaster III), at 115200 8N1. Commands are
plain text, so any terminal works:

- `r 1` reads register 1 and replies with 8 hex digits.
- `w 3 FFFF8000` writes register 3 and replies `OK`.
- Anything malformed gets the reply `?`.

`mandelbrot_ctl.py` wraps this with `status`, `view`, `palette`, `raw` and `interactive` commands. In
interactive mode the arrow keys pan, `+`/`-` zoom, `[`/`]` change max_it and `r` renders. The script
needs pyserial.

Altera's direct VIO equivalent is "In-System Sources and Probes", in case it's wanted later.

## New and ported modules

Generic blocks are in the repo-level library `spinal/` (package `fpgalib`); the rest in
`projects/mandelbrot/spinal/src/main/scala/mandelbrot/`.

| File | Replaces | Notes |
|---|---|---|
| `LinearInterpolator.scala` (fpgalib), `ColorConverter.scala` | `linear_interpolator.sv`, `color_converter.sv` | cycle-for-cycle identical to the SV |
| `DisplayDriver.scala` (fpgalib) | `display_driver.sv` | cycle-for-cycle identical to the SV; 1080p60 timing |
| `AxiMemory.scala` (fpgalib) | `memory_reader.sv`, `memory_writer.sv` | 256-bit AXI4, matching the LPDDR4 controller's port |
| `I2cWriter.scala`, `Adv7513Setup.scala` (fpgalib) | `ac701_adv7511_setup.sv`, `i2c/*` | ADV7513 with no I2C switch; setup reruns on monitor hot plug |
| `UartControl.scala` (fpgalib) | VIO | text register protocol |
| `EmifCalibration.scala` (fpgalib) | (new) | polls the LPDDR4 controller's calibration status |
| `MandelbrotSystem.scala` | `top.sv` minus vendor IP | three clocks: 198 MHz core, 310 MHz memory, 148.5 MHz pixel |
| `De25Nano.scala`, `De25NanoIp.scala` (fpgalib) | `top.sv`, `mig_wrapper.sv` | board top level, with wrappers for the LPDDR4 controller, PLL and reset-release IP |

## Verification

- All 13 SpinalHDL tests pass (`sbt test`), including the 8 that existed before.
- `SystemSim` runs the whole design except vendor IP, with three unrelated clocks, an AXI memory
  model, an ADV7513 I2C model and a simulated UART host. It checks:
  - the I2C register writes
  - the UART protocol
  - the framebuffer contents, against `RefModel`
  - every displayed pixel over several frames

  It covers two views and two palettes, the board key, and checks that no underrun happens.
- `cosim/run_parts.sh`: 4.6 million color-converter outputs and 3 full 1080p frames are identical
  to the SV.
- The generated top level lints clean against Terasic's own port lists for the LPDDR4 controller
  system and the reset-release IP. This check caught one real bug: the memory AXI address is 30 bits
  (1 GiB), not the 32 bits the demo's comments claim. It is fixed.

## Decisions made without asking

- **Terasic files:** the LPDDR4 controller system (`EMIF_Qsys`), reset-release IP, `quartus.ini`
  and pin assignments are copied from the Terasic resource package at build time and not committed.
  Terasic's license limits them to Terasic boards.
- **Unused memory bank:** Terasic's LPDDR4 system drives both banks, so bank B is also calibrated
  but tied off. Only bank A is used.
- **Core clock:** 198 MHz (asked for 200; see below). Change it with `make CORE_MHZ=...`, to a
  value one PLL can make exactly alongside 148.5 MHz.
- **Cores:** 60 (the most that fits, see below). The device's 376 multipliers are the 18×19 size. With FRAC_WIDTH = 16 each
  multiplier is 19×19, which takes a whole DSP block, so only 188 are usable. Change it with
  `make NCORES=...`; 1080 must be divisible by it.
- **Startup:** the board renders the full set once after configuration. KEY0 renders again and
  KEY1 resets.
- **LEDs:** see `spinal/README.md`. LED0 means memory calibrated and HDMI set up; LED7 is the
  heartbeat.

## Quartus results

### Current build (2026-11-12): 60 cores, 198 MHz core

- **Timing met.** Core clock 198.0 MHz, +1.1 ns setup slack, Fmax 254 MHz. Memory 411 MHz Fmax
  (runs at 310), pixel 262 (148.5), AXI-Lite 263 (155).
- **Resources:** 26,467 / 46,800 ALMs (57 %), 180 core multipliers in 27x27 DSP mode (182 DSP blocks).
- **Core clock:** 200 MHz isn't possible from one PLL together with exactly 148.5 MHz; 198 MHz is the
  closest (1188 MHz VCO: / 6 core, / 8 pixel).
- **Core count:** a 19x19 multiplier (fracWidth 16) needs a whole DSP block in 27x27 mode. The
  device has 188 such blocks (the product table's 376 counts 18x19 halves), so at most 62 cores;
  60 is the largest that divides 1080. A 90-core build put 82 multipliers in soft logic and needed
  107 % of the device. fracWidth 15 (18x18) would allow two per block, at one bit less zoom depth.
- **Fixes on the way there:**
  - `Wrapper`: the core dispatch is now pipelined. Without it the ready mux of the 60 cores (spread
    over the chip) limited the core clock to 170 MHz.
  - `quartus/Makefile`: `sys_pll` is now really regenerated when CORE_MHZ changes (before,
    quartus_ipgenerate kept the old PLL and the core silently stayed at 99 MHz).
  - New Makefile option SI_LATENCY (default 8).

### Earlier build (54 cores, 99 MHz core)

- Timing met after one SDC fix: the PLLs' asynchronous lock/reset (`tennm_ph2_iopll~pll_ctrl_reg`)
  into reset synchronizers is now a false path.
- Fmax: core 199 MHz, pixel 271, memory 373, AXI-Lite 240. 23,166 ALMs (50 %), 164 DSP blocks.
- Design-assistant items left open (still true):
  - Missing output delay on the HDMI/LED outputs: intentional, as in Terasic's demo.
  - CDC rules wanting `set_max_skew`/`set_max_delay` on the clock-crossing buses instead of plain
    asynchronous clock groups. Functionally covered by the Spinal CDC blocks; optional to tighten.
  - Unconstrained JTAG clock (`altera_reserved_tck`).

## HDMI clock margin

The design works on the board as it is. For reference:

- HDMI clock: the pixel clock goes straight to `HDMI_TX_CLK`, as in Terasic's demo, which leaves
  little hold margin. If the picture shows sparkles or wrong colors, change the ADV7513 clock delay
  (register 0xBA in `spinal/src/main/scala/fpgalib/Adv7513Setup.scala`) or invert the clock.

## Performance compared with a CPU (estimate, 2026-11-12)

Not measured yet. The CPU numbers are estimates from peak throughput for well-optimised SIMD code,
not benchmarks. A CPU benchmark with the same views, iteration limits and precisions is still to do.

**Conclusion:** this board does not beat a modern desktop CPU at any precision. The project's value
is the architecture and the efficiency per watt, and a design that scales to bigger FPGAs and to the
ASIC flow; it is not the fastest way to render.

Raw multiply throughput:

| | Multipliers | Clock | Multiplies per second |
|---|---|---|---|
| This FPGA | 188 DSP blocks (27x27) | 0.2 GHz | about 38 G (27-bit) |
| 16-core desktop CPU, AVX-512 (e.g. Ryzen 9950X) | 16 cores x 2 FMA units x 8 double lanes | about 5 GHz | about 1 300 G (53-bit) |

The CPU does about 30 times more multiplies per second, each twice as wide. Custom bit widths and the
lack of instruction overhead on the FPGA only recover a few times that.

| Precision | FPGA (this board) | 16-core CPU (estimate) |
|---|---|---|
| Current 19-bit fixed point (below float32's 24-bit mantissa) | 12 G iterations/s (60 cores, 198 MHz) | float32, 16 lanes: about 50-100 G iterations/s |
| About 106-128 bits | about 1 G iterations/s (5 cores, see [ROADMAP.md](ROADMAP.md)) | double-double SIMD: about 5-15 G iterations/s |
| Deep zoom with perturbation | about 2.5 G iterations/s (about 13 cores) | double deltas: about 30-60 G iterations/s |

- On top of this, deep-zoom software (Kalles Fraktaler, Imagina) uses series approximation and BLA to
  skip millions of iterations. A GPU is faster again at float32.

Where the FPGA does well:

- **Energy per iteration.** The board draws a few watts, the CPU about 200 W. At about 12 G
  iterations/s the FPGA is probably 3-5 times better per watt. To be measured.
- **No wasted work.** Each pixel goes to whichever core has a free slot. CPU SIMD lanes sit idle until
  every pixel in the vector has escaped.
- **Bigger FPGAs.** A large Agilex 7 has about 4 500 DSP blocks, 24 times this device, and would be
  competitive. The same design scales up directly.
- **The ASIC flow.** A custom chip with Booth/Dadda multipliers at 1 GHz or more is where a Mandelbrot
  accelerator could win on throughput.
