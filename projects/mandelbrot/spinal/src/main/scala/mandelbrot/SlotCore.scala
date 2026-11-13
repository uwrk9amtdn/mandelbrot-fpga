package mandelbrot

import fpgalib._

import spinal.core._
import spinal.lib._

/** Configuration of MandelbrotAccel and its cores (ROADMAP.md, phase 1).
  *
  * Coordinates are signed fixed point with `intBits` integer bits (sign included) and `fracWidth`
  * fraction bits. The bailout is |z|² >= 4. With 5 integer bits, z_n = z_(n-1)² + c can't overflow
  * before the bailout is seen: |c| < 2 gives |z_n| < 6, and any other c escapes at n = 1.
  */
case class AccelConfig(
    nCores: Int = 60,
    intBits: Int = 5,
    fracWidth: Int = 16,
    siLatency: Int = 8, // pipeline depth of one iteration = pixels in flight per core
    nCtx: Int = 8, // jobs held by the accelerator, queued or running (the job queue)
    doneDepth: Int = 16,
    treeFanIn: Int = 4 // fan-out / fan-in of the pixel and result trees
) {
  require(intBits >= 5, "fewer than 5 integer bits overflow before the bailout")
  require(siLatency >= 4 && nCtx >= 1 && isPow2(nCtx) && nCores >= 1)
  val w        = intBits + fracWidth
  val idxBits  = 16 // pixel index in a tile of at most 256 x 256
  val ctxBits  = log2Up(nCtx) max 1
  val tagBits  = ctxBits + idxBits
  val slotSize = 512 << 10 // bytes per result slot: 256 x 256 records of 8 bytes

  /** |z|² is reported as unsigned fixed point with 22 fraction bits (at most 512, so 32 bits). */
  val magFrac = 22
}

/** A pixel on its way into a core. */
case class CorePixel(cfg: AccelConfig) extends Bundle {
  val x, y = SInt(cfg.w bits)
  val tag  = Bits(cfg.tagBits bits) // job context (high bits) and pixel index
  def ctx  = tag(cfg.tagBits - 1 downto cfg.idxBits).asUInt
}

/** A finished pixel. */
case class CoreResult(cfg: AccelConfig) extends Bundle {
  val tag     = Bits(cfg.tagBits bits)
  val count   = UInt(32 bits) // n of the z_n that escaped, or MAX_IT when none did
  val mag     = UInt(32 bits) // |z_n|² at escape (cfg.magFrac fraction bits), else 0
  val escaped = Bool()
  val dropped = Bool() // the job was aborted: no result
  def ctx     = tag(cfg.tagBits - 1 downto cfg.idxBits).asUInt
  def idx     = tag(cfg.idxBits - 1 downto 0).asUInt
}

/** One iteration z' = z² + c, fully pipelined, `siLatency` cycles. Also reports |z|² of the INPUT z
  * and whether it reached the bailout.
  */
class EscapeIteration(cfg: AccelConfig) extends Component {
  import cfg._
  val mulLatency = siLatency - 2
  val f          = fracWidth

  val io = new Bundle {
    val sA, sB, sC, sD = in SInt (w bits)
    val mA, mB         = out SInt (w bits)
    val mStop          = out Bool ()
    val mMag           = out UInt (32 bits)
  }

  private def mul(name: String, x: SInt, y: SInt): SInt = {
    val m = new MulPipe(w, mulLatency, signed = true).setName(name)
    m.io.a := x.asBits
    m.io.b := y.asBits
    m.io.q.asSInt
  }
  val a2 = mul("m0", io.sA, io.sA)
  val b2 = mul("m1", io.sB, io.sB)
  val ab = mul("m2", io.sA, io.sB)

  val c = Delay(io.sC, mulLatency + 1)
  val d = Delay(io.sD, mulLatency + 1)

  // Stage 1: full precision, 2F fraction bits
  val sum      = RegNext((a2.resize(2 * w + 1) + b2.resize(2 * w + 1)).asUInt) // never negative
  val diff     = RegNext(a2.resize(2 * w + 1) - b2.resize(2 * w + 1))
  val abTimes2 = RegNext(ab << 1)

  // Stage 2: back to F fraction bits (truncating), add c
  io.mA    := RegNext(diff(f + w - 1 downto f) + c)
  io.mB    := RegNext(abTimes2(f + w - 1 downto f) + d)
  io.mStop := RegNext(sum(2 * w downto 2 * f + 2).orR) // >= 4
  val magFixed = if (2 * f >= magFrac) sum >> (2 * f - magFrac) else sum << (magFrac - 2 * f)
  io.mMag := RegNext(magFixed.resize(32 bits))
}

