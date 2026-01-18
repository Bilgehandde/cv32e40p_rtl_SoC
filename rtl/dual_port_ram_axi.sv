`timescale 1ns / 1ps

module dual_port_ram_axi #(
    parameter MEM_SIZE_BYTES = 8192
)(
    input logic clk,
    input logic rst_n,

    // =======================================================================
    // PORT A: INSTRUCTION FETCH INTERFACE (Read Only)
    // =======================================================================
    // Read Address Channel
    input  logic [31:0] a_araddr, 
    input  logic        a_arvalid, 
    output logic        a_arready,
    
    // Read Data Channel
    output logic [31:0] a_rdata,  
    output logic        a_rvalid,  
    input  logic        a_rready,

    // =======================================================================
    // PORT B: DATA ACCESS INTERFACE (Read / Write)
    // =======================================================================
    // Write Address Channel
    input  logic [31:0] b_awaddr, 
    input  logic        b_awvalid, 
    output logic        b_awready,
    
    // Write Data Channel
    input  logic [31:0] b_wdata,  
    input  logic [3:0]  b_wstrb,  
    input  logic        b_wvalid, 
    output logic        b_wready,
    
    // Write Response Channel
    output logic        b_bvalid, 
    input  logic        b_bready,
    
    // Read Address Channel
    input  logic [31:0] b_araddr, 
    input  logic        b_arvalid, 
    output logic        b_arready,
    
    // Read Data Channel
    output logic [31:0] b_rdata,  
    output logic        b_rvalid,  
    input  logic        b_rready
);

    // =======================================================================
    // MEMORY ARRAY DEFINITION
    // =======================================================================
    // Calculate depth based on 32-bit word width
    localparam DEPTH = MEM_SIZE_BYTES / 4;
    
    // The memory array itself (inferred as BRAM by Vivado)
    logic [31:0] mem [0:DEPTH-1];

    // =======================================================================
    // PORT A LOGIC: INSTRUCTION FETCH (READ ONLY)
    // =======================================================================
    
    // Always Ready: Block RAM can accept a read address every cycle
    assign a_arready = 1'b1; 

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_rvalid <= 1'b0;
            a_rdata  <= 32'b0; // Clear output to avoid X propagation
        end else begin
            // Handshake: If Master puts Valid Address and we are Ready
            if (a_arvalid && a_arready) begin
                // Read from memory
                // [14:2] extracts the Word Index from the Byte Address
                // (Assuming 32KB max address space for safety, though module is 8KB)
                a_rdata  <= mem[a_araddr[14:2]]; 
                a_rvalid <= 1'b1;
            end 
            // If Master accepted the data, deassert valid
            else if (a_rready) begin
                a_rvalid <= 1'b0;
            end
        end
    end

    // =======================================================================
    // PORT B LOGIC: DATA ACCESS (READ & WRITE)
    // =======================================================================

    // --- Write Channel ---
    assign b_awready = 1'b1; // Always ready for address
    assign b_wready  = 1'b1; // Always ready for data

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            b_bvalid <= 1'b0;
        end else begin
            // Write occurs when both Address and Data are Valid and Ready
            if (b_awvalid && b_wvalid && b_awready && b_wready) begin
                
                // Byte-Select Write Logic (WSTRB)
                // Allows writing individual bytes without affecting the rest of the word
                if (b_wstrb[0]) mem[b_awaddr[14:2]][7:0]   <= b_wdata[7:0];
                if (b_wstrb[1]) mem[b_awaddr[14:2]][15:8]  <= b_wdata[15:8];
                if (b_wstrb[2]) mem[b_awaddr[14:2]][23:16] <= b_wdata[23:16];
                if (b_wstrb[3]) mem[b_awaddr[14:2]][31:24] <= b_wdata[31:24];
                
                // Assert Write Response Valid
                b_bvalid <= 1'b1;
            end 
            // Handshake complete
            else if (b_bready) begin
                b_bvalid <= 1'b0;
            end
        end
    end

    // --- Read Channel ---
    assign b_arready = 1'b1; // Always ready for address

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            b_rvalid <= 1'b0;
            b_rdata  <= 32'b0;
        end else begin
            // Read Handshake
            if (b_arvalid && b_arready) begin
                b_rdata  <= mem[b_araddr[14:2]];
                b_rvalid <= 1'b1;
            end 
            // Handshake complete
            else if (b_rready) begin
                b_rvalid <= 1'b0;
            end
        end
    end

endmodule