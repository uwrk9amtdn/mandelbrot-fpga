package mandelbrot

import org.scalatest.funsuite.AnyFunSuite
import spinal.core._
import spinal.core.sim._
import spinal.lib.bus.amba4.axi.sim._

import scala.util.Random

/** AccelPlatform (MandelbrotAccel and its clock crossings) with an AXI memory model as HPS memory
  * and a register driver on the bridge clock. Results are compared with AccelModel record by record.
  */
class AccelSim extends AnyFunSuite {
  val cfg = AccelConfig(nCores = 5, fracWidth = 12, siLatency = 6, nCtx = 4, doneDepth = 4, treeFanIn = 2)
  import AccelRegs._

  val base = 0xBF000000L

  test("jobs, refused job, abort, statistics, board status") {
    MandelbrotSpinalConfig.sim.workspaceName("Accel").compile(new AccelPlatform(cfg)).doSim(seed = 7) { dut =>
      val bridgeCd = ClockDomain(dut.io.bridgeClk, dut.io.bridgeRst)
      val coreCd   = ClockDomain(dut.io.coreClk, dut.io.coreRst)
      val bus      = dut.io.bus
      bus.read  #= false
      bus.write #= false
      dut.io.board.fpgaTemp  #= 41
      dut.io.board.boardTemp #= 30
      dut.io.board.fanRpm    #= 3600
      dut.io.board.ready     #= true
      bridgeCd.forkStimulus(100) // 100 MHz against 198 MHz, roughly
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
      def read64(addr: Int): BigInt = BigInt(read(addr)) | (BigInt(read(addr + 4)) << 32)
      def fix(v: Double) = BigInt(math.round(v * (1 << cfg.fracWidth)))
      def raw(v: BigInt) = (v & ((BigInt(1) << cfg.w) - 1)).toLong

      case class Job(id: Int, slot: Int, x0: BigInt, y0: BigInt, step: BigInt, width: Int, height: Int, maxIt: Long)
      def push(j: Job): Unit = {
        write(X0, raw(j.x0)); write(Y0, raw(j.y0)); write(STEP, raw(j.step))
        write(SIZE, (j.height.toLong << 16) | j.width)
        write(MAX_IT, j.maxIt); write(JOB_ID, j.id); write(RESULT_SLOT, j.slot)
        write(CONTROL, 1 | (1 << 8))
      }
      def waitDone(): (Int, Int, BigInt) = {
        var d = read(DONE)
        while ((d >> 31) == 0) { bridgeCd.waitSampling(20); d = read(DONE) }
        val it = read64(DONE_ITERATIONS)
        write(DONE, 0)
        ((d & 0xFFFF).toInt, ((d >> 16) & 3).toInt, it)
      }
      def record(slot: Int, i: Int): BigInt =
        (0 until 8).map(b => BigInt(mem.memory.read(base + slot * cfg.slotSize + 8L * i + b) & 0xFF) << (8 * b)).sum
      def check(j: Job, iterations: BigInt): Unit = {
        val want = AccelModel.tile(cfg, j.x0, j.y0, j.step, j.width, j.height, j.maxIt)
        for ((r, i) <- want.zipWithIndex) assert(record(j.slot, i) == r, s"job ${j.id} pixel $i")
        val wantIt = want.map(r => (r & 0xFFFFFFFFL).toLong).map(c => if (c == AccelModel.Unresolved) j.maxIt else c).sum
        assert(iterations == wantIt, s"job ${j.id} iterations")
      }

      assert(read(ID) == idValue)
      assert(read(CAPS) == ((cfg.nCtx.toLong << 24) | (cfg.intBits << 16) | (cfg.w << 8) | cfg.nCores))
      assert(read(ARITH_ID) == arithId(cfg))
      write(RESULT_BASE, base)
      write(RESULT_SLOTS, 8)
      assert(read(RESULT_BASE) == base)
      assert(read(QUEUE) == cfg.nCtx)

      // more jobs than contexts: the pushes beyond the free contexts are ignored, so wait for room
      val rnd  = new Random(3)
      val jobs = Seq(
        Job(11, 0, fix(-2.0), fix(1.2), fix(0.15), 21, 16, 60), // whole set
        Job(12, 1, fix(-0.8), fix(0.3), fix(0.01), 7, 5, 300), // near the boundary, deep
        Job(13, 2, fix(-15.9), fix(15.9), fix(4.0), 8, 8, 20), // far outside: escape at n = 1
        Job(14, 3, fix(-0.1), fix(0.1), fix(0.02), 3, 2, 0), // MAX_IT 0: nothing escapes
        Job(15, 4, fix(0.25), fix(0.0), fix(0.001), 1, 1, 1000), // one pixel
        Job(16, 5, fix(-1.5), fix(0.9), fix(0.07), 33, 3, 40),
        Job(17, 6, fix(-2.1), fix(-1.0), fix(0.2), 16, 1, 25)
      )
      var finished = Map[Int, (Int, BigInt)]()
      for (j <- jobs) {
        while ((read(QUEUE) & 0xFFFF) == 0) {
          val (id, st, it) = waitDone()
          finished += id -> (st, it)
        }
        push(j)
      }
      while (finished.size < jobs.size) {
        val (id, st, it) = waitDone()
        finished += id -> (st, it)
      }
      for (j <- jobs) {
        assert(finished(j.id)._1 == 0, s"job ${j.id} status")
        check(j, finished(j.id)._2)
      }
      assert((read(STATUS) & 3) == 0)

      // a refused job (slot out of range) and a bad size
      push(Job(21, 8, 0, 0, 1, 4, 4, 10))
      assert(waitDone()._1 == 21)
      push(Job(22, 0, 0, 0, 1, 257, 4, 10))
      val (id22, st22, _) = waitDone()
      assert(id22 == 22 && st22 == 2)

      // abort by id: a long job inside the set, and a queued one behind it
      push(Job(31, 0, fix(-0.3), fix(0.2), fix(0.01), 16, 16, 1000000))
      push(Job(32, 1, fix(-0.3), fix(0.2), fix(0.01), 16, 16, 1000000))
      bridgeCd.waitSampling(200)
      assert((read(DONE) >> 31) == 0)
      assert((read(STATUS) & 1) == 1)
      write(ABORT, 32)
      write(ABORT, 31)
      val aborted = Seq(waitDone(), waitDone())
      assert(aborted.map(_._1).toSet == Set(31, 32))
      assert(aborted.forall(_._2 == 1))
      assert((read(STATUS) & 3) == 0)
      write(CONTROL, 0) // IRQ off
      assert(!dut.io.irq.toBoolean)

      // abort a queued job while the job ahead of it keeps running: it is done at once
      push(Job(51, 0, fix(-0.3), fix(0.2), fix(0.01), 16, 16, 1000000))
      push(Job(52, 1, fix(-0.3), fix(0.2), fix(0.01), 16, 16, 1000000))
      push(Job(53, 2, fix(-1.9), fix(0.1), fix(0.01), 4, 4, 30)) // short, queued behind both
      bridgeCd.waitSampling(200)
      write(ABORT, 52)
      val q1 = waitDone()
      assert(q1._1 == 52 && q1._2 == 1)
      write(ABORT, 51)
      val rest = Seq(waitDone(), waitDone())
      assert(rest.map(r => r._1 -> r._2).toSet == Set(51 -> 1, 53 -> 0))
      check(Job(53, 2, fix(-1.9), fix(0.1), fix(0.01), 4, 4, 30), rest.find(_._1 == 53).get._3)

      // the result area can't change while jobs are held
      push(Job(41, 0, fix(-0.3), fix(0.2), fix(0.01), 4, 4, 1000000))
      write(RESULT_BASE, 0)
      assert(read(RESULT_BASE) == base)
      write(CONTROL, 2) // abort all
      assert(waitDone()._2 == 1)

      // statistics: pixels = every pixel issued; cycles count at the core clock
      val it0 = read64(TOTAL_ITERATIONS)
      val px  = read64(TOTAL_PIXELS)
      val cy  = read64(TOTAL_CYCLES)
      val wantPixels = jobs.map(j => j.width * j.height).sum
      assert(px >= wantPixels, s"pixels $px")
      assert(it0 >= finished.values.map(_._2).sum)
      assert(cy > 0)

      // board status
      assert(read(BOARD_TEMP) == ((30L << 16) | 41))
      assert(read(FAN_RPM) == ((1L << 31) | 3600))

      // f2sdram read test
      write(TEST_ADDR, base + 32)
      write(TEST_CTRL, 2)
      while ((read(TEST_CTRL) & 2) != 0) {}
      assert(read(TEST_RDATA) == (record(0, 4) & 0xFFFFFFFFL))
    }
  }
}
