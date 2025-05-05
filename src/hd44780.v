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
`define HALF_COMMAND_DELAY_CYCLES 10
`define INTER_INSTRUCTION_DELAY 10
//8 bit mode
`define BUS_WIDTH 4
`define LINE_WIDTH 16
`define PRINT_LENGTH `LINE_WIDTH
`define MAX_MEM 4*`LINE_WIDTH
`define MAX_MEM_BITS $clog2(`MAX_MEM)
module hd44780
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
parameter DATA_LENGTH = 0;   //0 - 4 | 1 - 8 //Bits for comm
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
localparam INST_SET_DDRAM_ADDR_MASK = 8'b01111111;
localparam [`INST_WIDTH-1:0]INST_SET_DDRAM_ADDR  = 8'b10000000;
localparam HD44780_START_ADD_L1 = 8'h00;
localparam HD44780_START_ADD_L2 = 8'h40;
localparam HD44780_START_ADD_L3 = 8'h10;
localparam HD44780_START_ADD_L4 = 8'h50;
localparam [`INST_WIDTH-1:0]INST_SET_DDRAM_ADDR_L1  = INST_SET_DDRAM_ADDR
| (HD44780_START_ADD_L1 & INST_SET_DDRAM_ADDR_MASK);
localparam [`INST_WIDTH-1:0]INST_SET_DDRAM_ADDR_L2  = INST_SET_DDRAM_ADDR
| (HD44780_START_ADD_L2 & INST_SET_DDRAM_ADDR_MASK);
localparam [`INST_WIDTH-1:0]INST_SET_DDRAM_ADDR_L3  = INST_SET_DDRAM_ADDR
| (HD44780_START_ADD_L3 & INST_SET_DDRAM_ADDR_MASK);
localparam [`INST_WIDTH-1:0]INST_SET_DDRAM_ADDR_L4  = INST_SET_DDRAM_ADDR
| (HD44780_START_ADD_L4 & INST_SET_DDRAM_ADDR_MASK);

//// Debug for the macros/localparam definitions
//// It is shown at the beginning of the test/run
//initial begin
//        $display("INST = %x",INST_SET_DDRAM_ADDR);
//        $display("L1 = %x",INST_SET_DDRAM_ADDR_L1);
//        $display("L2 = %x",INST_SET_DDRAM_ADDR_L2);
//        $display("L3 = %x",INST_SET_DDRAM_ADDR_L3);
//        $display("L4 = %x",INST_SET_DDRAM_ADDR_L4);
//end

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
    end else begin        
        `define TIME_START 100
        `define FUNCTION_SET_1_HIGH (`TIME_START + `POWERON_DELAY_CYCLES)
        `define FUNCTION_SET_1_LOW (`FUNCTION_SET_1_HIGH + `INTER_INSTRUCTION_DELAY)
        // Only execute the half at first boot
        // Wait 100 millis, send function set
        if(coldboot) begin
            case(timecounter)
                `FUNCTION_SET_1_HIGH: begin
                    re <= 1'b1;
                    rrs <= 1'b0;
                    rdb <= INST_FUNCTION_SET[7:4];
                end
                `FUNCTION_SET_1_LOW: begin
                    re <= 1'b0;
                end
            endcase
        end
        case (timecounter)
            // Wait 10 millis, send function set high part
            `define FUNCTION_SET_2_H_HIGH (`FUNCTION_SET_1_LOW + `CLEAR_SCREEN_DELAY_CYCLES + `INTER_INSTRUCTION_DELAY)
            `FUNCTION_SET_2_H_HIGH: begin
                re <= 1'b1;
                rrs <= 1'b0;
                rdb <= INST_FUNCTION_SET[7:4];
            end
            `define FUNCTION_SET_2_H_LOW (`FUNCTION_SET_2_H_HIGH + `INTER_INSTRUCTION_DELAY)
            `FUNCTION_SET_2_H_LOW: begin
                re <= 1'b0;
            end
            `define FUNCTION_SET_2_L_HIGH (`FUNCTION_SET_2_H_LOW + `HALF_COMMAND_DELAY_CYCLES + `INTER_INSTRUCTION_DELAY)
            `FUNCTION_SET_2_L_HIGH: begin
                re <= 1'b1;
                rrs <= 1'b0;
                rdb <= INST_FUNCTION_SET[3:0];
            end
            `define FUNCTION_SET_2_L_LOW (`FUNCTION_SET_2_L_HIGH + `INTER_INSTRUCTION_DELAY)
            `FUNCTION_SET_2_L_LOW: begin
                re <= 1'b0;
            end
            // Wait 10 millis, send function set high part
            `define DISPLAY_CONTROL_H_HIGH (`FUNCTION_SET_2_L_LOW + `CLEAR_SCREEN_DELAY_CYCLES + `INTER_INSTRUCTION_DELAY)
            `DISPLAY_CONTROL_H_HIGH: begin
                re <= 1'b1;
                rrs <= 1'b0;
                rdb <= INST_DISPLAY_CONTROL[7:4];
            end
            `define DISPLAY_CONTROL_H_LOW (`DISPLAY_CONTROL_H_HIGH + `INTER_INSTRUCTION_DELAY)
            `DISPLAY_CONTROL_H_LOW: begin
                re <= 1'b0;
            end
            `define DISPLAY_CONTROL_L_HIGH (`DISPLAY_CONTROL_H_LOW + `HALF_COMMAND_DELAY_CYCLES + `INTER_INSTRUCTION_DELAY)
            `DISPLAY_CONTROL_L_HIGH: begin
                re <= 1'b1;
                rrs <= 1'b0;
                rdb <= INST_DISPLAY_CONTROL[3:0];
            end
            `define DISPLAY_CONTROL_L_LOW (`DISPLAY_CONTROL_L_HIGH + `INTER_INSTRUCTION_DELAY)
            `DISPLAY_CONTROL_L_LOW: begin
                re <= 1'b0;
            end
            // Wait 10 millis, send function set high part
            `define ENTRY_MODE_H_HIGH (`DISPLAY_CONTROL_L_LOW + `CLEAR_SCREEN_DELAY_CYCLES + `INTER_INSTRUCTION_DELAY)
            `ENTRY_MODE_H_HIGH: begin
                re <= 1'b1;
                rrs <= 1'b0;
                rdb <= INST_ENTRY_MODE[7:4];
            end
            `define ENTRY_MODE_H_LOW (`ENTRY_MODE_H_HIGH + `INTER_INSTRUCTION_DELAY)
            `ENTRY_MODE_H_LOW: begin
                re <= 1'b0;
            end
            `define ENTRY_MODE_L_HIGH (`ENTRY_MODE_H_LOW + `HALF_COMMAND_DELAY_CYCLES + `INTER_INSTRUCTION_DELAY)
            `ENTRY_MODE_L_HIGH: begin
                re <= 1'b1;
                rrs <= 1'b0;
                rdb <= INST_ENTRY_MODE[3:0];
            end
            `define ENTRY_MODE_L_LOW (`ENTRY_MODE_L_HIGH + `INTER_INSTRUCTION_DELAY)
            `ENTRY_MODE_L_LOW: begin
                re <= 1'b0;
            end
            // Wait 10 millis, send function set high part
            `define DISPLAY_CLEAR_H_HIGH (`ENTRY_MODE_L_LOW + `CLEAR_SCREEN_DELAY_CYCLES + `INTER_INSTRUCTION_DELAY)
            `DISPLAY_CLEAR_H_HIGH: begin
                re <= 1'b1;
                rrs <= 1'b0;
                rdb <= INST_DISPLAY_CLEAR[7:4];
            end
            `define DISPLAY_CLEAR_H_LOW (`DISPLAY_CLEAR_H_HIGH + `INTER_INSTRUCTION_DELAY)
            `DISPLAY_CLEAR_H_LOW: begin
                re <= 1'b0;
            end
            `define DISPLAY_CLEAR_L_HIGH (`DISPLAY_CLEAR_H_LOW + `HALF_COMMAND_DELAY_CYCLES + `INTER_INSTRUCTION_DELAY)
            `DISPLAY_CLEAR_L_HIGH: begin
                re <= 1'b1;
                rrs <= 1'b0;
                rdb <= INST_DISPLAY_CLEAR[3:0];
            end
            `define DISPLAY_CLEAR_L_LOW (`DISPLAY_CLEAR_L_HIGH + `INTER_INSTRUCTION_DELAY)
            `DISPLAY_CLEAR_L_LOW: begin
                re <= 1'b0;
            end
            // Wait 10 millis, finalize all
            `define RESET_CLEAR (`DISPLAY_CLEAR_L_LOW + `CLEAR_SCREEN_DELAY_CYCLES + `INTER_INSTRUCTION_DELAY)
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
    end else begin
        if (busy_print) begin
            // Loop for printing both secuences of lines
            // - First L1 and L3
            // - Second L2 and L4
            for (i=0; i<1; i=i+1) begin
                // Initial set instruction
                case (printcounter)
                    delaycounter: begin
                        busy_print <= 1'b1;
                        pe <= 1'b1;
                        prs <= 1'b0;
                        case(i)
                            0: pdb <= INST_SET_DDRAM_ADDR_L1[7:4];
                            1: pdb <= INST_SET_DDRAM_ADDR_L2[7:4];
                            2: pdb <= INST_SET_DDRAM_ADDR_L3[7:4];
                            3: pdb <= INST_SET_DDRAM_ADDR_L4[7:4];
                            default: pdb <= {`BUS_WIDTH {1'b0}};
                        endcase
                    end
                    delaycounter + 1 * `INTER_INSTRUCTION_DELAY: begin
                        pe <= 1'b0;
                    end
                    delaycounter + 2 * `INTER_INSTRUCTION_DELAY + `HALF_COMMAND_DELAY_CYCLES: begin
                        pe <= 1'b1;
                        prs <= 1'b0;
                        case(i)
                            0: pdb <= INST_SET_DDRAM_ADDR_L1[3:0];
                            1: pdb <= INST_SET_DDRAM_ADDR_L2[3:0];
                            2: pdb <= INST_SET_DDRAM_ADDR_L3[3:0];
                            3: pdb <= INST_SET_DDRAM_ADDR_L4[3:0];
                            default: pdb <= {`BUS_WIDTH {1'b0}};
                        endcase
                    end
                    delaycounter + 3 * `INTER_INSTRUCTION_DELAY + `HALF_COMMAND_DELAY_CYCLES: begin
                        pe <= 1'b0;
                    end
                endcase
                // Move forward delaycounter all steps + 1 + the delay for
                // a command.
                delaycounter = delaycounter + 4 * `INTER_INSTRUCTION_DELAY + `CLEAR_SCREEN_DELAY_CYCLES + `HALF_COMMAND_DELAY_CYCLES;
                for(j=0; j<`PRINT_LENGTH ; j=j+1) begin
                    tmp = (j | i << `MAX_MEM_BITS-1);
                    case(printcounter)
                        delaycounter: begin
                            idataaddr <= tmp[`MAX_MEM_BITS-1:0];
                        end
                        delaycounter + 1 * `INTER_INSTRUCTION_DELAY: begin
                            pe <= 1'b1;
                            prs <= 1'b1;
                            pdb <= idata[7:4];
                        end
                        delaycounter + 2 * `INTER_INSTRUCTION_DELAY: begin
                            pe <= 1'b0;
                        end
                        delaycounter + 3 * `INTER_INSTRUCTION_DELAY + `HALF_COMMAND_DELAY_CYCLES: begin
                            idataaddr <= tmp[`MAX_MEM_BITS-1:0];
                        end
                        delaycounter + 4 * `INTER_INSTRUCTION_DELAY + `HALF_COMMAND_DELAY_CYCLES: begin
                            pe <= 1'b1;
                            prs <= 1'b1;
                            pdb <= idata[3:0];
                        end
                        delaycounter + 5 * `INTER_INSTRUCTION_DELAY + `HALF_COMMAND_DELAY_CYCLES: begin
                            pe <= 1'b0;
                        end
                    endcase
                    // Move forward delaycounter all steps + 1 + the delay for
                    // a command.
                    delaycounter = delaycounter + 6 * `INTER_INSTRUCTION_DELAY + `COMMAND_DELAY_CYCLES + `HALF_COMMAND_DELAY_CYCLES;
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
