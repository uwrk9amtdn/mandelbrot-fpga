package mandelbrot

import org.scalatest.funsuite.AnyFunSuite
import spinal.core._
import spinal.core.sim._
import spinal.lib.bus.amba4.axi.sim._

/** AccelPlatform with wide cores (phase 2) against WideModel, record by record. */
class AccelWideSim extends AnyFunSuite {
  import AccelRegs._
  val base = 0xBF000000L

  for (w <- Seq(64, 128)) test(s"W = $w") {
    val cfg = AccelConfig(nCores = 2, intBits = 10, fracWidth = w - 10, nCtx = 4, doneDepth = 4,
      treeFanIn = 2, wide = true)
    val p = cfg.wideParams
    MandelbrotSpinalConfig.sim.workspaceName(s"AccelWide$w").compile(new AccelPlatform(cfg)).doSim(seed = 3) { dut =>
      val bridgeCd = ClockDomain(dut.io.bridgeClk, dut.io.bridgeRst)
      val coreCd   = ClockDomain(dut.io.coreClk, dut.io.coreRst)
      val bus      = dut.io.bus
      bus.read  #= false
      bus.write #= false
      dut.io.board.fpgaTemp  #= 0
      dut.io.board.boardTemp #= 0
      dut.io.board.fanRpm    #= 0
      dut.io.board.ready     #= false
      bridgeCd.forkStimulus(100)
      coreCd.forkStimulus(51)
      bridgeCd.assertReset()
      coreCd.assertReset()
      bridgeCd.waitSampling(10)
      bridgeCd.deassertReset()
      coreCd.deassertReset()
      val mem = AxiMemorySim(dut.io.axi, bridgeCd, AxiMemorySimConfig(readResponseDelay = 5, writeResponseDelay = 4))
      mem.start()
      bridgeCd.waitSampling(20)

      def write(addr: Int, data: Long): Unit = {
        bus.address    #= addr
        bus.writeData  #= data & 0xFFFFFFFFL
        bus.byteEnable #= 0xF
        bus.write      #= true
        bridgeCd.waitSamplingWhere(bus.waitRequestn.toBoolean)
        bus.write #= false
      }
      def read(addr: Int): Long = {
        bus.address #= addr
        bus.read    #= true
        bridgeCd.waitSamplingWhere(bus.waitRequestn.toBoolean)
        bus.read #= false
        bridgeCd.waitSamplingWhere(bus.readDataValid.toBoolean)
        bus.readData.toLong
      }
      def writeCoord(reg: Int, v: BigInt): Unit = {
        val raw = v & ((BigInt(1) << 128) - 1) // sign-extended words, low first
        for (k <- 0 until 4) write(reg + 4 * k, ((raw >> (32 * k)) & 0xFFFFFFFFL).toLong)
      }
      def fix(v: Double): BigInt = (BigDecimal(v) * BigDecimal(BigInt(1) << p.f)).setScale(0, BigDecimal.RoundingMode.HALF_EVEN).toBigInt

      assert(read(CAPS) == ((cfg.nCtx.toLong << 24) | (implementedFlags.toLong << 21) | (10L << 16) | (w.toLong << 8) | cfg.nCores))
      assert(read(R2) == 256)
      write(RESULT_BASE, base)
      write(RESULT_SLOTS, 8)

      case class Job(id: Int, slot: Int, x0: BigInt, y0: BigInt, step: BigInt, width: Int, height: Int, maxIt: Long,
                     flags: Int = 0)
      val jobs = Seq(
        Job(1, 0, fix(-2.2), fix(1.3), fix(0.3), 12, 9, 100), // whole set
        Job(2, 1, fix(-0.743643887037151), fix(0.131825904205330), 16, 6, 5, 400), // deepest level
        Job(3, 2, fix(-500.0), fix(500.0), fix(97.0), 11, 11, 20), // far outside: large |z|^2
        Job(4, 3, fix(-1.5), fix(0.02), fix(0.01), 7, 3, 1), // max_it 1
        Job(5, 4, fix(-1.4), fix(0.8), fix(0.1), 20, 17, 60, FLAG_CARDIOID) // cardioid, bulb, outside
      )
      // more jobs than contexts: a push with no free context is ignored, so push only when QUEUE
      // shows one (as mandelbrotd does), and drain DONE meanwhile
      var todo = jobs.toList
      var done = Map[Int, Int]()
      var cycles = 0
      while (done.size < jobs.size) {
        assert(cycles < 2000000, s"timed out, done ${done.keys.toSeq.sorted}")
        if (todo.nonEmpty && (read(QUEUE) & 0xFFFF) != 0) {
          val j = todo.head
          todo = todo.tail
          writeCoord(X0, j.x0); writeCoord(Y0, j.y0); writeCoord(STEP, j.step)
          write(SIZE, (j.height.toLong << 16) | j.width)
          write(MAX_IT, j.maxIt); write(JOB_ID, j.id); write(RESULT_SLOT, j.slot); write(FLAGS, j.flags)
          write(CONTROL, 1)
        }
        val d = read(DONE)
        if ((d >> 31) != 0) {
          write(DONE, 0)
          done += (d & 0xFFFF).toInt -> ((d >> 16) & 3).toInt
        } else {
          bridgeCd.waitSampling(50)
          cycles += 50
        }
      }
      for (j <- jobs) {
        assert(done(j.id) == 0, s"job ${j.id} status")
        for (row <- 0 until j.height; col <- 0 until j.width) {
          val i  = row * j.width + col
          val cx = WideModel.wrap(j.x0 + j.step * col, w)
          val cy = WideModel.wrap(j.y0 - j.step * row, w)
          val want =
            if ((j.flags & FLAG_CARDIOID) != 0 && CardioidCheck.inside(cx, cy, p.f)) BigInt(AccelModel.Interior)
            else {
              val (count, mag) = WideModel.pixel(p, cx, cy, j.maxIt)
              (BigInt(WideModel.magToF32Bits(p, mag)) << 32) | count
            }
          val addr = base + j.slot * cfg.slotSize + 8L * i
          val got  = (0 until 8).map(b => BigInt(mem.memory.read(addr + b) & 0xFF) << (8 * b)).sum
          assert(got == want, f"job ${j.id} pixel $i: got $got%016x, want $want%016x")
        }
      }
    }
  }
}
