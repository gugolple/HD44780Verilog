module counter
#(
  // Short config sets the module to work in 4 bit wide
  parameter COUNT = 6,
  parameter RESET = 1
)
(
  input clk,
  input rst,
  output reg flag
);
`define REG_WIDTHC $clog2(COUNT)
reg [`REG_WIDTHC-1:0]CNT;
always @(posedge clk, negedge rst) begin
  if (!rst) begin
    CNT <= { `REG_WIDTHC {1'b0}};
    flag <= 1'b0;
  end else begin
    // We have to remove one because 0 is valid
    if (CNT == (COUNT-1)) begin
      if (RESET) begin
        CNT <= { `REG_WIDTHC {1'b0}};
      end
      flag <= 1'b1;
    end else begin
      CNT <= CNT + 1;
      flag <= 1'b0;
    end
  end
end
endmodule