/** Iterates up to `siLatency` pixels at once through one EscapeIteration pipeline. Every pipeline
  * slot works on its own pixel: when a pixel finishes, its slot hands over the result and takes the
  * next pixel in the same cycle, whatever the other slots are doing.
  *
  * A pixel's count is the smallest n >= 1 with |z_n|² >= 4 (z_0 = 0, z_n = z_(n-1)² + c). If there
  * is none up to the job's MAX_IT, the pixel is reported as not escaped. A pixel uses the pipeline
  * count + 1 times, because the bailout of z_n is seen one pass later.
  *
  * `maxIt` and `abort` are per job context; a pixel names its context in its tag. Pixels of an
  * aborted context finish at once, flagged `dropped`.
  */
class SlotCore(cfg: AccelConfig) extends Component {
  import cfg._
  val n = siLatency

  val io = new Bundle {
    val maxIt     = in Vec (UInt(32 bits), nCtx)
    val abort     = in Bits (nCtx bits)
    val s         = slave Stream (CorePixel(cfg))
    val m         = master Stream (CoreResult(cfg))
    val iterating = out Bool () // this cycle starts a real iteration (for the statistics)
  }

  val it = new EscapeIteration(cfg)

  private def lutram[T <: Data](t: HardType[T]): Mem[T] = {
    val m = Mem(t, n)
    m.addAttribute("ram_style", "distributed")
    m
  }
  val xMem, yMem = lutram(SInt(w bits))
  val tagMem     = lutram(Bits(tagBits bits))
  val jMem       = lutram(UInt(32 bits)) // n of the z_n whose bailout is at the pipeline output
  val limMem     = lutram(Bool()) // j has reached MAX_IT
  val magMem     = lutram(UInt(32 bits)) // result of a slot that waits for the output
  val escMem     = lutram(Bool())

  val busy, waiting = Reg(Bits(n bits)) init (0)

  // The slot whose z is at the pipeline output now; what goes in now comes back in n cycles.
  val ptr = Reg(UInt(log2Up(n) bits)) init (0)
  ptr := Mux(ptr === n - 1, U(0), ptr + 1)

  val tag     = tagMem.readAsync(ptr, writeFirst)
  val ctx     = tag(tagBits - 1 downto idxBits).asUInt
  val j       = jMem.readAsync(ptr, writeFirst)
  val aborted = io.abort(ctx)
  val isWait  = busy(ptr) && waiting(ptr)
  val running = busy(ptr) && !waiting(ptr)
  val stop    = it.io.mStop
  val finish  = running && (stop || limMem.readAsync(ptr, writeFirst) || aborted)
  val cont    = running && !finish

  val res = Stream(CoreResult(cfg))
  res.valid   := finish || isWait
  res.tag     := tag
  res.count   := j
  res.dropped := aborted
  when(isWait) {
    res.mag     := magMem.readAsync(ptr, writeFirst)
    res.escaped := escMem.readAsync(ptr, writeFirst)
  } otherwise {
    res.mag     := Mux(stop, it.io.mMag, U(0))
    res.escaped := stop
  }
  io.m << res.m2sPipe()

  val freed = res.fire
  io.s.ready := !busy(ptr) || freed
  val load = io.s.fire

  it.io.sA := Mux(cont, it.io.mA, S(0))
  it.io.sB := Mux(cont, it.io.mB, S(0))
  it.io.sC := Mux(load, io.s.x, xMem.readAsync(ptr, writeFirst))
  it.io.sD := Mux(load, io.s.y, yMem.readAsync(ptr, writeFirst))
  io.iterating := cont || load

  xMem.write(ptr, io.s.x, enable = load)
  yMem.write(ptr, io.s.y, enable = load)
  tagMem.write(ptr, io.s.tag, enable = load)

  val jNext = j + 1
  jMem.write(ptr, Mux(load, U(0), jNext), enable = load || cont)
  limMem.write(ptr, Mux(load, io.maxIt(io.s.ctx) === 0, jNext === io.maxIt(ctx)), enable = load || cont)

  // A finished pixel that can't leave keeps its result in the slot.
  val park = finish && !res.ready
  magMem.write(ptr, res.mag, enable = park)
  escMem.write(ptr, res.escaped, enable = park)

  when(load) {
    busy(ptr)    := True
    waiting(ptr) := False
  } elsewhen (freed) {
    busy(ptr)    := False
    waiting(ptr) := False
  } elsewhen (park) {
    waiting(ptr) := True
  }
}
