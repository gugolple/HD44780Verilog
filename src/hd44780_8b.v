////////////////////////////////////////////////////////////////////////////////
// Global definitions
////////////////////////////////////////////////////////////////////////////////
`define INST_WIDTH 8
`define EXPECTED_FREQ 250_000 // 250khz
`define MILLI 1_000
`define MICRO 1_000_000
`define MILLI_TO_CLOCK(t) (t*`EXPECTED_FREQ/`MILLI)
`define MICRO_TO_CLOCK(t) (t*`EXPECTED_FREQ/`MICRO)
`define POWERON_DELAY_MILLI 100
`define POWERON_DELAY_CYCLES `MILLI_TO_CLOCK(`POWERON_DELAY_MILLI)
`define CLEAR_SCREEN_DELAY_MILLI 10
`define CLEAR_SCREEN_DELAY_CYCLES `MILLI_TO_CLOCK(`CLEAR_SCREEN_DELAY_MILLI)
`define CLEAR_SCREEN_DELAY_MILLI 10
`define CLEAR_SCREEN_DELAY_CYCLES `MILLI_TO_CLOCK(`CLEAR_SCREEN_DELAY_MILLI)
`define COMMAND_DELAY_MICROS 80
`define COMMAND_DELAY_CYCLES `MICRO_TO_CLOCK(`COMMAND_DELAY_MICROS)
`define INTER_INSTRUCTION_DELAY 200
//8 bit mode
`define BUS_WIDTH 8
`define LINE_WIDTH 20
`define PRINT_LENGTH `LINE_WIDTH
`define MAX_MEM 4*`LINE_WIDTH
`define MAX_MEM_BITS $clog2(`MAX_MEM)
module hd447808b
(
    // Inputs
    input clk,
    input rst,
    input trg,
    // Outputs
    output busy,
    output e,
    output rs,
    output [`BUS_WIDTH-1:0] db,
    // Mem Accessing
    output reg [`MAX_MEM_BITS-1:0]idataaddr,
    input [`INST_WIDTH-1:0] idata,
    // Test only for flags
    output reg busy_reset,
    // Test only for flags
    output reg busy_print
);
reg coldboot = 1'b1;
////////////////////////////////////////////////////////////////////////////////
// Instruction globals to configure
////////////////////////////////////////////////////////////////////////////////
localparam [`INST_WIDTH-1:0]INST_DISPLAY_CLEAR   = 8'b00000001;
localparam [`INST_WIDTH-1:0]INST_RETURN_HOME     = 8'b00000010;
parameter CURSOR_DIRECTION = 1; // 0 - left | 1 - right
parameter SHIFT_CURSOR = 1; // 0 - off | 1 - on
localparam [`INST_WIDTH-1:0]INST_ENTRY_MODE      = 8'b00000100
| (8'b0 | CURSOR_DIRECTION << 1)
| (8'b0 | SHIFT_CURSOR << 0);
parameter DISPLAY_ON_OFF = 1; // 0 - off | 1 - on
parameter CURSOR_ON_OFF = 1; // 0 - off | 1 - on
parameter CURSOR_BLINK = 0; // 0 - off | 1 - on
localparam [`INST_WIDTH-1:0]INST_DISPLAY_CONTROL = 8'b00001000
| (8'b0 | DISPLAY_ON_OFF << 2)
| (8'b0 | CURSOR_ON_OFF << 1)
| (8'b0 | CURSOR_BLINK << 0);
// SC - RL Table:
//  0    0 Shift cursor to the left (AC-1)
//  0    1 Shift cursor to the right (AC+1)
//  1    0 Shift display to the left, cursor follows
//  1    1 Shift display to the right, cursor follows
parameter DISPLAY_SHIFT_SC = 0;
parameter DISPLAY_SHIFT_RL = 0;
localparam [`INST_WIDTH-1:0]INST_DISPLAY_SHIFT   = 8'b0001000
| (8'b0 | DISPLAY_SHIFT_SC << 3)
| (8'b0 | DISPLAY_SHIFT_RL << 2);
// Hardware configuration of unit
parameter DATA_LENGTH = 1;   //0 - 4 | 1 - 8 //Bits for comm
parameter DISPLAY_LINES = 1; //0 - 1 | 1 - 2
parameter CHARACTER_FONT = 0;
localparam [`INST_WIDTH-1:0]INST_FUNCTION_SET    = 8'b00100000
| (8'b0 | DATA_LENGTH << 4)
| (8'b0 | DISPLAY_LINES << 3)
| (8'b0 | CHARACTER_FONT << 2);
localparam INST_SET_CGRAM_ADDR_MASK = 8'b00111111;
localparam [`INST_WIDTH-1:0]INST_SET_CGRAM_ADDR  = 8'b01000000;

// All DDRAM definitions
// Used for setting the cursor position
// They are used to set at the line start
`define MHD44780_START_ADD_L1 8'h00
`define MHD44780_START_ADD_L2 8'h40

localparam [`INST_WIDTH-1:0]INST_SET_DDRAM_ADDR_MASK = 8'b01111111;
localparam [`INST_WIDTH-1:0]INST_SET_DDRAM_ADDR  = 8'b10000000;
localparam [`INST_WIDTH-1:0]HD44780_START_ADD_L1 = `MHD44780_START_ADD_L1;
localparam [`INST_WIDTH-1:0]HD44780_START_ADD_L2 = `MHD44780_START_ADD_L2;
localparam [`INST_WIDTH-1:0]HD44780_START_ADD_L3 = `MHD44780_START_ADD_L1 + `LINE_WIDTH;
localparam [`INST_WIDTH-1:0]HD44780_START_ADD_L4 = `MHD44780_START_ADD_L2 + `LINE_WIDTH;
localparam [`INST_WIDTH-1:0]INST_SET_DDRAM_ADDR_L1  = INST_SET_DDRAM_ADDR
| (HD44780_START_ADD_L1);
localparam [`INST_WIDTH-1:0]INST_SET_DDRAM_ADDR_L2  = INST_SET_DDRAM_ADDR
| (HD44780_START_ADD_L2);
localparam [`INST_WIDTH-1:0]INST_SET_DDRAM_ADDR_L3  = INST_SET_DDRAM_ADDR
| (HD44780_START_ADD_L3);
localparam [`INST_WIDTH-1:0]INST_SET_DDRAM_ADDR_L4  = INST_SET_DDRAM_ADDR
| (HD44780_START_ADD_L4);

////////////////////////////////////////////////////////////////////////////////
// Restart system
////////////////////////////////////////////////////////////////////////////////
`define TIMECOUNTERWIDHT 32
reg [`TIMECOUNTERWIDHT-1:0]timecounter;
reg rrs, re;
reg [`BUS_WIDTH-1:0]rdb;
always @(posedge clk, negedge rst) begin
    if (!rst) begin
        busy_reset <= 1'b1;
        rrs <= 1'b0;
        re <= 1'b0;
        rdb <= {`BUS_WIDTH {1'b0}};
        timecounter <= {`TIMECOUNTERWIDHT {1'b0}}; // Set to 0
    end else if(busy_reset) begin        
        `define TIME_START 100
        case (timecounter)
		// Wait 100 millis, send function set
            `define FUNCTION_SET_HIGH (`TIME_START + `POWERON_DELAY_CYCLES)
            `FUNCTION_SET_HIGH: begin
                re <= 1'b1;
                rrs <= 1'b0;
                rdb <= INST_FUNCTION_SET;
            end
            `define FUNCTION_SET_LOW (`FUNCTION_SET_HIGH + `INTER_INSTRUCTION_DELAY)
            `FUNCTION_SET_LOW: begin
                re <= 1'b0;
            end
            // Wait 10 millis, send function set high part
            `define DISPLAY_CONTROL_HIGH (`FUNCTION_SET_LOW + `CLEAR_SCREEN_DELAY_CYCLES)
            `DISPLAY_CONTROL_HIGH: begin
                re <= 1'b1;
                rrs <= 1'b0;
                rdb <= INST_DISPLAY_CONTROL;
            end
            `define DISPLAY_CONTROL_LOW (`DISPLAY_CONTROL_HIGH + `INTER_INSTRUCTION_DELAY)
            `DISPLAY_CONTROL_LOW: begin
                re <= 1'b0;
            end
            // Wait 10 millis, send function set high part
            `define ENTRY_MODE_HIGH (`DISPLAY_CONTROL_LOW + `CLEAR_SCREEN_DELAY_CYCLES)
            `ENTRY_MODE_HIGH: begin
                re <= 1'b1;
                rrs <= 1'b0;
                rdb <= INST_ENTRY_MODE;
            end
            `define ENTRY_MODE_LOW (`ENTRY_MODE_HIGH + `INTER_INSTRUCTION_DELAY)
            `ENTRY_MODE_LOW: begin
                re <= 1'b0;
            end
            // Wait 10 millis, send function set high part
            `define DISPLAY_CLEAR_HIGH (`ENTRY_MODE_LOW + `CLEAR_SCREEN_DELAY_CYCLES)
            `DISPLAY_CLEAR_HIGH: begin
                re <= 1'b1;
                rrs <= 1'b0;
                rdb <= INST_DISPLAY_CLEAR;
            end
            `define DISPLAY_CLEAR_LOW (`DISPLAY_CLEAR_HIGH + `INTER_INSTRUCTION_DELAY)
            `DISPLAY_CLEAR_LOW: begin
                re <= 1'b0;
            end
            // Wait 10 millis, finalize all
            `define RESET_CLEAR (`DISPLAY_CLEAR_LOW + `CLEAR_SCREEN_DELAY_CYCLES)
            `RESET_CLEAR: begin
                coldboot <= 1'b0;
                busy_reset <= 1'b0;
                re <= 1'b0;
                rrs <= 1'b0;
                rdb <= {`BUS_WIDTH {1'b0}};
            end
        endcase
        // Prevent rollover restart
        if (timecounter <= `RESET_CLEAR) begin
            timecounter <= timecounter + 1;
        end
    end
end

////////////////////////////////////////////////////////////////////////////////
// Print system
////////////////////////////////////////////////////////////////////////////////
reg prs, pe;
reg [`BUS_WIDTH-1:0]pdb;
reg print_rst;
`define PRINTCOUNTERWIDHT 32
reg [`PRINTCOUNTERWIDHT-1:0]printcounter;
`define PRINT_START_DELAY 100
always @(posedge clk, negedge rst, posedge trg) begin
    automatic integer i;
    automatic integer j;
    automatic integer tmp;
    automatic integer delaycounter = `PRINT_START_DELAY;
    if (!rst | trg) begin
        printcounter <= {`PRINTCOUNTERWIDHT {1'b0}};
        print_rst <= 1'b1;
        busy_print <= 1'b1;
        prs <= 1'b0;
        pe <= 1'b0;
        pdb <= {`BUS_WIDTH {1'b0}};
        idataaddr <= {`MAX_MEM_BITS {1'b0}};
    end else begin
        if (!busy_reset & busy_print) begin
            // Loop for printing both secuences of lines
            // - First L1 and L3
            // - Second L2 and L4
            for (i=0; i<4; i=i+1) begin
                // Initial set instruction
                case (printcounter)
                    delaycounter: begin
                        busy_print <= 1'b1;
                        pe <= 1'b1;
                        prs <= 1'b0;
                        case(printcounter)
                            0: pdb <= INST_SET_DDRAM_ADDR_L1;
                            1: pdb <= INST_SET_DDRAM_ADDR_L2;
                            2: pdb <= INST_SET_DDRAM_ADDR_L3;
                            3: pdb <= INST_SET_DDRAM_ADDR_L4;
                            default: pdb <= {`BUS_WIDTH {1'b0}};
                        endcase
                    end
                    delaycounter + 3 * `INTER_INSTRUCTION_DELAY: begin
                        pe <= 1'b0;
                    end
                endcase
                // Move forward delaycounter all steps + 1 + the delay for
                // a command.
                delaycounter = delaycounter + 4 * `INTER_INSTRUCTION_DELAY + `CLEAR_SCREEN_DELAY_CYCLES + 100;
                tmp = (i);
                for(j=0; j<`PRINT_LENGTH ; j=j+1) begin
                    case(printcounter)
                        delaycounter: begin
                            idataaddr <= tmp[`MAX_MEM_BITS-1:0];
                        end
                        delaycounter + 1 * `INTER_INSTRUCTION_DELAY: begin
                            pe <= 1'b1;
                            prs <= 1'b1;
                            pdb <= idata;
                        end
                        delaycounter + 2 * `INTER_INSTRUCTION_DELAY: begin
                            pe <= 1'b0;
                        end
                    endcase
                    // Move forward delaycounter all steps + 1 + the delay for
                    // a command.
                    delaycounter = delaycounter + 3 * `INTER_INSTRUCTION_DELAY + `COMMAND_DELAY_CYCLES;
                    tmp = tmp + 1;
                end
            end
        end
        if (!busy_reset & (printcounter <= delaycounter)) begin
            printcounter <= printcounter + 1;
        end
        if (printcounter > delaycounter) begin
            print_rst <= 1'b0;
            busy_print <= 1'b0;
            prs <= 1'b0;
            pe <= 1'b0;
            pdb <= {`BUS_WIDTH {1'b0}};
            printcounter <= {`PRINTCOUNTERWIDHT {1'b0}};
        end
    end
end

////////////////////////////////////////////////////////////////////////////////
// Output configs 
////////////////////////////////////////////////////////////////////////////////
assign busy = busy_reset | busy_print;
assign e = re | pe;
assign rs = rrs | prs;
assign db = rdb | pdb;

endmodule
