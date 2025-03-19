module clockdivider 
(
  input clk,
  input rst,
  output reg clkdvd
);
// Short config sets the module to work in 4 bit wide
parameter CLOCK_COUNT = 6;
`define TGT_CLOCK_COUNT CLOCK_COUNT/2
`define REG_WIDTH $clog2(CLOCK_COUNT)
reg [`REG_WIDTH-1:0]CNT;
always @(posedge clk, negedge rst) begin
  if (!rst) begin
    CNT <= { `REG_WIDTH {1'b0}};
    clkdvd <= 0;
  end else begin
    if (CNT == `TGT_CLOCK_COUNT) begin
      CNT <= { `REG_WIDTH {1'b0}};
      clkdvd <= ~clkdvd;
    end else begin
      CNT <= CNT + 1;
    end
  end
end
endmodule