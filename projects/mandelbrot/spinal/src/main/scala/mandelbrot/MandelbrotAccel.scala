package mandelbrot

import fpgalib._

import spinal.core._
import spinal.lib._
import spinal.lib.bus.amba4.axi._
import spinal.lib.bus.avalon._

/** Register map of MandelbrotAccel (ROADMAP.md, "Register slave"). Byte offsets on lwhps2fpga.
  * Registers that are not plain storage (CONTROL, ABORT, DONE, RESULT_*) take whole 32-bit writes.
  */
object AccelRegs {
  val addressWidth = 12 // 4 KB
  def busConfig    = AvalonMMSlaveFactory.getAvalonConfig(addressWidth, 32, useByteEnable = true)

  val idValue = BigInt(0x4D414E44L) // 'MAND'
  val version = 1

  val ID               = 0x000
  val VERSION          = 0x004
  val CAPS             = 0x008 // 7:0 nCores, 15:8 W, 20:16 I, 31:24 job contexts (the queue depth)
  val ARITH_ID         = 0x00C
  val CONTROL          = 0x010 // bit 0 push the job, bit 1 abort all, bit 8 IRQ enable (every write sets it)
  val STATUS           = 0x014 // bit 0 busy, bit 1 DONE FIFO not empty (the interrupt)
  val ABORT            = 0x018 // write a job id
  val QUEUE            = 0x01C // 15:0 free job contexts, 31:16 entries in the DONE FIFO
  val X0               = 0x020 // 4 words each, low word first
  val Y0               = 0x030
  val STEP             = 0x040
  val SIZE             = 0x050 // 15:0 width, 31:16 height, 1..256 each
  val MAX_IT           = 0x054
  val FLAGS            = 0x058 // nothing implemented yet
  val JOB_ID           = 0x05C
  val RESULT_BASE      = 0x060 // 64 bits; only the low 32 are used (the high word must be 0)
  val RESULT_SLOTS     = 0x068
  val RESULT_SLOT      = 0x06C
  val DONE             = 0x070 // bit 31 valid, 17:16 status (0 complete, 1 aborted, 2 error), 15:0 job id
  val DONE_ITERATIONS  = 0x074 // 64 bits
  val TOTAL_ITERATIONS = 0x080 // 64 bits each; reading this low word latches all three
  val TOTAL_CYCLES     = 0x088
  val TOTAL_PIXELS     = 0x090
  val BOARD_TEMP       = 0x098 // 15:0 FPGA, 31:16 board, signed °C
  val FAN_RPM          = 0x09C // 15:0 RPM, bit 31 readings valid

  // Bring-up test of f2sdram reads, not part of the register map.
  val TEST_ADDR  = 0xF00 // address of the 32-byte beat (a multiple of 32)
  val TEST_CTRL  = 0xF08 // write bit 1: read the beat. Read: bit 1 busy, bits 11:10 read response
  val TEST_RDATA = 0xF20 // 8 words: the beat that was read

  /** Identifies everything that changes result bits (PC_APP_PLAN.md, "Arithmetic id"). */
  def arithId(cfg: AccelConfig): Long = {
    val crc = new java.util.zip.CRC32
    crc.update(s"fpga-slotcore|w=${cfg.w}|i=${cfg.intBits}|f=${cfg.fracWidth}|r2=4|records-v1".getBytes("UTF-8"))
    crc.getValue
  }
}

case class BoardStatus() extends Bundle {
  val fpgaTemp, boardTemp = SInt(16 bits) // °C
  val fanRpm              = UInt(16 bits)
  val ready               = Bool() // the readings are valid
}

case class AccelJob(cfg: AccelConfig) extends Bundle {
  val x0, y0, step  = SInt(cfg.w bits)
  val width, height = UInt(9 bits) // 1..256
  val maxIt         = UInt(32 bits)
  val jobId         = UInt(16 bits)
  val base          = UInt(32 bits) // address of the job's result slot
}

case class DoneEntry() extends Bundle {
  val status     = UInt(2 bits)
  val jobId      = UInt(16 bits)
  val iterations = UInt(64 bits)
}

/** The accelerator (ROADMAP.md, phase 1): job contexts, pixel issuer, per-slot cores, result
  * writer. Everything runs in one clock domain (the core clock); AccelPlatform crosses the bus and
  * the AXI port to the bridge clock.
  *
  * Jobs: a push copies the job registers into a free context (there are cfg.nCtx; together they
  * are the job queue). The issuer takes the contexts in push order and walks each tile, one pixel
  * per cycle. Pixels go to any core with a free pipeline slot, so the next job's pixels fill the
  * cores while the slow pixels of the previous ones finish. A context is done, and reported in the
  * DONE FIFO, when every record it issued has been written and acknowledged on AXI.
  *
  * Results: one 64-bit record per pixel at base + 8 * (row * width + col): the u32 count in the
  * low half (0xFFFFFFFF if the pixel did not escape), the f32 |z|² at escape in the high half
  * (truncated, 0 if it did not escape). Each record is one AXI write of one beat, with strobes.
  */
