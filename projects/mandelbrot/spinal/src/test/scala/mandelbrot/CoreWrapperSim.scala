package mandelbrot

import fpgalib._

import org.scalatest.funsuite.AnyFunSuite
import spinal.core._
import spinal.core.sim._
import spinal.lib.sim._

import scala.collection.mutable

/** Whole frames through CoreWrapper, output stream compared with RefModel. */
class CoreWrapperSim extends AnyFunSuite {

  /** @param drain wait for each frame's output before sending the next command
    *              (needed when maxIt changes: the core reads maxIt live)
    */
  def run(cfg: MandelbrotConfig, cmds: Seq[RefModel.Cmd], backpressure: Boolean, drain: Boolean): Unit = {
    // expected stream
    var addr     = cfg.startAddr
    val expected = mutable.ArrayBuffer[(Int, Boolean)]()
    val perFrame = mutable.ArrayBuffer[Int]()
    for (c <- cmds) {
      val (words, next) = RefModel.frame(cfg, c, addr)
      expected ++= words
      perFrame += expected.size
      addr = next
    }

    MandelbrotSpinalConfig.sim
      .workspaceName(s"CoreWrapper_${cfg.string}")
      .compile {
        val dut = new CoreWrapper(cfg)
        dut.core.state.simPublic()
        dut.core.ptr.simPublic()
        dut.core.io.s.valid.simPublic()
        dut
      }
      .doSim(seed = 1) { dut =>
        val cd   = dut.clockDomain
        val core = dut.core
        dut.io.s.valid #= false
        dut.io.m.ready #= !backpressure
        cd.forkStimulus(10)
        cd.waitSampling(5)

        val got = mutable.ArrayBuffer[(Int, Boolean)]()
        StreamMonitor(dut.io.m, cd) { p =>
          got += ((p.fragment.toInt, p.last.toBoolean))
          val i = got.size - 1
          assert(i < expected.size, s"more output words than expected (${expected.size})")
          assert(got(i) == expected(i), s"word $i: got ${got(i)}, expected ${expected(i)}")
        }
        if (backpressure) StreamReadyRandomizer(dut.io.m, cd)

        // Core matches pipeline outputs to slots by cycle count: a started LOAD must not pause.
        cd.onSamplings {
          if (core.state.toEnum == CoreState.LOAD && core.ptr.toInt != 0)
            assert(core.io.s.valid.toBoolean, "gap in core input during LOAD")
        }

        for ((c, f) <- cmds.zip(perFrame)) {
          dut.io.s.payload.xStart #= c.xStart
          dut.io.s.payload.yStart #= c.yStart
          dut.io.s.payload.xyStep #= c.xyStep
          dut.io.s.payload.maxIt  #= c.maxIt
          dut.io.s.valid          #= true
          cd.waitSamplingWhere(dut.io.s.ready.toBoolean)
          dut.io.s.valid #= false
          if (drain) cd.waitSamplingWhere(got.size >= f)
        }

        val timeout = expected.size * (cmds.map(_.maxIt).max + 4) * 4 + 10000
        var cycles  = 0
        while (got.size < expected.size) {
          cd.waitSampling()
          cycles += 1
          assert(cycles < timeout, s"timeout: ${got.size}/${expected.size} words")
        }
        cd.waitSampling(50)
        assert(got.size == expected.size, "extra output words")
      }
  }

  def view(cfg: MandelbrotConfig, x0: Double, y0: Double, width: Double, maxIt: Int) = {
    val f = cfg.fracWidth
    RefModel.Cmd(RefModel.fix(x0, f), RefModel.fix(y0, f), RefModel.fix(width / cfg.xRes, f), maxIt)
  }

  test("16x8, n=8, siLatency=4, fracWidth=8, backpressure, back-to-back frames") {
    val cfg = MandelbrotConfig(startAddr = 0xFFC0, xRes = 16, yRes = 8, n = 8, fracWidth = 8, siLatency = 4)
    run(cfg, Seq(view(cfg, -2.0, 1.0, 2.5, 40), view(cfg, -1.0, 0.4, 0.6, 40)), backpressure = true, drain = false)
  }

  test("12x4, n=8, siLatency=4, fracWidth=12, maxIt changes between frames") {
    val cfg = MandelbrotConfig(startAddr = 0x100, xRes = 12, yRes = 4, n = 8, fracWidth = 12, siLatency = 4)
    run(cfg, Seq(view(cfg, -2.0, 1.0, 2.5, 25), view(cfg, -0.8, 0.3, 0.5, 60)), backpressure = true, drain = true)
  }

  test("16x8, n=16, siLatency=8, fracWidth=16, no backpressure") {
    val cfg = MandelbrotConfig(xRes = 16, yRes = 8, n = 16, fracWidth = 16, siLatency = 8)
    run(cfg, Seq(view(cfg, -2.0, 1.2, 2.6, 100)), backpressure = false, drain = false)
  }

  test("8x6, n=8, siLatency=8, maxIt=1 and wrap-around coordinates") {
    val cfg = MandelbrotConfig(startAddr = 0xFFFFFF00L, xRes = 8, yRes = 6, n = 8, fracWidth = 8, siLatency = 8)
    run(cfg, Seq(view(cfg, 3.5, -3.5, 4.0, 1), view(cfg, 3.5, -3.5, 4.0, 1)), backpressure = true, drain = false)
  }
}
