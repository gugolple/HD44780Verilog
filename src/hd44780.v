//8 bit mode
`define BUS_WIDTH 4
module hd44780 
(
  input clk,
  input rst,
  output e,
  output rs,
  output [`BUS_WIDTH-1:0] db
);

// Data memory definitions
`define DATAMEMWIDTH 8
`define DATAMEMDEPTH 128
reg [`DATAMEMWIDTH-1:0] data [0:`DATAMEMDEPTH-1];

// State Machine definitions
`define SMDEPTH 16
`define SMDEPTHBITS $clog2(`SMDEPTH)
`define SMWIDTH 16
reg [`SMWIDTH-1:0] mem [0:`SMDEPTH];
reg [`SMWIDTH-1:0] memdata;
reg [`SMDEPTHBITS-1:0] memaddress;

always @* begin
  memdata <= mem[memaddress];
end

// State machine next address bits
// 15
`define SMNAS `SMWIDTH-1
// 15 - 5 + 1 = 12
`define SMNAE `SMNAS - `SMDEPTHBITS +1
// State machine CMD bits
`define SMCMDW 5
// 11
`define SMCMDS `SMNAE -1
// 11 - 5 + 1 = 7
`define SMCMDE `SMCMDS - `SMCMDW + 1
// State machine counter selector
`define SMCNTW 2
// 6
`define SMCNTS `SMCMDE -1
// 6 - 2 + 1 = 5
`define SMCNTE `SMCNTS - `SMCNTW + 1


// Current next instruction 4 bits, 16 instructions
wire [`SMDEPTHBITS:0] SMNEXT_ADDRESS;
// 4 highest bits
assign SMNEXT_ADDRESS = memdata[`SMNAS:`SMNAE];

// Current OUTPUTS of instruction
wire [5:0] SMCMD;
assign SMCMD = memdata[`SMCMDS:`SMCMDE];
assign rs = SMCMD[5];
assign e = SMCMD[4];
assign db = SMCMD[3:0];

// Clock counter setting, 2 bits, 4 possibilities
wire [1:0] SMCLK;
assign SMCLK = memdata[`SMCNTS:`SMCNTE];

// Clock selector
wire [2**`SMCNTW:0] demuxclkw;
demux #(
    .BITS(`SMCNTW)
  ) demuxclk (
    .val(SMCLK),
    .sel(demuxclkw)
  );

// Clock dividers for the waits

wire counterwaitinstw;
counter #(
    .COUNT(2)
  )counterwaitinst (
    .clk(clk),
    .rst(rst),
    .flag(counterwaitinstw)
  );

wire allflags; // This will manage the next flag
assign allflags = counterwaitinstw & demuxclkw[0];

// Initialization
initial begin
  $readmemb("hd44780sm.mem", mem);
  $readmemh("hd44780data.mem", data);
end

// Logic for State Machine
always @(posedge allflags, negedge rst) begin
  if (!rst) begin
    // Start at address 0
    memaddress <= {`SMDEPTHBITS {1'b0} };
  end else begin
    memaddress <= SMNEXT_ADDRESS;
  end
end

endmodule
