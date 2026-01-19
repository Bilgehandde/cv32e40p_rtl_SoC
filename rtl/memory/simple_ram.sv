`timescale 1ns / 1ps

/**
 * Module: simple_ram
 * Description:
 * A high-performance Single-Port RAM with a standard AXI4-Lite Slave interface.
 * * Design Features:
 * 1. Dual-Block Architecture: Separates the synchronous memory array from the 
 * AXI handshake logic to optimize timing closure.
 * 2. BRAM Inference: The memory array is designed for direct mapping to FPGA 
 * Block RAM resources, ensuring minimal LUT usage.
 * 3. Little-Endian Byte Access: Fully supports AXI byte-strobe (wstrb) for 
 * partial word writes.
 */
module simple_ram #(
    parameter MEM_SIZE_BYTES = 8192,
    parameter INIT_FILE      = ""
)(
    input  logic         clk,
    input  logic         rst_n,

    // --- AXI4-Lite Interface ---
    input  logic [31:0] awaddr, input awvalid, output logic awready,
    input  logic [31:0] wdata,  input [3:0] wstrb, input wvalid, output logic wready,
    output logic        bvalid, input bready,
    input  logic [31:0] araddr, input arvalid, output logic arready,
    output logic [31:0] rdata,  output logic rvalid, input rready
);

    localparam DEPTH = MEM_SIZE_BYTES / 4;

    // Memory array storage (Hardened BRAM Primitive Inference)
    (* ram_style = "block" *) logic [31:0] mem [0:DEPTH-1];

    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end

    // =======================================================================
    // PHASE 1: SYNCHRONOUS MEMORY PIPELINE
    // =======================================================================
    // This dedicated stage handles high-speed data sampling and retrieval.
    logic [31:0] rdata_internal;
    always_ff @(posedge clk) begin
        // Synchronous Write Path with Strobe Masking
        if (awvalid && wvalid && awready) begin
            if (wstrb[0]) mem[awaddr[12:2]][7:0]   <= wdata[7:0];
            if (wstrb[1]) mem[awaddr[12:2]][15:8]  <= wdata[15:8];
            if (wstrb[2]) mem[awaddr[12:2]][23:16] <= wdata[23:16];
            if (wstrb[3]) mem[awaddr[12:2]][31:24] <= wdata[31:24];
        end
        // Synchronous Read Path
        if (arvalid && arready) begin
            rdata_internal <= mem[araddr[12:2]];
        end
    end

    // =======================================================================
    // PHASE 2: AXI HANDSHAKE & RESPONSE LOGIC
    // =======================================================================
    // Manages the AXI protocol states independently of the memory storage path.
    logic bvalid_reg, rvalid_reg;
    assign {bvalid, rvalid, rdata} = {bvalid_reg, rvalid_reg, rdata_internal};
    assign {awready, wready, arready} = {~bvalid_reg, ~bvalid_reg, ~rvalid_reg};

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bvalid_reg <= 1'b0;
            rvalid_reg <= 1'b0;
        end else begin
            // Write Ack Management
            if (awvalid && wvalid && awready) bvalid_reg <= 1'b1;
            else if (bvalid_reg && bready)    bvalid_reg <= 1'b0;

            // Read Data Ready Management
            if (arvalid && arready)        rvalid_reg <= 1'b1;
            else if (rvalid_reg && rready) rvalid_reg <= 1'b0;
        end
    end
endmodule