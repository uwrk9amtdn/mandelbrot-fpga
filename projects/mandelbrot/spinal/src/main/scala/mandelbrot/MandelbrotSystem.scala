package mandelbrot

import fpgalib._

import spinal.core._
import spinal.lib._
import spinal.lib.bus.amba4.axi._
import spinal.lib.com.uart._

/** Everything of the board design that isn't vendor IP (SV: top.sv without the clock, MIG and VIO
  * blocks). Board-independent; simulated as a whole by SystemSim.
  *
  * @param coreHz      core clock frequency (UART baud rate, I2C speed, LED blink)
  * @param readerBurst AXI beats per read burst of the display path
  */
case class SystemConfig(
    wrapper: WrapperConfig = WrapperConfig(fracWidth = 16, nCores = 60, arbiterTreeSans = 5, burstLength = 32,
      dataWidth = 256), // 60 x 3 19x19 multipliers of the 188 DSP blocks
    timing: VideoTiming = VideoTiming.p1080,
    axi: Axi4Config = MemoryAxi.emifConfig,
    coreHz: Double = 198e6, // 1188 MHz VCO / 6; the pixel clock is / 8
    readerBurst: Int = 16,
    uartBaud: Int = 115200,
    hdmiStartDelay: Double = 10e-3,
    readFifoDepth: Int = 512,
    initialView: (Double, Double, Double, Int) = (-0.5, 0.0, 3.0, 100) // centre x, y, width, max_it
) {
  require(wrapper.xRes == timing.h.active && wrapper.yRes == timing.v.active, "resolution mismatch")
  require(wrapper.dataWidth == axi.dataWidth, "Wrapper dataWidth must equal the AXI data width")
  val w = wrapper.w
}

/** Register map of the UART interface. See README / tools/mandelbrot_ctl.py. */
object Regs {
  val ID        = 0x00 // RO 'MAND'
  val STATUS    = 0x01 // RO see SystemStatus
  val CONTROL   = 0x02 // WO bit 0: render the current view
  val CENTER_X  = 0x03 // RW signed fixed point, fracWidth fraction bits
  val CENTER_Y  = 0x04 // RW
  val XY_STEP   = 0x05 // RW distance between pixels
  val MAX_IT    = 0x06 // RW 16 bits
  val CC_START  = 0x07 // RW palette start index (4 bits)
  val CC_TWO    = 0x08 // RW two-color palette (1 bit)
  val COLOR0    = 0x09 // RW 0xRRGGBB, COLOR0..COLOR3 = 0x09..0x0C
  val X_RES     = 0x10 // RO
  val Y_RES     = 0x11 // RO
  val FRAC      = 0x12 // RO fracWidth
  val FRAMES    = 0x13 // RO renders started since reset

  val idValue = 0x4d414e44L // "MAND"
}

class MandelbrotSystem(val cfg: SystemConfig) extends Component {
  import cfg._

  val io = new Bundle {
    val coreClk, coreRst = in Bool ()
    val memClk, memRst   = in Bool () // memRst: until the EMIF is ready
    val pixClk, pixRst   = in Bool ()

    val axi = master(Axi4(cfg.axi))

    val uart = master(Uart())
    val hdmi = new Bundle {
      val r, g, b          = out Bits (8 bits)
      val hsync, vsync, de = out Bool ()
      val scl, sda         = master(OpenDrain())
      val interrupt        = in Bool () // active low, asynchronous
    }

    val memCalibrated = in Bool () // asynchronous
    val renderKey     = in Bool () // asynchronous, true = pressed
    val leds          = out Bits (8 bits) // true = on
  }

  val coreCd = ClockDomain(io.coreClk, io.coreRst)
  val memCd  = ClockDomain(io.memClk, io.memRst)
  val pixCd  = ClockDomain(io.pixClk, io.pixRst)

