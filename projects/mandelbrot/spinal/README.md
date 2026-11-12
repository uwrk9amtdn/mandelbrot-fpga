# Mandelbrot compute engine in SpinalHDL

SpinalHDL version of the whole design: `../src/wrapper.sv` and everything below it, and the board
level (`top.sv`, display path, memory reader/writer, HDMI setup) ported from the Xilinx AC701 to the
**Terasic DE25-Nano** (Agilex 5). See [DE25-Nano](#de25-nano) below and `../quartus/`.

- `CoreWrapper` and below (`core_wrapper.sv`, `core.sv`, `single_iteration.sv`, `cfg.sv`,
  `mul_dsp.sv`, `delayer.sv`) is a close port, **cycle-for-cycle identical** to the SV.
- `Wrapper` (`wrapper.sv` plus the `axis/` arbiter tree, skid buffers, width converter and
  `constant_multiplier.sv`) is written the SpinalHDL way, using `Stream` library blocks.
  It is **functionally identical**: every address receives the same bursts in the same order.
  Packets from different cores may come out in a different order, because the arbiters differ.

## Requirements

- `sbt` (`pacman -S sbt`). The first run downloads Scala and SpinalHDL from Maven Central.
- Verilator (for tests and co-simulation).
- **A full JDK (`jdk21-openjdk`), not just a JRE.** SpinalSim compiles a JNI bridge and needs `jni.h`,
  which the `jre*-openjdk` packages don't include.

## Usage

```bash
sbt test                                   # SpinalSim tests against the Scala reference model
sbt "runMain mandelbrot.GenerateWrapper"   # default config (54 cores) -> gen/sp_Wrapper.v
sbt "runMain mandelbrot.GenerateWrapper nCores=4 arbiterTreeSans=4 dataWidth=16 fracWidth=16"
sbt "runMain mandelbrot.GenerateVerilog"   # CoreWrapper alone -> gen/sp_CoreWrapper.v
cosim/run_wrapper.sh                       # SV wrapper vs Wrapper, per-address comparison
NCORES=3 Y_RES=6 X_RES=8 DATA_WIDTH=64 cosim/run_wrapper.sh
cosim/run.sh                               # SV core_wrapper vs CoreWrapper, cycle by cycle
X_RES=32 Y_RES=4 N=16 FRAC_WIDTH=16 cosim/run.sh
cosim/run_parts.sh                         # SV color_converter + display_driver vs Spinal, cycle by cycle
sbt "runMain mandelbrot.GenerateDe25Nano"  # DE25-Nano top level -> gen/sp_De25NanoTop.v
make -C ../quartus                         # DE25-Nano bitstream (needs Quartus Pro), see below
```

## Wrapper configuration (`WrapperConfig`)

| SV (`wrapper.sv`)   | Scala             | default |
|---------------------|-------------------|---------|
| `X_RES`, `Y_RES`    | `xRes`, `yRes`    | 1920, 1080 |
| `FRAC_WIDTH`        | `fracWidth`       | 8       |
| `NCORES`            | `nCores`          | 54      |
| `ARBITER_TREE_SANS` | `arbiterTreeSans` | 4       |
| `BURST_LENGTH`      | `burstLength`     | 16      |
| `FB_START_ADDR`     | `fbStartAddr`     | 0       |
| `m_data.DATA_WIDTH` | `dataWidth`       | 64 (was an interface parameter) |
| `cfg::SI_LATENCY`   | `siLatency`       | 8       |

Ports match `asic/src/mandelbrot_asic.sv`: `s_valid, s_ready, s_center_x, s_center_y, s_xy_step,
s_max_it, m_addr_valid, m_addr_ready, m_addr_data, m_data_valid, m_data_ready, m_data_data, m_data_last`.

How the SV blocks map to SpinalHDL:

| SV | SpinalHDL |
|---|---|
| `constant_multiplier` x3 + READY/PREPARE states | `io.s.map { … }.m2sPipe()` |
| DISPATCH state, one-hot `core_s_valid` | `Counter` + `StreamDemux` |
| `generate for` + `localparam START_ADDR` | `for (i <- 0 until nCores) yield new CoreWrapper(core(i))` |
| `axis_rr_arbiter_tree` (77 lines) + `axis_rr_arbiter` + `axis_skid_buffer` | recursive `arbiterTree` (6 lines): `StreamArbiterFactory.roundRobin.fragmentLock` + `s2mPipe().m2sPipe()` |
| `master_block` ADDR1/ADDR2/DATA FSM + `axis_wc`/`axis_adapter` | `StreamDemux` by word position + `StreamWidthAdapter` / `StreamFragmentWidthAdapter` |

## Configuration

All options are Scala parameters (`MandelbrotConfig`), fixed when the Verilog is generated.
The generated Verilog has no parameters.

| SV                        | Scala       | default | notes                                   |
|---------------------------|-------------|---------|-----------------------------------------|
| `core_wrapper.START_ADDR` | `startAddr` | 0       | byte address of the first packet        |
| `core_wrapper.X_RES`      | `xRes`      | 1920    |                                         |
| `core_wrapper.Y_RES`      | `yRes`      | 1080    |                                         |
| `core_wrapper.N`          | `n`         | 16      | iteration counts per output packet      |
| `FRAC_WIDTH`              | `fracWidth` | 8       | values are `SInt(fracWidth + 3)` = SV `[2:-FRAC_WIDTH]` |
| `cfg::SI_LATENCY`         | `siLatency` | 8       | was a global constant, now per instance |

The SV `$error` checks are `require`s in `Config.scala`. One difference: `siLatency >= 4`.
The SV checked `>= 3`, but 3 gives `mul_dsp` a latency of 1, which `mul_dsp` itself rejects.

## Files

Files marked fpgalib are generic and live in the repo-level SpinalHDL library `../../../spinal/`
(package `fpgalib`, its own sbt build with its own tests), which `build.sbt` pulls in as a source
dependency. The others are in `src/main/scala/mandelbrot/`. SV paths are relative to the repo root.

| file | SV original | notes |
|---|---|---|
| `Config.scala` | `cfg.sv`, parameters | `MandelbrotConfig`, shared `SpinalConfig` (prefix `sp_`) |
| fpgalib `MulPipe.scala` | `mul_dsp.sv` | `use_dsp` attribute kept |
| `SingleIteration.scala` | `single_iteration.sv` | `delayer` replaced by SpinalHDL's built-in `Delay` |
| `Core.scala` | `core.sv` | memories are `Mem` + async read, `ram_style="distributed"` kept |
| `CoreWrapper.scala` | `core_wrapper.sv` | `Stream`/`Fragment` inside, SV port names outside |
| `Wrapper.scala` | `wrapper.sv` + `axis/*` + `constant_multiplier.sv` | `WrapperConfig`, idiomatic stream design |
| fpgalib `LinearInterpolator.scala` | `sv/misc/linear_interpolator.sv` | cycle-exact |
| `ColorConverter.scala` | `color_converter.sv` | cycle-exact; `Palette` bundle for the color settings |
| fpgalib `DisplayDriver.scala` | `sv/hdmi/display_driver.sv` | cycle-exact; `VideoTiming` (1080p60 preset) |
| fpgalib `AxiMemory.scala` | `memory_reader.sv`, `memory_writer.sv` | SpinalHDL `Axi4` |
| fpgalib `I2cWriter.scala`, `Adv7513Setup.scala` | `sv/hdmi/ac701_adv7511_setup.sv`, `sv/i2c/*` | write-only I2C master, ADV7513 setup |
| fpgalib `UartControl.scala` | Xilinx VIO | text register protocol over UART |
| fpgalib `EmifCalibration.scala` | – | Agilex EMIF calibration poll (Terasic `axil_driver_calibration.sv`) |
| `MandelbrotSystem.scala` | `top.sv` minus vendor IP | three clock domains, register map (`Regs`) |
| `De25Nano.scala` | `top.sv` + `mig_wrapper.sv` | DE25-Nano top level, `sys_pll` BlackBox |
| fpgalib `De25NanoIp.scala` | – | BlackBoxes for Terasic's EMIF_Qsys and the reset-release IP, EMIF AXI config |
| fpgalib `SvClockNames.scala` | – | names the implicit clock/reset `clk`/`rst` |
| `Generate.scala` | – | `GenerateVerilog` (CoreWrapper), `GenerateWrapper`, `GenerateParts`, `GenerateDe25Nano` |
| `src/test/...` | – | `RefModel` (bit-accurate model), `SingleIterationSim`, `CoreWrapperSim`, `WrapperSim`, `ColorConverterSim`, `SystemSim` |
| `cosim/` | – | SV and generated designs side by side: `cosim_tb.sv` (core_wrapper), `wrapper_cosim_tb.sv`, `parts_cosim_tb.sv` |

Clock and reset are the implicit SpinalHDL clock domain (synchronous, active high). The `SvClockNames`
trait names them `clk` / `rst` on whichever component is the top level.

Generated ports: `clk, rst` (synchronous, active high), `s_valid, s_ready, s_x_start, s_y_start,
s_xy_step, s_max_it, m_valid, m_ready, m_data, m_last`. Vectors are zero-based (`[fracWidth+2:0]`).

The two "if ready or not valid, load the register" output stages of `core_wrapper.sv` are SpinalHDL's
`m2sPipe()` here. The co-simulation confirms it behaves identically.

## Behaviour notes

- **Bug fixed (in the SV too):** in LOAD, `core.sv` fed `x_mem[ptr]` into the pipeline in the same cycle
  that slot was being written, so the first iteration used the previous batch's point. Both versions
  now feed the incoming point directly.
- Core matches pipeline outputs to slots by cycle count, so once a batch starts loading its input must be
  valid for `siLatency` consecutive cycles. CoreWrapper guarantees this, and `CoreWrapperSim` checks it.
- Core reads `maxIt` live. A new command accepted while the previous frame's last batch is still
  computing changes `maxIt` for that batch (same in the SV).

## DE25-Nano

```
                 core clock (99 MHz)                 memory clock (310 MHz)          pixel clock (148.5 MHz)
 FPGA_UART ──► UartControl ─► registers ─► Wrapper ─► FIFOs ─► MemoryWriter ─┐
                    │                    (54 cores)                          ├─ AXI4 ─► LPDDR4 EMIF (bank A)
 HDMI_I2C  ◄── Adv7513Setup                       MemoryReader ◄─ vsync ─────┘
                                                       └─► FIFO (256 bit) ─► 16-bit counts ─► ColorConverter ─► DisplayDriver ─► HDMI_TX
```

What changed compared with the AC701 `top.sv`:

| AC701 (Xilinx) | DE25-Nano (Altera) |
|---|---|
| 200 MHz LVDS clock, 7-series PLLs | `CLOCK0_50` → IOPLL `sys_pll` (148.5 MHz pixel, 99 MHz core) |
| MIG DDR3, 512-bit AXI + `axi_wc` down to 64 bit | Terasic `EMIF_Qsys` LPDDR4, 256-bit AXI at 310 MHz, used directly (`Wrapper.dataWidth = 256`) |
| ADV7511 behind a PCA9548 I2C switch | ADV7513 directly on `HDMI_I2C_*`; re-initialised on hot plug (`HDMI_TX_INT`) |
| VIO (`vio_0`, JTAG) | `UartControl` on `FPGA_UART_*` (USB-Blaster III serial port) + `../tools/mandelbrot_ctl.py` |
| `NCORES = 108`, `ARBITER_TREE_SANS = 5`, `BURST_LENGTH = 32` | 54 cores by default (50 % of the ALMs, 164/376 DSP blocks); logic limits the count |
| `power_on_reset` | Agilex reset release IP (`ninit_done`) + PLL lock + `KEY[1]` |
| frame pipeline reset during vsync | same |

### Building

Needs Quartus Prime Pro with Agilex 5 support on `PATH` (`quartus_sh`, `ip-deploy`, `quartus_ipgenerate`),
sbt, and the Terasic DE25-Nano resource package. The EMIF system, the reset-release IP and the pin
assignments come from Terasic's `RTL_LPDDR4_AXI4_Test` demo and are copied into `quartus/build/` at
build time (Terasic's license only allows using them with Terasic boards, so they aren't committed).

```bash
cd ../quartus
make DE25_DIR=~/Desktop/fpga/de25nano/DE25-Nano_revB_v.1.0.0_ResourcePackage   # (the default)
make program
make CORE_MHZ=148.5 NCORES=60                                                    # options
```

After configuration the design renders the full set once (`initialView` in `SystemConfig`).
`KEY[0]` renders again, `KEY[1]` resets.

| LED (active low on the board) | meaning |
|---|---|
| 0 | LPDDR4 calibrated and ADV7513 set up |
| 1 | ADV7513 I2C error (retries every 100 ms) |
| 2 | underrun in the last frame (display read too slow) |
| 3 | render requested, not yet accepted |
| 5 | LPDDR4 calibration failed |
| 7 | heartbeat (core clock) |

### UART control (replaces the VIO)

115200 8N1 on the FPGA UART, one of the serial ports of the board's USB-C connection. Lines can be
typed in any terminal:

```
r 0             -> 4D414E44        read register 0
w 3 FFFF8000    -> OK              write register 3
r 1 2           -> ?               anything malformed
```

| reg | name | access | |
|---|---|---|---|
| 0x00 | ID | R | `0x4D414E44` ("MAND") |
| 0x01 | STATUS | R | bit 0 memory calibrated, 1 HDMI set up, 2 HDMI I2C error, 3 underrun in the last frame, 4 render pending |
| 0x02 | CONTROL | W | bit 0: render the current view |
| 0x03 / 0x04 | CENTER_X / CENTER_Y | RW | signed fixed point, `fracWidth` fraction bits (read sign-extended) |
| 0x05 | XY_STEP | RW | distance between pixels, same format |
| 0x06 | MAX_IT | RW | 16 bits |
| 0x07 | CC_START | RW | palette start index (iteration-count bit, 0..15) |
| 0x08 | CC_TWO | RW | 1 = use colors 0 and 1 only |
| 0x09–0x0C | COLOR0–3 | RW | `0xRRGGBB` |
| 0x10 / 0x11 / 0x12 | X_RES / Y_RES / FRAC | R | build parameters |
| 0x13 | FRAMES | R | renders started since reset |

View registers only take effect at the next render (CONTROL bit 0); palette registers apply at once.
`../tools/mandelbrot_ctl.py` wraps this (`status`, `view`, `palette`, `interactive` with arrow-key pan
and +/- zoom; needs pyserial).

### What is verified, what isn't

- `SystemSim`: the whole `MandelbrotSystem` (everything except vendor IP) with three unrelated clocks,
  an AXI memory model, an ADV7513 I2C model and a UART host. Checks the I2C register writes, the UART
  protocol, the framebuffer contents (against `RefModel`) and every displayed pixel over several frames
  (against `ColorModel`), for two views and two palettes.
- `cosim/run_parts.sh`: color_converter and display_driver cycle-exact against the SV.
- The generated top level lints clean against Terasic's `EMIF_Qsys_bb.v` / `agilex_reset_release_bb.v` port lists.
- Quartus Pro 26: compiles with timing met (core Fmax 199 MHz, memory 373 MHz, pixel 271 MHz),
  50 % of the ALMs and 164 of 376 DSP blocks at 54 cores. **Not yet tried on the board.**

