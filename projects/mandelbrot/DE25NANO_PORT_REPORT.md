# DE25-Nano port: status report

Date: 2026-11-11

The mandelbrot design is ported from the Xilinx AC701 to the Terasic DE25-Nano (Agilex 5,
A5EB013BB23BE4SCS), entirely in SpinalHDL. It passes all simulation tests and compiles in Quartus
Pro 26 (`module load quartus_26`) with timing met. It has **not been tried on the board yet**.

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
| `MandelbrotSystem.scala` | `top.sv` minus vendor IP | three clocks: 99 MHz core, 310 MHz memory, 148.5 MHz pixel |
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
- **Core clock:** 99 MHz, because one PLL also has to produce exactly 148.5 MHz for the pixel
  clock. Change it with `make CORE_MHZ=...`.
- **Cores:** 54. The device's 376 multipliers are the 18×19 size. With FRAC_WIDTH = 16 each
  multiplier is 19×19, which takes a whole DSP block, so only 188 are usable. Change it with
  `make NCORES=...`; 1080 must be divisible by it.
- **Startup:** the board renders the full set once after configuration. KEY0 renders again and
  KEY1 resets.
- **LEDs:** see `spinal/README.md`. LED0 means memory calibrated and HDMI set up; LED7 is the
  heartbeat.

## Quartus results (2026-11-12, 54 cores, 99 MHz core)

- **Timing met** after one SDC fix. The first run failed setup/recovery on paths from
  `tennm_ph2_iopll~pll_ctrl_reg` (the PLLs' asynchronous lock/reset) into reset synchronizers.
  These are now a false path in `quartus/mandelbrot.sdc`. The duplicate `create_clock`s for the
  50 MHz inputs were also removed (the PLL IP defines them).
- **Fmax:** core 199 MHz (runs at 99), pixel 271 (needs 148.5), memory 373 (needs 310), AXI-Lite 240.
- **Resources:** 23,166 / 46,800 ALMs (50 %), 164 / 376 DSP blocks (44 %). A 19×19 multiplier does
  *not* take a whole DSP block on this device, so logic, not DSPs, limits the core count.
- **Room to grow:**
  - `make CORE_MHZ=148.5` (1485 MHz VCO / 10, same as the pixel clock) roughly doubles render speed.
  - More cores: try `NCORES=72` or `90` (1080 must be divisible by it).
  - Both need a new compile and timing check.
- Design-assistant items left open:
  - Missing output delay on the HDMI/LED outputs: intentional, as in Terasic's demo.
  - CDC rules wanting `set_max_skew`/`set_max_delay` on the clock-crossing buses instead of plain
    asynchronous clock groups. Functionally covered by the Spinal CDC blocks; optional to tighten.
  - Unconstrained JTAG clock (`altera_reserved_tck`).

## Original list of things to check (items 1–4 done; 5 still needs the board)

1. **PLL generation:** the `ip-deploy` parameters in `quartus/Makefile` are copied from Terasic's
   PLL file but have never been run.
2. **Clock constraints:** `quartus/mandelbrot.sdc` finds the PLL clocks by name pattern. It prints
   what it matched, and a critical warning if a pattern matches nothing.
3. **Timing:** the memory side runs at 310 MHz and the core at 99 MHz.
4. **DSP usage:** 54 cores × 3 multipliers, plus 3 in the color converter.
5. **HDMI clock:** the pixel clock goes straight to `HDMI_TX_CLK`, as in Terasic's demo, which
   leaves little hold margin. If the picture shows sparkles or wrong colors, change the ADV7513
   clock delay (register 0xBA in `spinal/src/main/scala/fpgalib/Adv7513Setup.scala`) or invert the clock.

Nothing is committed yet.
