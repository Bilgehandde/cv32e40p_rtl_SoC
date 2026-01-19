module cv32e40p_pmp #(
    parameter int PMP_NUM_REGIONS = 16
)(
    input  logic        clk,
    input  logic        rst_n,

    // Instruction fetch
    input  logic [31:0] instr_addr_i,
    output logic        instr_access_o,

    // Data access
    input  logic [31:0] data_addr_i,
    input  logic        data_we_i,
    output logic        data_access_o
);
    
    assign instr_access_o = 1'b1;
    assign data_access_o  = 1'b1;
endmodule
