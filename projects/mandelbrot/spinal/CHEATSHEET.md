# SpinalHDL cheatsheet (this project)

Run everything from `projects/mandelbrot/spinal/`.

## 1. Running things

| Task | Command |
|---|---|
| Generate the whole engine (54 cores) | `sbt "runMain mandelbrot.GenerateWrapper"` → `gen/sp_Wrapper.v` |
| … with other options | `sbt "runMain mandelbrot.GenerateWrapper nCores=4 dataWidth=16 fracWidth=16"` |
| Generate one CoreWrapper | `sbt "runMain mandelbrot.GenerateVerilog xRes=16 yRes=8 n=8"` → `gen/sp_CoreWrapper.v` |
| Generate somewhere else | add `targetDir=/some/dir` |
| All tests | `sbt test` |
| One test suite | `sbt "testOnly mandelbrot.WrapperSim"` |
| Tests whose name contains text | `sbt 'testOnly mandelbrot.WrapperSim -- -z "5 cores"'` |
| Tests with waveforms | `WAVE=1 sbt "testOnly mandelbrot.CoreWrapperSim"` |
| Open a waveform | `surfer simWorkspace/<test>/test/wave.fst` (or `gtkwave …`) |
| Compare with the SV: core_wrapper | `cosim/run.sh` (cycle by cycle) |
| Compare with the SV: wrapper | `cosim/run_wrapper.sh` (per address) |
| Co-sim with other options | `NCORES=3 Y_RES=6 X_RES=8 DATA_WIDTH=64 cosim/run_wrapper.sh` |
| Lint generated Verilog | `verilator --lint-only -Wall gen/sp_Wrapper.v` |
| Compare with the SV: color_converter, display_driver | `cosim/run_parts.sh` (cycle by cycle) |
| Whole board design in simulation | `sbt "testOnly mandelbrot.SystemSim"` (add `WAVE=1` for waveforms) |
| DE25-Nano top level | `sbt "runMain mandelbrot.GenerateDe25Nano coreMHz=99 nCores=54"` → `gen/sp_De25NanoTop.v` |
| DE25-Nano bitstream / program | `make -C ../quartus`, `make -C ../quartus program` (Quartus Pro) |
| Talk to the board | `../tools/mandelbrot_ctl.py -p /dev/ttyUSB2 status` (or `interactive`) |

Generator options:
- **`GenerateWrapper`:** `xRes yRes fracWidth nCores arbiterTreeSans burstLength fbStartAddr dataWidth siLatency targetDir`
- **`GenerateVerilog`:** `startAddr xRes yRes n fracWidth siLatency targetDir`

Numbers can be decimal or `0x…`.

## 2. sbt tips

(What sbt is and which files it reads: see section 8.)

- **Use the sbt shell for repeated work.** Every `sbt …` command starts a new JVM, which takes about 10 s. Run `sbt` once,
  then type commands at the `sbt:mandelbrot-spinal>` prompt:
  ```
  compile
  runMain mandelbrot.GenerateWrapper nCores=4
  testOnly mandelbrot.SingleIterationSim
  ~compile        # recompile on every save (Enter stops it)
  ~testOnly mandelbrot.SingleIterationSim
  exit
  ```
- `sbt -batch …` gives no prompt, which suits scripts.
- **Clean everything:** `sbt clean; rm -rf simWorkspace gen cosim/build*`
- **Editor:** VS Code + the *Metals* extension (Scala) gives completion and go-to-definition, including
  into SpinalHDL's own source code.

## 3. Where things go

| Path | What |
|---|---|
| `src/main/scala/mandelbrot/` | hardware (`Config`, `SingleIteration`, `Core`, `CoreWrapper`, `Wrapper`, `Generate`) |
| `../../../spinal/` | generic blocks, package `fpgalib` (`MulPipe`, `DisplayDriver`, `I2cWriter`, `UartControl`, ...); own build: `cd ../../../spinal && sbt test` |
| `src/test/scala/mandelbrot/` | `RefModel` + simulations |
| `gen/` | generated Verilog |
| `simWorkspace/<name>/` | Verilator builds per test; `test/wave.fst` with `WAVE=1` |
| `cosim/build*/` | co-sim builds (`verilator.log` shows compile problems) |

