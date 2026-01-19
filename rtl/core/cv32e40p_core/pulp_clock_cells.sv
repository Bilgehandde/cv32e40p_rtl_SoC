`timescale 1ns / 1ps


module pulp_clock_mux2 (
    input  logic clk0_i, 
    input  logic clk1_i, 
    input  logic sel_i,  
    output logic clk_o   
);
    assign clk_o = (sel_i) ? clk1_i : clk0_i;

endmodule

module pulp_clock_xor2 (
    input  logic clk0_i,
    input  logic clk1_i,
    output logic clk_o
);
    assign clk_o = clk0_i ^ clk1_i;

endmodule

module pulp_clock_inverter (
    input  logic clk_i,
    output logic clk_o
);
    assign clk_o = ~clk_i;

endmodule