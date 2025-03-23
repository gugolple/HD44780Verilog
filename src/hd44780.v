//8 bit mode
`define BUS_WIDTH 4
module hd44780 
(
  input clk,
  input rst,
  output reg e,
  output reg rs,
  output reg [`BUS_WIDTH-1:0] db
);
`define INST_WIDTH 8
// Startup functions
// Function Select set to 4 bits, 2 Lines
localparam [`INST_WIDTH-1:0] FS = 9'b00101000;
// Display Control set to rotate positive
localparam [`INST_WIDTH-1:0] DC = 9'b00001110;
// Entry Mode set to english
localparam [`INST_WIDTH-1:0] EM = 9'b00000110;

// Operation functions
// The two should realize the same task
// Clear Display, return to position 0
localparam [`INST_WIDTH-1:0] CD = 9'b00000001;
// Set DDRam address to 0
localparam [`INST_WIDTH-1:0] SD = 9'b10000000;

// Data memory definitions
`define DATAMEMWIDTH 8
`define DATAMEMDEPTH 128
reg [`DATAMEMWIDTH-1:0] data [0:`DATAMEMDEPTH-1];

// Clock selector
`define COUNTERSELECTORBITS 2
reg [`COUNTERSELECTORBITS-1:0] demuxclkval;
wire [2**`COUNTERSELECTORBITS:0] demuxclksel;
demux #(
    .BITS(`COUNTERSELECTORBITS)
  ) demuxclk (
    .val(demuxclkval),
    .sel(demuxclksel)
  );

// Clock dividers for the waits
reg iact;
wire irst;
assign irst = rst | iact;
wire waitclk;
//Enable activation
wire counterwaitinstenable;
counter #(
    .COUNT(2)
  )counterwaitinste (
    .clk(clk),
    .rst(rst),
    .flag(counterwaitinstenable)
  );
// Basic instruction process delay
wire counterwaitinstprocess;
counter #(
    .COUNT(20)
  )counterwaitinstp (
    .clk(clk),
    .rst(rst),
    .flag(counterwaitinstprocess)
  );
// 10ms wait
wire counterwait10ms;
counter #(
    .COUNT(2500)
  )counterwait10m (
    .clk(clk),
    .rst(rst),
    .flag(counterwait10ms)
  );
// 100ms wait
wire counterwait100ms;
counter #(
    .COUNT(25000)
  )counterwait100m (
    .clk(clk),
    .rst(rst),
    .flag(counterwait100ms)
  );

assign waitclk = 
  (counterwaitinstenable & demuxclksel[0]) 
  | (counterwaitinstprocess & demuxclksel[1])
  | (counterwait10ms & demuxclksel[2])
  | (counterwait100ms & demuxclksel[3]);

// Initialization
initial begin
  $readmemh("hd44780data.mem", data);
end

