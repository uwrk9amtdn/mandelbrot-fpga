package fpgalib

import spinal.core._
import spinal.lib._

/** Open-drain line: `drive` pulls it low, otherwise it floats high (pull-up). */
case class OpenDrain() extends Bundle with IMasterSlave {
  val read  = Bool() // line level
  val drive = Bool() // true = pull low
  override def asMaster(): Unit = { in(read); out(drive) }
}

case class I2cWrite() extends Bundle {
  val device = UInt(7 bits)
  val reg    = Bits(8 bits)
  val data   = Bits(8 bits)
}

/** Minimal I2C master that only does register writes: START, device+W, reg, data, STOP.
  * `rsp` reports whether all three bytes were acknowledged. No clock stretching, no arbitration.
  * Replaces i2c/i2c_bit_ctrl.sv + i2c_byte_ctrl.sv, which supported reads the setup never used.
  */
class I2cWriter(clkHz: Double, sclHz: Double = 100e3) extends Component {
  val io = new Bundle {
    val cmd = slave Stream (I2cWrite())
    val rsp = master Flow (Bool()) // true = acknowledged
    val scl = master(OpenDrain())
    val sda = master(OpenDrain())
  }

  // Each SCL period is 4 quarters; one tick per quarter.
  val quarterCycles = scala.math.max(1, scala.math.ceil(clkHz / sclHz / 4).toInt)
  val tick          = CounterFreeRun(quarterCycles).willOverflow

  // 27 bits = 3 bytes, each followed by an ACK slot where the master releases SDA.
  val nBits = 27
  object Phase extends SpinalEnum { val IDLE, START, BITS, STOP = newElement() }
  val phase   = RegInit(Phase.IDLE)
  val quarter = Reg(UInt(2 bits)) init (0)
  val bitIdx  = Reg(UInt(5 bits)) init (0)
  val shift   = Reg(Bits(nBits bits))
  val acked   = Reg(Bool())

  val sclHigh = RegInit(True)
  val sdaHigh = RegInit(True)
  io.scl.drive := !sclHigh
  io.sda.drive := !sdaHigh

  io.cmd.ready := phase === Phase.IDLE
  io.rsp.valid := False
  io.rsp.payload := acked

  def byte(b: Bits) = b ## True // data then ACK slot released
  when(io.cmd.fire) {
    shift   := byte(io.cmd.device.asBits ## False) ## byte(io.cmd.reg) ## byte(io.cmd.data)
    acked   := True
    quarter := 0
    bitIdx  := 0
    phase   := Phase.START
  }

  when(tick && phase =/= Phase.IDLE) {
    quarter := quarter + 1
    switch(phase) {
      is(Phase.START) { // SDA falls while SCL is high, then SCL falls
        switch(quarter) {
          is(0) { sdaHigh := True; sclHigh := True }
          is(1) { sdaHigh := False }
          is(2) { sclHigh := False }
          is(3) { phase := Phase.BITS }
        }
      }
      is(Phase.BITS) {
        switch(quarter) {
          is(0) { sdaHigh := shift.msb }       // SCL is low: change SDA
          is(1) { sclHigh := True }
          is(2) {                              // SCL is high: sample the ACK slots
            when(bitIdx === 8 || bitIdx === 17 || bitIdx === 26) {
              when(io.sda.read) { acked := False }
            }
          }
          is(3) {
            sclHigh := False
            shift   := shift |<< 1
            bitIdx  := bitIdx + 1
            when(bitIdx === nBits - 1) { phase := Phase.STOP }
          }
        }
      }
      is(Phase.STOP) { // SDA rises while SCL is high
        switch(quarter) {
          is(0) { sdaHigh := False }
          is(1) { sclHigh := True }
          is(2) { sdaHigh := True }
          is(3) {
            phase        := Phase.IDLE
            io.rsp.valid := True
          }
        }
      }
    }
  }
}
