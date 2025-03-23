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

wire drst;
wire debfloat;
wire debrst;
debouncer
  #(
    .COUNT(10)
  ) debouncerst (
    .clk(clk),
    .in(rst),
    .floating(debfloat),
    .flag(debrst)
  );
assign drst = !debfloat | debrst;

wire clk250khz;
clockdivider 
  #(
    .CLOCK_COUNT(56)
  ) clkdiv250khz (
    .clk(clk), 
    .rst(rst),
    .clkdvd(clk250khz)
  );

wire busy;
hd44780 hd44780drv1 (
    .clk(clk250khz),
    .rst(drst),
    .trg(1'b0),
    .busy(busy),
    .e(e),
    .rs(rs),
    .db(db)
);
assign led[0] = !busy;
assign led[1] = !debfloat;
assign led[2] = !debrst;
assign led[3] = !drst;
assign led[4] = !rst;
endmodule
