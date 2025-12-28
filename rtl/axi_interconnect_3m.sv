`timescale 1ns / 1ps

module axi_interconnect_3m (
    input logic clk,
    input logic rst_n,

    // MASTER 0: INSTRUCTION (Read Only)
    input  logic [31:0] m0_araddr, input logic m0_arvalid, output logic m0_arready,
    output logic [31:0] m0_rdata,  output logic m0_rvalid, input logic m0_rready,

    // MASTER 1: DATA (Read/Write)
    input  logic [31:0] m1_awaddr, input logic m1_awvalid, output logic m1_awready,
    input  logic [31:0] m1_wdata,  input logic [3:0] m1_wstrb, input logic m1_wvalid, output logic m1_wready,
    output logic        m1_bvalid, input logic m1_bready,
    input  logic [31:0] m1_araddr, input logic m1_arvalid, output logic m1_arready,
    output logic [31:0] m1_rdata,  output logic m1_rvalid, input logic m1_rready,

    // MASTER 2: DMA (Read/Write)
    input  logic [31:0] m2_awaddr, input logic m2_awvalid, output logic m2_awready,
    input  logic [31:0] m2_wdata,  input logic [3:0] m2_wstrb, input logic m2_wvalid, output logic m2_wready,
    output logic        m2_bvalid, input logic m2_bready,
    input  logic [31:0] m2_araddr, input logic m2_arvalid, output logic m2_arready,
    output logic [31:0] m2_rdata,  output logic m2_rvalid, input logic m2_rready,

    // SLAVE PORT (Shared Bus)
    output logic [31:0] s_awaddr, output logic s_awvalid, input logic s_awready,
    output logic [31:0] s_wdata,  output logic [3:0] s_wstrb, output logic s_wvalid, input logic s_wready,
    input  logic        s_bvalid, output logic s_bready,
    output logic [31:0] s_araddr, output logic s_arvalid, input logic s_arready,
    input  logic [31:0] s_rdata,  input  logic s_rvalid,  output logic s_rready
);

    typedef enum logic [1:0] {GRANT_M0, GRANT_M1, GRANT_M2} grant_t;
    grant_t current_grant, next_grant;

    logic req_m0, req_m1, req_m2;
    assign req_m0 = m0_arvalid; 
    assign req_m1 = m1_arvalid || m1_awvalid;
    assign req_m2 = m2_arvalid || m2_awvalid;

    // --- LOCK (KÝLÝT) MANTIÐI ---
    // Bir iþlem baþladýðýnda (Adres/Data gittiðinde), cevap gelene kadar arbiter'ý kilitle.
    logic busy_write, busy_read;

    // Yazma Ýþlemi Takibi (Start: Address Handshake, End: BValid Handshake)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) busy_write <= 1'b0;
        else begin
            if (s_awvalid && s_awready) busy_write <= 1'b1; // Yazma Baþladý
            else if (s_bvalid && s_bready) busy_write <= 1'b0; // Yazma Bitti (Cevap geldi)
        end
    end

    // Okuma Ýþlemi Takibi (Start: Address Handshake, End: RValid Handshake)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) busy_read <= 1'b0;
        else begin
            if (s_arvalid && s_arready) busy_read <= 1'b1; // Okuma Baþladý
            else if (s_rvalid && s_rready) busy_read <= 1'b0; // Okuma Bitti (Cevap geldi)
        end
    end

    // --- ARBITER MANTIÐI ---
    always_comb begin
        next_grant = current_grant; // Varsayýlan: Deðiþme

        // Eðer sistem meþgulse (Cevap bekleniyorsa) asla master deðiþtirme!
        if (!busy_write && !busy_read) begin
            case (current_grant)
                GRANT_M0: begin
                    if (req_m1) next_grant = GRANT_M1;
                    else if (req_m2) next_grant = GRANT_M2;
                end
                GRANT_M1: begin
                    if (req_m2) next_grant = GRANT_M2;
                    else if (req_m0) next_grant = GRANT_M0;
                end
                GRANT_M2: begin
                    if (req_m0) next_grant = GRANT_M0;
                    else if (req_m1) next_grant = GRANT_M1;
                end
                default: next_grant = GRANT_M0;
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_grant <= GRANT_M0;
        else current_grant <= next_grant;
    end

    // MUX Logic (Master to Slave)
    assign s_awaddr  = (current_grant == GRANT_M1) ? m1_awaddr : (current_grant == GRANT_M2) ? m2_awaddr : 32'b0;
    assign s_awvalid = (current_grant == GRANT_M1) ? m1_awvalid : (current_grant == GRANT_M2) ? m2_awvalid : 1'b0;
    assign s_wdata   = (current_grant == GRANT_M1) ? m1_wdata : (current_grant == GRANT_M2) ? m2_wdata : 32'b0;
    assign s_wstrb   = (current_grant == GRANT_M1) ? m1_wstrb : (current_grant == GRANT_M2) ? m2_wstrb : 4'b0;
    assign s_wvalid  = (current_grant == GRANT_M1) ? m1_wvalid : (current_grant == GRANT_M2) ? m2_wvalid : 1'b0;
    assign s_bready  = (current_grant == GRANT_M1) ? m1_bready : (current_grant == GRANT_M2) ? m2_bready : 1'b0;
    assign s_araddr  = (current_grant == GRANT_M0) ? m0_araddr : (current_grant == GRANT_M1) ? m1_araddr : (current_grant == GRANT_M2) ? m2_araddr : 32'b0;
    assign s_arvalid = (current_grant == GRANT_M0) ? m0_arvalid : (current_grant == GRANT_M1) ? m1_arvalid : (current_grant == GRANT_M2) ? m2_arvalid : 1'b0;
    assign s_rready  = (current_grant == GRANT_M0) ? m0_rready : (current_grant == GRANT_M1) ? m1_rready : (current_grant == GRANT_M2) ? m2_rready : 1'b0;

    // DEMUX Logic (Slave to Master)
    assign m0_arready = (current_grant == GRANT_M0) ? s_arready : 1'b0;
    assign m0_rdata   = s_rdata;
    assign m0_rvalid  = (current_grant == GRANT_M0) ? s_rvalid  : 1'b0;

    assign m1_awready = (current_grant == GRANT_M1) ? s_awready : 1'b0;
    assign m1_wready  = (current_grant == GRANT_M1) ? s_wready  : 1'b0;
    assign m1_bvalid  = (current_grant == GRANT_M1) ? s_bvalid  : 1'b0;
    assign m1_arready = (current_grant == GRANT_M1) ? s_arready : 1'b0;
    assign m1_rdata   = s_rdata;
    assign m1_rvalid  = (current_grant == GRANT_M1) ? s_rvalid  : 1'b0;

    assign m2_awready = (current_grant == GRANT_M2) ? s_awready : 1'b0;
    assign m2_wready  = (current_grant == GRANT_M2) ? s_wready  : 1'b0;
    assign m2_bvalid  = (current_grant == GRANT_M2) ? s_bvalid  : 1'b0;
    assign m2_arready = (current_grant == GRANT_M2) ? s_arready : 1'b0;
    assign m2_rdata   = s_rdata;
    assign m2_rvalid  = (current_grant == GRANT_M2) ? s_rvalid  : 1'b0;

endmodule