All of these output folders are gitignored.

## 4. SpinalHDL ↔ SystemVerilog

| SystemVerilog | SpinalHDL |
|---|---|
| `logic [7:0] a;` (unsigned / signed / plain) | `val a = UInt(8 bits)` / `SInt(8 bits)` / `Bits(8 bits)` |
| `logic b;` | `val b = Bool()` |
| `assign a = x;` | `a := x` |
| `always_ff … a <= x;` | `val a = RegNext(x)` or `val a = Reg(UInt(8 bits)); a := x` |
| register with reset | `val a = RegInit(U(0, 8 bits))` or `Reg(…) init(0)` |
| `if / else if / else` | `when(c) {…} elsewhen(d) {…} otherwise {…}` |
| `case` | `switch(x) { is(1) {…} is(2, 3) {…} default {…} }` |
| `c ? a : b` | `Mux(c, a, b)` or `c ? a \| b` |
| `a == b`, `a != b` | `a === b`, `a =/= b` |
| `{a, b}` | `a ## b` |
| `a[7:4]`, `a[0]` | `a(7 downto 4)`, `a(0)` |
| width change | `a.resize(16)`; widths never change silently |
| type casts | `a.asUInt`, `a.asSInt`, `a.asBits`, `b.asBool` |
| `\|a` (reduce OR) | `a.orR` (also `andR`, `xorR`) |
| `$clog2(n)` | `log2Up(n)` |
| `typedef enum {A, B}` | `object S extends SpinalEnum { val A, B = newElement() }` |
| `logic [7:0] mem [16]` | `val mem = Mem(Bits(8 bits), 16)`; `mem.write(addr, d)`; `mem.readAsync(addr)` / `readSync` |
| `generate for` | an ordinary Scala `for` loop / `map` |
| `parameter` | constructor argument / case-class config |
| `$error` at elaboration | `require(cond, "message")` |
| module instance | `val u = new Child(cfg); u.io.a := x` |
| `(* attr = "v" *)` | `sig.addAttribute("attr", "v")` |

## 5. Streams (valid/ready handshake)

```scala
val s = slave  Stream(UInt(8 bits))          // input:  valid, ready, payload
val m = master Stream(Fragment(Bits(16 bits))) // output: + last (m.last, m.fragment)

s.fire                       // valid && ready
m << s                       // connect (valid, payload forward; ready back)
m << s.m2sPipe()             // register valid/payload  (one "if ready or !valid" stage)
m << s.s2mPipe().m2sPipe()   // full skid buffer (registered both ways)
s.map(x => x + 1)            // change payload
s.throwWhen(cond)            // drop transactions
StreamFifo(UInt(8 bits), 16) // FIFO
StreamDemux(s, sel, n)       // one → n
new StreamArbiterFactory().roundRobin.fragmentLock.on(Seq(a, b, c))  // n → one, packets kept whole
StreamWidthAdapter(in, out, BIG | LITTLE)   // e.g. 16 → 32 bit
StreamFragmentWidthAdapter(in, out)         // same, keeps `last`
```

## 6. Writing a simulation (SpinalSim)

```scala
MandelbrotSpinalConfig.sim
  .compile(new SingleIteration(8, 4))
  .doSim(seed = 1) { dut =>
    dut.clockDomain.forkStimulus(10)          // clock (period 10) + reset pulse
    dut.io.sA #= 5                            // drive an input
    dut.clockDomain.waitSampling()            // wait one rising edge
    dut.clockDomain.waitSampling(10)          // … ten edges
    dut.clockDomain.waitSamplingWhere(dut.io.s.ready.toBoolean)
    val v = dut.io.mA.toBigInt                // read (also .toInt, .toLong, .toBoolean, .toEnum)
    assert(v == 42, s"got $v")
    fork { /* runs in parallel */ }
  }
```

Stream helpers (`import spinal.lib.sim._`):
- `StreamMonitor(stream, cd) { payload => … }`: called on every transfer
- `StreamReadyRandomizer(stream, cd)`: random backpressure
- `StreamDriver(stream, cd) { payload => …; true }`: drives valid and payload

To read an internal signal in a test, mark it at elaboration:
`.compile { val d = new X; d.core.state.simPublic(); d }`.

