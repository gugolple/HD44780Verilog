`define LEDARRAY 6
`define LEDARRAYLAST `LEDARRAY-1
`define EXTERNALDBSIZE 8
`define HD44780BUS 8
module top (
  input clk,
  input rst,
  output [`LEDARRAYLAST:0] led,
  output e,
  output rs,
  output [`EXTERNALDBSIZE-1:0]db
);


debouncer #(.DIV_CNT(20)) inc_btn(
	.clk(clk),
	.btn(rst),
	.out(debrst)
);

wire clk250khz;
clockdivider 
  #(
    .CLOCK_COUNT(60)
  ) clkdiv250khz (
    .clk(clk), 
    .rst(debrst),
    .clkdvd(clk250khz)
  );

wire busy;
wire [7:0]idataaddr;
wire [7:0]idatares;
hd447808b hd44780drv1 (
    .clk(clk250khz),
    .rst(debrst),
    .trg(1'b0),
    .busy(busy),
    .e(e),
    .rs(rs),
    .db(db[`EXTERNALDBSIZE-1:`EXTERNALDBSIZE-`HD44780BUS]),
    .idata(idatares),
    .idataaddr(idataaddr)
);
assign idatares = "a" + idataaddr;
assign led[0] = !busy;
assign led[2] = !debrst;
assign led[4] = !rst;
endmodule
