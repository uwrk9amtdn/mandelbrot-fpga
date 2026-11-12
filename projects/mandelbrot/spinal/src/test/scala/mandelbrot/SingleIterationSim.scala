package mandelbrot

import fpgalib._

import org.scalatest.funsuite.AnyFunSuite
import spinal.core._
import spinal.core.sim._

import scala.util.Random

/** Random full-range inputs through SingleIteration, checked against RefModel.iterate. */
class SingleIterationSim extends AnyFunSuite {

  def check(fracWidth: Int, siLatency: Int, cycles: Int = 2000): Unit = {
    val w = fracWidth + 3
    MandelbrotSpinalConfig.sim
      .workspaceName(s"SingleIteration_f${fracWidth}_l$siLatency")
      .compile(new SingleIteration(fracWidth, siLatency))
      .doSim(seed = 42) { dut =>
        val rnd = new Random(fracWidth * 100 + siLatency)
        def randS = RefModel.wrap(BigInt(w, rnd), w)

        dut.clockDomain.forkStimulus(10)
        dut.clockDomain.waitSampling()

        val inputs  = scala.collection.mutable.ArrayBuffer[(BigInt, BigInt, BigInt, BigInt)]()
        val outputs = scala.collection.mutable.ArrayBuffer[(BigInt, BigInt, Boolean)]()
        for (_ <- 0 until cycles) {
          val in = (randS, randS, randS, randS)
          dut.io.sA #= in._1; dut.io.sB #= in._2; dut.io.sC #= in._3; dut.io.sD #= in._4
          dut.clockDomain.waitSampling()
          inputs += in
          outputs += ((dut.io.mA.toBigInt, dut.io.mB.toBigInt, dut.io.mStop.toBoolean))
        }

        // Values read after waitSampling() are the ones sampled at that edge, so
        // outputs(j) must equal the model applied to inputs(j - siLatency), and no other offset.
        def matches(off: Int) = (off + 10 until cycles).forall { j =>
          val (a, b, c, d) = inputs(j - off)
          outputs(j) == RefModel.iterate(a, b, c, d, fracWidth)
        }
        val offsets = (0 to siLatency + 2).filter(matches)
        assert(offsets == Seq(siLatency), s"expected latency $siLatency, model matched at offsets $offsets")
      }
  }

  test("fracWidth=8, siLatency=4")(check(8, 4))
  test("fracWidth=8, siLatency=8")(check(8, 8))
  test("fracWidth=16, siLatency=4")(check(16, 4))
  test("fracWidth=32, siLatency=6")(check(32, 6))
}
