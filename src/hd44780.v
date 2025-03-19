`define LONG_BUS 8
`define SHORT_BUS 4
module hd44780 
(
  output rs,
  output rw,
  output e,
  output [BUS_WIDTH-1:0] db
);
// Short config sets the module to work in 4 bit wide
parameter BUS_WIDTH = 8;


endmodule