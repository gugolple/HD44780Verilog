`define LEDARRAY 7
`define LEDARRAYLAST `LEDARRAY-1
module top (
  input clk,
  input rst,
  output [`LEDARRAYLAST:0] led
);


genvar i;
for (i = 0; i < `LEDARRAY; i = i + 1)
  begin
    if (i&1) begin
      assign led[i] = rst;
    end else begin
      assign led[i] = ~rst;
    end
  end

endmodule
