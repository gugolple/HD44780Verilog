module clockdivider
#(
  // This tells me how many pulses shall each half be long
  parameter TGT_PULSE = 4
)
(
  input clk,
  input rst,
  output reg clkdvd
);
`define REG_WIDTH $rtoi($ceil($clog2($itor(TGT_PULSE))))
reg [`REG_WIDTH-1:0]CNT;
always @(posedge clk, negedge rst) begin
  if (!rst) begin
    CNT <= { `REG_WIDTH {1'b0}};
    clkdvd <= 0;
  end else begin
    if (CNT == (TGT_PULSE-1)) begin
      clkdvd <= ~clkdvd;
      CNT <= { `REG_WIDTH {1'b0}};
    end else begin
      CNT <= CNT + 1;
    end
  end
end
endmodule