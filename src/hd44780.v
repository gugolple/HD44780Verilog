//8 bit mode
`define BUS_WIDTH 4
module hd44780 
(
  input clk,
  input rst,
  input trg,
  output busy,
  output reg e,
  output reg rs,
  output reg [`BUS_WIDTH-1:0] db
);
`define INST_WIDTH 8
// Startup functions
// Function Select set to 4 bits, 2 Lines
localparam [`INST_WIDTH-1:0] FS = 9'b00101000;
// Display Control set to rotate positive
localparam [`INST_WIDTH-1:0] DC = 9'b00001100;
// Entry Mode set to english
localparam [`INST_WIDTH-1:0] EM = 9'b00000110;

// Operation functions
// The two should realize the same task
// Clear Display, return to position 0
localparam [`INST_WIDTH-1:0] CD = 9'b00000001;
// Set DDRam address to 0
localparam [`INST_WIDTH-1:0] SDL1 = 8'h80; // 0x80 + 0x00
localparam [`INST_WIDTH-1:0] SDL2 = 8'hC0; // 0x80 + 0x40
localparam [`INST_WIDTH-1:0] SDL3 = 8'h90; // 0x80 + 0x10
localparam [`INST_WIDTH-1:0] SDL4 = 8'hD0; // 0x80 + 0x50

// Data memory definitions
`define DATAMEMWIDTH 8
`define DATAMEMDEPTH 16
`define DATAMEMADRW $clog2(`DATAMEMDEPTH)
reg [`INST_WIDTH-1:0] sdl;
reg [`DATAMEMWIDTH-1:0] dataldata;
reg [2:0] datalsel;
reg [`DATAMEMWIDTH-1:0] datal1 [0:`DATAMEMDEPTH-1];
reg [`DATAMEMWIDTH-1:0] datal2 [0:`DATAMEMDEPTH-1];
reg [`DATAMEMWIDTH-1:0] datal3 [0:`DATAMEMDEPTH-1];
reg [`DATAMEMWIDTH-1:0] datal4 [0:`DATAMEMDEPTH-1];

always @(negedge clk) begin
  if (datalsel == 0) begin
    sdl = SDL1;
    dataldata = datal1[counterdataramaddress];
  end else if (datalsel == 1) begin
    sdl = SDL2;
    dataldata = datal2[counterdataramaddress];
  end else if (datalsel == 2) begin
    sdl = SDL3;
    dataldata = datal3[counterdataramaddress];
  end else if (datalsel == 3) begin
    sdl = SDL4;
    dataldata = datal4[counterdataramaddress];
  end
end

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
    .COUNT(20)
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
// 200ms wait
wire counterwait200ms;
counter #(
    .COUNT(50000)
  )counterwait100m (
    .clk(clk),
    .rst(rst),
    .flag(counterwait200ms)
  );

assign waitclk = 
  (counterwaitinstenable & demuxclksel[0]) 
  | (counterwaitinstprocess & demuxclksel[1])
  | (counterwait10ms & demuxclksel[2])
  | (counterwait200ms & demuxclksel[3]);

assign busy = trigger;

// Initialization
initial begin
  $readmemh("hd44780datal1.mem", datal1);
  $readmemh("hd44780datal2.mem", datal2);
  $readmemh("hd44780datal3.mem", datal3);
  $readmemh("hd44780datal4.mem", datal4);
end

`define COUNTERSTATEW 4
reg [`COUNTERSTATEW-1:0] counterstate;
reg [`DATAMEMADRW-1:0] counterdataramaddress;
reg trigger;
reg rdy;
reg clks;
always @(posedge clk, negedge rst) begin
  if (!rst) begin
    trigger = 1'b1;
    counterstate = {`COUNTERSTATEW {1'b0}};
    demuxclkval = 3; //200ms, restart wait
    iact = 1'b0;
    rs = 1'b0;
    e = 1'b0;
    db = {`BUS_WIDTH {1'b0}};
    demuxclkval = 3;
    rdy = 1'b0;
    datalsel = 0;
  end else begin
    if (!rdy) begin
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
          counterstate = 0; // Reset counter
        end
      end
    end else begin
      // Capture the trigger request
      if (trg) begin
        trigger = 1'b1;
      end
      if (trigger) begin
        if (datalsel != 4) begin
          if (counterstate == 0) begin
            if (iact) begin
              iact = 1'b0;
            end else if (waitclk) begin
              // Once wait is reached, set to Set DDRam Address, this time send the two
              // halfs, this is only top
              iact = 1'b1; // Set reset for counters
              counterdataramaddress = 0;
              e = 1'b1;
              rs = 1'b0;
              db = sdl[7:4];
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
              demuxclkval = 0;
              counterstate = counterstate + 1;
            end
          end else if (counterstate == 2) begin
            if (iact) begin
              iact = 1'b0;
            end else if (waitclk) begin
              // Once wait is reached, set to Set DDRam Address, this time send the two
              // halfs, this is only bottom
              iact = 1'b1; // Set reset for counters
              e = 1'b1;
              rs = 1'b0;
              db = sdl[3:0];
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
              demuxclkval = 1;
              counterstate = counterstate + 1;
            end
          // Configured for printing, restarted at address 0
          // Now loop 16 times
          end else if (counterstate == 4) begin
            if (iact) begin
              iact = 1'b0;
            end else if (waitclk) begin
              iact = 1'b1; // Set reset for counters
              e = 1'b1;
              rs = 1'b1;
              db = dataldata[7:4];
              demuxclkval = 0;
              iact = 1'b1;
              counterstate = counterstate + 1;
            end
          end else if (counterstate == 5) begin
            if (iact) begin
              iact = 1'b0;
            end else if (waitclk) begin
              iact = 1'b1; // Set reset for counters
              e = 1'b0;
              demuxclkval = 1;
              counterstate = counterstate + 1;
            end
          end else if (counterstate == 6) begin
            if (iact) begin
              iact = 1'b0;
            end else if (waitclk) begin
              iact = 1'b1; // Set reset for counters
              e = 1'b1;
              rs = 1'b1;
              db = dataldata[3:0];
              demuxclkval = 0;
              iact = 1'b1;
              counterstate = counterstate + 1;
            end
          end else if (counterstate == 7) begin
            if (iact) begin
              counterdataramaddress = counterdataramaddress + 1;
              iact = 1'b0;
            end else if (waitclk) begin
              iact = 1'b1; // Set reset for counters
              e = 1'b0;
              demuxclkval = 1;
              counterstate <= 4;
              if (counterdataramaddress == `DATAMEMDEPTH) begin
                counterstate <= 0;
                datalsel = datalsel + 1;
              end
            end
          end
        end else begin
          trigger = 0;
          datalsel = 0;
        end
      end
    end
  end
end

endmodule
