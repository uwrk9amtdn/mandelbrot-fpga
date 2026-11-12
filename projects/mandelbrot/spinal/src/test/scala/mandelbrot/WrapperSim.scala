package mandelbrot

import fpgalib._

import org.scalatest.funsuite.AnyFunSuite
import spinal.core._
import spinal.core.sim._
import spinal.lib.sim._

import scala.collection.mutable

/** Whole views through Wrapper, compared packet by packet with RefModel.
  *
  * Packets from different cores interleave in arbiter order, so results are compared
  * per address: every address must receive exactly the expected bursts, in order.
  */
class WrapperSim extends AnyFunSuite {

  def run(cfg: WrapperConfig, views: Seq[RefModel.View], drain: Boolean): Unit = {
    val addrs    = Array.tabulate(cfg.nCores)(i => cfg.core(i).startAddr)
    val frames   = views.map(v => RefModel.wrapperFrame(cfg, v, addrs))
    val expected = mutable.Map[BigInt, mutable.Queue[Seq[Int]]]()
    for (f <- frames; (a, d) <- f) expected.getOrElseUpdate(a, mutable.Queue()) += d
    val total = frames.map(_.size).sum

    MandelbrotSpinalConfig.sim
      .workspaceName(s"Wrapper_x${cfg.xRes}_y${cfg.yRes}_c${cfg.nCores}_s${cfg.arbiterTreeSans}_d${cfg.dataWidth}")
      .compile(new Wrapper(cfg))
      .doSim(seed = 3) { dut =>
        val cd = dut.clockDomain
        dut.io.s.valid #= false
        cd.forkStimulus(10)
        cd.waitSampling(5)

        StreamReadyRandomizer(dut.io.mAddr, cd)
        StreamReadyRandomizer(dut.io.mData, cd)

        val addrQueue = mutable.Queue[BigInt]()
        val beatWords = mutable.ArrayBuffer[Int]()
        var packets   = 0
        StreamMonitor(dut.io.mAddr, cd)(a => addrQueue += a.toBigInt)
        StreamMonitor(dut.io.mData, cd) { p =>
          val bits = p.fragment.toBigInt
          for (k <- 0 until cfg.dataWidth / 16) beatWords += ((bits >> (16 * k)) & 0xFFFF).toInt // low word first
          if (p.last.toBoolean) {
            assert(beatWords.size == cfg.burstLength, s"packet has ${beatWords.size} words")
            assert(addrQueue.nonEmpty, "data packet without address")
            val a = addrQueue.dequeue()
            val q = expected.get(a)
            assert(q.exists(_.nonEmpty), f"unexpected packet for address 0x$a%08x")
            val exp = q.get.dequeue()
            assert(beatWords.toSeq == exp, f"address 0x$a%08x: got $beatWords, expected $exp")
            beatWords.clear()
            packets += 1
          } else {
            assert(beatWords.size < cfg.burstLength, "packet longer than burstLength")
          }
        }

        var sent = 0
        for ((v, f) <- views.zip(frames)) {
          dut.io.s.centerX #= v.centerX
          dut.io.s.centerY #= v.centerY
          dut.io.s.xyStep  #= v.xyStep
          dut.io.s.maxIt   #= v.maxIt
          dut.io.s.valid   #= true
          cd.waitSamplingWhere(dut.io.s.ready.toBoolean)
          dut.io.s.valid #= false
          sent += f.size
          if (drain) cd.waitSamplingWhere(packets >= sent)
        }

        val timeout = total * (cfg.burstLength + 2) * (views.map(_.maxIt).max + 4) * 4 + 20000
        var cycles  = 0
        while (packets < total) {
          cd.waitSampling()
          cycles += 1
          assert(cycles < timeout, s"timeout: $packets/$total packets")
        }
        cd.waitSampling(100)
        assert(packets == total && addrQueue.isEmpty, "extra output")
        assert(expected.values.forall(_.isEmpty))
      }
  }

  def view(cfg: WrapperConfig, cx: Double, cy: Double, width: Double, maxIt: Int) = {
    val f = cfg.fracWidth
    RefModel.View(RefModel.fix(cx, f), RefModel.fix(cy, f), RefModel.fix(width / cfg.xRes, f), maxIt)
  }

  test("16x8, 4 cores, 2-input arbiters, 32-bit data, back-to-back views") {
    val cfg = WrapperConfig(xRes = 16, yRes = 8, nCores = 4, arbiterTreeSans = 2, burstLength = 8,
      dataWidth = 32, siLatency = 4)
    run(cfg, Seq(view(cfg, -0.75, 0.0, 2.5, 40), view(cfg, -0.5, 0.5, 1.0, 40)), drain = false)
  }

  test("8x6, 3 cores (uneven tree), 64-bit data, fbStartAddr, maxIt changes") {
    val cfg = WrapperConfig(xRes = 8, yRes = 6, nCores = 3, arbiterTreeSans = 2, burstLength = 8,
      fbStartAddr = 0x1000, dataWidth = 64, siLatency = 8, fracWidth = 12)
    run(cfg, Seq(view(cfg, -0.75, 0.0, 2.5, 30), view(cfg, -0.8, 0.2, 0.6, 80)), drain = true)
  }

  test("16x10, 5 cores, 4-input arbiters, 16-bit data") {
    val cfg = WrapperConfig(xRes = 16, yRes = 10, nCores = 5, arbiterTreeSans = 4, burstLength = 16,
      dataWidth = 16, siLatency = 8)
    run(cfg, Seq(view(cfg, -0.75, 0.0, 3.0, 50)), drain = false)
  }
}
