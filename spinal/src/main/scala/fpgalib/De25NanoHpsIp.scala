package fpgalib

import spinal.core._
import spinal.lib._
import spinal.lib.bus.amba4.axi._

// Vendor IP of the Terasic DE25-Nano for designs that use the HPS. The files come from the Terasic
// resource package at build time: the GHRD (Demonstration/SoC_FPGA/GHRD), reshaped by
// projects/mandelbrot/quartus/hps_qsys.tcl, and the board management IP of the Board_Info_RTL demo.

object HpsAxi {
  /** The f2sdram bridge behind Terasic's f2sdram_adapter: AXI4, 256-bit data. Addresses are HPS
    * physical addresses (RAM starts at 0x8000_0000).
    */
  def f2sdramConfig = Axi4Config(
    addressWidth = 32,
    dataWidth    = 256,
    idWidth      = 5,
    arUserWidth  = 8,
    awUserWidth  = 8,
    wUserWidth   = 8,
    bUserWidth   = 8,
    rUserWidth   = 8
  )
}

/** Pins of the HPS as Terasic's golden_top names them. */
case class HpsPins() extends Bundle {
  val CLK_25                      = in Bool ()
  val ENET_TX_CLK, ENET_TX_CTL    = out Bool ()
  val ENET_RX_CLK, ENET_RX_CTL    = in Bool ()
  val ENET_TX_DATA                = out Bits (4 bits)
  val ENET_RX_DATA                = in Bits (4 bits)
  val ENET_MDIO                   = inout(Analog(Bool()))
  val ENET_MDC                    = out Bool ()
  val SD_CLK                      = out Bool ()
  val SD_CMD                      = inout(Analog(Bool()))
  val SD_DATA                     = inout(Analog(Bits(4 bits)))
  val UART_RX                     = in Bool ()
  val UART_TX                     = out Bool ()
  val USB_CLK, USB_DIR, USB_NXT   = in Bool ()
  val USB_STP                     = out Bool ()
  val USB_DATA                    = inout(Analog(Bits(8 bits)))
  val I2C_SDA, I2C_SCL            = inout(Analog(Bool()))
  val GSENSOR_INT, GSENSOR_I2C_EN = inout(Analog(Bool()))
  val KEY, LED                    = inout(Analog(Bool()))
}

/** The GHRD's Platform Designer system after hps_qsys.tcl: HPS and its LPDDR4 EMIF (bank A), with
  * lwhps2fpga exported as an Avalon-MM master (`reg`, 4 KB), f2sdram as an AXI4 slave and the
  * FPGA-to-HPS interrupts. Everything runs on clk_100.
  */
class qsys_top extends BlackBox {
  val clk_100_clk           = in Bool ()
  val reset_reset_n         = in Bool ()
  val ninit_done_ninit_done = out Bool ()
  val h2f_reset_reset       = out Bool ()
  val h2f_warm_reset_handshake_reset_req = out Bool ()
  val h2f_warm_reset_handshake_reset_ack = in Bool ()

  val reg_address       = out UInt (12 bits)
  val reg_read          = out Bool ()
  val reg_write         = out Bool ()
  val reg_writedata     = out Bits (32 bits)
  val reg_byteenable    = out Bits (4 bits)
  val reg_readdata      = in Bits (32 bits)
  val reg_readdatavalid = in Bool ()
  val reg_waitrequest   = in Bool ()

  val f2sdram = slave(Axi4(HpsAxi.f2sdramConfig)) setName "f2sdram"
  SpecNames(f2sdram)

  val f2h_irq_irq     = in Bits (32 bits)
  val f2h_irq1_in_irq = in Bits (32 bits)

  val hps_io_hps_osc_clk = in Bool ()
  val hps_io_sdmmc_cclk  = out Bool ()
  val hps_io_sdmmc_cmd   = inout(Analog(Bool()))
  val hps_io_sdmmc_data  = Seq.tabulate(4)(i => inout(Analog(Bool())) setName s"hps_io_sdmmc_data$i")
  val hps_io_usb0_clk    = in Bool ()
  val hps_io_usb0_stp    = out Bool ()
  val hps_io_usb0_dir    = in Bool ()
  val hps_io_usb0_nxt    = in Bool ()
  val hps_io_usb0_data   = Seq.tabulate(8)(i => inout(Analog(Bool())) setName s"hps_io_usb0_data$i")
  val hps_io_emac0_tx_clk = out Bool ()
  val hps_io_emac0_tx_ctl = out Bool ()
  val hps_io_emac0_rx_clk = in Bool ()
  val hps_io_emac0_rx_ctl = in Bool ()
  val hps_io_emac0_txd    = Seq.tabulate(4)(i => out Bool () setName s"hps_io_emac0_txd$i")
  val hps_io_emac0_rxd    = Seq.tabulate(4)(i => in Bool () setName s"hps_io_emac0_rxd$i")
  val hps_io_mdio0_mdio   = inout(Analog(Bool()))
  val hps_io_mdio0_mdc    = out Bool ()
  val hps_io_uart1_tx     = out Bool ()
  val hps_io_uart1_rx     = in Bool ()
  val hps_io_i2c1_sda     = inout(Analog(Bool()))
  val hps_io_i2c1_scl     = inout(Analog(Bool()))
  val hps_io_gpio28       = inout(Analog(Bool()))
  val hps_io_gpio34       = inout(Analog(Bool()))
  val hps_io_gpio40       = inout(Analog(Bool()))
  val hps_io_gpio41       = inout(Analog(Bool()))

