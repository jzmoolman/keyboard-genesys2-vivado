
module Top(
  input  clock,
         reset,
         io_PS2Clk,
         io_PS2Data,
  output io_tx
);

  wire        _uart_tx_ready;
  wire        _uart_buf_con_tstart;
  wire [7:0]  _uart_buf_con_tbus;
  wire [31:0] _conv_io_O;
  wire [15:0] _uut_keycode;
  wire        _uut_oflag;
  reg         start;
  reg  [15:0] keycodev;
  reg  [2:0]  bcount;
  reg         cn;
  reg  [15:0] keycode_b;
  always @(posedge clock) begin
    if (reset) begin
      start <= 1'h0;
      keycodev <= 16'h0;
      bcount <= 3'h0;
      cn <= 1'h0;
      keycode_b <= 16'h0;
    end
    else begin
      automatic logic _GEN = _uut_oflag & cn;
      start <= _GEN;
      if (_GEN)
        keycodev <= _uut_keycode;
      if (~(keycode_b == _uut_keycode)) begin
        automatic logic _GEN_0 = _uut_keycode[7:0] == 8'hF0;
        automatic logic _GEN_1 = _uut_keycode[15:8] == 8'hF0;
        bcount <= _GEN_0 ? 3'h0 : _GEN_1 ? 3'h5 : 3'h2;
        cn <=
          ~_GEN_0
          & (_GEN_1
               ? _uut_keycode != keycodev
               : {8'h0, _uut_keycode[7:0]} != keycodev | keycodev[15:8] == 8'hF0);
      end
      keycode_b <= _uut_keycode;
    end
  end // always @(posedge)
  PS2Receiver uut (
    .clk     (clock),
    .kclk    (io_PS2Clk),
    .kdata   (io_PS2Data),
    .keycode (_uut_keycode),
    .oflag   (_uut_oflag)
  );
  bin2ascii conv (
    .clock (clock),
    .reset (reset),
    .io_I  (keycodev),
    .io_O  (_conv_io_O)
  );
  uart_buf_con uart_buf_con (
    .clk    (clock),
    .bcount (bcount),
    .tbuf   (_conv_io_O),
    .start  (start),
    .ready  (/* unused */),
    .tstart (_uart_buf_con_tstart),
    .tready (_uart_tx_ready),
    .tbus   (_uart_buf_con_tbus)
  );
  uart_tx uart_tx (
    .clk   (clock),
    .tbus  (_uart_buf_con_tbus),
    .start (_uart_buf_con_tstart),
    .tx    (io_tx),
    .ready (_uart_tx_ready)
  );
endmodule

module TopWrapper(
  input  clk_p,
         clk_n,
         reset,
         PS2Data,
         PS2Clk,
  output tx
);

  wire _ibufds_O;
  IBUFDS #(
    .DIFF_TERM("FALSE"),
    .IBUF_LOW_PWR("TRUE"),
    .IOSTANDARD("LVDS")
  ) ibufds (
    .O  (_ibufds_O),
    .I  (clk_p),
    .IB (clk_n)
  );
  Top top (
    .clock      (_ibufds_O),
    .reset      (~reset),
    .io_PS2Clk  (PS2Clk),
    .io_PS2Data (PS2Data),
    .io_tx      (tx)
  );
endmodule