class MandelbrotAccel(cfg: AccelConfig) extends Component {
  import cfg._
  import AccelRegs._

  val io = new Bundle {
    val bus   = slave(AvalonMM(busConfig))
    val axi   = master(Axi4(HpsAxi.f2sdramConfig))
    val irq   = out Bool ()
    val busy  = out Bool () // a job is held
    val board = in(BoardStatus())
  }
  require(io.axi.config.idWidth >= ctxBits)

  val f     = AvalonMMSlaveFactory(io.bus)
  val wdata = Bits(32 bits)
  f.nonStopWrite(wdata, 0)

  // ---------------------------------------------------------------------------------- contexts
  val ctxs = for (i <- 0 until nCtx) yield new Area {
    val valid                      = RegInit(False)
    val job                        = Reg(AccelJob(cfg))
    val aborted, error, issueDone  = Reg(Bool()) init (False)
    val issued, acked, skipped     = Reg(UInt(17 bits)) init (0)
    val iterations                 = Reg(UInt(64 bits)) init (0)
    val complete = RegNext(valid && issueDone && acked + skipped === issued) init (False)
  }
  val validBits = ctxs.map(_.valid).asBits
  val busy      = validBits.orR
  io.busy      := busy
  val jobs      = Vec(ctxs.map(_.job))

