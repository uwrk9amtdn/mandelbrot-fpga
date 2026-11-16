package mandelbrot

import org.scalatest.funsuite.AnyFunSuite
import spinal.core._
import spinal.core.sim._

import scala.collection.mutable
import scala.util.Random

/** WideSquare against WideModel.square, at the three widths, with random and extreme operands. */
class WideSquareSim extends AnyFunSuite {
  for (w <- Seq(64, 96, 128)) test(s"W = $w") {
    val p = WideParams(w)
    MandelbrotSpinalConfig.sim.workspaceName(s"WideSquare$w").compile(new WideSquare(p)).doSim(seed = w) { dut =>
      val cd  = dut.clockDomain
      val rnd = new Random(w)
      val top = BigInt(1) << (p.limbBits * p.limbs)
      // all ones, powers of two, values near limb boundaries, and the magnitudes the core sees
      val special = Seq(BigInt(0), BigInt(1), top - 1, BigInt(1) << (w - 1), (BigInt(1) << w) - 1) ++
        (0 until p.limbs).flatMap(k => Seq((BigInt(1) << (p.limbBits * k)) - 1, BigInt(1) << (p.limbBits * k)))
      val values = special ++ Seq.fill(3000) {
        val bits = 1 + rnd.nextInt(p.limbBits * p.limbs)
        BigInt(bits, rnd.self)
      }
      val expect = mutable.Queue[BigInt]()
      cd.forkStimulus(10)
      dut.io.a #= 0
      cd.waitSampling(dut.latency + 2)
      var checked = 0
      cd.onSamplings {
        if (expect.size > dut.latency) {
          val want = expect.dequeue()
          assert(dut.io.q.toBigInt == want, s"square: got ${dut.io.q.toBigInt}, want $want")
          checked += 1
        }
      }
      for (v <- values) {
        dut.io.a #= v
        expect.enqueue(WideModel.square(p, v) & ((BigInt(1) << p.sqBits) - 1))
        cd.waitSampling()
      }
      for (_ <- 0 to dut.latency) { // flush: the last operands' results come out
        dut.io.a #= 0
        expect.enqueue(0)
        cd.waitSampling()
      }
      assert(checked >= values.size)
    }
  }
}
