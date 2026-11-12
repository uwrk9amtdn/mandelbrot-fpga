package mandelbrot

import fpgalib._

import spinal.core._
import spinal.lib._

/** A complex number / pixel coordinate in fixed point. */
case class Point(w: Int) extends Bundle {
  val x = SInt(w bits)
  val y = SInt(w bits)
}

object CoreState extends SpinalEnum {
  val LOAD, CALC, UNLOAD = newElement()
}

/** Iterates `siLatency` points at once through one SingleIteration pipeline (SV: core.sv).
  *
  * LOAD:   accept siLatency points (one per cycle) and push z0 = 0 for each into the pipeline.
  * CALC:   every cycle the slot at `ptr` gets its next z from the pipeline output;
  *         a slot is done when |z| >= 2 or the iteration count reaches maxIt.
  * UNLOAD: output the iteration counts in load order.
  *
  * The pipeline runs freely and is matched to slots by cycle count, so once LOAD has
  * started, `s.valid` must stay high for siLatency consecutive cycles (CoreWrapper does this).
  */
class Core(fracWidth: Int, siLatency: Int) extends Component {
  val w = fracWidth + 3
  val n = siLatency

  val io = new Bundle {
    val maxIt = in UInt (16 bits)
    val s     = slave Stream (Point(w))
    val m     = master Stream (UInt(16 bits))
  }

  val msi = new SingleIteration(fracWidth, siLatency)

  // FPGA: keep the small memories in LUTRAM (asynchronous read)
  private def distributed[T <: Data](mem: Mem[T]): Mem[T] = {
    mem.addAttribute("ram_style", "distributed")
    mem
  }
  val xMem    = distributed(Mem(SInt(w bits), n))
  val yMem    = distributed(Mem(SInt(w bits), n))
  val doneMem = distributed(Mem(Bool(), n))
  val iterMem = distributed(Mem(UInt(16 bits), n))

  val state     = RegInit(CoreState.LOAD)
  val ptr       = RegInit(U(0, log2Up(n) bits))
  val activeCnt = Reg(UInt(log2Up(n) + 1 bits))
  val iterCnt   = Reg(UInt(16 bits))

  val ptrLast = ptr === n - 1
  val ptrNext = Mux(ptrLast, U(0, ptr.getWidth bits), ptr + 1)

  val isLoad = state === CoreState.LOAD
  val isCalc = state === CoreState.CALC

  // Pipeline inputs. During LOAD, z0 = 0 and c comes straight from the input:
  // x/yMem[ptr] is only written at the end of this cycle.
  msi.io.sA := Mux(isLoad, S(0, w bits), msi.io.mA)
  msi.io.sB := Mux(isLoad, S(0, w bits), msi.io.mB)
  msi.io.sC := Mux(isLoad, io.s.payload.x, xMem.readAsync(ptr, writeFirst))
  msi.io.sD := Mux(isLoad, io.s.payload.y, yMem.readAsync(ptr, writeFirst))

  io.s.ready   := isLoad
  io.m.valid   := state === CoreState.UNLOAD
  io.m.payload := iterMem.readAsync(ptr, writeFirst)

  val done      = doneMem.readAsync(ptr, writeFirst)
  val finishing = isCalc && !done && (msi.io.mStop || iterCnt >= io.maxIt)

  xMem.write(ptr, io.s.payload.x, enable = isLoad && io.s.valid)
  yMem.write(ptr, io.s.payload.y, enable = isLoad && io.s.valid)
  doneMem.write(ptr, !isLoad, enable = isLoad || finishing) // LOAD: clear, CALC: set
  iterMem.write(ptr, iterCnt, enable = finishing)

  switch(state) {
    is(CoreState.LOAD) {
      iterCnt   := 1
      activeCnt := n
      when(io.s.valid) {
        ptr := ptrNext
        when(ptrLast)(state := CoreState.CALC)
      }
    }
    is(CoreState.CALC) {
      ptr := ptrNext
      when(ptrLast)(iterCnt := iterCnt + 1)
      when(finishing)(activeCnt := activeCnt - 1)
      when(activeCnt === 0) {
        ptr   := 0
        state := CoreState.UNLOAD
      }
    }
    is(CoreState.UNLOAD) {
      when(io.m.ready) {
        ptr := ptrNext
        when(ptrLast)(state := CoreState.LOAD)
      }
    }
  }
}
