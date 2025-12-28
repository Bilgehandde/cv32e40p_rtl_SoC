`timescale 1ns / 1ps

module axi_timer (
    input  logic clk,
    input  logic rst_n,

    // AXI4-Lite Slave Arayüzü
    input  logic [31:0] s_awaddr, input logic s_awvalid, output logic s_awready,
    input  logic [31:0] s_wdata,  input logic s_wvalid,  output logic s_wready,
    output logic        s_bvalid, input logic s_bready,
    input  logic [31:0] s_araddr, input logic s_arvalid, output logic s_arready,
    output logic [31:0] s_rdata,  output logic s_rvalid, input logic s_rready
);

    // Register Haritasý
    // 0x00: Kontrol Register (Bit 0: Enable, Bit 1: Reset Counter)
    // 0x04: Counter Deðeri (Read Only)
    // 0x08: Prescaler (Hýz Bölücü)
    
    logic [31:0] reg_ctrl;
    logic [31:0] reg_count;
    logic [31:0] reg_prescale;
    
    // AXI Handshake
    assign s_awready = 1'b1; assign s_wready = 1'b1; assign s_arready = 1'b1;

    // --- SAYMA MANTIÐI ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_count <= 32'b0;
        end else begin
            if (reg_ctrl[1]) begin // Reset Bit
                reg_count <= 32'b0;
            end else if (reg_ctrl[0]) begin // Enable Bit
                // Burada basitlik için her cycle artýrýyorum.
                // Prescaler mantýðý buraya eklenebilir.
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
            if (s_awvalid && s_wvalid) begin
                case (s_awaddr[3:0])
                    4'h00: reg_ctrl <= s_wdata; // Kontrol Yaz
                    4'h08: reg_prescale <= s_wdata; // Prescale Yaz
                endcase
                s_bvalid <= 1'b1;
            end else if (s_bready) begin
                s_bvalid <= 1'b0;
                reg_ctrl[1] <= 1'b0; // Reset bitini otomatik temizle (Self-clearing)
            end
        end
    end

    // --- OKUMA ÝÞLEMÝ ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin s_rvalid <= 1'b0; s_rdata <= 32'b0; end
        else begin
            if (s_arvalid) begin
                s_rvalid <= 1'b1;
                case (s_araddr[3:0])
                    4'h00: s_rdata <= reg_ctrl;
                    4'h04: s_rdata <= reg_count;
                    4'h08: s_rdata <= reg_prescale;
                    default: s_rdata <= 32'b0;
                endcase
            end else if (s_rready) s_rvalid <= 1'b0;
        end
    end
endmodule