`define EXPECTED_FREQ 250_000 // 250khz
`define MILLI 1_000
`define MICRO 1_000_000
`define MILLI_TO_CLOCK(t) (t*`EXPECTED_FREQ/`MILLI)
`define MICRO_TO_CLOCK(t) (t*`EXPECTED_FREQ/`MICRO)
`define POWERON_DELAY_MILLI 100
`define CLEAR_SCREEN_DELAY_MILLI 10
//8 bit mode
`define BUS_WIDTH 4
module hd44780 
(
  input clk,
  input rst,
  input trg,
  output reg busy,
  output reg e,
  output reg rs,
  output reg [`BUS_WIDTH-1:0] db
);
`define INST_WIDTH 8
// Startup functions
// Function Select set to 4 bits, 2 Lines
localparam [`INST_WIDTH-1:0] FS = `INST_WIDTH'b00101000;
// Display Control set to rotate positive
localparam [`INST_WIDTH-1:0] DC = `INST_WIDTH'b00001100;
// Entry Mode set to english
localparam [`INST_WIDTH-1:0] EM = `INST_WIDTH'b00000110;

// Operation functions
// The two should realize the same task
// Clear Display, return to position 0
localparam [`INST_WIDTH-1:0] CD = `INST_WIDTH'b00000001;
// Set DDRam address to 0
localparam [`INST_WIDTH-1:0] SDL1 = `INST_WIDTH'h80; // 0x80 + 0x00
localparam [`INST_WIDTH-1:0] SDL2 = `INST_WIDTH'hC0; // 0x80 + 0x40
localparam [`INST_WIDTH-1:0] SDL3 = `INST_WIDTH'h90; // 0x80 + 0x10
localparam [`INST_WIDTH-1:0] SDL4 = `INST_WIDTH'hD0; // 0x80 + 0x50


localparam [`INST_WIDTH-1:0]INST_DISPLAY_CLEAR   = 8'b00000001;
localparam [`INST_WIDTH-1:0]INST_RETURN_HOME     = 8'b00000010;
`define CURSOR_DIRECTION 1 // 0 - left | 1 - right
`define SHIFT_CURSOR 1 // 0 - off | 1 - on
localparam [`INST_WIDTH-1:0]INST_ENTRY_MODE      = 8'b000001`CURSOR_DIRECTION`SHIFT_CURSOR;
`define DISPLAY_ON_OFF 1 // 0 - off | 1 - on
`define CURSOR_ON_OFF 1 // 0 - off | 1 - on
`define CURSOR_BLINK 0 // 0 - off | 1 - on
localparam [`INST_WIDTH-1:0]INST_DISPLAY_CONTROL = 8'b00001`DISPLAY_ON_OFF`CURSOR_ON_OFF`CURSOR_BLINK;
// SC - RL Table:
//  0    0 Shift cursor to the left (AC-1)
//  0    1 Shift cursor to the right (AC+1)
//  1    0 Shift display to the left, cursor follows
//  1    1 Shift display to the right, cursor follows
`define DISPLAY_SHIFT_SC 0
`define DISPLAY_SHIFT_RL 0
`define DISPLAY_PAD 00
localparam [`INST_WIDTH-1:0]INST_DISPLAY_SHIFT   = 8'b0001`DISPLAY_SHIFT_SC`DISPLAY_SHIFT_RL`DISPLAY_PAD;
// Hardware configuration of unit
`define DATA_LENGTH    0 //0 - 4 | 1 - 8 //Bits for comm
`define DISPLAY_LINES  1 //0 - 1 | 1 - 2
`define CHARACTER_FONT 0 
`define FUNCTION_SET_PAD 00
localparam [`INST_WIDTH-1:0]INST_FUNCTION_SET    = 8'b001`DATA_LENGTH`DISPLAY_LINES`CHARACTER_FONT`FUNCTION_SET_PAD;
localparam [`INST_WIDTH-1:0]INST_SET_CGRAM_ADDR  = 8'b01000000;
localparam [`INST_WIDTH-1:0]INST_SET_DDRAM_ADDR  = 8'b10000000;

// Data memory definitions
`define DATAMEMWIDTH 8
`define DATAMEMDEPTH 16
`define DATAMEMDEPTHMAX 15
`define DATAMEMADRW $clog2(`DATAMEMDEPTH)
wire [`INST_WIDTH-1:0] sdl;
wire [`DATAMEMWIDTH-1:0] dataldata;
reg [2:0] datalsel;
reg [`DATAMEMWIDTH-1:0] datal1 [0:`DATAMEMDEPTH-1];
reg [`DATAMEMWIDTH-1:0] datal2 [0:`DATAMEMDEPTH-1];
reg [`DATAMEMWIDTH-1:0] datal3 [0:`DATAMEMDEPTH-1];
reg [`DATAMEMWIDTH-1:0] datal4 [0:`DATAMEMDEPTH-1];

assign sdl =
  (SDL1 & {`INST_WIDTH{datalsel == 0}})
  | (SDL2 & {`INST_WIDTH{datalsel == 1}})
  | (SDL3 & {`INST_WIDTH{datalsel == 2}})
  | (SDL4 & {`INST_WIDTH{datalsel == 3}});

reg [`DATAMEMADRW-1:0] counterdataramaddress;
assign dataldata =
  (datal1[counterdataramaddress] & {`DATAMEMWIDTH{datalsel == 0}})
  | (datal2[counterdataramaddress] & {`DATAMEMWIDTH{datalsel == 1}})
  | (datal3[counterdataramaddress] & {`DATAMEMWIDTH{datalsel == 2}})
  | (datal4[counterdataramaddress] & {`DATAMEMWIDTH{datalsel == 3}});

// Initialization
initial begin
  $readmemh("hd44780datal1.mem", datal1);
  $readmemh("hd44780datal2.mem", datal2);
  $readmemh("hd44780datal3.mem", datal3);
  $readmemh("hd44780datal4.mem", datal4);
end

`define TIMECOUNTERWIDHT 32
reg [`TIMECOUNTERWIDHT-1:0]timecounter;
always @(posedge clk, negedge rst) begin
  if (!rst) begin
    busy <= 1'b1;
    rs <= 1'b0;
    e <= 1'b0;
    db <= {`BUS_WIDTH {1'b0}};
    datalsel <= 0;
    timecounter <= {`TIMECOUNTERWIDHT {1'b0}}; // Set to 0
  end else begin
    timecounter <= timecounter + 1;
    case (timecounter)
`define TIME_START 100
// Wait 100 millis, send function set
`define FUNCTION_SET_1_HIGH (`TIME_START + `MILLI_TO_CLOCK(`POWERON_DELAY_MILLI))
        `FUNCTION_SET_1_HIGH: begin
            e <= 1'b1;
            rs <= 1'b0;
            db <= INST_FUNCTION_SET[7:4];
        end
`define FUNCTION_SET_1_LOW (`FUNCTION_SET_1_HIGH + 1)
        `FUNCTION_SET_1_LOW: begin
            e <= 1'b0;
        end
// Wait 10 millis, send function set high part
`define FUNCTION_SET_2_H_HIGH (`FUNCTION_SET_1_LOW + `MILLI_TO_CLOCK(`CLEAR_SCREEN_DELAY_MILLI) + 1)
        `FUNCTION_SET_2_H_HIGH: begin
            e <= 1'b1;
            rs <= 1'b0;
            db <= INST_FUNCTION_SET[7:4];
        end
`define FUNCTION_SET_2_H_LOW (`FUNCTION_SET_2_H_HIGH + 1)
        `FUNCTION_SET_2_H_LOW: begin
            e <= 1'b0;
        end
`define FUNCTION_SET_2_L_HIGH (`FUNCTION_SET_2_H_LOW + 1)
        `FUNCTION_SET_2_L_HIGH: begin
            e <= 1'b1;
            rs <= 1'b0;
            db <= INST_FUNCTION_SET[3:0];
        end
`define FUNCTION_SET_2_L_LOW (`FUNCTION_SET_2_L_HIGH + 1)
        `FUNCTION_SET_2_L_LOW: begin
            e <= 1'b0;
        end
// Wait 10 millis, send function set high part
`define DISPLAY_CLEAR_H_HIGH (`FUNCTION_SET_2_L_LOW + `MILLI_TO_CLOCK(`CLEAR_SCREEN_DELAY_MILLI) + 1)
        `DISPLAY_CLEAR_H_HIGH: begin
            e <= 1'b1;
            rs <= 1'b0;
            db <= INST_DISPLAY_CLEAR[7:4];
        end
`define DISPLAY_CLEAR_H_LOW (`DISPLAY_CLEAR_H_HIGH + 1)
        `DISPLAY_CLEAR_H_LOW: begin
            e <= 1'b0;
        end
`define DISPLAY_CLEAR_L_HIGH (`DISPLAY_CLEAR_H_LOW + 1)
        `DISPLAY_CLEAR_L_HIGH: begin
            e <= 1'b1;
            rs <= 1'b0;
            db <= INST_DISPLAY_CLEAR[3:0];
        end
`define DISPLAY_CLEAR_L_LOW (`DISPLAY_CLEAR_L_HIGH + 1)
        `DISPLAY_CLEAR_L_LOW: begin
            e <= 1'b0;
        end
// Wait 10 millis, send function set high part
`define DISPLAY_CONTROL_H_HIGH (`DISPLAY_CLEAR_L_LOW + `MILLI_TO_CLOCK(`CLEAR_SCREEN_DELAY_MILLI) + 1)
        `DISPLAY_CONTROL_H_HIGH: begin
            e <= 1'b1;
            rs <= 1'b0;
            db <= INST_DISPLAY_CONTROL[7:4];
        end
`define DISPLAY_CONTROL_H_LOW (`DISPLAY_CONTROL_H_HIGH + 1)
        `DISPLAY_CONTROL_H_LOW: begin
            e <= 1'b0;
        end
`define DISPLAY_CONTROL_L_HIGH (`DISPLAY_CONTROL_H_LOW + 1)
        `DISPLAY_CONTROL_L_HIGH: begin
            e <= 1'b1;
            rs <= 1'b0;
            db <= INST_DISPLAY_CONTROL[3:0];
        end
`define DISPLAY_CONTROL_L_LOW (`DISPLAY_CONTROL_L_HIGH + 1)
        `DISPLAY_CONTROL_L_LOW: begin
            e <= 1'b0;
        end
// Wait 10 millis, send function set high part
`define ENTRY_MODE_H_HIGH (`DISPLAY_CONTROL_L_LOW + `MILLI_TO_CLOCK(`CLEAR_SCREEN_DELAY_MILLI) + 1)
        `ENTRY_MODE_H_HIGH: begin
            e <= 1'b1;
            rs <= 1'b0;
            db <= INST_ENTRY_MODE[7:4];
        end
`define ENTRY_MODE_H_LOW (`ENTRY_MODE_H_HIGH + 1)
        `ENTRY_MODE_H_LOW: begin
            e <= 1'b0;
        end
`define ENTRY_MODE_L_HIGH (`ENTRY_MODE_H_LOW + 1)
        `ENTRY_MODE_L_HIGH: begin
            e <= 1'b1;
            rs <= 1'b0;
            db <= INST_ENTRY_MODE[3:0];
        end
`define ENTRY_MODE_L_LOW (`ENTRY_MODE_L_HIGH + 1)
        `ENTRY_MODE_L_LOW: begin
            e <= 1'b0;
        end
// Wait 10 millis, finalize all
`define RESET_CLEAR (`ENTRY_MODE_L_LOW + `MILLI_TO_CLOCK(`CLEAR_SCREEN_DELAY_MILLI) + 1)
        `RESET_CLEAR: begin
            busy <= 1'b0;
        end
    endcase
  end
end

endmodule
