module bin2ascii(
  input         clock,
                reset,
  input  [15:0] io_I,
  output [31:0] io_O
);

  reg [7:0] O_r_0;
  reg [7:0] O_r_1;
  reg [7:0] O_r_2;
  reg [7:0] O_r_3;
  always @(posedge clock) begin
    if (reset) begin
      O_r_0 <= 8'h0;
      O_r_1 <= 8'h0;
      O_r_2 <= 8'h0;
      O_r_3 <= 8'h0;
    end
    else begin
      automatic logic       _GEN = io_I[15:12] < 4'hA;
      automatic logic [7:0] _GEN_0 = {4'h0, io_I[15:12]};
      O_r_0 <= _GEN ? _GEN_0 + 8'h30 : _GEN_0 + 8'h37;
      O_r_1 <= _GEN ? _GEN_0 + 8'h30 : _GEN_0 + 8'h37;
      O_r_2 <= _GEN ? _GEN_0 + 8'h30 : _GEN_0 + 8'h37;
      O_r_3 <= _GEN ? _GEN_0 + 8'h30 : _GEN_0 + 8'h37;
    end
  end // always @(posedge)
  assign io_O = {O_r_3, O_r_2, O_r_1, O_r_0};
endmodule

// external module uart_buf_con

// external module uart_tx

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
        bcount <= _GEN_0 ? 3'h0 : _GEN_1 ? 3'h5 : 3'h3;
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
    .IOSTANDARD("DEFAULT")
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

module PS2Receiver(
    input clk,
    input kclk,
    input kdata,
    output reg [15:0] keycode=0,
    output reg oflag
    );

    wire kclkf, kdataf;
    reg [7:0]datacur=0;
    reg [7:0]dataprev=0;
    reg [3:0]cnt=0;
    reg flag=0;

debouncer #(
    .COUNT_MAX(76),
    .COUNT_WIDTH(7)
) db_clk(
    .clk(clk),
    .I(kclk),
    .O(kclkf)
);
debouncer #(
   .COUNT_MAX(76),
   .COUNT_WIDTH(7)
) db_data(
    .clk(clk),
    .I(kdata),
    .O(kdataf)
);

always@(negedge(kclkf))begin
    case(cnt)
    0:;//Start bit
    1:datacur[0]<=kdataf;
    2:datacur[1]<=kdataf;
    3:datacur[2]<=kdataf;
    4:datacur[3]<=kdataf;
    5:datacur[4]<=kdataf;
    6:datacur[5]<=kdataf;
    7:datacur[6]<=kdataf;
    8:datacur[7]<=kdataf;
    9:flag<=1'b1;
    10:flag<=1'b0;

    endcase
        if(cnt<=9) cnt<=cnt+1;
        else if(cnt==10) cnt<=0;
end

reg pflag;
always@(posedge clk) begin
    if (flag == 1'b1 && pflag == 1'b0) begin
        keycode <= {dataprev, datacur};
        oflag <= 1'b1;
        dataprev <= datacur;
    end else
        oflag <= 'b0;
    pflag <= flag;
end

endmodule

module debouncer(
    input clk,
    input I,
    output reg O
    );
    parameter COUNT_MAX=255, COUNT_WIDTH=8;
    reg [COUNT_WIDTH-1:0] count;
    reg Iv=0;
    always@(posedge clk)
        if (I == Iv) begin
            if (count == COUNT_MAX)
                O <= I;
            else
                count <= count + 1'b1;
        end else begin
            count <= 'b0;
            Iv <= I;
        end

endmodule

// ----- 8< ----- FILE "./uart_buf_con.v" ----- 8< -----

module uart_buf_con(
    input             clk,
    input      [ 2:0] bcount,
    input      [31:0] tbuf,
    input             start,
    output            ready,
    output reg        tstart=0,
    input             tready,
    output reg [ 7:0] tbus=0
    );
    reg [2:0] sel=0;
    reg [31:0] pbuf=0;
    reg running=0;
    initial tstart <= 'b0;
    initial tbus <= 'b0;
    always@(posedge clk)
        if (tready == 1'b1) begin
            if (running == 1'b1) begin
                if (sel == 4'd1) begin
                    running <= 1'b0;
                    sel <= bcount + 2'd2;
                end else begin
                    sel <= sel - 1'b1;
                    tstart <= 1'b1;
                    running <= 1'b1;
                end
            end else begin
                if (bcount != 2'b0) begin
                    pbuf <= tbuf;
                    tstart <= start;
                    running <= start;
                    sel <= bcount + 2'd2;
                end
            end
        end else
            tstart <= 1'b0;
    assign ready = ~running;
    always@(sel, pbuf)
        case (sel)
        1: tbus <= 8'd13;
        2: tbus <= 8'd10;
        3: tbus <= pbuf[7:0];
        4: tbus <= pbuf[15:8];
        5: tbus <= 8'd32;
        6: tbus <= pbuf[23:16];
        7: tbus <= pbuf[31:24];
        default: tbus <= 8'd0;
        endcase
endmodule

// ----- 8< ----- FILE "./uart_tx.v" ----- 8< -----


module uart_tx(
    input       clk   ,
    input [7:0] tbus  ,
    input       start,
    output      tx    ,
    output      ready
    );
    parameter CD_MAX=10416, CD_WIDTH=16;
    reg [CD_WIDTH-1:0] cd_count=0;
    reg [3:0] count=0;
    reg running=0;
    reg [10:0] shift=11'h7ff;
    always@(posedge clk) begin
        if (running == 1'b0) begin
            shift <= {2'b11, tbus, 1'b0};
            running <= start;
            cd_count <= 'b0;
            count <= 'b0;
        end else if (cd_count == CD_MAX) begin
            shift <= {1'b1, shift[10:1]};
            cd_count <= 'b0;
            if (count == 4'd10) begin
                running <= 1'b0;
                count <= 'b0;
            end
            else
                count <= count + 1'b1;
        end else
            cd_count <= cd_count + 1'b1;
    end
    assign tx = (running == 1'b1) ? shift[0] : 1'b1;
    assign ready = ((running == 1'b0 && start == 1'b0) || (cd_count == CD_MAX && count == 4'd10)) ? 1'b1 : 1'b0;
endmodule


