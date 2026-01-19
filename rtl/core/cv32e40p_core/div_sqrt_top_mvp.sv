module div_sqrt_top_mvp (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        div_valid_i,
    output logic        div_ready_o,

    input  logic [31:0] operand_a_i,
    input  logic [31:0] operand_b_i,
    output logic [31:0] result_o
);
   
    assign div_ready_o = 1'b1;
    assign result_o    = 32'b0;
endmodule
