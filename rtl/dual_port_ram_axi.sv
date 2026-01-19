`timescale 1ns / 1ps

/**
 * Module: dual_port_ram_axi
 * Description:
 * A high-bandwidth True Dual-Port Memory Controller with AXI4-Lite interfaces.
 * Optimized for simultaneous Instruction Fetch (Port A) and Data Access (Port B).
 *
 * Design Logic:
 * Uses a pipelined architecture where the memory core operates on clock edges 
 * while the AXI control registers handle synchronization and handshaking.
 */
module dual_port_ram_axi #(
    parameter MEM_SIZE_BYTES = 8192
)(
    input  logic         clk,
    input  logic         rst_n,

    // --- PORT A: Instruction Fetch Interface ---
    input  logic [31:0] a_araddr, input a_arvalid, output logic a_arready,
    output logic [31:0] a_rdata,  output logic a_rvalid, input a_rready,

    // --- PORT B: Data/Load-Store Interface ---
    input  logic [31:0] b_awaddr, input b_awvalid, output logic b_awready,
    input  logic [31:0] b_wdata,  input [3:0] b_wstrb, input b_wvalid, output logic b_wready,
    output logic        b_bvalid, input b_bready,
    input  logic [31:0] b_araddr, input b_arvalid, output logic b_arready,
    output logic [31:0] b_rdata,  output logic b_rvalid, input b_rready
);

    localparam DEPTH = MEM_SIZE_BYTES / 4;

    // Dual-Port Storage Core
    (* ram_style = "block" *) logic [31:0] mem [0:DEPTH-1];

    logic [31:0] a_rdata_internal, b_rdata_internal;

    // =======================================================================
    // 1. DUAL-PORT SYNCHRONOUS PIPELINE
    // =======================================================================
    always_ff @(posedge clk) begin
        // Parallel Read Operations
        if (a_arvalid && a_arready) a_rdata_internal <= mem[a_araddr[12:2]];
        if (b_arvalid && b_arready) b_rdata_internal <= mem[b_araddr[12:2]];
        
        // Port B Write Logic
        if (b_awvalid && b_wvalid && b_awready && b_wready) begin
            if (b_wstrb[0]) mem[b_awaddr[12:2]][7:0]   <= b_wdata[7:0];
            if (b_wstrb[1]) mem[b_awaddr[12:2]][15:8]  <= b_wdata[15:8];
            if (b_wstrb[2]) mem[b_awaddr[12:2]][23:16] <= b_wdata[23:16];
            if (b_wstrb[3]) mem[b_awaddr[12:2]][31:24] <= b_wdata[31:24];
        end
    end

    // =======================================================================
    // 2. AXI STATE MACHINE & HANDSHAKING
    // =======================================================================
    logic a_rvalid_reg, b_bvalid_reg, b_rvalid_reg;
    assign {a_rdata, b_rdata} = {a_rdata_internal, b_rdata_internal};
    assign {a_rvalid, b_bvalid, b_rvalid} = {a_rvalid_reg, b_bvalid_reg, b_rvalid_reg};
    assign {a_arready, b_awready, b_wready, b_arready} = {~a_rvalid_reg, ~b_bvalid_reg, ~b_bvalid_reg, ~b_rvalid_reg};

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_rvalid_reg <= 1'b0; b_bvalid_reg <= 1'b0; b_rvalid_reg <= 1'b0;
        end else begin
            if (a_arvalid && a_arready) a_rvalid_reg <= 1'b1; else if (a_rready) a_rvalid_reg <= 1'b0;
            if (b_awvalid && b_wvalid && b_awready && b_wready) b_bvalid_reg <= 1'b1; else if (b_bready) b_bvalid_reg <= 1'b0;
            if (b_arvalid && b_arready) b_rvalid_reg <= 1'b1; else if (b_rready) b_rvalid_reg <= 1'b0;
        end
    end
endmodule