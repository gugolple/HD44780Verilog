`define LEDARRAY 7
`define LEDARRAYLAST `LEDARRAY-1
module top (
  input clk,
  input rst,
  output [`LEDARRAYLAST:0] led
);

wire clk500kw;
clockdivider
      #(
        .TGT_PULSE(27)
      ) clk500k (
        .clk(clk),
        .rst(rst),
        .clkdvd(clk500kw)
      );

wire [`LEDARRAY:0]CONN;
assign CONN[0] = clk;
generate
  genvar i;
  for (i = 0; i < `LEDARRAY; i = i + 1) begin : ckd
      clockdivider
      #(
        .TGT_PULSE(3)
      ) (
        .clk(CONN[i]),
        .rst(rst),
        .clkdvd(CONN[i+1])
      );
    end
endgenerate

for (i = 0; i < `LEDARRAY; i = i + 1)
begin
  assign led[i] = ~CONN[i+1];
end

endmodule
