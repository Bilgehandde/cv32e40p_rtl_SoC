`timescale 1ns / 1ps

module dual_port_ram_axi #(
    parameter MEM_SIZE_BYTES = 8192
)(
    input logic clk,
    input logic rst_n,

    // PORT A (Read Only - Instruction)
    input  logic [31:0] a_araddr, input  logic a_arvalid, output logic a_arready,
    output logic [31:0] a_rdata,  output logic a_rvalid,  input  logic a_rready,

    // PORT B (Read/Write - Data)
    input  logic [31:0] b_awaddr, input  logic b_awvalid, output logic b_awready,
    input  logic [31:0] b_wdata,  input  logic [3:0] b_wstrb, input  logic b_wvalid, output logic b_wready,
    output logic        b_bvalid, input  logic b_bready,
    input  logic [31:0] b_araddr, input  logic b_arvalid, output logic b_arready,
    output logic [31:0] b_rdata,  output logic b_rvalid,  input  logic b_rready
);

    // RAM Belleði (Byte Addressable mantýðýyla 32-bit word)
    localparam DEPTH = MEM_SIZE_BYTES / 4;
    logic [31:0] mem [0:DEPTH-1];

    // ========================================================================
    // PORT A: INSTRUCTION FETCH (Sadece Okuma)
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_rvalid <= 1'b0;
            a_rdata  <= 32'b0; // X'leri temizle
        end else begin
            // Handshake varsa veriyi oku
            if (a_arvalid && a_arready) begin
                a_rdata  <= mem[a_araddr[14:2]]; // Word Alignment
                a_rvalid <= 1'b1;
            end 
            else if (a_rready) begin
                a_rvalid <= 1'b0;
            end
        end
    end
    assign a_arready = 1'b1; 


    // ========================================================================
    // PORT B: DATA ACCESS (Okuma ve Yazma)
    // ========================================================================
    
    // --- 1. WRITE CHANNEL ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            b_bvalid <= 1'b0;
        end else begin
            if (b_awvalid && b_wvalid && b_awready && b_wready) begin
                if (b_wstrb[0]) mem[b_awaddr[14:2]][7:0]   <= b_wdata[7:0];
                if (b_wstrb[1]) mem[b_awaddr[14:2]][15:8]  <= b_wdata[15:8];
                if (b_wstrb[2]) mem[b_awaddr[14:2]][23:16] <= b_wdata[23:16];
                if (b_wstrb[3]) mem[b_awaddr[14:2]][31:24] <= b_wdata[31:24];
                b_bvalid <= 1'b1;
            end 
            else if (b_bready) begin
                b_bvalid <= 1'b0;
            end
        end
    end
    
    assign b_awready = 1'b1;
    assign b_wready  = 1'b1;

    // --- 2. READ CHANNEL ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            b_rvalid <= 1'b0;
            b_rdata  <= 32'b0; // X'leri temizle
        end else begin
            if (b_arvalid && b_arready) begin
                b_rdata  <= mem[b_araddr[14:2]];
                b_rvalid <= 1'b1;
            end else if (b_rready) begin
                b_rvalid <= 1'b0;
            end
        end
    end
    assign b_arready = 1'b1;

endmodule