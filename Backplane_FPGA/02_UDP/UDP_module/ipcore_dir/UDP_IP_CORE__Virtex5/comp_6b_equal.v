////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2010 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor: Xilinx
// \   \   \/     Version: M.63c
//  \   \         Application: netgen
//  /   /         Filename: comp_6b_equal.v
// /___/   /\     Timestamp: Thu Oct 25 10:13:44 2012
// \   \  /  \ 
//  \___\/\___\
//             
// Command	: -intstyle ise -w -sim -ofmt verilog ./tmp/_cg\comp_6b_equal.ngc ./tmp/_cg\comp_6b_equal.v 
// Device	: 5vlx110tff1136-1
// Input file	: ./tmp/_cg/comp_6b_equal.ngc
// Output file	: ./tmp/_cg/comp_6b_equal.v
// # of Modules	: 1
// Design Name	: comp_6b_equal
// Xilinx        : C:\Xilinx\12.2\ISE_DS\ISE\
//             
// Purpose:    
//     This verilog netlist is a verification model and uses simulation 
//     primitives which may not represent the true implementation of the 
//     device, however the netlist is functionally correct and should not 
//     be modified. This file cannot be synthesized and should only be used 
//     with supported simulation tools.
//             
// Reference:  
//     Command Line Tools User Guide, Chapter 23 and Synthesis and Simulation Design Guide, Chapter 6
//             
////////////////////////////////////////////////////////////////////////////////

`timescale 1 ns/1 ps

module comp_6b_equal (
  qa_eq_b, clk, a, b
)/* synthesis syn_black_box syn_noprune=1 */;
  output qa_eq_b;
  input clk;
  input [5 : 0] a;
  input [5 : 0] b;
  
  // synthesis translate_off
  
  wire \BU2/N01 ;
  wire \BU2/U0/gen_structure_logic.gen_nonpipelined.a_equal_notequal_b.i_a_eq_ne_b/i_use_carry_plus_luts.lut_and.i_gate_bit/tier_gen[1].i_tier/loop_tiles[0].i_tile/o85_16 ;
  wire \BU2/U0/gen_structure_logic.gen_nonpipelined.a_equal_notequal_b.i_a_eq_ne_b/temp_result ;
  wire \BU2/a_ge_b ;
  wire NLW_VCC_P_UNCONNECTED;
  wire NLW_GND_G_UNCONNECTED;
  wire [5 : 0] a_2;
  wire [5 : 0] b_3;
  assign
    a_2[5] = a[5],
    a_2[4] = a[4],
    a_2[3] = a[3],
    a_2[2] = a[2],
    a_2[1] = a[1],
    a_2[0] = a[0],
    b_3[5] = b[5],
    b_3[4] = b[4],
    b_3[3] = b[3],
    b_3[2] = b[2],
    b_3[1] = b[1],
    b_3[0] = b[0];
  VCC   VCC_0 (
    .P(NLW_VCC_P_UNCONNECTED)
  );
  GND   GND_1 (
    .G(NLW_GND_G_UNCONNECTED)
  );
  LUT6 #(
    .INIT ( 64'h8421000000000000 ))
  \BU2/U0/gen_structure_logic.gen_nonpipelined.a_equal_notequal_b.i_a_eq_ne_b/i_use_carry_plus_luts.lut_and.i_gate_bit/tier_gen[1].i_tier/loop_tiles[0].i_tile/o107  (
    .I0(a_2[0]),
    .I1(a_2[4]),
    .I2(b_3[0]),
    .I3(b_3[4]),
    .I4
(\BU2/U0/gen_structure_logic.gen_nonpipelined.a_equal_notequal_b.i_a_eq_ne_b/i_use_carry_plus_luts.lut_and.i_gate_bit/tier_gen[1].i_tier/loop_tiles[0].i_tile/o85_16 )
,
    .I5(\BU2/N01 ),
    .O(\BU2/U0/gen_structure_logic.gen_nonpipelined.a_equal_notequal_b.i_a_eq_ne_b/temp_result )
  );
  LUT4 #(
    .INIT ( 16'h9009 ))
  \BU2/U0/gen_structure_logic.gen_nonpipelined.a_equal_notequal_b.i_a_eq_ne_b/i_use_carry_plus_luts.lut_and.i_gate_bit/tier_gen[1].i_tier/loop_tiles[0].i_tile/o107_SW0  (
    .I0(a_2[5]),
    .I1(b_3[5]),
    .I2(a_2[3]),
    .I3(b_3[3]),
    .O(\BU2/N01 )
  );
  LUT4 #(
    .INIT ( 16'h9009 ))
  \BU2/U0/gen_structure_logic.gen_nonpipelined.a_equal_notequal_b.i_a_eq_ne_b/i_use_carry_plus_luts.lut_and.i_gate_bit/tier_gen[1].i_tier/loop_tiles[0].i_tile/o85  (
    .I0(a_2[1]),
    .I1(b_3[1]),
    .I2(a_2[2]),
    .I3(b_3[2]),
    .O
(\BU2/U0/gen_structure_logic.gen_nonpipelined.a_equal_notequal_b.i_a_eq_ne_b/i_use_carry_plus_luts.lut_and.i_gate_bit/tier_gen[1].i_tier/loop_tiles[0].i_tile/o85_16 )

  );
  FD #(
    .INIT ( 1'b0 ))
  \BU2/U0/gen_structure_logic.gen_nonpipelined.a_equal_notequal_b.i_a_eq_ne_b/gen_output_reg.output_reg/fd/output_1  (
    .C(clk),
    .D(\BU2/U0/gen_structure_logic.gen_nonpipelined.a_equal_notequal_b.i_a_eq_ne_b/temp_result ),
    .Q(qa_eq_b)
  );
  GND   \BU2/XST_GND  (
    .G(\BU2/a_ge_b )
  );

// synthesis translate_on

endmodule

// synthesis translate_off

`ifndef GLBL
`define GLBL

`timescale  1 ps / 1 ps

