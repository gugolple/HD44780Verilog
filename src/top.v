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

wire clk500khz;
clockdivider 
  #(
    .CLOCK_COUNT(54)
  ) clkdiv500khz (
    .clk(clk), 
    .rst(rst),
    .clkdvd(clk500khz)
  );


hd44780 hd44780drv1 (
    .clk(clk500khz),
    .e(e),
    .rs(rs),
    .db(db)
);
endmodule
