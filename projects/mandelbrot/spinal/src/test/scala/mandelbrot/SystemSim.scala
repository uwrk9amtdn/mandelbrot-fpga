package mandelbrot

import fpgalib._

import org.scalatest.funsuite.AnyFunSuite
import spinal.core._
import spinal.core.sim._
import spinal.lib.bus.amba4.axi.sim._

import scala.collection.mutable

/** The whole board design minus vendor IP: UART commands in, framebuffer in an AXI memory model,
  * HDMI pixels out. Three unrelated clocks.
  *
  * Checks: the ADV7513 register writes on I2C, UART register reads/writes, the framebuffer
  * contents against RefModel, and every displayed pixel against ColorModel.
  */
class SystemSim extends AnyFunSuite {

  // Small but complete: 32x8 visible, 2 cores, one 256-bit beat per packet.
  val timing = VideoTiming(AxisTiming(32, 4, 4, 8, true), AxisTiming(8, 1, 2, 2, true))
  val cfg = SystemConfig(
    wrapper = WrapperConfig(xRes = 32, yRes = 8, fracWidth = 12, nCores = 2, arbiterTreeSans = 2,
      burstLength = 16, dataWidth = 256, siLatency = 8),
    timing = timing,
    coreHz = 8e6,
    uartBaud = 200000, // 40 core cycles per bit
    readerBurst = 4,
    readFifoDepth = 16,
    hdmiStartDelay = 20e-6,
    initialView = (-0.75, 0.0, 3.0, 30)
  )

  val corePeriod = 125 // ps units of the sim: arbitrary, only the ratios matter
  val memPeriod  = 70
  val pixPeriod  = 50

