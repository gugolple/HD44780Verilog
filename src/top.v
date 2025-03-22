`define LEDARRAY 6
`define LEDARRAYLAST `LEDARRAY-1
`define HD44780BUS 8
module top (
  input clk,
  input rst,
  output [`LEDARRAYLAST:0] led,
  output e,
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

wire clk1khz;
clockdivider 
  #(
    .CLOCK_COUNT(50000)
  ) clkdiv1khz (
    .clk(clk500khz), 
    .rst(rst),
    .clkdvd(clk1khz)
  );

wire clk500hz;
clockdivider 
  #(
    .CLOCK_COUNT(2)
  ) clkdiv500hz (
    .clk(clk1khz), 
    .rst(rst),
    .clkdvd(clk500hz)
  );

wire clk250hz;
clockdivider 
  #(
    .CLOCK_COUNT(2)
  ) clkdiv250hz (
    .clk(clk500hz), 
    .rst(rst),
    .clkdvd(clk250hz)
  );

wire clk125hz;
clockdivider 
  #(
    .CLOCK_COUNT(2)
  ) clkdiv125hz (
    .clk(clk250hz), 
    .rst(rst),
    .clkdvd(clk125hz)
  );

assign e = clk1khz;
assign led[0] = clk1khz;
assign rs = clk500hz;
assign led[1] = clk500hz;
assign rw = clk250hz;
assign led[2] = clk250hz;
assign led[3] = clk125hz;
assign led[5] = clk500khz;

genvar i;
for(i=0; i<`HD44780BUS ; i=i+1) begin : fordb
  assign db[i] = clk125hz;
end

//hd44780 hd44780drv1 (
//    .e(e),
//    .db(db)
//  );
endmodule
