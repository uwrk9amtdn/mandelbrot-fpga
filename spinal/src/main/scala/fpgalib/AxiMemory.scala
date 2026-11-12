package fpgalib

import spinal.core._
import spinal.lib._
import spinal.lib.bus.amba4.axi._

/** Reads `pixels` 16-bit words from `startAddr` in bursts of `burstLength` beats after each `start`
  * pulse, and streams them out as whole AXI beats (SV: memory_reader.sv, without the width converter,
  * which now sits after the clock-crossing FIFO).
  *
  * Like the SV, it is meant to be reset at every vertical sync: while in reset, `r.ready` is held
  * high so stale read data is drained.
  */
class MemoryReader(axiCfg: Axi4Config, startAddr: BigInt, pixels: Int, burstLength: Int, axiId: Int = 0)
    extends Component {
  val wordsPerBeat = axiCfg.dataWidth / 16
  val bytesPerBurst = burstLength * axiCfg.bytePerWord
  require(axiCfg.dataWidth >= 16 && axiCfg.dataWidth % 16 == 0)
  require(burstLength >= 1 && burstLength <= 256, "burstLength must be 1..256 beats")
  require(pixels % (burstLength * wordsPerBeat) == 0, "pixels must be a multiple of burstLength * words per beat")
  require(startAddr % 4096 + bytesPerBurst <= 4096 && 4096 % bytesPerBurst == 0,
    "bursts must not cross 4 KiB boundaries")
  val nBursts = pixels / (burstLength * wordsPerBeat)

  val io = new Bundle {
    val start = in Bool ()
    val busy  = out Bool ()
    val axi   = master(Axi4ReadOnly(axiCfg))
    val beats = master Stream (Bits(axiCfg.dataWidth bits)) // first pixel in the low bits
  }

  val active  = RegInit(False)
  val arValid = RegInit(False)
  val arAddr  = Reg(UInt(axiCfg.addressWidth bits))
  val counter = Reg(UInt(log2Up(nBursts max 2) bits)) init (0)

  io.busy := active

  when(!active && io.start) {
    active  := True
    arValid := True
    arAddr  := startAddr
  }
  when(io.axi.ar.fire) {
    arAddr := arAddr + bytesPerBurst
    when(counter === nBursts - 1) {
      counter := 0
      active  := False
      arValid := False
    } otherwise {
      counter := counter + 1
    }
  }

  val ar = io.axi.ar
  ar.valid := arValid
  ar.addr  := arAddr
  ar.id    := axiId
  ar.len   := burstLength - 1
  ar.size  := log2Up(axiCfg.bytePerWord)
  ar.setBurstINCR()
  if (axiCfg.useLock) ar.lock := 0
  if (axiCfg.useCache) ar.cache := B"0011"
  if (axiCfg.useProt) ar.prot := 0
  if (axiCfg.useQos) ar.qos := 0
  if (axiCfg.useRegion) ar.region := 0
  if (axiCfg.useArUser) ar.user := 0

  io.beats.valid   := io.axi.r.valid
  io.beats.payload := io.axi.r.data
  io.axi.r.ready   := io.beats.ready || ClockDomain.current.isResetActive
}

/** Turns (address, data burst) streams into AXI4 write bursts (SV: memory_writer.sv).
  * One address word per burst; each burst is `beatsPerBurst` data beats, the last one with `last` set.
  * Write responses are ignored.
  */
class MemoryWriter(axiCfg: Axi4Config, beatsPerBurst: Int, axiId: Int = 1) extends Component {
  val io = new Bundle {
    val addr = slave Stream (UInt(32 bits))
    val data = slave Stream (Fragment(Bits(axiCfg.dataWidth bits)))
    val axi  = master(Axi4WriteOnly(axiCfg))
  }

  val aw = io.axi.aw
  aw.arbitrationFrom(io.addr)
  aw.addr := io.addr.payload.resized
  aw.id   := axiId
  aw.len  := beatsPerBurst - 1
  aw.size := log2Up(axiCfg.bytePerWord)
  aw.setBurstINCR()
  if (axiCfg.useLock) aw.lock := 0
  if (axiCfg.useCache) aw.cache := B"0011"
  if (axiCfg.useProt) aw.prot := 0
  if (axiCfg.useQos) aw.qos := 0
  if (axiCfg.useRegion) aw.region := 0
  if (axiCfg.useAwUser) aw.user := 0

  val w = io.axi.w
  w.arbitrationFrom(io.data)
  w.data := io.data.fragment
  w.strb.setAll()
  w.last := io.data.last

  io.axi.b.ready := True
}
