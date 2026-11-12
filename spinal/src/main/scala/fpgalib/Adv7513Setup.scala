package fpgalib

import spinal.core._
import spinal.lib._

/** ADV7513 HDMI transmitter setup over I2C (replaces hdmi/ac701_adv7511_setup.sv).
  *
  * The register list is the one Terasic uses on the DE25-Nano (HDMI_TX demo, I2C_HDMI_Config.v),
  * plus 0x17 = 0x02 (16:9) from the AC701 setup. The AC701 needed a PCA9548 bus switch first,
  * the DE25-Nano doesn't.
  *
  * The sequence starts after `startDelay` seconds, is retried after `retryDelay` if a write isn't
  * acknowledged, and runs again whenever the ADV7513 raises its interrupt (hot plug: the chip
  * powers down and forgets its settings when the monitor is unplugged).
  */
class Adv7513Setup(clkHz: Double, startDelay: Double = 10e-3, retryDelay: Double = 100e-3) extends Component {
  val io = new Bundle {
    val interrupt = in Bool () // HDMI_TX_INT, active low, already synchronized
    val done      = out Bool ()
    val error     = out Bool ()
    val scl       = master(OpenDrain())
    val sda       = master(OpenDrain())
  }

  import Adv7513Setup._

  val i2c = new I2cWriter(clkHz)
  io.scl <> i2c.io.scl
  io.sda <> i2c.io.sda

  val rom   = Vec(regs.map { case (r, d) => B((r << 8) | d, 16 bits) })
  val index = Reg(UInt(log2Up(regs.size + 1) bits)) init (0)

  def cycles(t: Double) = (t * clkHz).toLong max 1
  val timer = Reg(UInt(log2Up(cycles(startDelay max retryDelay) + 1) bits)) init (cycles(startDelay))

  object State extends SpinalEnum { val WAIT, SEND, ACK, DONE = newElement() }
  val state = RegInit(State.WAIT)
  val done  = RegInit(False)
  val error = RegInit(False)
  io.done  := done
  io.error := error

  i2c.io.cmd.valid  := state === State.SEND
  i2c.io.cmd.device := device
  i2c.io.cmd.reg    := rom(index.resized)(15 downto 8)
  i2c.io.cmd.data   := rom(index.resized)(7 downto 0)

  switch(state) {
    is(State.WAIT) {
      timer := timer - 1
      when(timer === 0) {
        index := 0
        state := State.SEND
      }
    }
    is(State.SEND) {
      when(i2c.io.cmd.ready) { state := State.ACK }
    }
    is(State.ACK) {
      when(i2c.io.rsp.valid) {
        when(!i2c.io.rsp.payload) {
          error := True
          timer := cycles(retryDelay)
          state := State.WAIT
        } elsewhen (index === regs.size - 1) {
          done  := True
          error := False
          state := State.DONE
        } otherwise {
          index := index + 1
          state := State.SEND
        }
      }
    }
    is(State.DONE) {
      when(!io.interrupt) { // hot plug event: set up again (this also clears the interrupt)
        done  := False
        timer := cycles(startDelay)
        state := State.WAIT
      }
    }
  }
}

object Adv7513Setup {
  val device = 0x39 // 0x72 in 8-bit notation
  val regs: Seq[(Int, Int)] = Seq(
    0x98 -> 0x03, // must be 0x03
    0x01 -> 0x00, 0x02 -> 0x18, 0x03 -> 0x00, // audio N = 6144
    0x0b -> 0x2e, // MCLK active
    0x0c -> 0xbc, // I2S audio
    0x14 -> 0x72, // audio word length
    0x15 -> 0x20, // input 4:4:4 RGB, separate syncs, 48 kHz
    0x16 -> 0x30, // output 4:4:4, 24-bit input
    0x17 -> 0x02, // 16:9 aspect ratio
    0x18 -> 0x46, // CSC off
    0x40 -> 0x80, // general control packet on
    0x41 -> 0x10, // power up
    0x49 -> 0xa8, // dither
    0x55 -> 0x10, // RGB in AVI infoframe
    0x56 -> 0x08, // active format aspect
    0x96 -> 0xf6, // clear interrupts
    0x73 -> 0x07, 0x76 -> 0x1f, // audio infoframe
    0x98 -> 0x03, 0x99 -> 0x02, 0x9a -> 0xe0, 0x9c -> 0x30, 0x9d -> 0x61, // fixed values from the datasheet
    0xa2 -> 0xa4, 0xa3 -> 0xa4, 0xa5 -> 0x04, 0xab -> 0x40,
    0xaf -> 0x16, // HDMI mode
    0xba -> 0x60, // no clock delay
    0xd1 -> 0xff, 0xde -> 0x10, 0xe4 -> 0x60, 0xfa -> 0x7d
  )
}
