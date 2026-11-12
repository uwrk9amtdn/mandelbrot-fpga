package mandelbrot

import fpgalib._

import spinal.core._
import spinal.lib._

/** All configuration options of wrapper.sv (+ the core options it passes down).
  *
  * | SV                      | here            |
  * |-------------------------|-----------------|
  * | X_RES, Y_RES            | xRes, yRes      |
  * | FRAC_WIDTH              | fracWidth       |
  * | NCORES                  | nCores          |
  * | ARBITER_TREE_SANS       | arbiterTreeSans |  (inputs per arbiter in the tree)
  * | BURST_LENGTH            | burstLength     |
  * | FB_START_ADDR           | fbStartAddr     |
  * | m_data.DATA_WIDTH       | dataWidth       |  (was an interface parameter)
  * | cfg::SI_LATENCY         | siLatency       |
  */
case class WrapperConfig(
    xRes: Int = 1920,
    yRes: Int = 1080,
    fracWidth: Int = 8,
    nCores: Int = 54,
    arbiterTreeSans: Int = 4,
    burstLength: Int = 16,
    fbStartAddr: BigInt = 0,
    dataWidth: Int = 64,
    siLatency: Int = 8
) {
  require(yRes % nCores == 0, "yRes must be a multiple of nCores")
  require(arbiterTreeSans >= 2, "arbiterTreeSans must be at least 2")
  require(dataWidth % 16 == 0, "dataWidth must be a multiple of 16")
  require(dataWidth / 16 <= burstLength && burstLength % (dataWidth / 16) == 0,
    "burstLength must be a multiple of dataWidth / 16")

  val w = fracWidth + 3

  /** Core i computes rows [i * yRes/nCores, (i+1) * yRes/nCores) and writes its own slice of the frame. */
  def core(i: Int): MandelbrotConfig = MandelbrotConfig(
    startAddr = (fbStartAddr + BigInt(xRes) * yRes * 2 * i / nCores) & 0xFFFFFFFFL,
    xRes = xRes,
    yRes = yRes / nCores,
    n = burstLength,
    fracWidth = fracWidth,
    siLatency = siLatency
  )
  core(0) // run the core's checks at construction
}

/** View request: centre of the image, distance between pixels, iteration limit. */
case class ViewCmd(w: Int) extends Bundle {
  val centerX = SInt(w bits)
  val centerY = SInt(w bits)
  val xyStep  = SInt(w bits)
  val maxIt   = UInt(16 bits)
}

/** A view converted to what the cores need. */
case class FrameSetup(w: Int) extends Bundle {
  val topLeftX  = SInt(w bits)
  val topLeftY  = SInt(w bits)
  val coreYStep = SInt(w bits) // y distance between two cores' first rows
  val xyStep    = SInt(w bits)
  val maxIt     = UInt(16 bits)
}

/** nCores CoreWrappers, each computing a horizontal band of the frame (SV: wrapper.sv).
  *
  *   s ──► setup (top-left corner) ──► dispatch to core 0..n-1 ──► cores
  *   cores ──► round-robin arbiter tree ──► split: header words ──► m_addr (32 bit)
  *                                                 data words   ──► m_data (dataWidth, last)
  */
class Wrapper(val cfg: WrapperConfig) extends Component with SvClockNames {
  import cfg._

  val io = new Bundle {
    val s     = slave Stream (ViewCmd(w))
    val mAddr = master Stream (UInt(32 bits))
    val mData = master Stream (Fragment(Bits(dataWidth bits)))
  }
  noIoPrefix()
  // same flat names as projects/mandelbrot/asic/src/mandelbrot_asic.sv
  io.s.valid.setName("s_valid")
  io.s.ready.setName("s_ready")
  io.s.centerX.setName("s_center_x")
  io.s.centerY.setName("s_center_y")
  io.s.xyStep.setName("s_xy_step")
  io.s.maxIt.setName("s_max_it")
  io.mAddr.valid.setName("m_addr_valid")
  io.mAddr.ready.setName("m_addr_ready")
  io.mAddr.payload.setName("m_addr_data")
  io.mData.valid.setName("m_data_valid")
  io.mData.ready.setName("m_data_ready")
  io.mData.fragment.setName("m_data_data")
  io.mData.last.setName("m_data_last")

  // ------------------------------------------------------------------ command side

  /** v * k for a constant k, wrapped to w bits (SV: constant_multiplier). */
  def times(v: SInt, k: Int): SInt = (v * S(k, log2Up(k) + 2 bits))(w - 1 downto 0)

  val setup = io.s.map { c =>
    val f = FrameSetup(w)
    f.topLeftX  := c.centerX - times(c.xyStep, xRes / 2)
    f.topLeftY  := c.centerY + times(c.xyStep, yRes / 2)
    f.coreYStep := times(c.xyStep, yRes / nCores)
    f.xyStep    := c.xyStep
    f.maxIt     := c.maxIt
    f
  }.m2sPipe()

  // Send the setup to every core in turn; core i starts i bands lower.
  val coreIdx = Counter(nCores)
  val yOffset = RegInit(S(0, w bits))

  val toCores = Stream(FrameCmd(w))
  toCores.valid  := setup.valid
  toCores.xStart := setup.topLeftX
  toCores.yStart := setup.topLeftY - yOffset
  toCores.xyStep := setup.xyStep
  toCores.maxIt  := setup.maxIt
  setup.ready    := toCores.ready && coreIdx.willOverflowIfInc // consumed once the last core has it

  when(toCores.fire) {
    coreIdx.increment()
    yOffset := Mux(coreIdx.willOverflowIfInc, S(0, w bits), yOffset + setup.coreYStep)
  }

  val cores = for (i <- 0 until nCores) yield new CoreWrapper(core(i)).setName(s"core_$i")
  for ((core, port) <- cores.zip(StreamDemux(toCores, coreIdx, nCores))) core.io.s << port

  // ------------------------------------------------------------------ result side

  /** Round-robin arbiters of `arbiterTreeSans` inputs, each followed by a skid buffer,
    * repeated until one stream is left (SV: axis_rr_arbiter_tree). `fragmentLock` keeps
    * a packet together.
    */
  def arbiterTree[T <: Data](inputs: Seq[Stream[Fragment[T]]]): Stream[Fragment[T]] =
    if (inputs.size == 1) inputs.head
    else arbiterTree(inputs.grouped(arbiterTreeSans).toSeq.map { group =>
      new StreamArbiterFactory().roundRobin.fragmentLock.on(group).s2mPipe().m2sPipe()
    })

  val packets = arbiterTree(cores.map(_.io.m))

  // Each packet: 2 address words, then burstLength data words. Route them by position.
  val wordIdx = RegInit(U(0, 2 bits)) // 0, 1 = address, 2 = data
  when(packets.fire) {
    wordIdx := Mux(packets.last, U(0), Mux(wordIdx === 2, U(2), wordIdx + 1))
  }
  val Seq(header, payload) = StreamDemux(packets, (wordIdx === 2).asUInt, 2).toSeq

  val addr = Stream(UInt(32 bits))
  StreamWidthAdapter(header.translateWith(header.fragment), addr, BIG) // first word = high half
  io.mAddr << addr.m2sPipe()

  val data = Stream(Fragment(Bits(dataWidth bits)))
  StreamFragmentWidthAdapter(payload, data, LITTLE) // first word = low bits (like axis_adapter)
  io.mData << data.m2sPipe()
}