`define COUNTERSTATEW 4
reg [`COUNTERSTATEW-1:0] counterstate;
reg clks;
reg rdy;
always @(posedge clk, negedge rst) begin
  if (!rst) begin
    counterstate = {`COUNTERSTATEW {1'b0}};
    demuxclkval = 3; //100ms, restart wait
    iact = 1'b0;
    rs = 1'b0;
    e = 1'b0;
    db = {`BUS_WIDTH {1'b0}};
    demuxclkval = 3;
    rdy = 1'b0;
  end else begin
    // wait resstart
    if (counterstate == 0) begin
      if (waitclk) begin
        // Once wait is reached, set to Function Set, first only half
        iact = 1'b1; // Set reset for counters
        e = 1'b1;
        rs = 1'b0;
        db = FS[7:4];
        demuxclkval = 0;
        iact = 1'b1;
        counterstate = counterstate + 1;
      end
    end else if (counterstate == 1) begin
      if (iact) begin
        iact = 1'b0;
      end else if (waitclk) begin
        // Once wait is reached, set enable to 0, commiting instruction
        iact = 1'b1; // Set reset for counters
        e = 1'b0;
        demuxclkval = 2; // Wait for 10ms
        counterstate = counterstate + 1;
      end
    end else if (counterstate == 2) begin
      if (iact) begin
        iact = 1'b0;
      end else if (waitclk) begin
        // Once wait is reached, set to Function Set, this time send the two
        // halfs, this is only top
        iact = 1'b1; // Set reset for counters
        e = 1'b1;
        rs = 1'b0;
        db = FS[7:4];
        demuxclkval = 0;
        iact = 1'b1;
        counterstate = counterstate + 1;
      end
    end else if (counterstate == 3) begin
      if (iact) begin
        iact = 1'b0;
      end else if (waitclk) begin
        // Once wait is reached, set enable to 0, commiting instruction
        iact = 1'b1; // Set reset for counters
        e = 1'b0;
        demuxclkval = 0;
        counterstate = counterstate + 1;
      end
    end else if (counterstate == 4) begin
      if (iact) begin
        iact = 1'b0;
      end else if (waitclk) begin
        // Once wait is reached, set to Function Set, this time send the two
        // halfs, this is only bottom
        iact = 1'b1; // Set reset for counters
        e = 1'b1;
        rs = 1'b0;
        db = FS[3:0];
        demuxclkval = 0;
        iact = 1'b1;
        counterstate = counterstate + 1;
      end
    end else if (counterstate == 5) begin
      if (iact) begin
        iact = 1'b0;
      end else if (waitclk) begin
        // Once wait is reached, set enable to 0, commiting instruction
        iact = 1'b1; // Set reset for counters
        e = 1'b0;
        demuxclkval = 3; // Wait for 10ms
        counterstate = counterstate + 1;
      end
    end else if (counterstate == 6) begin
      if (iact) begin
        iact = 1'b0;
      end else if (waitclk) begin
        // Once wait is reached, set to Display Control, this time send the two
        // halfs, this is only top
        iact = 1'b1; // Set reset for counters
        e = 1'b1;
        rs = 1'b0;
        db = DC[7:4];
        demuxclkval = 0;
        iact = 1'b1;
        counterstate = counterstate + 1;
      end
    end else if (counterstate == 7) begin
      if (iact) begin
        iact = 1'b0;
      end else if (waitclk) begin
        // Once wait is reached, set enable to 0, commiting instruction
        iact = 1'b1; // Set reset for counters
        e = 1'b0;
        demuxclkval = 0;
        counterstate = counterstate + 1;
      end
    end else if (counterstate == 8) begin
      if (iact) begin
        iact = 1'b0;
      end else if (waitclk) begin
        // Once wait is reached, set to Display Control, this time send the two
        // halfs, this is only bottom
        iact = 1'b1; // Set reset for counters
        e = 1'b1;
        rs = 1'b0;
        db = DC[3:0];
        demuxclkval = 0;
        iact = 1'b1;
        counterstate = counterstate + 1;
      end
    end else if (counterstate == 9) begin
      if (iact) begin
        iact = 1'b0;
      end else if (waitclk) begin
        // Once wait is reached, set enable to 0, commiting instruction
        iact = 1'b1; // Set reset for counters
        e = 1'b0;
        demuxclkval = 1; // Wait 40 us
        counterstate = counterstate + 1;
      end
    end else if (counterstate == 10) begin
      if (iact) begin
        iact = 1'b0;
      end else if (waitclk) begin
        // Once wait is reached, set to Entry Mode, this time send the two
        // halfs, this is only top
        iact = 1'b1; // Set reset for counters
        e = 1'b1;
        rs = 1'b0;
        db = EM[7:4];
        demuxclkval = 0;
        iact = 1'b1;
        counterstate = counterstate + 1;
      end
    end else if (counterstate == 11) begin
      if (iact) begin
        iact = 1'b0;
      end else if (waitclk) begin
        // Once wait is reached, set enable to 0, commiting instruction
        iact = 1'b1; // Set reset for counters
        e = 1'b0;
        demuxclkval = 0;
        counterstate = counterstate + 1;
      end
    end else if (counterstate == 12) begin
      if (iact) begin
        iact = 1'b0;
      end else if (waitclk) begin
        // Once wait is reached, set to Entry Mode, this time send the two
        // halfs, this is only bottom
        iact = 1'b1; // Set reset for counters
        e = 1'b1;
        rs = 1'b0;
        db = EM[3:0];
        demuxclkval = 0;
        iact = 1'b1;
        counterstate = counterstate + 1;
      end
    end else if (counterstate == 13) begin
      if (iact) begin
        iact = 1'b0;
      end else if (waitclk) begin
        // Once wait is reached, set enable to 0, commiting instruction
        iact = 1'b1; // Set reset for counters
        e = 1'b0;
        demuxclkval = 1; // Wait 40 us
        counterstate = counterstate + 1;
      end
    end else if (counterstate == 14) begin
      if (iact) begin
        iact = 1'b0;
      end else if (waitclk) begin
        // Once wait is reached, set enable to 0, commiting instruction
        iact = 1'b1; // Set reset for counters
        rdy = 1'b1; // Finalized startup sequence
      end
    end
  end
end

endmodule