## 7. Troubleshooting

| Symptom | Fix |
|---|---|
| `jni.h: No such file or directory` | install a full JDK: `jdk21-openjdk` (a `jre…` isn't enough) |
| `%Warning-UNOPTPUBLIC … Exiting due to warnings` | a test uses `simPublic()`; `MandelbrotSpinalConfig.sim` already disables that warning, so use it instead of plain `SimConfig` |
| `requirement failed: …` when generating | a `require` in a config class; the message says which option is wrong |
| `WIDTH MISMATCH` / `ASSIGNMENT OVERLAP` / `LATCH DETECTED` | real design errors that SV would let through: add `.resize`, or fix the double / missing assignment |
| `NO DRIVER ON …` | an output or signal is never assigned |
| strange failures after changing build.sbt | `sbt clean` and `rm -rf simWorkspace` |
| first `sbt` run is slow | it downloads Scala and SpinalHDL once (into `~/.cache/coursier`) |

## 8. What sbt is

sbt (the "Scala Build Tool") does for Scala what `make` plus a package manager does for C. It downloads
the libraries, compiles the `.scala` files, and runs programs (`runMain`) and tests (`test`).
SpinalHDL is just a Scala library, so "running SpinalHDL" means compiling and running a Scala
program with sbt. That program elaborates the hardware and writes Verilog.

### Files sbt reads

```
spinal/
├── build.sbt                  ← the build definition (the "Makefile")
├── project/
│   └── build.properties       ← which sbt version to use
├── src/main/scala/…           ← source code (found by convention, no listing needed)
└── src/test/scala/…           ← test code (only compiled for `sbt test`)
```

**`project/build.properties`** contains `sbt.version=1.12.15`. `/usr/bin/sbt` is only a launcher: it reads
this line and downloads that exact sbt version, so the project builds the same way on any machine.

**`build.sbt`**:

```scala
ThisBuild / scalaVersion := "2.13.12"     // Scala compiler version (must match SpinalHDL's)
val spinalVersion = "1.15.1"

lazy val root = (project in file("."))    // the project lives in this folder
  .settings(
    name := "mandelbrot-spinal",
    libraryDependencies ++= Seq(          // libraries, downloaded from Maven Central
      "com.github.spinalhdl" %% "spinalhdl-core" % spinalVersion,
      "com.github.spinalhdl" %% "spinalhdl-lib"  % spinalVersion,   // Stream, Fifo, arbiters…
      compilerPlugin("com.github.spinalhdl" %% "spinalhdl-idsl-plugin" % spinalVersion),
      "org.scalatest" %% "scalatest" % "3.2.14" % Test               // only for tests
    ),
    fork := true,                         // run programs/tests in a separate JVM
    Test / parallelExecution := false     // one test suite at a time (separate Verilator builds)
  )
```

- `%%` appends the Scala version to the library name: `spinalhdl-core` → `spinalhdl-core_2.13`.
- The **idsl-plugin** is a compiler plugin. It's how SpinalHDL learns the Scala variable names (`val ptr = …`),
  so they show up as `ptr` in the generated Verilog.
- `% Test` makes that library available only to `src/test`.

If they existed, sbt would also read `project/plugins.sbt` (sbt plugins), `project/*.scala` (build code)
and any other `*.sbt` file in the root (merged with `build.sbt`).

### Files sbt writes

| Path | What |
|---|---|
| `target/`, `project/target/` | compiled classes and build caches (safe to delete; `sbt clean`) |
| `.bsp/` | connection info for IDEs like VS Code Metals (may only appear after an IDE connects) |
| `~/.cache/coursier/` | downloaded jars (SpinalHDL, Scala, sbt itself), shared by all projects |
| `~/.sbt/`, `~/.ivy2/` | sbt's own global settings and caches |

`gen/` and `simWorkspace/` aren't from sbt. They're written by the SpinalHDL code when it runs.

### What `sbt test` does

1. Reads `project/build.properties` and starts sbt 1.12.15.
2. Reads `build.sbt` and downloads any missing libraries.
3. Compiles `src/main` and `src/test` (only what changed).
4. Starts a separate JVM (`fork`) that runs the tests. The tests then elaborate the hardware,
   run Verilator and simulate.
