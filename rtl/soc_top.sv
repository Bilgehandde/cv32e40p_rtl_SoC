`timescale 1ns / 1ps

module soc_top (
    input  logic clk,        // Basys 3 (W5 pini) - 100 MHz
    input  logic rst_n,      // SW15 - Active Low Reset
    output logic [15:0] gpio_out_pins // LED'ler
);

    // ========================================================================
    // 0. SAAT VE RESET YÖNETÝMÝ (EN ÖNEMLÝ KISIM)
    // ========================================================================
    logic clk_50mhz;
    logic clk_locked;  // Clock Wizard'dan gelen "Saat Kararlý" sinyali
    logic soc_rst_n;   // Sistemin kullanacaðý GÜVENLÝ Reset

    // Clock Wizard IP (Sýfýrdan eklediðin hali)
    // Locked portunu açtýðýndan emin ol!
    clk_wiz_0 u_clock_gen (
        .clk_in1  (clk),
        .clk_out1 (clk_50mhz),
        .locked   (clk_locked) 
    );

    // GÜVENLÝ RESET MANTIÐI:
    // Reset, ancak ve ancak "Dýþarýdan Reset gelmiyorsa" (1) VE "Saat Kilitlendiyse" (1) serbest kalýr (1).
    // Aksi takdirde sistem sürekli reset halinde bekler (0).
    assign soc_rst_n = rst_n && clk_locked;

    // Sabit Giriþler
    logic [15:0] gpio_in_pins = 16'h0000;


    // ========================================================================
    // 1. AXI SÝNYALLERÝ (KABLOLAMA)
    // ========================================================================

    // M0: Instruction (CPU -> Interconnect)
    logic [31:0] m0_araddr, m0_rdata;
    logic m0_arvalid, m0_arready, m0_rvalid, m0_rready;

    // M1: Data (CPU -> Interconnect)
    logic [31:0] m1_awaddr, m1_wdata, m1_araddr, m1_rdata;
    logic [3:0]  m1_wstrb;
    logic m1_awvalid, m1_awready, m1_wvalid, m1_wready, m1_bvalid, m1_bready;
    logic m1_arvalid, m1_arready, m1_rvalid, m1_rready;

    // S: Interconnect Output (Interconnect -> Decoder)
    logic [31:0] s_awaddr, s_wdata, s_araddr, s_rdata;
    logic [3:0]  s_wstrb;
    logic s_awvalid, s_awready, s_wvalid, s_wready, s_bvalid, s_bready;
    logic s_arvalid, s_arready, s_rvalid, s_rready;

    // Decoder Outputs (Decoder -> Slaves)
    // ROM
    logic [31:0] rom_araddr, rom_rdata;
    logic rom_arvalid, rom_arready, rom_rvalid, rom_rready;
    // IRAM
    logic [31:0] iram_awaddr, iram_wdata, iram_araddr, iram_rdata; logic [3:0] iram_wstrb;
    logic iram_awvalid, iram_awready, iram_wvalid, iram_wready, iram_bvalid, iram_bready;
    logic iram_arvalid, iram_arready, iram_rvalid, iram_rready;
    // DRAM
    logic [31:0] dram_awaddr, dram_wdata, dram_araddr, dram_rdata; logic [3:0] dram_wstrb;
    logic dram_awvalid, dram_awready, dram_wvalid, dram_wready, dram_bvalid, dram_bready;
    logic dram_arvalid, dram_arready, dram_rvalid, dram_rready;
    // PERIPH
    logic [31:0] periph_awaddr, periph_wdata, periph_araddr, periph_rdata; logic [3:0] periph_wstrb;
    logic periph_awvalid, periph_wvalid, periph_bvalid, periph_arvalid, periph_rvalid;
    logic periph_awready, periph_wready, periph_bready, periph_arready, periph_rready;


    // ========================================================================
    // 2. MODÜLLER
    // ========================================================================

    // ------------------------------------------------------------------------
    // A. CPU (RISC-V Core)
    // ------------------------------------------------------------------------
    cv32e40p_axi_top u_cpu_top (
        .clk(clk_50mhz),
        .rst_n(soc_rst_n), // Güvenli Reset

        // Konfigürasyon (Sabit)
        .boot_addr_i(32'h0000_0000), 
        .mtvec_addr_i(32'h0000_0000), 
        .dm_halt_addr_i(32'h0000_0000),
        .hart_id_i(32'h0), 
        .dm_exception_addr_i(32'h0000_0000), 
        .fetch_enable_i(1'b1),

        // Instruction Master Baðlantýsý
        .m_axi_instr_awaddr (), .m_axi_instr_awvalid(), .m_axi_instr_awready(1'b1), // Yazma yok
        .m_axi_instr_wdata  (), .m_axi_instr_wstrb(),   .m_axi_instr_wvalid(), .m_axi_instr_wready(1'b1),
        .m_axi_instr_bvalid (1'b0), .m_axi_instr_bready(),
        
        .m_axi_instr_araddr (m0_araddr),
        .m_axi_instr_arvalid(m0_arvalid),
        .m_axi_instr_arready(m0_arready),
        .m_axi_instr_rdata  (m0_rdata),
        .m_axi_instr_rvalid (m0_rvalid),
        .m_axi_instr_rready (m0_rready),

        // Data Master Baðlantýsý
        .m_axi_data_awaddr (m1_awaddr),
        .m_axi_data_awvalid(m1_awvalid),
        .m_axi_data_awready(m1_awready),
        .m_axi_data_wdata  (m1_wdata),
        .m_axi_data_wstrb  (m1_wstrb),
        .m_axi_data_wvalid (m1_wvalid),
        .m_axi_data_wready (m1_wready),
        .m_axi_data_bvalid (m1_bvalid),
        .m_axi_data_bready (m1_bready),
        .m_axi_data_araddr (m1_araddr),
        .m_axi_data_arvalid(m1_arvalid),
        .m_axi_data_arready(m1_arready),
        .m_axi_data_rdata  (m1_rdata),
        .m_axi_data_rvalid (m1_rvalid),
        .m_axi_data_rready (m1_rready)
    );

    // ------------------------------------------------------------------------
    // B. INTERCONNECT
    // ------------------------------------------------------------------------
    axi_interconnect_3m u_interconnect (
        .clk(clk_50mhz),
        .rst_n(soc_rst_n),

        // M0: Instruction
        .m0_araddr(m0_araddr), .m0_arvalid(m0_arvalid), .m0_arready(m0_arready),
        .m0_rdata(m0_rdata),   .m0_rvalid(m0_rvalid),   .m0_rready(m0_rready),
        
        // M1: Data
        .m1_awaddr(m1_awaddr), .m1_awvalid(m1_awvalid), .m1_awready(m1_awready),
        .m1_wdata(m1_wdata),   .m1_wstrb(m1_wstrb),     .m1_wvalid(m1_wvalid), .m1_wready(m1_wready),
        .m1_bvalid(m1_bvalid), .m1_bready(m1_bready),
        .m1_araddr(m1_araddr), .m1_arvalid(m1_arvalid), .m1_arready(m1_arready),
        .m1_rdata(m1_rdata),   .m1_rvalid(m1_rvalid),   .m1_rready(m1_rready),

        // M2: DMA (KULLANILMIYOR - GÝRÝÞLER KAPALI)
        .m2_awaddr(32'b0), .m2_awvalid(1'b0), .m2_awready(),
        .m2_wdata(32'b0),  .m2_wstrb(4'b0),   .m2_wvalid(1'b0), .m2_wready(),
        .m2_bvalid(),      .m2_bready(1'b0),
        .m2_araddr(32'b0), .m2_arvalid(1'b0), .m2_arready(),
        .m2_rdata(),       .m2_rvalid(),      .m2_rready(1'b0),

        // Slave Port (Çýkýþ)
        .s_awaddr(s_awaddr), .s_awvalid(s_awvalid), .s_awready(s_awready),
        .s_wdata(s_wdata),   .s_wstrb(s_wstrb),     .s_wvalid(s_wvalid), .s_wready(s_wready),
        .s_bvalid(s_bvalid), .s_bready(s_bready),
        .s_araddr(s_araddr), .s_arvalid(s_arvalid), .s_arready(s_arready),
        .s_rdata(s_rdata),   .s_rvalid(s_rvalid),   .s_rready(s_rready)
    );

    // ------------------------------------------------------------------------
    // C. DECODER
    // ------------------------------------------------------------------------
    axi_decoder u_decoder (
        // Giriþ (Interconnect'ten gelen)
        .s_awaddr(s_awaddr), .s_awvalid(s_awvalid), .s_awready(s_awready),
        .s_wdata(s_wdata),   .s_wstrb(s_wstrb),     .s_wvalid(s_wvalid), .s_wready(s_wready),
        .s_bvalid(s_bvalid), .s_bready(s_bready),
        .s_araddr(s_araddr), .s_arvalid(s_arvalid), .s_arready(s_arready),
        .s_rdata(s_rdata),   .s_rvalid(s_rvalid),   .s_rready(s_rready),

        // Çýkýþ 1: Boot ROM
        .rom_araddr(rom_araddr), .rom_arvalid(rom_arvalid), .rom_arready(rom_arready),
        .rom_rdata(rom_rdata),   .rom_rvalid(rom_rvalid),   .rom_rready(rom_rready),

        // Çýkýþ 2: Instruction RAM
        .iram_awaddr(iram_awaddr), .iram_awvalid(iram_awvalid), .iram_awready(iram_awready),
        .iram_wdata(iram_wdata),   .iram_wstrb(iram_wstrb),     .iram_wvalid(iram_wvalid), .iram_wready(iram_wready),
        .iram_bvalid(iram_bvalid), .iram_bready(iram_bready),
        .iram_araddr(iram_araddr), .iram_arvalid(iram_arvalid), .iram_arready(iram_arready),
        .iram_rdata(iram_rdata),   .iram_rvalid(iram_rvalid),   .iram_rready(iram_rready),

        // Çýkýþ 3: Data RAM
        .dram_awaddr(dram_awaddr), .dram_awvalid(dram_awvalid), .dram_awready(dram_awready),
        .dram_wdata(dram_wdata),   .dram_wstrb(dram_wstrb),     .dram_wvalid(dram_wvalid), .dram_wready(dram_wready),
        .dram_bvalid(dram_bvalid), .dram_bready(dram_bready),
        .dram_araddr(dram_araddr), .dram_arvalid(dram_arvalid), .dram_arready(dram_arready),
        .dram_rdata(dram_rdata),   .dram_rvalid(dram_rvalid),   .dram_rready(dram_rready),

        // Çýkýþ 4: Peripherals
        .periph_awaddr(periph_awaddr), .periph_awvalid(periph_awvalid), .periph_awready(periph_awready),
        .periph_wdata(periph_wdata),   .periph_wstrb(periph_wstrb),     .periph_wvalid(periph_wvalid), .periph_wready(periph_wready),
        .periph_bvalid(periph_bvalid), .periph_bready(periph_bready),
        .periph_araddr(periph_araddr), .periph_arvalid(periph_arvalid), .periph_arready(periph_arready),
        .periph_rdata(periph_rdata),   .periph_rvalid(periph_rvalid),   .periph_rready(periph_rready)
    );

    // ------------------------------------------------------------------------
    // D. SLAVE MODÜLLERÝ
    // ------------------------------------------------------------------------

    boot_rom u_boot_rom (
        .clk(clk_50mhz),
        .rst_n(soc_rst_n),
        .araddr(rom_araddr), .arvalid(rom_arvalid), .arready(rom_arready),
        .rdata(rom_rdata),   .rvalid(rom_rvalid),   .rready(rom_rready)
    );
    
    simple_ram #(.MEM_SIZE_BYTES(8192)) u_inst_ram (
        .clk(clk_50mhz),
        .rst_n(soc_rst_n),
        .awaddr(iram_awaddr), .awvalid(iram_awvalid), .awready(iram_awready),
        .wdata(iram_wdata),   .wstrb(iram_wstrb),     .wvalid(iram_wvalid), .wready(iram_wready),
        .bvalid(iram_bvalid), .bready(iram_bready),
        .araddr(iram_araddr), .arvalid(iram_arvalid), .arready(iram_arready),
        .rdata(iram_rdata),   .rvalid(iram_rvalid),   .rready(iram_rready)
    );

    simple_ram #(.MEM_SIZE_BYTES(8192)) u_data_ram (
        .clk(clk_50mhz),
        .rst_n(soc_rst_n),
        .awaddr(dram_awaddr), .awvalid(dram_awvalid), .awready(dram_awready),
        .wdata(dram_wdata),   .wstrb(dram_wstrb),     .wvalid(dram_wvalid), .wready(dram_wready),
        .bvalid(dram_bvalid), .bready(dram_bready),
        .araddr(dram_araddr), .arvalid(dram_arvalid), .arready(dram_arready),
        .rdata(dram_rdata),   .rvalid(dram_rvalid),   .rready(dram_rready)
    );

    periph_wrapper u_periph (
        .clk(clk_50mhz),
        .rst_n(soc_rst_n),
        .s_awaddr(periph_awaddr), .s_awvalid(periph_awvalid), .s_awready(periph_awready),
        .s_wdata(periph_wdata),   .s_wvalid(periph_wvalid),   .s_wready(periph_wready), 
        .s_bvalid(periph_bvalid), .s_bready(periph_bready),
        .s_araddr(periph_araddr), .s_arvalid(periph_arvalid), .s_arready(periph_arready),
        .s_rdata(periph_rdata),   .s_rvalid(periph_rvalid),   .s_rready(periph_rready),
        .gpio_in(gpio_in_pins), .gpio_out(gpio_out_pins)
    );

endmodule