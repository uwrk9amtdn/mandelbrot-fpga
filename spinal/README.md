# fpgalib: shared SpinalHDL blocks

Reusable SpinalHDL components for the projects in `../projects/`. Package `fpgalib`.
The SystemVerilog libraries are in `../sv/`.

| File | Contents |
|---|---|
| `MulPipe.scala` | pipelined multiplier for DSP blocks (SV: `sv/arithmetic/mul_dsp.sv`) |
| `LinearInterpolator.scala` | `a + alpha * (b - a)`, pipelined, stream handshake (SV: `sv/misc/linear_interpolator.sv`) |
| `DisplayDriver.scala` | video timing generator, `VideoTiming` (1080p60 preset) (SV: `sv/hdmi/display_driver.sv`) |
| `I2cWriter.scala` | write-only I2C master, `OpenDrain` bundle |
| `Adv7513Setup.scala` | ADV7513 HDMI transmitter register setup, re-run on hot plug |
| `AxiMemory.scala` | `MemoryReader` (AXI4 burst reads to a stream), `MemoryWriter` (address + data streams to AXI4 writes) |
| `UartControl.scala` | 32-bit register access over UART, text protocol (`w AA DDDDDDDD` / `r AA`) |
| `EmifCalibration.scala` | Agilex 5 EMIF calibration status poll over AXI4-Lite |
| `De25NanoIp.scala` | BlackBoxes for Terasic DE25-Nano IP: `EMIF_Qsys` (LPDDR4), `agilex_reset_release`, EMIF AXI config |
| `SvClockNames.scala` | mixin that names the implicit clock/reset `clk`/`rst` on a top level |

## Using it from a project

In `projects/<name>/spinal/build.sbt`:

```scala
lazy val fpgalib = RootProject(file("../../../spinal"))
lazy val root = (project in file(".")).dependsOn(fpgalib).settings(/* ... */)
```

and `import fpgalib._` in the sources. sbt compiles the library from source with the project, so
changes here are picked up immediately. Both builds must use the same Scala/SpinalHDL versions.

## Tests

```bash
sbt test    # LinearInterpolatorSim
```

The other blocks are tested through the projects (e.g. `projects/mandelbrot/spinal`: `SystemSim`
covers DisplayDriver, I2cWriter, Adv7513Setup, MemoryReader/Writer and UartControl).
