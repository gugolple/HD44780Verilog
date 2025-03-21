//8 bit mode
`define BUS_WIDTH 4
module hd44780 
(
  input clk,
  output e,
  output rs,
  output [`BUS_WIDTH-1:0] db
);
`define MEMDEPTH 16
`define MEMWIDTH 16
reg [`MEMWIDTH-1:0] 	mem [0:`MEMDEPTH];

`define DATAMEMWIDTH 8
`define DATAMEMDEPTH 128
reg [`DATAMEMWIDTH-1:0] 	data [0:`DATAMEMDEPTH];

// ROM initialization
initial begin
  $readmemh("hd44780.mem", mem);
  $readmemh("hd44780data.mem", data);
end

// Startup sequence


endmodule