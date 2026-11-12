package mandelbrot

import fpgalib._

import spinal.core._

/** All configuration options of the original SV hierarchy.
  *
  * | SV                      | here        |
  * |-------------------------|-------------|
  * | core_wrapper.START_ADDR | startAddr   |
  * | core_wrapper.X_RES      | xRes        |
  * | core_wrapper.Y_RES      | yRes        |
  * | core_wrapper.N          | n           |  (burst length: results per output packet)
  * | *.FRAC_WIDTH            | fracWidth   |
  * | cfg::SI_LATENCY         | siLatency   |  (was a global package constant, now per instance)
  *
  * Fixed-point numbers are signed with 3 integer bits: SV `[2:-FRAC_WIDTH]`,
  * here `SInt(fracWidth + 3 bits)` with the same bit pattern.
  */
case class MandelbrotConfig(
    startAddr: BigInt = 0,
    xRes: Int = 1920,
    yRes: Int = 1080,
    n: Int = 16,
    fracWidth: Int = 8,
    siLatency: Int = 8
) {
  require(startAddr >= 0 && startAddr < (BigInt(1) << 32), "startAddr must fit in 32 bits")
  require(xRes >= 2 && yRes >= 2, "xRes and yRes must be at least 2")
  require(fracWidth >= 1, "fracWidth must be at least 1")
  // single_iteration.sv checks SI_LATENCY >= 3, but its multipliers get LATENCY = SI_LATENCY - 2
  // and mul_dsp.sv requires LATENCY >= 2, so the real minimum is 4.
  require(siLatency >= 4, "siLatency must be at least 4")
  require((BigInt(xRes) * yRes) % n == 0, "xRes * yRes must be a multiple of n") // core_wrapper.sv
  require(n % siLatency == 0, "n must be a multiple of siLatency") // core_wrapper.sv

  /** Width of a fixed-point value (SV `[2:-FRAC_WIDTH]`). */
  val dataWidth: Int = fracWidth + 3

  /** Latency of each multiplier; the iteration adds 2 more register stages. */
  val mulLatency: Int = siLatency - 2

  /** Address of the last burst of a frame (SV computes this in 32 bits). */
  val lastAddr: BigInt = (startAddr + (BigInt(xRes) * yRes - n) * 2) & 0xFFFFFFFFL

  def string: String = s"sa${startAddr}_x${xRes}_y${yRes}_n${n}_f${fracWidth}_l${siLatency}"
}


object MandelbrotSpinalConfig {

  /** SpinalHDL settings shared by generation and simulation.
    * Synchronous active-high reset like the SV; the "sp_" prefix keeps generated
    * module names apart from the SV ones.
    */
  def apply(targetDirectory: String = "gen"): SpinalConfig = SpinalConfig(
    targetDirectory = targetDirectory,
    globalPrefix = "sp_",
    defaultConfigForClockDomains = ClockDomainConfig(resetKind = SYNC, resetActiveLevel = HIGH)
  )

  /** Simulation settings: signals probed with simPublic() trigger Verilator's
    * UNOPTPUBLIC warning, which Verilator 5.x treats as fatal.
    * Set the environment variable WAVE=1 to dump FST waveforms into simWorkspace/.
    */
  def sim: spinal.core.sim.SpinalSimConfig = {
    val c = spinal.core.sim.SimConfig
      .withConfig(apply())
      .addSimulatorFlag("-Wno-UNOPTPUBLIC")
    if (sys.env.get("WAVE").exists(_ != "0")) c.withFstWave else c
  }
}
