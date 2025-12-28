`timescale 1ns / 1ps

module axi_decoder (
    // ==========================================================
    // 1. GÝRÝÞ PORTU (Interconnect'ten Gelen Tek Kanal)
    // ==========================================================
    // Yazma Kanallarý (Master -> Decoder)
    input  logic [31:0] s_awaddr, 
    input  logic        s_awvalid, 
    output logic        s_awready, // Decoder -> Master
    input  logic [31:0] s_wdata,  
    input  logic [3:0]  s_wstrb,   // Byte Enable eklendi
    input  logic        s_wvalid,  
    output logic        s_wready,  // Decoder -> Master
    output logic        s_bvalid,  // Decoder -> Master
    input  logic        s_bready,

    // Okuma Kanallarý (Master -> Decoder)
    input  logic [31:0] s_araddr, 
    input  logic        s_arvalid, 
    output logic        s_arready, // Decoder -> Master
    output logic [31:0] s_rdata,   // Decoder -> Master
    output logic        s_rvalid,  // Decoder -> Master
    input  logic        s_rready,

    // ==========================================================
    // 2. ÇIKIÞ PORTLARI (Hafýzalara ve Çevre Birimlerine Gider)
    // ==========================================================
    
    // SLAVE 0: BOOT ROM (Adres: 0x0000_XXXX)
    output logic [31:0] rom_araddr, output logic rom_arvalid, input logic rom_arready,
    input  logic [31:0] rom_rdata,  input  logic rom_rvalid,  output logic rom_rready,
    // (ROM sadece okunur, yazma portlarýna gerek yok)

    // SLAVE 1: INSTRUCTION RAM (Adres: 0x0010_XXXX)
    output logic [31:0] iram_awaddr, output logic iram_awvalid, input logic iram_awready,
    output logic [31:0] iram_wdata,  output logic [3:0] iram_wstrb, output logic iram_wvalid,  input logic iram_wready,
    input  logic        iram_bvalid, output logic iram_bready,
    output logic [31:0] iram_araddr, output logic iram_arvalid, input logic iram_arready,
    input  logic [31:0] iram_rdata,  input  logic iram_rvalid,  output logic iram_rready,

    // SLAVE 2: DATA RAM (Adres: 0x0020_XXXX)
    output logic [31:0] dram_awaddr, output logic dram_awvalid, input logic dram_awready,
    output logic [31:0] dram_wdata,  output logic [3:0] dram_wstrb, output logic dram_wvalid,  input logic dram_wready,
    input  logic        dram_bvalid, output logic dram_bready,
    output logic [31:0] dram_araddr, output logic dram_arvalid, input logic dram_arready,
    input  logic [31:0] dram_rdata,  input  logic dram_rvalid,  output logic dram_rready,

    // SLAVE 3: PERIPHERALS (Adres: 0x1000_XXXX)
    output logic [31:0] periph_awaddr, output logic periph_awvalid, input logic periph_awready,
    output logic [31:0] periph_wdata,  output logic [3:0] periph_wstrb, output logic periph_wvalid,  input logic periph_wready,
    input  logic        periph_bvalid, output logic periph_bready,
    output logic [31:0] periph_araddr, output logic periph_arvalid, input logic periph_arready,
    input  logic [31:0] periph_rdata,  input  logic periph_rvalid,  output logic periph_rready
);

    logic [1:0] read_sel;
    logic [1:0] write_sel;

    // ==========================================================
    // ADRES ÇÖZÜCÜLER (ADDRESS DECODING)
    // ==========================================================

    // OKUMA (READ) ADRESÝNE GÖRE SEÇÝM
    // 0:ROM, 1:IRAM, 2:DRAM, 3:PERIPH
    always_comb begin
        case (s_araddr[31:20]) // Ýlk 3 hex hanesine bak (4KB/1MB bloklar)
            12'h000: read_sel = 2'b00; // 0x0000_... -> Boot ROM
            12'h001: read_sel = 2'b01; // 0x0010_... -> Instr RAM
            12'h002: read_sel = 2'b10; // 0x0020_... -> Data RAM
            12'h100: read_sel = 2'b11; // 0x1000_... -> Peripherals
            default: read_sel = 2'b00; // Hata durumunda ROM'a düþsün (Güvenlik)
        endcase
    end

    // YAZMA (WRITE) ADRESÝNE GÖRE SEÇÝM
    always_comb begin
        case (s_awaddr[31:20])
            12'h000: write_sel = 2'b00; // ROM'a yazýlmaz (Boþa düþecek)
            12'h001: write_sel = 2'b01; // Instr RAM
            12'h002: write_sel = 2'b10; // Data RAM
            12'h100: write_sel = 2'b11; // Peripherals
            default: write_sel = 2'b00;
        endcase
    end

    // ==========================================================
    // MUX / DEMUX MANTIÐI (Sinyal Yönlendirme)
    // ==========================================================

    // ------------------- READ CHANNEL -------------------
    
    // 1. MASTER -> SLAVE (Adres ve Valid Sinyalleri)
    assign rom_arvalid    = (read_sel == 2'b00) ? s_arvalid : 1'b0;
    assign iram_arvalid   = (read_sel == 2'b01) ? s_arvalid : 1'b0;
    assign dram_arvalid   = (read_sel == 2'b10) ? s_arvalid : 1'b0;
    assign periph_arvalid = (read_sel == 2'b11) ? s_arvalid : 1'b0;

    // Adresi herkese gönder, sadece Valid olan alýr
    assign rom_araddr = s_araddr; 
    assign iram_araddr = s_araddr; 
    assign dram_araddr = s_araddr; 
    assign periph_araddr = s_araddr;
    
    // 2. SLAVE -> MASTER (Cevaplar: Ready, Data, Valid)
    assign s_arready = (read_sel == 2'b00) ? rom_arready : 
                       (read_sel == 2'b01) ? iram_arready : 
                       (read_sel == 2'b10) ? dram_arready : periph_arready;

    assign s_rdata = (read_sel == 2'b00) ? rom_rdata : 
                     (read_sel == 2'b01) ? iram_rdata : 
                     (read_sel == 2'b10) ? dram_rdata : periph_rdata;
                     
    assign s_rvalid = (read_sel == 2'b00) ? rom_rvalid : 
                      (read_sel == 2'b01) ? iram_rvalid : 
                      (read_sel == 2'b10) ? dram_rvalid : periph_rvalid;
    
    // Master'ýn "Hazýrým" sinyalini tüm Slave'lere ilet
    assign rom_rready = s_rready;
    assign iram_rready = s_rready;
    assign dram_rready = s_rready;
    assign periph_rready = s_rready;


    // ------------------- WRITE CHANNELS -------------------

    // 1. MASTER -> SLAVE (Adres, Data, Valid)
    // Valid sinyallerini seçiciye göre aç/kapa
    assign iram_awvalid   = (write_sel == 2'b01) ? s_awvalid : 1'b0;
    assign dram_awvalid   = (write_sel == 2'b10) ? s_awvalid : 1'b0;
    assign periph_awvalid = (write_sel == 2'b11) ? s_awvalid : 1'b0;
    
    assign iram_wvalid    = (write_sel == 2'b01) ? s_wvalid : 1'b0;
    assign dram_wvalid    = (write_sel == 2'b10) ? s_wvalid : 1'b0;
    assign periph_wvalid  = (write_sel == 2'b11) ? s_wvalid : 1'b0;

    // Verileri herkese gönder
    assign iram_awaddr = s_awaddr; 
    assign dram_awaddr = s_awaddr; 
    assign periph_awaddr = s_awaddr;
    assign iram_wdata  = s_wdata;  
    assign dram_wdata  = s_wdata;  
    assign periph_wdata  = s_wdata;
    assign iram_wstrb  = s_wstrb;  
    assign dram_wstrb  = s_wstrb;  
    assign periph_wstrb  = s_wstrb;

    // 2. SLAVE -> MASTER (Ready, BValid)
    assign s_awready = (write_sel == 2'b01) ? iram_awready : 
                       (write_sel == 2'b10) ? dram_awready : 
                       (write_sel == 2'b11) ? periph_awready : 1'b0;
                       
    assign s_wready  = (write_sel == 2'b01) ? iram_wready : 
                       (write_sel == 2'b10) ? dram_wready : 
                       (write_sel == 2'b11) ? periph_wready : 1'b0;
                       
    assign s_bvalid  = (write_sel == 2'b01) ? iram_bvalid : 
                       (write_sel == 2'b10) ? dram_bvalid : 
                       (write_sel == 2'b11) ? periph_bvalid : 1'b0;

    assign iram_bready = s_bready;
    assign dram_bready = s_bready;
    assign periph_bready = s_bready;

endmodule