import chisel3._
import _root_.circt.stage.ChiselStage
import chisel3.experimental._ // To enable experimental features
import chisel3.util.HasBlackBoxResource

class IBUFDS extends BlackBox(Map("DIFF_TERM" -> "FALSE",
  "IBUF_LOW_PWR" -> "TRUE",
  "IOSTANDARD" -> "DEFAULT")) {
  val io = IO(new Bundle {
    val O = Output(Clock())
    val I = Input(Clock())
    val IB = Input(Clock())
  })
}

class PS2Receiver extends BlackBox with HasBlackBoxResource {
  val io = IO(new Bundle {
    val clk = Input(Clock())
    val kclk  = Input(Clock())
    val kdata =  Input(Bool())
    val keycode = Output(UInt(16.W))
    val oflag = Output(Bool())
  })
  addResource("/PS2Receiver.v")
  addResource("/debouncer.v")
}

class uart_tx extends BlackBox with HasBlackBoxResource {
  val io = IO(new Bundle {
    val clk = Input(Clock())
    val tbus = Input(UInt(8.W))
    val start = Input(Bool())
    val tx = Output(Bool())
    val ready = Output(Bool())
  })
  addResource("/uart_tx.v")
}

class uart_buf_con extends BlackBox with HasBlackBoxResource {
  val io = IO(new Bundle {
    val clk = Input(Clock())
    val bcount = Input(UInt(3.W))
    val tbuf = Input(UInt(32.W))
    val start = Input(Bool())
    val ready = Output(Bool())
    val tstart = Output(Bool()) // reg
    val tready = Input(Bool())
    val tbus = Output(UInt(8.W)) // reg
  })
  addResource("/uart_buf_con.v")
}

class TopWrapper extends RawModule {
  val clk_p = IO(Input(Clock()))
  val clk_n = IO(Input(Clock()))
  val reset = IO(Input(Bool()))
  val PS2Data = IO(Input(Bool()))
  val PS2Clk = IO(Input(Clock()))
  val tx = IO(Output(Bool()))

  val clk = Wire(Clock())
  val ibufds = Module(new IBUFDS)
  ibufds.io.I := clk_p
  ibufds.io.IB := clk_n
  clk := ibufds.io.O

  val top = withClockAndReset(clk, ~reset) {Module( new Top) }
  top.io.PS2Clk := PS2Clk;
  top.io.PS2Data := PS2Data;
  tx := top.io.tx
}

class Top extends Module {
  val io = IO(new Bundle {
    val PS2Clk = Input(Clock())
    val PS2Data = Input(Bool())
    val tx = Output(Bool())
  })

  val tready = Wire(Bool())
  val ready = Wire(Bool())
  val tstart = Wire(Bool())
  val start  = RegInit(false.B)
  val tbuf = Wire(UInt(32.W))
  val keycodev = RegInit(0.U(16.W))
  val keycode = Wire(UInt(16.W))
  val tbus = Wire(UInt(8.W))
  val bcount = RegInit(0.U(3.W))
  val flag = Wire(Bool())
  val cn = RegInit(false.B)

  val uut = Module(new PS2Receiver)
  uut.io.clk := clock
  uut.io.kclk := io.PS2Clk
  uut.io.kdata := io.PS2Data
  keycode := uut.io.keycode
  flag := uut.io.oflag

  val keycode_b = RegInit(0.U(16.W))

  when (keycode_b =/= keycode) {
    keycode_b := keycode
    when (keycode(7,0) === "hf0".U) {
      cn := false.B
      bcount := 0.U(3.W)
    } .elsewhen(keycode(15,8) === "hf0".U(8.W)) {
      cn := keycode =/= keycodev
      bcount := 5.U(3.W)
    } .otherwise {
      cn := keycode(7,0) =/= keycodev || keycodev(15,8) === "hf0".U(8.W)
      bcount := 3.U(2.W)
    }
  }

  when (flag === true.B && cn === true.B) {
    start := true.B;
    keycodev :=  keycode;
  } .otherwise {
    start := false.B;
  }

  val conv = Module(new bin2ascii(2))
  conv.io.I := keycodev
  tbuf := conv.io.O

  val uart_buf_con = Module(new uart_buf_con)
  uart_buf_con.io.clk := clock
  uart_buf_con.io.bcount := bcount
  uart_buf_con.io.tbuf := tbuf
  uart_buf_con.io.start := start
  ready := uart_buf_con.io.ready
  tstart := uart_buf_con.io.tstart
  uart_buf_con.io.tready := tready
  tbus := uart_buf_con.io.tbus

  val uart_tx = Module(new uart_tx)
  uart_tx.io.clk := clock
  uart_tx.io.start := tstart
  uart_tx.io.tbus := tbus
  io.tx := uart_tx.io.tx
  tready := uart_tx.io.ready
}

class bin2ascii(nbytes: Int) extends Module {
  val io = IO(new Bundle {
    val I = Input(UInt((nbytes*8).W))
    val O = Output(UInt((nbytes*16).W))
  })
  //val initRegOfVec = RegInit(VecInit(Seq.fill(4)(0.U(32.W))))
  val O_r = RegInit(VecInit(Seq.fill(4)(0.U(8.W))))

  val I_w =  Wire(UInt(4.W))

  for (i <- 0 to nbytes*2-1) {
    I_w := io.I(4*i+3,4*i)
    when( I_w >= 0.U(4.W) && I_w <= 9.U(4.W)) {
      O_r(i) := 48.U(8.W) + I_w
    } .otherwise {
      O_r(i) := 55.U(8.W) + I_w
    }
  }
  io.O := O_r.asUInt
}

object Main extends App {
  println(
    ChiselStage.emitSystemVerilog(
//    ChiselStage.emitVerilog(
      gen = new TopWrapper,
      firtoolOpts = Array("-disable-all-randomization", "-strip-debug-info")
    )
  )
}