  test("render, display, UART control") {
    MandelbrotSpinalConfig.sim.workspaceName("System").compile(new MandelbrotSystem(cfg)).doSim(seed = 11) { dut =>
      val coreCd = ClockDomain(dut.io.coreClk, dut.io.coreRst)
      val memCd  = ClockDomain(dut.io.memClk, dut.io.memRst)
      val pixCd  = ClockDomain(dut.io.pixClk, dut.io.pixRst)

      dut.io.uart.rxd       #= true
      dut.io.hdmi.interrupt #= true
      dut.io.memCalibrated  #= false
      dut.io.renderKey      #= false
      dut.io.hdmi.scl.read  #= true
      dut.io.hdmi.sda.read  #= true

      coreCd.forkStimulus(corePeriod)
      pixCd.forkStimulus(pixPeriod)
      // memory clock: reset held for a while, like the EMIF before calibration
      memCd.forkStimulus(memPeriod)
      fork {
        memCd.waitSampling(30)
        memCd.assertReset()
        memCd.waitRisingEdge(500)
        memCd.deassertReset()
        dut.io.memCalibrated #= true
      }

      val axiMem = AxiMemorySim(dut.io.axi, memCd, AxiMemorySimConfig(readResponseDelay = 3, writeResponseDelay = 2))
      for (a <- 0 until 2 * timing.pixelsPerFrame) axiMem.memory.write(a.toLong, 0.toByte) // read before the first render
      axiMem.start()

      // ------------------------------------------------------------ ADV7513 model on I2C
      val i2cBytes = mutable.ArrayBuffer[Int]()
      val i2cWrites = mutable.ArrayBuffer[(Int, Int, Int)]()
      fork {
        var ackDrive = false
        var bits     = 0
        var byte     = 0
        var prevScl  = true
        var prevSda  = true
        while (true) {
          coreCd.waitSampling()
          val scl = !dut.io.hdmi.scl.drive.toBoolean
          val sda = !dut.io.hdmi.sda.drive.toBoolean && !ackDrive
          if (prevScl && scl && prevSda && !sda) { bits = 0; byte = 0; i2cBytes.clear() } // START
          if (prevScl && scl && !prevSda && sda) {                                          // STOP
            if (i2cBytes.size == 3) i2cWrites += ((i2cBytes(0), i2cBytes(1), i2cBytes(2)))
          }
          if (!prevScl && scl && bits < 8) { byte = (byte << 1) | (if (sda) 1 else 0); bits += 1 }
          else if (!prevScl && scl && bits == 8) bits = 9
          if (prevScl && !scl) {
            if (bits == 8) { ackDrive = true; i2cBytes += byte }
            else if (bits == 9) { ackDrive = false; bits = 0; byte = 0 }
          }
          dut.io.hdmi.sda.read #= sda
          dut.io.hdmi.scl.read #= scl
          prevScl = scl
          prevSda = sda
        }
      }

      // ------------------------------------------------------------ UART host
      val bitCycles = (cfg.coreHz / cfg.uartBaud).round.toInt
      val rxLine    = new StringBuilder
      val rxLines   = mutable.Queue[String]()
      fork { // receive from the FPGA
        while (true) {
          coreCd.waitSamplingWhere(!dut.io.uart.txd.toBoolean)
          coreCd.waitSampling(bitCycles / 2)
          var c = 0
          for (i <- 0 until 8) {
            coreCd.waitSampling(bitCycles)
            if (dut.io.uart.txd.toBoolean) c |= 1 << i
          }
          coreCd.waitSampling(bitCycles)
          assert(dut.io.uart.txd.toBoolean, "stop bit")
          if (c == '\n') { rxLines += rxLine.toString.stripSuffix("\r"); rxLine.clear() }
          else rxLine += c.toChar
        }
      }
      def send(s: String): Unit = for (c <- s) {
        val frame = Seq(false) ++ (0 until 8).map(i => ((c >> i) & 1) == 1) ++ Seq(true)
        for (b <- frame) { dut.io.uart.rxd #= b; coreCd.waitSampling(bitCycles) }
      }
      def command(s: String): String = {
        send(s + "\n")
        coreCd.waitSamplingWhere(rxLines.nonEmpty)
        rxLines.dequeue()
      }
      def write(addr: Int, data: Long): Unit = {
        val r = command(f"w ${addr}%x ${data & 0xffffffffL}%x")
        assert(r == "OK", s"write reply '$r'")
      }
      def read(addr: Int): Long = {
        val r = command(f"r $addr%02X")
        assert(r.matches("[0-9A-F]{8}"), s"read reply '$r'")
        java.lang.Long.parseLong(r, 16)
      }

      // ------------------------------------------------------------ display capture
      val frames = mutable.Queue[Seq[Int]]()
      fork {
        val cur      = mutable.ArrayBuffer[Int]()
        var prevVs   = false
        while (true) {
          pixCd.waitSampling()
          val vs = dut.io.hdmi.vsync.toBoolean
          if (vs && !prevVs) {
            if (cur.size == timing.pixelsPerFrame) frames += cur.toList
            cur.clear()
          }
          prevVs = vs
          if (dut.io.hdmi.de.toBoolean)
            cur += (dut.io.hdmi.r.toInt << 16) | (dut.io.hdmi.g.toInt << 8) | dut.io.hdmi.b.toInt
        }
      }

      // ------------------------------------------------------------ expected images
      val w = cfg.w
      val f = cfg.wrapper.fracWidth
      def iterationsOf(v: RefModel.View): Seq[Int] = {
        val addrs = Array.tabulate(cfg.wrapper.nCores)(i => cfg.wrapper.core(i).startAddr)
        val img   = Array.fill(timing.pixelsPerFrame)(-1)
        for ((a, words) <- RefModel.wrapperFrame(cfg.wrapper, v, addrs); (it, k) <- words.zipWithIndex)
          img((a / 2).toInt + k) = it
        assert(!img.contains(-1))
        img.toSeq
      }
      def framebuffer(): Seq[Int] =
        (0 until timing.pixelsPerFrame).map(i =>
          (axiMem.memory.read(2L * i) & 0xff) | ((axiMem.memory.read(2L * i + 1) & 0xff) << 8))
      def view(cx: Double, cy: Double, width: Double, maxIt: Int) =
        RefModel.View(RefModel.fix(cx, f), RefModel.fix(cy, f), RefModel.fix(width / cfg.wrapper.xRes, f), maxIt)

      /** Wait until the framebuffer holds `its`, then until two whole frames show it in `pal`. */
      def checkImage(its: Seq[Int], pal: ColorModel.Pal, what: String): Unit = {
        var tries = 0
        while (framebuffer() != its) {
          coreCd.waitSampling(1000)
          tries += 1
          assert(tries < 500, s"$what: framebuffer never matched")
        }
        val want = its.map(ColorModel.rgb(_, pal))
        frames.clear()
        pixCd.waitSamplingWhere(frames.size >= 3) // first one may have started before the last write
        frames.dequeue()
        for (fr <- frames) {
          val bad = fr.zip(want).indexWhere { case (a, b) => a != b }
          if (bad >= 0) fail(f"$what: pixel $bad shows ${fr(bad)}%06x, expected ${want(bad)}%06x")
        }
        println(s"[SystemSim] $what: ok")
      }

      // ------------------------------------------------------------ test sequence
      coreCd.waitSamplingWhere(i2cWrites.size >= Adv7513Setup.regs.size)
      assert(i2cWrites.toSeq == Adv7513Setup.regs.map { case (r, d) => (0x72, r, d) }, s"I2C writes: $i2cWrites")
      println("[SystemSim] ADV7513 setup: ok")

      assert(read(Regs.ID) == Regs.idValue)
      assert(read(Regs.X_RES) == 32 && read(Regs.Y_RES) == 8 && read(Regs.FRAC) == f)
      assert(command("x 1") == "?" && command("w 5") == "?" && command("r 1 2") == "?")
      assert((read(Regs.STATUS) & 0x7) == 0x3, "status: calibrated, HDMI done, no error")

      // the view rendered after reset
      val (cx, cy, wd, mi) = cfg.initialView
      checkImage(iterationsOf(view(cx, cy, wd, mi)), ColorModel.default, "initial view")
      assert(read(Regs.FRAMES) == 1)

      // a new view and palette over UART
      val v2 = view(-0.6, 0.4, 1.2, 60)
      write(Regs.CENTER_X, v2.centerX.toLong)
      write(Regs.CENTER_Y, v2.centerY.toLong)
      write(Regs.XY_STEP, v2.xyStep.toLong)
      write(Regs.MAX_IT, v2.maxIt)
      assert(read(Regs.CENTER_X) == (v2.centerX & 0xffffffffL), "sign-extended read back")
      val pal = ColorModel.Pal(1, twoColor = false, Seq(0x102030, 0xf0e0d0, 0x00ff80, 0x804000))
      write(Regs.CC_START, pal.startIndex)
      write(Regs.CC_TWO, 0)
      for (i <- 0 until 4) write(Regs.COLOR0 + i, pal.colors(i))
      write(Regs.CONTROL, 1)
      checkImage(iterationsOf(v2), pal, "view 2 over UART")

      // the board key renders again (same image)
      dut.io.renderKey #= true
      coreCd.waitSampling(10)
      dut.io.renderKey #= false
      var n = 0
      while (read(Regs.FRAMES) != 3) { n += 1; assert(n < 20, "key press didn't start a render") }

      assert((read(Regs.STATUS) & 0x18) == 0, "no underrun, nothing pending")
    }
  }
}
