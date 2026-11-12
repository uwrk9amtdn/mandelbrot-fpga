package mandelbrot

import fpgalib._

import spinal.core._
import spinal.lib._

/** Frame request: top-left point, distance between pixels, iteration limit. */
case class FrameCmd(w: Int) extends Bundle {
  val xStart = SInt(w bits)
  val yStart = SInt(w bits)
  val xyStep = SInt(w bits)
  val maxIt  = UInt(16 bits)
}

object PixelState extends SpinalEnum {
  val READY, CALC = newElement()
}

object OutState extends SpinalEnum {
  val LOAD, ADDR1, ADDR2, UNLOAD = newElement()
}

/** Computes one frame per command with one Core (SV: core_wrapper.sv).
  *
  * Input:  one FrameCmd per frame. Pixels go left to right (x += step) and
  *         top to bottom (y -= step).
  * Output: one packet per `n` pixels: addr[31:16], addr[15:0], then n
  *         iteration counts, `last` on the final one. addr starts at startAddr,
  *         advances by 2n bytes per packet and wraps after a frame.
  *
  * As a top level, port names match the SV module: clk, rst, s_*, m_*.
  */
class CoreWrapper(val cfg: MandelbrotConfig) extends Component with SvClockNames {
  import cfg._

  val io = new Bundle {
    val s = slave Stream (FrameCmd(dataWidth))
    val m = master Stream (Fragment(Bits(16 bits)))
  }
  noIoPrefix()

  io.s.valid.setName("s_valid")
  io.s.ready.setName("s_ready")
  io.s.payload.xStart.setName("s_x_start")
  io.s.payload.yStart.setName("s_y_start")
  io.s.payload.xyStep.setName("s_xy_step")
  io.s.payload.maxIt.setName("s_max_it")
  io.m.valid.setName("m_valid")
  io.m.ready.setName("m_ready")
  io.m.payload.fragment.setName("m_data")
  io.m.payload.last.setName("m_last")

  val core = new Core(fracWidth, siLatency)

  // ---------------------------------------------------------------- pixel generator
  val pixelState = RegInit(PixelState.READY)
  val xStart     = Reg(SInt(dataWidth bits))
  val xyStep     = Reg(SInt(dataWidth bits))
  val maxIt      = Reg(UInt(16 bits))
  val x, y       = Reg(SInt(dataWidth bits))
  val xCtr       = Reg(UInt(log2Up(xRes) bits))
  val yCtr       = Reg(UInt(log2Up(yRes) bits))

  io.s.ready    := pixelState === PixelState.READY
  core.io.maxIt := maxIt

  when(io.s.fire) {
    xStart     := io.s.xStart
    x          := io.s.xStart
    y          := io.s.yStart
    maxIt      := io.s.maxIt
    xyStep     := io.s.xyStep
    xCtr       := 0
    yCtr       := 0
    pixelState := PixelState.CALC
  }

  val pixels = Stream(Point(dataWidth))
  pixels.valid     := pixelState === PixelState.CALC
  pixels.payload.x := x
  pixels.payload.y := y

  when(pixels.fire) {
    when(xCtr === xRes - 1) {
      xCtr := 0
      x    := xStart
      y    := y - xyStep
      when(yCtr === yRes - 1) {
        yCtr       := 0
        pixelState := PixelState.READY
      } otherwise {
        yCtr := yCtr + 1
      }
    } otherwise {
      xCtr := xCtr + 1
      x    := x + xyStep
    }
  }

  // Register stage between generator and core (SV: core_s_valid/x/y registers)
  core.io.s << pixels.m2sPipe()

  // ---------------------------------------------------------------- output packets
  val outState = RegInit(OutState.LOAD)
  val ptr      = RegInit(U(0, log2Up(n) bits))
  val addr     = RegInit(U(startAddr, 32 bits))
  val buffer   = Mem(Bits(16 bits), n)
  buffer.addAttribute("ram_style", "distributed")

  val ptrLast = ptr === n - 1
  val ptrNext = Mux(ptrLast, U(0, ptr.getWidth bits), ptr + 1)

  core.io.m.ready := outState === OutState.LOAD

  when(core.io.m.fire) {
    buffer.write(ptr, core.io.m.payload.asBits)
    ptr := ptrNext
    when(ptrLast)(outState := OutState.ADDR1)
  }

  val words = Stream(Fragment(Bits(16 bits)))
  words.valid            := outState =/= OutState.LOAD
  words.payload.fragment := buffer.readAsync(ptr, writeFirst)
  words.payload.last     := False

  switch(outState) {
    is(OutState.ADDR1) {
      words.payload.fragment := addr(31 downto 16).asBits
      when(words.fire)(outState := OutState.ADDR2)
    }
    is(OutState.ADDR2) {
      words.payload.fragment := addr(15 downto 0).asBits
      when(words.fire) {
        outState := OutState.UNLOAD
        addr     := Mux(addr === lastAddr, U(startAddr, 32 bits), addr + 2 * n)
      }
    }
    is(OutState.UNLOAD) {
      words.payload.last := ptrLast
      when(words.fire) {
        ptr := ptrNext
        when(ptrLast)(outState := OutState.LOAD)
      }
    }
    default {}
  }

  // Register stage on the output (SV: m.valid/data/last registers)
  io.m << words.m2sPipe()
}
