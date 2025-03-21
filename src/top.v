`define LEDARRAY 7
`define LEDARRAYLAST `LEDARRAY-1
module top (
  input clk,
  input rst,
  output [`LEDARRAYLAST:0] led
);

wire [`LEDARRAY:0]CONN;
assign CONN[0] = clk;
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
  assign led[i] = ~CONN[i+1];
end

endmodule
