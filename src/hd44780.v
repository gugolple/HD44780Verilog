//8 bit mode
`define BUS_WIDTH 8
module hd44780 
(
  output e,
  output [`BUS_WIDTH-1:0] db
);
`define MEMDEPTH 16
`define MEMWIDTH 16

reg [`MEMWIDTH-1:0] 	mem [0:`MEMDEPTH];

// ROM initialization
initial begin
  $readmemh("hd44780.mem", mem);
end



endmodule