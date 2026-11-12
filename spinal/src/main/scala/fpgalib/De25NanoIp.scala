package fpgalib

import spinal.core._
import spinal.lib._
import spinal.lib.bus.amba4.axi._
import spinal.lib.bus.amba4.axilite._

// Vendor IP of the Terasic DE25-Nano (Agilex 5). The Verilog comes from the Terasic resource package
// (RTL_LPDDR4_AXI4_Test demo): EMIF_Qsys.qsys + ip/EMIF_Qsys/*.ip and agilex_reset_release.ip.

object MemoryAxi {
  /** AXI4 port of the Agilex 5 LPDDR4 EMIF (DE25-Nano, see RTL_LPDDR4_AXI4_Test in the Terasic package).
    * No cache/region signals, 14-bit ar/aw user (tied to 0).
    */
  def emifConfig = Axi4Config(
    addressWidth = 30, // 1 GiB (EMIF_Qsys_bb.v: [29:0], even though the demo comments say 32)
    dataWidth    = 256,
    idWidth      = 7,
    useRegion    = false,
    useCache     = false,
    arUserWidth  = 14,
    awUserWidth  = 14
  )
}

/** AXI/AXI-Lite port names as the IP uses them: `<prefix>_awvalid`, `<prefix>_araddr`, ... */
object SpecNames {
  def apply(b: Bundle): Unit = {
    def doIt(): Unit = b.flatten.foreach { bt =>
      bt.setName(bt.getName().replace("_payload_", "").replace("_valid", "valid").replace("_ready", "ready"))
    }
    if (Component.current == b.component) b.component.addPrePopTask(() => doIt()) else doIt()
  }
}

/** Agilex reset release (Terasic RTL_LPDDR4_AXI4_Test/agilex_reset_release.ip). High until the
  * device has finished initialising; nothing may leave reset before that.
  */
class agilex_reset_release extends BlackBox {
  val ninit_done = out Bool ()
}

/** One LPDDR4 interface of the Terasic EMIF_Qsys Platform Designer system. */
case class Lpddr4Pins() extends Bundle {
  val CS_n    = out Bool ()
  val CA      = out Bits (6 bits)
  val CK      = out Bool ()
  val CK_n    = out Bool ()
  val CKE     = out Bool ()
  val DM      = inout(Analog(Bits(4 bits)))
  val DQ      = inout(Analog(Bits(32 bits)))
  val DQS     = inout(Analog(Bits(4 bits)))
  val DQS_n   = inout(Analog(Bits(4 bits)))
  val RESET_n = out Bool ()
  val RZQ     = in Bool ()
  val REFCLK_p = in Bool ()
}

/** Terasic's EMIF_Qsys (RTL_LPDDR4_AXI4_Test): two LPDDR4 EMIFs with 256-bit AXI4 ports, an IOPLL
  * that makes the 310 MHz AXI clock and the AXI4-Lite clock, both from a 50 MHz reference.
  */
class EMIF_Qsys extends BlackBox {
  val axiCfg  = MemoryAxi.emifConfig
  val axilCfg = AxiLite4Config(27, 32)

  val clock_310m_out_clk_clk     = out Bool ()
  val iopll_refclk_clk           = in Bool ()
  val iopll_locked_export        = out Bool ()
  val iopll_reset_reset          = in Bool ()
  val iopll_outclk_axi4_lite_clk = out Bool ()
  val reset_reset_n              = in Bool ()

  class Channel(n: String) extends Area {
    val ctrlReady  = out Bool () setName (s"emif_lpddr4${n}_s0_axi4_ctrl_ready_reset_n")
    val axi        = slave(Axi4(axiCfg)) setName (s"emif_lpddr4${n}_s0_axi4")
    val axilClk    = in Bool () setName (s"emif_lpddr4${n}_s0_axi4lite_clock_clk")
    val axilRstN   = in Bool () setName (s"emif_lpddr4${n}_s0_axi4lite_reset_n_reset_n")
    val axil       = slave(AxiLite4(axilCfg)) setName (s"emif_lpddr4${n}_s0_axi4lite")
    val mem_cs     = out Bool () setName (s"emif_lpddr4${n}_mem_mem_cs")
    val mem_ca     = out Bits (6 bits) setName (s"emif_lpddr4${n}_mem_mem_ca")
    val mem_cke    = out Bool () setName (s"emif_lpddr4${n}_mem_mem_cke")
    val mem_dq     = inout(Analog(Bits(32 bits))) setName (s"emif_lpddr4${n}_mem_mem_dq")
    val mem_dqs_t  = inout(Analog(Bits(4 bits))) setName (s"emif_lpddr4${n}_mem_mem_dqs_t")
    val mem_dqs_c  = inout(Analog(Bits(4 bits))) setName (s"emif_lpddr4${n}_mem_mem_dqs_c")
    val mem_dmi    = inout(Analog(Bits(4 bits))) setName (s"emif_lpddr4${n}_mem_mem_dmi")
    val mem_ck_t   = out Bool () setName (s"emif_lpddr4${n}_mem_ck_mem_ck_t")
    val mem_ck_c   = out Bool () setName (s"emif_lpddr4${n}_mem_ck_mem_ck_c")
    val mem_reset_n = out Bool () setName (s"emif_lpddr4${n}_mem_reset_n_mem_reset_n")
    val oct_rzqin  = in Bool () setName (s"emif_lpddr4${n}_oct_oct_rzqin")
    val ref_clk    = in Bool () setName (s"emif_lpddr4${n}_ref_clk_clk")
    SpecNames(axi)
    SpecNames(axil)

    def connectPins(p: Lpddr4Pins): Unit = {
      p.CS_n    := mem_cs
      p.CA      := mem_ca
      p.CKE     := mem_cke
      p.CK      := mem_ck_t
      p.CK_n    := mem_ck_c
      p.RESET_n := mem_reset_n
      p.DQ <> mem_dq
      p.DQS <> mem_dqs_t
      p.DQS_n <> mem_dqs_c
      p.DM <> mem_dmi
      oct_rzqin := p.RZQ
      ref_clk   := p.REFCLK_p
    }
  }
  val a = new Channel("a")
  val b = new Channel("b")
}