  val emif_hps_emif_mem_0_mem_cs    = out Bool ()
  val emif_hps_emif_mem_0_mem_ca    = out Bits (6 bits)
  val emif_hps_emif_mem_0_mem_cke   = out Bool ()
  val emif_hps_emif_mem_0_mem_dq    = inout(Analog(Bits(32 bits)))
  val emif_hps_emif_mem_0_mem_dqs_t = inout(Analog(Bits(4 bits)))
  val emif_hps_emif_mem_0_mem_dqs_c = inout(Analog(Bits(4 bits)))
  val emif_hps_emif_mem_0_mem_dmi   = inout(Analog(Bits(4 bits)))
  val emif_hps_emif_mem_ck_0_mem_ck_t       = out Bool ()
  val emif_hps_emif_mem_ck_0_mem_ck_c       = out Bool ()
  val emif_hps_emif_mem_reset_n_mem_reset_n = out Bool ()
  val emif_hps_emif_oct_0_oct_rzqin         = in Bool ()
  val emif_hps_emif_ref_clk_0_clk           = in Bool ()

  def connectPins(h: HpsPins, m: Lpddr4Pins): Unit = {
    hps_io_hps_osc_clk := h.CLK_25
    h.SD_CLK := hps_io_sdmmc_cclk
    h.SD_CMD <> hps_io_sdmmc_cmd
    for (i <- 0 until 4) h.SD_DATA(i) <> hps_io_sdmmc_data(i)
    hps_io_usb0_clk := h.USB_CLK
    h.USB_STP       := hps_io_usb0_stp
    hps_io_usb0_dir := h.USB_DIR
    hps_io_usb0_nxt := h.USB_NXT
    for (i <- 0 until 8) h.USB_DATA(i) <> hps_io_usb0_data(i)
    h.ENET_TX_CLK       := hps_io_emac0_tx_clk
    h.ENET_TX_CTL       := hps_io_emac0_tx_ctl
    hps_io_emac0_rx_clk := h.ENET_RX_CLK
    hps_io_emac0_rx_ctl := h.ENET_RX_CTL
    for (i <- 0 until 4) {
      h.ENET_TX_DATA(i)   := hps_io_emac0_txd(i)
      hps_io_emac0_rxd(i) := h.ENET_RX_DATA(i)
    }
    h.ENET_MDIO <> hps_io_mdio0_mdio
    h.ENET_MDC      := hps_io_mdio0_mdc
    h.UART_TX       := hps_io_uart1_tx
    hps_io_uart1_rx := h.UART_RX
    h.I2C_SDA <> hps_io_i2c1_sda
    h.I2C_SCL <> hps_io_i2c1_scl
    h.GSENSOR_INT <> hps_io_gpio28
    h.GSENSOR_I2C_EN <> hps_io_gpio34
    h.KEY <> hps_io_gpio40
    h.LED <> hps_io_gpio41

    m.CS_n    := emif_hps_emif_mem_0_mem_cs
    m.CA      := emif_hps_emif_mem_0_mem_ca
    m.CKE     := emif_hps_emif_mem_0_mem_cke
    m.CK      := emif_hps_emif_mem_ck_0_mem_ck_t
    m.CK_n    := emif_hps_emif_mem_ck_0_mem_ck_c
    m.RESET_n := emif_hps_emif_mem_reset_n_mem_reset_n
    m.DQ <> emif_hps_emif_mem_0_mem_dq
    m.DQS <> emif_hps_emif_mem_0_mem_dqs_t
    m.DQS_n <> emif_hps_emif_mem_0_mem_dqs_c
    m.DM <> emif_hps_emif_mem_0_mem_dmi
    emif_hps_emif_oct_0_oct_rzqin := m.RZQ
    emif_hps_emif_ref_clk_0_clk   := m.REFCLK_p
  }
}

/** The GHRD's IOPLL (ip/pll.ip): 100 MHz from a 50 MHz reference. */
class pll extends BlackBox {
  val refclk   = in Bool ()
  val rst      = in Bool ()
  val outclk_0 = out Bool ()
  val locked   = out Bool ()
}

/** Terasic's board management IP (Board_Info_RTL demo): talks to the AMC6821 fan controller on the
  * HDMI I2C pins. In auto mode it sets the fan speed from the FPGA temperature, 3000 RPM at 35 °C
  * rising to 10000 RPM at 90 °C. Only the ports we use are declared.
  */
class BOARD_MANAGEMENT extends BlackBox {
  val clk_50            = in Bool ()
  val reset_n           = in Bool ()
  val I2C_SCL           = inout(Analog(Bool()))
  val I2C_SDA           = inout(Analog(Bool()))
  val I2C_READY         = out Bool ()
  val FPGA_Temperature  = out SInt (16 bits)
  val Board_Temperature = out SInt (16 bits)
  val Fan_Speed         = out UInt (16 bits)
  val Auto_Fan_Speed    = in Bool ()
  val Set_Fan_Speed     = in UInt (16 bits)
}
