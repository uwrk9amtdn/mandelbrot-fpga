package fpgalib

import org.scalatest.funsuite.AnyFunSuite
import spinal.core._
import spinal.core.sim._
import spinal.lib.sim._

import scala.collection.mutable

/** LinearInterpolator against q = floor(a + alpha * (b - a)), signed and unsigned, with backpressure. */
class LinearInterpolatorSim extends AnyFunSuite {
  def run(width: Int, precision: Int, signed: Boolean): Unit = {
    val cfg = SimConfig.withConfig(SpinalConfig(defaultConfigForClockDomains = ClockDomainConfig(resetKind = SYNC)))
    cfg.workspaceName(s"LinearInterpolator_w${width}_p${precision}_s$signed")
      .compile(new LinearInterpolator(width, precision, signed)).doSim(seed = 5) { dut =>
        val cd = dut.clockDomain
        dut.io.s.valid #= false
        cd.forkStimulus(10)
        cd.waitSampling(3)

        def value(raw: BigInt): BigInt =
          if (signed && raw.testBit(width - 1)) raw - (BigInt(1) << width) else raw
        val expected = mutable.Queue[BigInt]()
        var got      = 0
        StreamMonitor(dut.io.m, cd) { q =>
          val e = expected.dequeue()
          assert(q.toBigInt == e, s"got ${q.toBigInt}, expected $e")
          got += 1
        }
        StreamReadyRandomizer(dut.io.m, cd)

        val n    = 3000
        var sent = 0
        while (sent < n) {
          val a = BigInt(width, simRandom)
          val b = BigInt(width, simRandom)
          val k = BigInt(precision, simRandom)
          dut.io.s.a     #= a
          dut.io.s.b     #= b
          dut.io.s.alpha #= k
          dut.io.s.valid #= simRandom.nextInt(4) != 0
          cd.waitSampling()
          if (dut.io.s.valid.toBoolean && dut.io.s.ready.toBoolean) {
            val (va, vb) = (value(a), value(b))
            val q = ((va << precision) + k * (vb - va)) >> precision // floor (BigInt >> is arithmetic)
            expected += q & ((BigInt(1) << width) - 1)
            sent += 1
          }
        }
        dut.io.s.valid #= false
        cd.waitSamplingWhere(got == n)
      }
  }

  test("unsigned 8 bit, 8-bit alpha (ColorConverter)") { run(8, 8, signed = false) }
  test("signed 8 bit, 8-bit alpha") { run(8, 8, signed = true) }
  test("unsigned 12 bit, 5-bit alpha") { run(12, 5, signed = false) }
}
