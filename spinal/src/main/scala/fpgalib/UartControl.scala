package fpgalib

import spinal.core._
import spinal.lib._
import spinal.lib.com.uart._

/** Register access over a UART with a human-typable text protocol (replaces the Xilinx VIO).
  *
  *   w AA DDDDDDDD<enter>   write hex data to register AA   -> "OK"
  *   r AA<enter>            read register AA               -> "DDDDDDDD" (8 hex digits)
  *   anything else                                         -> "?"
  *
  * Replies end with CR LF. Hex is case-insensitive, leading zeros are optional, spaces separate
  * fields, upper-case W/R work too. 115200 8N1 by default.
  *
  * The register file itself is outside: `write` is a one-cycle Flow, `readAddr` is looked up
  * combinationally into `readData`.
  */
class UartControl(clkHz: Double, baud: Int = 115200) extends Component {
  val io = new Bundle {
    val uart     = master(Uart())
    val write    = master Flow (RegWrite())
    val readAddr = out UInt (8 bits)
    val readData = in Bits (32 bits)
  }

  val uart = new UartCtrl(UartCtrlGenerics())
  uart.io.config.setClockDivider(baud Hz, clkHz Hz)
  uart.io.config.frame.dataLength := 7 // 8 bits
  uart.io.config.frame.parity     := UartParityType.NONE
  uart.io.config.frame.stop       := UartStopType.ONE
  uart.io.writeBreak              := False
  io.uart <> uart.io.uart

  // ------------------------------------------------------------------ receive / parse
  object Cmd extends SpinalEnum { val NONE, WRITE, READ, BAD = newElement() }
  val cmd      = RegInit(Cmd.NONE)
  val acc      = Reg(Bits(32 bits)) init (0)
  val sawDigit = RegInit(False)
  val fields   = Reg(UInt(2 bits)) init (0) // completed hex fields (saturating)
  val addr     = Reg(UInt(8 bits)) init (0)
  val data     = Reg(Bits(32 bits)) init (0)

  val busy = Bool() // reply still being sent
  val rx   = uart.io.read
  rx.ready := !busy

  def C(ch: Char): UInt = U(ch.toInt, 8 bits)
  val c       = rx.payload.asUInt
  val isDigit = c >= C('0') && c <= C('9')
  val isLower = c >= C('a') && c <= C('f')
  val isUpper = c >= C('A') && c <= C('F')
  val nibble  = Mux(isDigit, c - C('0'), Mux(isLower, c - C('a') + 10, c - C('A') + 10)).resize(4)
  val isEol   = c === C('\r') || c === C('\n')
  val isSep   = c === C(' ') || c === C(',') || c === C('\t')

  val execute = False

  /** Close the current hex field: the first one is the address, the second the data. */
  def endField(): Unit = when(sawDigit) {
    when(fields === 0) { addr := acc(7 downto 0).asUInt }
    when(fields === 1) { data := acc }
    when(fields =/= 3) { fields := fields + 1 }
    acc      := 0
    sawDigit := False
  }

  when(rx.fire) {
    when(c === C('w') || c === C('W')) {
      cmd := Mux(cmd === Cmd.NONE, Cmd.WRITE, Cmd.BAD)
    } elsewhen (c === C('r') || c === C('R')) {
      cmd := Mux(cmd === Cmd.NONE, Cmd.READ, Cmd.BAD)
    } elsewhen (isDigit || isLower || isUpper) {
      acc      := acc(27 downto 0) ## nibble.asBits
      sawDigit := True
      when(cmd === Cmd.NONE) { cmd := Cmd.BAD }
    } elsewhen (isSep) {
      endField()
    } elsewhen (isEol) {
      execute := True
    } otherwise {
      cmd := Cmd.BAD
    }
  }

  // Fields including one still being typed when the line ends.
  val totalFields = fields + sawDigit.asUInt
  val lineAddr    = Mux(sawDigit && fields === 0, acc(7 downto 0).asUInt, addr)
  val lineData    = Mux(sawDigit && fields === 1, acc, data)

  io.write.valid   := False
  io.write.address := lineAddr
  io.write.data    := lineData

  // ------------------------------------------------------------------ reply
  object Reply extends SpinalEnum { val NONE, OK, DATA, ERR = newElement() }
  val reply     = RegInit(Reply.NONE)
  val replyData = Reg(Bits(32 bits))
  val replyIdx  = Reg(UInt(4 bits)) init (0)
  busy := reply =/= Reply.NONE

  io.readAddr := lineAddr

  when(execute) {
    switch(cmd) {
      is(Cmd.WRITE) {
        when(totalFields === 2) {
          io.write.valid := True
          reply          := Reply.OK
        } otherwise { reply := Reply.ERR }
      }
      is(Cmd.READ) {
        when(totalFields === 1) {
          replyData := io.readData
          reply     := Reply.DATA
        } otherwise { reply := Reply.ERR }
      }
      is(Cmd.BAD) { reply := Reply.ERR }
      default {} // empty line: no reply
    }
    replyIdx := 0
    cmd      := Cmd.NONE
    acc      := 0
    sawDigit := False
    fields   := 0
  }

  def hexChar(n: UInt): Bits = Mux(n < 10, n.resize(8) + C('0'), n.resize(8) + C('A') - 10).asBits
  def ch(c: Char): Bits      = B(c.toInt, 8 bits)

  val tx   = uart.io.write
  val char = Bits(8 bits)
  val last = Bool()
  char := ch('\n')
  last := False
  switch(reply) {
    is(Reply.OK) {
      char := replyIdx.mux(0 -> ch('O'), 1 -> ch('K'), 2 -> ch('\r'), default -> ch('\n'))
      last := replyIdx === 3
    }
    is(Reply.ERR) {
      char := replyIdx.mux(0 -> ch('?'), 1 -> ch('\r'), default -> ch('\n'))
      last := replyIdx === 2
    }
    is(Reply.DATA) {
      val nib = replyData.subdivideIn(4 bits).reverse // most significant first
      char := Mux(replyIdx < 8, hexChar(nib(replyIdx.resize(3)).asUInt), Mux(replyIdx === 8, ch('\r'), ch('\n')))
      last := replyIdx === 9
    }
    default {}
  }
  tx.valid   := busy
  tx.payload := char
  when(tx.fire) {
    replyIdx := replyIdx + 1
    when(last) { reply := Reply.NONE }
  }
}

case class RegWrite() extends Bundle {
  val address = UInt(8 bits)
  val data    = Bits(32 bits)
}
