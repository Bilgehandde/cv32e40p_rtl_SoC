`timescale 1ns / 1ps

module axi_instr_decoder (
    input  logic clk,
    input  logic rst_n,

    // MASTER PORT (CPU Instruction Port)
    input  logic [31:0] s_araddr, 
    input  logic s_arvalid, 
    output logic s_arready,
    output logic [31:0] s_rdata,  
    output logic s_rvalid,  
    input  logic s_rready,

    // SLAVE 0: BOOT ROM
    output logic [31:0] rom_araddr, 
    output logic rom_arvalid, 
    input  logic rom_arready,
    input  logic [31:0] rom_rdata,  
    input  logic rom_rvalid,  
    output logic rom_rready,

    // SLAVE 1: IRAM (PORT A)
    output logic [31:0] iram_araddr, 
    output logic iram_arvalid, 
    input  logic iram_arready,
    input  logic [31:0] iram_rdata,  
    input  logic iram_rvalid,  
    output logic iram_rready
);

    // Adres Seçiciler (Basit Combinational Logic)
    // 0x000... -> ROM
    // 0x001... -> IRAM
    wire sel_rom  = (s_araddr[31:20] == 12'h000);
    wire sel_iram = (s_araddr[31:20] == 12'h001);

    // -----------------------------------------------------------
    // 1. ADRES YOLU (MASTER -> SLAVE)
    // -----------------------------------------------------------
    // Gelen adresi ve valid sinyalini direkt ilgili slave'e yönlendir.
    // Latch YOK, State Machine YOK.
    
    assign rom_araddr  = s_araddr;
    assign rom_arvalid = s_arvalid && sel_rom;
    
    assign iram_araddr  = s_araddr;
    assign iram_arvalid = s_arvalid && sel_iram;

    // Master'a "Hazırım" cevabı:
    // Hangi slave seçiliyse onun ready sinyalini Master'a ilet.
    // Eğer adres boşluğa denk geliyorsa (default) hemen 1 dön.
    assign s_arready = sel_rom  ? rom_arready :
                       sel_iram ? iram_arready : 
                       1'b1; // Default Ready

    // -----------------------------------------------------------
    // 2. VERİ YOLU (SLAVE -> MASTER)
    // -----------------------------------------------------------
    // Cevap kimden geliyorsa onu Master'a ilet.
    // Burası için basit bir MUX veya 'OR' mantığı yeterli çünkü
    // AXI protokolünde sadece biri valid olur.
    
    always_comb begin
        s_rdata  = 32'b0;
        s_rvalid = 1'b0;
        
        rom_rready  = 1'b0;
        iram_rready = 1'b0;

        // ROM'dan cevap geldiyse
        if (rom_rvalid) begin
            s_rdata    = rom_rdata;
            s_rvalid   = 1'b1;
            rom_rready = s_rready; // Master hazırsa Slave'e ilet
        end
        // IRAM'den cevap geldiyse
        else if (iram_rvalid) begin
            s_rdata    = iram_rdata;
            s_rvalid   = 1'b1;
            iram_rready = s_rready;
        end
    end

endmodule