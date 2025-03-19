`define LEDARRAY 7
`define LEDARRAYLAST `LEDARRAY-1
module top (
  input clk,
  input rst,
  output [`LEDARRAYLAST:0] led
);

`define CLKDIVSIZE 19
`define CLKDIVLAST `CLKDIVSIZE-1
reg [`CLKDIVLAST:0] clkdivreg;
wire clkdiv;
always @ (posedge clk) begin
  if (!rst) begin
    clkdivreg <= { `CLKDIVSIZE { 1'b0 }};
  end else begin
    clkdivreg <= clkdivreg + 1;
  end
end

wire [`LEDARRAY:0]CONN;
assign CONN[0] = clkdivreg[`CLKDIVLAST];
generate
  genvar i;
  for (i = 0; i < `LEDARRAY; i = i + 1) begin : ckd
      clockdivider
      #(
        .CLOCK_COUNT(4)
      ) (
        .clk(CONN[i]),
        .rst(rst),
        .clkdvd(CONN[i+1])
      );
    end
endgenerate

for (i = 0; i < `LEDARRAY; i = i + 1)
begin
  assign led[i] = CONN[i+1];
end

endmodule