  // ---------------------------------------------------------------------------------- job registers
  val nWords = (w + 31) / 32
  def coordinate(base: Int): SInt = {
    val words = (0 until 4).map(i => f.createReadAndWrite(Bits(32 bits), base + 4 * i) init (0))
    words.take(nWords).reverse.reduce(_ ## _)(w - 1 downto 0).asSInt
  }
  val stX0    = coordinate(X0)
  val stY0    = coordinate(Y0)
  val stStep  = coordinate(STEP)
  val stSize  = f.createReadAndWrite(Bits(32 bits), SIZE) init (0)
  val stMaxIt = f.createReadAndWrite(UInt(32 bits), MAX_IT) init (0)
  val stFlags = f.createReadAndWrite(Bits(32 bits), FLAGS) init (0)
  val stJobId = f.createReadAndWrite(UInt(16 bits), JOB_ID) init (0)
  val stSlot  = f.createReadAndWrite(UInt(32 bits), RESULT_SLOT) init (0)

  // The result area can't change while jobs are held.
  val resultBase  = Reg(UInt(64 bits)) init (0)
  val resultSlots = Reg(UInt(32 bits)) init (0)
  f.read(resultBase(31 downto 0), RESULT_BASE)
  f.read(resultBase(63 downto 32), RESULT_BASE + 4)
  f.read(resultSlots, RESULT_SLOTS)
  val baseLoWrite  = f.isWriting(RESULT_BASE)
  val baseHiWrite  = f.isWriting(RESULT_BASE + 4)
  val slotsWrite   = f.isWriting(RESULT_SLOTS)
  when(!busy) {
    when(baseLoWrite)(resultBase(31 downto 0) := wdata.asUInt)
    when(baseHiWrite)(resultBase(63 downto 32) := wdata.asUInt)
    when(slotsWrite)(resultSlots := wdata.asUInt)
  }

  val ctrlWrite = f.isWriting(CONTROL)
  val irqEnable = RegInit(False)
  when(ctrlWrite)(irqEnable := wdata(8))

  // ---------------------------------------------------------------------------------- push
  val push = new Area {
    val width  = stSize(15 downto 0).asUInt
    val height = stSize(31 downto 16).asUInt
    val ok = width =/= 0 && width <= 256 && height =/= 0 && height <= 256 &&
      stSlot < resultSlots && resultBase(63 downto 32) === 0
    val freeOh = OHMasking.first(~validBits)
    val go     = ctrlWrite && wdata(0) && (~validBits).orR // ignored when no context is free

    // contexts in push order, for the issuer; never full (one entry per held context at most)
    val order = StreamFifo(UInt(ctxBits bits), nCtx)
    order.io.push.valid   := go && ok
    order.io.push.payload := OHToUInt(freeOh)

    for ((c, i) <- ctxs.zipWithIndex) when(go && freeOh(i)) {
      c.valid      := True
      c.job.x0     := stX0
      c.job.y0     := stY0
      c.job.step   := stStep
      c.job.width  := width.resized
      c.job.height := height.resized
      c.job.maxIt  := stMaxIt
      c.job.jobId  := stJobId
      c.job.base   := resultBase(31 downto 0) + (stSlot << 19).resize(32) // 512 KB slots
      c.aborted    := False
      c.error      := !ok // a refused job completes at once, with status "error"
      c.issueDone  := !ok
      c.issued     := 0
      c.acked      := 0
      c.skipped    := 0
      c.iterations := 0
    }
  }

  // ---------------------------------------------------------------------------------- abort
  val abortAll   = ctrlWrite && wdata(1)
  val abortWrite = f.isWriting(ABORT)
  for (c <- ctxs) when(c.valid && (abortAll || (abortWrite && c.job.jobId === wdata(15 downto 0).asUInt))) {
    c.aborted := True
  }

  // ---------------------------------------------------------------------------------- issuer
  val issuer = new Area {
    val active           = RegInit(False)
    val cur              = Reg(UInt(ctxBits bits)) init (0)
    val x, y, x0, step   = Reg(SInt(w bits))
    val col, row         = Reg(UInt(9 bits))
    val lastCol, lastRow = Reg(UInt(9 bits))
    val idx              = Reg(UInt(idxBits bits))
    val curAborted       = Vec(ctxs.map(_.aborted))(cur)

    val pop = push.order.io.pop
    pop.ready := !active
    when(pop.fire) {
      val j = jobs(pop.payload)
      active  := True
      cur     := pop.payload
      x       := j.x0
      x0      := j.x0
      y       := j.y0
      step    := j.step
      col     := 0
      row     := 0
      idx     := 0
      lastCol := j.width - 1
      lastRow := j.height - 1
    }

    val out = Stream(CorePixel(cfg))
    out.valid := active && !curAborted
    out.x     := x
    out.y     := y
    out.tag   := cur.asBits ## idx.asBits

    val endOfRow = col === lastCol
    val finished = (out.fire && endOfRow && row === lastRow) || (active && curAborted)
    when(out.fire) {
      idx := idx + 1
      when(endOfRow) {
        col := 0
        row := row + 1
        x   := x0
        y   := y - step
      } otherwise {
        col := col + 1
        x   := x + step
      }
    }
    when(finished)(active := False)
  }
  for ((c, i) <- ctxs.zipWithIndex) {
    when(issuer.out.fire && issuer.cur === i)(c.issued := c.issued + 1)
    when(issuer.finished && issuer.cur === i)(c.issueDone := True)
  }

  // ---------------------------------------------------------------------------------- cores
  // Per-context settings reach the cores two cycles late; a new job's pixels take longer.
  val maxItV = Delay(Vec(ctxs.map(_.job.maxIt)), 2)
  val abortV = Delay(ctxs.map(_.aborted).asBits, 2)

  val cores = Seq.fill(nCores)(new SlotCore(cfg))
  for (c <- cores) {
    c.io.maxIt := maxItV
    c.io.abort := abortV
  }

  /** Each pixel goes to the first child that can take it; children are buffered, so `ready` is
    * a register everywhere.
    */
  def dispatch(in: Stream[CorePixel], sinks: Seq[Stream[CorePixel]]): Unit = {
    if (sinks.size == 1) {
      sinks.head << in
      return
    }
    val groups =
      if (sinks.size <= treeFanIn) sinks.map(Seq(_))
      else sinks.grouped((sinks.size + treeFanIn - 1) / treeFanIn).toSeq
    val outs = groups.map(_ => Stream(CorePixel(cfg)))
    val sel  = OHMasking.first(outs.map(_.ready).asBits)
    for ((o, i) <- outs.zipWithIndex) {
      o.valid   := in.valid && sel(i)
      o.payload := in.payload
    }
    in.ready := outs.map(_.ready).orR
    for ((o, g) <- outs.zip(groups)) dispatch(o.s2mPipe().m2sPipe(), g)
  }
  dispatch(issuer.out.m2sPipe(), cores.map(_.io.s))

  def collect(ins: Seq[Stream[CoreResult]]): Stream[CoreResult] =
    if (ins.size == 1) ins.head
    else collect(ins.grouped(treeFanIn).map { g =>
      new StreamArbiterFactory().roundRobin.noLock.on(g).s2mPipe().m2sPipe()
    }.toSeq)
  val results = collect(cores.map(_.io.m))

  // ---------------------------------------------------------------------------------- statistics
  val totalIterations, totalCycles, totalPixels = Reg(UInt(64 bits)) init (0)
  totalCycles := totalCycles + 1
  when(results.fire) {
    totalPixels := totalPixels + 1
    when(!results.dropped)(totalIterations := totalIterations + results.count)
  }
  for ((c, i) <- ctxs.zipWithIndex) when(results.fire && results.ctx === i) {
    when(results.dropped)(c.skipped := c.skipped + 1) otherwise (c.iterations := c.iterations + results.count)
  }

  // ---------------------------------------------------------------------------------- result writer
  case class Normalize() extends Bundle {
    val addr  = UInt(32 bits)
    val count = UInt(32 bits)
    val mag   = UInt(32 bits)
    val top   = UInt(5 bits) // index of the highest set bit of mag
    val ctx   = UInt(ctxBits bits)
  }
  case class Record() extends Bundle {
    val addr = UInt(32 bits)
    val data = Bits(64 bits)
    val ctx  = UInt(ctxBits bits)
  }
  val normalized = results.throwWhen(results.dropped).map { r =>
    val o = Normalize()
    o.addr  := jobs(r.ctx).base + (r.idx << 3).resize(32)
    o.count := Mux(r.escaped, r.count, U(BigInt(0xFFFFFFFFL), 32 bits))
    o.mag   := r.mag
    o.top   := OHToUInt(OHMasking.first(r.mag.asBits.reversed).reversed)
    o.ctx   := r.ctx
    o
  }.m2sPipe()
  val records = normalized.map { r =>
    val o    = Record()
    val norm = (r.mag << (U(31, 5 bits) - r.top)).resize(32) // highest set bit at 31
    val exp  = r.top.resize(8) + 105 // top - magFrac + 127
    val f32  = Mux(r.mag === 0, B(0, 32 bits), B"0" ## exp.asBits ## norm(30 downto 8).asBits)
    o.addr := r.addr
    o.data := f32 ## r.count.asBits
    o.ctx  := r.ctx
    o
  }.m2sPipe()
  require(magFrac == 22)

  val (awRec, wRec) = StreamFork2(records)
  val axi           = io.axi
  axi.aw.valid := awRec.valid
  awRec.ready  := axi.aw.ready
  axi.aw.payload.clearAll()
  axi.aw.addr.allowOverride  := awRec.addr(31 downto 5) @@ U(0, 5 bits)
  axi.aw.size.allowOverride  := 5 // 32 bytes
  axi.aw.burst.allowOverride := Axi4.burst.INCR
  axi.aw.id.allowOverride    := awRec.ctx.resized

  axi.w.valid := wRec.valid
  wRec.ready  := axi.w.ready
  axi.w.payload.clearAll()
  axi.w.data.allowOverride := wRec.data ## wRec.data ## wRec.data ## wRec.data
  axi.w.strb.allowOverride := B(0xFF, 32 bits) |<< (wRec.addr(4 downto 3) @@ U(0, 3 bits))
  axi.w.last.allowOverride := True

  axi.b.ready := True
  for ((c, i) <- ctxs.zipWithIndex) when(axi.b.fire && axi.b.id === i) {
    c.acked := c.acked + 1
    when(axi.b.resp(1))(c.error := True) // SLVERR or DECERR
  }

  // ---------------------------------------------------------------------------------- done
  val done      = StreamFifo(DoneEntry(), doneDepth)
  val completes = ctxs.map(c => c.complete && c.valid).asBits
  val compOh    = OHMasking.first(completes)
  val compIdx   = OHToUInt(compOh)
  done.io.push.valid      := completes.orR
  done.io.push.status     := Mux(Vec(ctxs.map(_.error))(compIdx), U(2, 2 bits), Mux(Vec(ctxs.map(_.aborted))(compIdx), U(1, 2 bits), U(0, 2 bits)))
  done.io.push.jobId      := jobs(compIdx).jobId
  done.io.push.iterations := Vec(ctxs.map(_.iterations))(compIdx)
  for ((c, i) <- ctxs.zipWithIndex) when(done.io.push.fire && compOh(i))(c.valid := False)

  val head = done.io.pop
  head.ready := f.isWriting(DONE)
  io.irq     := irqEnable && head.valid

  // ---------------------------------------------------------------------------------- read-only registers
  f.read(B(idValue, 32 bits), ID)
  f.read(B(version, 32 bits), VERSION)
  f.read(B((BigInt(nCtx) << 24) | (intBits << 16) | (w << 8) | nCores, 32 bits), CAPS)
  f.read(B(arithId(cfg), 32 bits), ARITH_ID)
  f.read(head.valid ## busy, STATUS)
  f.read(done.io.occupancy.resize(16).asBits ## CountOne(~validBits).resize(16).asBits, QUEUE)
  f.read(head.valid ## B(0, 13 bits) ## head.status.asBits ## head.jobId.asBits, DONE)
  f.read(head.iterations(31 downto 0), DONE_ITERATIONS)
  f.read(head.iterations(63 downto 32), DONE_ITERATIONS + 4)

  val snapIterations, snapCycles, snapPixels = Reg(UInt(64 bits)) init (0)
  f.onRead(TOTAL_ITERATIONS) {
    snapIterations := totalIterations
    snapCycles     := totalCycles
    snapPixels     := totalPixels
  }
  f.read(totalIterations(31 downto 0), TOTAL_ITERATIONS) // the value being latched
  f.read(snapIterations(63 downto 32), TOTAL_ITERATIONS + 4)
  f.read(snapCycles(31 downto 0), TOTAL_CYCLES)
  f.read(snapCycles(63 downto 32), TOTAL_CYCLES + 4)
  f.read(snapPixels(31 downto 0), TOTAL_PIXELS)
  f.read(snapPixels(63 downto 32), TOTAL_PIXELS + 4)

  /** A slowly changing value from another clock domain: taken over when two samples agree. */
  private def slow(v: Bits): Bits = {
    val s    = BufferCC(v)
    val prev = RegNext(s)
    RegNextWhen(s, s === prev)
  }
  f.read(slow(io.board.boardTemp.asBits) ## slow(io.board.fpgaTemp.asBits), BOARD_TEMP)
  f.read(slow(io.board.ready.asBits) ## B(0, 15 bits) ## slow(io.board.fanRpm.asBits), FAN_RPM)

  // ---------------------------------------------------------------------------------- f2sdram read test
  val test = new Area {
    val addr               = f.createReadAndWrite(UInt(32 bits), TEST_ADDR) init (0)
    val arPending, rPending = RegInit(False)
    val rResp              = Reg(Bits(2 bits)) init (0)
    val rData              = Reg(Bits(256 bits)) init (0)
    val ctrlWrite = f.isWriting(TEST_CTRL)
    when(ctrlWrite && wdata(1) && !arPending && !rPending) {
      arPending := True
      rPending  := True
    }
    axi.ar.valid := arPending
    axi.ar.payload.clearAll()
    axi.ar.addr.allowOverride  := addr
    axi.ar.size.allowOverride  := 5
    axi.ar.burst.allowOverride := Axi4.burst.INCR
    axi.r.ready := True
    when(axi.ar.fire)(arPending := False)
    when(axi.r.fire) {
      rPending := False
      rResp    := axi.r.resp
      rData    := axi.r.data
    }
    f.read(rResp ## B(0, 8 bits) ## (arPending || rPending) ## B"0", TEST_CTRL)
    for (i <- 0 until 8) f.read(rData(32 * i, 32 bits), TEST_RDATA + 4 * i)
  }
}

/** MandelbrotAccel with its clock crossings: the register bus and the AXI port are in the bridge
  * clock domain, the accelerator in the core clock domain.
  */
class AccelPlatform(cfg: AccelConfig) extends Component {
  val io = new Bundle {
    val bridgeClk, bridgeRst, coreClk, coreRst = in Bool ()
    val bus   = slave(AvalonMM(AccelRegs.busConfig))
    val axi   = master(Axi4(HpsAxi.f2sdramConfig))
    val irq   = out Bool ()
    val busy  = out Bool () // in the bridge clock domain
    val board = in(BoardStatus())
  }
  val bridgeCd = ClockDomain(io.bridgeClk, io.bridgeRst)
  val coreCd   = ClockDomain(io.coreClk, io.coreRst)

  val accel = coreCd(new MandelbrotAccel(cfg))
  accel.io.board := io.board

  val busCC = new AvalonMMCC(AccelRegs.busConfig, bridgeCd, coreCd)
  busCC.io.input <> io.bus
  busCC.io.output <> accel.io.bus

  io.axi.aw << accel.io.axi.aw.queue(16, coreCd, bridgeCd)
  io.axi.w << accel.io.axi.w.queue(16, coreCd, bridgeCd)
  accel.io.axi.b << io.axi.b.queue(16, bridgeCd, coreCd)
  io.axi.ar << accel.io.axi.ar.queue(4, coreCd, bridgeCd)
  accel.io.axi.r << io.axi.r.queue(4, bridgeCd, coreCd)

  io.irq  := bridgeCd(BufferCC(accel.io.irq, init = False))
  io.busy := bridgeCd(BufferCC(accel.io.busy, init = False))
}