module glbl ();

    parameter ROC_WIDTH = 100000;
    parameter TOC_WIDTH = 0;

    wire GSR;
    wire GTS;
    wire GWE;
    wire PRLD;
    tri1 p_up_tmp;
    tri (weak1, strong0) PLL_LOCKG = p_up_tmp;

    reg GSR_int;
    reg GTS_int;
    reg PRLD_int;

//--------   JTAG Globals --------------
    wire JTAG_TDO_GLBL;
    wire JTAG_TCK_GLBL;
    wire JTAG_TDI_GLBL;
    wire JTAG_TMS_GLBL;
    wire JTAG_TRST_GLBL;

    reg JTAG_CAPTURE_GLBL;
    reg JTAG_RESET_GLBL;
    reg JTAG_SHIFT_GLBL;
    reg JTAG_UPDATE_GLBL;
    reg JTAG_RUNTEST_GLBL;

    reg JTAG_SEL1_GLBL = 0;
    reg JTAG_SEL2_GLBL = 0 ;
    reg JTAG_SEL3_GLBL = 0;
    reg JTAG_SEL4_GLBL = 0;

    reg JTAG_USER_TDO1_GLBL = 1'bz;
    reg JTAG_USER_TDO2_GLBL = 1'bz;
    reg JTAG_USER_TDO3_GLBL = 1'bz;
    reg JTAG_USER_TDO4_GLBL = 1'bz;

    assign (weak1, weak0) GSR = GSR_int;
    assign (weak1, weak0) GTS = GTS_int;
    assign (weak1, weak0) PRLD = PRLD_int;

    initial begin
	GSR_int = 1'b1;
	PRLD_int = 1'b1;
	#(ROC_WIDTH)
	GSR_int = 1'b0;
	PRLD_int = 1'b0;
    end

    initial begin
	GTS_int = 1'b1;
	#(TOC_WIDTH)
	GTS_int = 1'b0;
    end

endmodule

`endif

// synthesis translate_on
