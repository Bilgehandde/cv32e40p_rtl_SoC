`timescale 1ns / 1ps

module periph_wrapper (
    input  logic clk,
    input  logic rst_n,

    // AXI Bus
    input  logic [31:0] s_awaddr, input logic s_awvalid, output logic s_awready,
    input  logic [31:0] s_wdata,  input logic s_wvalid,  output logic s_wready,
    output logic        s_bvalid, input logic s_bready,
    input  logic [31:0] s_araddr, input logic s_arvalid, output logic s_arready,
    output logic [31:0] s_rdata,  output logic s_rvalid, input logic s_rready,

    // Pins
    input  logic [15:0] gpio_in,
    output logic [15:0] gpio_out
);

    // ---------------------------------------------------------
    // ADRES ÇÖZÜMLEME
    // ---------------------------------------------------------
    logic [1:0] p_sel_read;  // Okuma için seçim
    logic [1:0] p_sel_write; // Yazma için seçim

    // 0x1000_0... -> GPIO
    // 0x1000_1... -> TIMER
    
    // Okuma Adresi Seçimi
    always_comb begin
        case (s_araddr[15:12]) 
            4'h0: p_sel_read = 2'b00; // GPIO
            4'h1: p_sel_read = 2'b01; // TIMER
            default: p_sel_read = 2'b00;
        endcase
    end

    // Yazma Adresi Seçimi
    always_comb begin
        case (s_awaddr[15:12]) 
            4'h0: p_sel_write = 2'b00; // GPIO
            4'h1: p_sel_write = 2'b01; // TIMER
            default: p_sel_write = 2'b00;
        endcase
    end

    // ---------------------------------------------------------
    // 1. GPIO MODÜLÜ
    // ---------------------------------------------------------
    logic [31:0] gpio_rdata; logic gpio_rvalid; logic gpio_bvalid;
    
    axi_gpio u_gpio (
        .clk(clk), .rst_n(rst_n),
        // Sadece Yazma Adresi 0x...0 ise Valid gönder
        .s_awaddr(s_awaddr), .s_awvalid(s_awvalid && (p_sel_write == 2'b00)), 
        .s_wdata(s_wdata),   .s_wvalid(s_wvalid && (p_sel_write == 2'b00)),
        .s_bvalid(gpio_bvalid), .s_bready(s_bready),
        
        // Sadece Okuma Adresi 0x...0 ise Valid gönder
        .s_araddr(s_araddr), .s_arvalid(s_arvalid && (p_sel_read == 2'b00)),
        .s_rdata(gpio_rdata), .s_rvalid(gpio_rvalid), .s_rready(s_rready),
        
        // Pinler
        .gpio_in(gpio_in), .gpio_out(gpio_out)
    );

    // ---------------------------------------------------------
    // 2. TIMER MODÜLÜ (EKLENDÝ)
    // ---------------------------------------------------------
    logic [31:0] timer_rdata; logic timer_rvalid; logic timer_bvalid;

    axi_timer u_timer (
        .clk(clk), .rst_n(rst_n),
        // Sadece Yazma Adresi 0x...1 ise Valid gönder
        .s_awaddr(s_awaddr), .s_awvalid(s_awvalid && (p_sel_write == 2'b01)), 
        .s_wdata(s_wdata),   .s_wvalid(s_wvalid && (p_sel_write == 2'b01)),
        .s_bvalid(timer_bvalid), .s_bready(s_bready),
        
        // Sadece Okuma Adresi 0x...1 ise Valid gönder
        .s_araddr(s_araddr), .s_arvalid(s_arvalid && (p_sel_read == 2'b01)),
        .s_rdata(timer_rdata), .s_rvalid(timer_rvalid), .s_rready(s_rready)
    );

    // ---------------------------------------------------------
    // CEVAPLARI BÝRLEÞTÝR (MUX / OR)
    // ---------------------------------------------------------

    // Read Data MUX
    always_comb begin
        case (p_sel_read)
            2'b00: begin s_rdata = gpio_rdata; s_rvalid = gpio_rvalid; end
            2'b01: begin s_rdata = timer_rdata; s_rvalid = timer_rvalid; end
            default: begin s_rdata = 32'b0; s_rvalid = 1'b0; end
        endcase
    end

    // Write Response MUX (BValid)
    always_comb begin
        case (p_sel_write)
            2'b00: s_bvalid = gpio_bvalid;
            2'b01: s_bvalid = timer_bvalid;
            default: s_bvalid = 1'b0;
        endcase
    end

    // Ready sinyalleri (Hepsi 1 cycle'da cevap veriyor varsayýyoruz)
    assign s_awready = 1'b1; 
    assign s_wready  = 1'b1; 
    assign s_arready = 1'b1; 

endmodule