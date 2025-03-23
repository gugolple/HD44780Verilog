`define LEDARRAY 6
`define LEDARRAYLAST `LEDARRAY-1
`define HD44780BUS 4
module top (
  input clk,
  input rst,
  output [`LEDARRAYLAST:0] led,
  output e,
  output rs,
  output [`HD44780BUS-1:0]db
);

wire clk250khz;
clockdivider 
  #(
    .CLOCK_COUNT(56)
  ) clkdiv250khz (
    .clk(clk), 
    .rst(rst),
    .clkdvd(clk250khz)
  );


hd44780 hd44780drv1 (
    .clk(clk250khz),
    .rst(rst),
    .e(e),
    .rs(rs),
    .db(db)
);
endmodule
