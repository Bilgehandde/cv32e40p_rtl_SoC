`timescale 1ns / 1ps

module axi_timer (
    input  logic clk,
    input  logic rst_n,

    // AXI4-Lite Slave Arayüzü
    input  logic [31:0] s_awaddr, 
    input  logic        s_awvalid, 
    output logic        s_awready, // <--- EKLENDÝ

    input  logic [31:0] s_wdata,  
    input  logic        s_wvalid,  
    output logic        s_wready,  // <--- EKLENDÝ

    output logic        s_bvalid, 
    input  logic        s_bready,

    input  logic [31:0] s_araddr, 
    input  logic        s_arvalid, 
    output logic        s_arready, // <--- EKLENDÝ

    output logic [31:0] s_rdata,  
    output logic        s_rvalid, 
    input  logic        s_rready,
    
    input  logic [3:0]  s_wstrb
);

    // Register Haritasý
    logic [31:0] reg_ctrl;
    logic [31:0] reg_count;
    logic [31:0] reg_prescale;
    
    // AXI Handshake (Always Ready)
    assign s_awready = 1'b1; 
    assign s_wready  = 1'b1; 
    assign s_arready = 1'b1;

    // --- SAYMA MANTIÐI ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_count <= 32'b0;
        end else begin
            if (reg_ctrl[1]) begin // Reset Bit
                reg_count <= 32'b0;
            end else if (reg_ctrl[0]) begin // Enable Bit
                reg_count <= reg_count + 1;
            end
        end
    end

    // --- YAZMA ÝÞLEMÝ ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_ctrl <= 32'b0;
            reg_prescale <= 32'b0;
            s_bvalid <= 1'b0;
        end else begin
            // Valid geldiðinde yaz (Ready kontrolüne gerek yok, zaten 1)
            if (s_awvalid && s_wvalid) begin
                case (s_awaddr[3:0])
                    4'h0: reg_ctrl <= s_wdata; // 0x00
                    4'h8: reg_prescale <= s_wdata; // 0x08
                endcase
                s_bvalid <= 1'b1;
            end 
            // Master cevabý aldýysa
            else if (s_bready) begin
                s_bvalid <= 1'b0;
                reg_ctrl[1] <= 1'b0; // Self-clearing reset
            end
        end
    end

    // --- OKUMA ÝÞLEMÝ ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin 
            s_rvalid <= 1'b0; 
            s_rdata <= 32'b0; 
        end else begin
            if (s_arvalid) begin
                s_rvalid <= 1'b1;
                case (s_araddr[3:0])
                    4'h0: s_rdata <= reg_ctrl;
                    4'h4: s_rdata <= reg_count;
                    4'h8: s_rdata <= reg_prescale;
                    default: s_rdata <= 32'b0;
                endcase
            end else if (s_rready) begin
                s_rvalid <= 1'b0;
            end
        end
    end
endmodule