`define OUTWIDTH 2**BITS
module demux
#(
  parameter BITS = 3
)
(
  input [BITS-1:0]val,
  output reg [`OUTWIDTH:0]sel
);

always @* begin
  sel = {`OUTWIDTH {1'b0}};
  sel[val] = 1'b1;
end

endmodule