  // ================================================================== pixel clock: video output
  val pix = new ClockingArea(pixCd) {
    val driver = new DisplayDriver(timing)

    // Frame pipeline reset during vertical sync (SV: rst = vsync), so every frame starts aligned.
    val inVSync = RegNext(driver.io.inVSync) init (True)
    val frameCd = ClockDomain(io.pixClk, io.pixRst || inVSync)

    val palette = Reg(Palette()) init (Palette.default) // loaded from the core clock domain below

    // Underrun: a pixel was due but none was there. Reported per frame.
    val underrunNow       = Bool()
    val underrunThisFrame = RegInit(False) setWhen (underrunNow)
    val underrunLastFrame = RegInit(False)
    when(driver.io.inVSync && !inVSync) {
      underrunLastFrame := underrunThisFrame
      underrunThisFrame := False
    }

    // Registered outputs: all video signals see the same one-cycle delay.
    io.hdmi.r     := RegNext(driver.io.r)
    io.hdmi.g     := RegNext(driver.io.g)
    io.hdmi.b     := RegNext(driver.io.b)
    io.hdmi.hsync := RegNext(driver.io.hsync)
    io.hdmi.vsync := RegNext(driver.io.vsync)
    io.hdmi.de    := RegNext(driver.io.de) init (False)
  }

  // ================================================================== memory clock: display reads
  val mem = new ClockingArea(memCd) {
    val vsync   = BufferCC(pix.inVSync, init = True, bufferDepth = 4)
    val vsyncD1 = RegNext(vsync) init (True)
    val start   = RegNext(vsyncD1 && !vsync) init (False) // end of vertical sync

    val frameCd = ClockDomain(io.memClk, io.memRst || vsync)
    val reader = frameCd(new MemoryReader(cfg.axi, wrapper.fbStartAddr, timing.pixelsPerFrame, readerBurst))
    reader.io.start := start
  }

  // Read data: memory clock -> pixel clock, 256 bits -> 16-bit iteration counts -> RGB
  val readFifo = StreamFifoCC(Bits(cfg.axi.dataWidth bits), readFifoDepth, mem.frameCd, pix.frameCd)
  readFifo.io.push << mem.reader.io.beats

  val pixFrame = new ClockingArea(pix.frameCd) {
    val counts = Stream(Bits(16 bits))
    StreamWidthAdapter(readFifo.io.pop, counts, LITTLE) // first pixel in the low bits

    val cc = new ColorConverter
    cc.io.palette := pix.palette
    cc.io.s << counts.map(_.asUInt)

    pix.driver.io.rgb := cc.io.m.payload
    cc.io.m.ready     := pix.driver.io.de
  }
  pix.underrunNow := pix.driver.io.de && !pixFrame.cc.io.m.valid

