package mandelbrot

import org.scalatest.funsuite.AnyFunSuite
import spinal.core._
import spinal.core.sim._

import scala.collection.mutable
import scala.util.Random

/** SlotCore against AccelModel: random pixels from two job contexts with different MAX_IT, random
  * gaps at the input and random back-pressure at the output, then an abort.
  */
class SlotCoreSim extends AnyFunSuite {
  val cfg = AccelConfig(nCores = 1, fracWidth = 12, siLatency = 6, nCtx = 4)

  test("random pixels, back-pressure, abort") {
    MandelbrotSpinalConfig.sim.workspaceName("SlotCore").compile(new SlotCore(cfg)).doSim(seed = 5) { dut =>
      val cd  = dut.clockDomain
      val rnd = new Random(1)
      val maxIts = Seq(40L, 7L, 0L, 1L)
      for (i <- 0 until 4) dut.io.maxIt(i) #= maxIts(i)
      dut.io.abort   #= 0
      dut.io.s.valid #= false
      dut.io.m.ready #= false
      cd.forkStimulus(10)
      cd.waitSampling(3)

      def fix(v: Double) = BigInt(math.round(v * (1 << cfg.fracWidth)))
      case class Px(x: BigInt, y: BigInt, ctx: Int, idx: Int)
      val pixels = (0 until 600).map { i =>
        // mostly near the set, some far outside (escape at n = 1, large |z|²)
        val r = if (i % 7 == 0) 15.9 else 2.2
        Px(fix((rnd.nextDouble() * 2 - 1) * r), fix((rnd.nextDouble() * 2 - 1) * r), rnd.nextInt(4), i)
      }
      val expected = pixels.map(p => p.idx -> AccelModel.pixel(cfg, p.x, p.y, maxIts(p.ctx))).toMap
      val got      = mutable.Map[Int, (Long, Long)]()
      var passes   = 0L
      var aborting = false

      cd.onSamplings {
        if (dut.io.iterating.toBoolean) passes += 1
        if (!aborting && dut.io.m.valid.toBoolean && dut.io.m.ready.toBoolean) {
          val idx = (dut.io.m.tag.toLong & 0xFFFF).toInt
          assert(!got.contains(idx), s"pixel $idx came out twice")
          assert(!dut.io.m.dropped.toBoolean)
          val count = if (dut.io.m.escaped.toBoolean) dut.io.m.count.toLong else AccelModel.Unresolved
          got(idx) = (count, dut.io.m.mag.toLong)
        }
        if (!aborting) dut.io.m.ready #= rnd.nextInt(4) != 0
      }

      for (p <- pixels) {
        if (rnd.nextInt(5) == 0) cd.waitSampling(rnd.nextInt(4))
        dut.io.s.x     #= p.x
        dut.io.s.y     #= p.y
        dut.io.s.tag   #= (p.ctx.toLong << cfg.idxBits) | p.idx
        dut.io.s.valid #= true
        cd.waitSamplingWhere(dut.io.s.ready.toBoolean)
        dut.io.s.valid #= false
      }
      cd.waitSampling(60 * cfg.siLatency)
      assert(got.size == pixels.size)
      for (p <- pixels) assert(got(p.idx) == expected(p.idx), s"pixel $p")
      // every pixel uses the pipeline count + 1 times (MAX_IT + 1 when it does not escape)
      val want = pixels.map { p =>
        val c = expected(p.idx)._1
        (if (c == AccelModel.Unresolved) maxIts(p.ctx) else c) + 1
      }.sum
      assert(passes == want)

      // abort: pixels of context 0 that would run for a long time come out dropped
      aborting = true
      dut.io.maxIt(0) #= 1000000
      dut.io.m.ready  #= true
      var dropped = 0
      cd.onSamplings { if (dut.io.m.valid.toBoolean && dut.io.m.dropped.toBoolean) dropped += 1 }
      for (i <- 0 until 4) {
        dut.io.s.x     #= 0
        dut.io.s.y     #= 0
        dut.io.s.tag   #= 1000 + i
        dut.io.s.valid #= true
        cd.waitSamplingWhere(dut.io.s.ready.toBoolean)
      }
      dut.io.s.valid #= false
      cd.waitSampling(50)
      assert(dropped == 0)
      dut.io.abort #= 1
      cd.waitSampling(3 * cfg.siLatency)
      assert(dropped == 4)
    }
  }
}
