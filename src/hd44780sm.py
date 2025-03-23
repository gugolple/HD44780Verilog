#!/usr/bin/env python3
# This script is to generate the state machine for the FPGA in a sensible way
# This should be moslty an assembler that will transform the user readable
# code to the binary format needed for the Verilog read.

_HD44780_FUNCTION_SET = [0,0,1,0,1,0,0,0]