  // ================================================================== core clock: control + compute
  val core = new ClockingArea(coreCd) {
    val ctl = new UartControl(coreHz, uartBaud)
    io.uart <> ctl.io.uart

    val hdmiInterrupt = BufferCC(io.hdmi.interrupt, init = True)
    val memCalibrated = BufferCC(io.memCalibrated, init = False)
    val underrun      = BufferCC(pix.underrunLastFrame, init = False)
    val renderKey     = BufferCC(io.renderKey, init = False)

    val hdmiSetup = new Adv7513Setup(coreHz, hdmiStartDelay)
    hdmiSetup.io.interrupt := hdmiInterrupt
    io.hdmi.scl <> hdmiSetup.io.scl
    io.hdmi.sda <> hdmiSetup.io.sda

    // ---------------------------------------------------------------- registers
    val f = wrapper.fracWidth
    def fix(v: Double) = S(BigInt(scala.math.round(v * (1L << f))), w bits)
    val (cx, cy, width, it) = initialView

    val centerX = RegInit(fix(cx))
    val centerY = RegInit(fix(cy))
    val xyStep  = RegInit(fix(width / wrapper.xRes))
    val maxIt   = RegInit(U(it, 16 bits))
    val palette = Reg(Palette()) init (Palette.default)
    val frames  = Reg(UInt(32 bits)) init (0)

    // Render requests: one after reset, on CONTROL bit 0, and on the board key.
    val renderPending = RegInit(True)
    when(renderKey.rise(False)) { renderPending := True }

    val wr = ctl.io.write
    when(wr.valid) {
      val d = wr.data
      switch(wr.address) {
        is(Regs.CONTROL)  { when(d(0)) { renderPending := True } }
        is(Regs.CENTER_X) { centerX := d.asSInt.resize(w) }
        is(Regs.CENTER_Y) { centerY := d.asSInt.resize(w) }
        is(Regs.XY_STEP)  { xyStep := d.asSInt.resize(w) }
        is(Regs.MAX_IT)   { maxIt := d.asUInt.resize(16) }
        is(Regs.CC_START) { palette.startIndex := d.asUInt.resize(4) }
        is(Regs.CC_TWO)   { palette.twoColor := d(0) }
        for (i <- 0 until 4) is(Regs.COLOR0 + i) { palette.colors(i) := d(23 downto 0) }
      }
    }

    val status = B(0, 27 bits) ## renderPending ## underrun ## hdmiSetup.io.error ## hdmiSetup.io.done ## memCalibrated
    val rd = Bits(32 bits)
    rd := 0
    switch(ctl.io.readAddr) {
      is(Regs.ID)       { rd := B(Regs.idValue, 32 bits) }
      is(Regs.STATUS)   { rd := status }
      is(Regs.CENTER_X) { rd := centerX.resize(32).asBits }
      is(Regs.CENTER_Y) { rd := centerY.resize(32).asBits }
      is(Regs.XY_STEP)  { rd := xyStep.resize(32).asBits }
      is(Regs.MAX_IT)   { rd := maxIt.resize(32).asBits }
      is(Regs.CC_START) { rd := palette.startIndex.resize(32).asBits }
      is(Regs.CC_TWO)   { rd := palette.twoColor.asBits.resize(32) }
      for (i <- 0 until 4) is(Regs.COLOR0 + i) { rd := palette.colors(i).resize(32) }
      is(Regs.X_RES)    { rd := B(wrapper.xRes, 32 bits) }
      is(Regs.Y_RES)    { rd := B(wrapper.yRes, 32 bits) }
      is(Regs.FRAC)     { rd := B(f, 32 bits) }
      is(Regs.FRAMES)   { rd := frames.asBits }
    }
    ctl.io.readData := rd

    // Palette to the pixel clock domain, re-sent continuously (it changes rarely).
    val paletteFlow = Flow(Palette())
    paletteFlow.valid   := CounterFreeRun(64).willOverflow
    paletteFlow.payload := palette

    // ---------------------------------------------------------------- compute engine
    val engine = new Wrapper(wrapper)
    engine.io.s.valid   := renderPending
    engine.io.s.centerX := centerX
    engine.io.s.centerY := centerY
    engine.io.s.xyStep  := xyStep
    engine.io.s.maxIt   := maxIt
    when(engine.io.s.fire) {
      renderPending := False
      frames        := frames + 1
    }

    // ---------------------------------------------------------------- LEDs
    val blink = Reg(Bool()) init (False)
    val blinkCounter = CounterFreeRun((coreHz / 2).toLong max 2)
    when(blinkCounter.willOverflow) { blink := !blink }
    io.leds := blink ## B"000" ## renderPending ## underrun ## hdmiSetup.io.error ## (memCalibrated && hdmiSetup.io.done)
  }

  val paletteCC = FlowCCByToggle(core.paletteFlow, coreCd, pixCd)
  when(paletteCC.valid) { pix.palette := paletteCC.payload }

  // Engine results: core clock -> memory clock -> AXI writes
  val addrFifo = StreamFifoCC(UInt(32 bits), 16, coreCd, memCd)
  val dataFifo = StreamFifoCC(Fragment(Bits(cfg.axi.dataWidth bits)), 32, coreCd, memCd)
  addrFifo.io.push << core.engine.io.mAddr
  dataFifo.io.push << core.engine.io.mData

  val memWrite = new ClockingArea(memCd) {
    val writer = new MemoryWriter(cfg.axi, wrapper.burstLength * 16 / cfg.axi.dataWidth)
    writer.io.addr << addrFifo.io.pop
    writer.io.data << dataFifo.io.pop
  }

  // One AXI port: reads from the display path, writes from the engine
  io.axi.ar << mem.reader.io.axi.ar
  io.axi.r >> mem.reader.io.axi.r
  io.axi.aw << memWrite.writer.io.axi.aw
  io.axi.w << memWrite.writer.io.axi.w
  io.axi.b >> memWrite.writer.io.axi.b
}
