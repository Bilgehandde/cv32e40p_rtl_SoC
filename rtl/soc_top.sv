`timescale 1ns / 1ps

module soc_top (
    input  logic clk,           // System Clock Input (e.g., 100MHz from board)
    input  logic rst_n,         // External Reset (Active Low)
    input  logic [15:0] sw_in,  // Slide Switches
    output logic [15:0] gpio_out_pins, // LEDs

    // UART Interfaces
    input  logic uart0_rx, output logic uart0_tx,
    input  logic uart1_rx, output logic uart1_tx,

    // QSPI Flash Interface
    output logic qspi_sck,  // Serial Clock
    output logic qspi_cs_n, // Chip Select (Active Low)
    inout  wire  [3:0] qspi_dq // Data Lines (Quad I/O)
);

    // ========================================================================
    // 1. CLOCK AND RESET GENERATION
    // ========================================================================
    logic clk_50mhz, clk_locked, soc_rst_n;

    // Clock Wizard: Converts input clock to system clock (50MHz)
    clk_wiz_0 u_clock_gen (
        .clk_in1(clk),
        .clk_out1(clk_50mhz),
        .locked(clk_locked)
    );

    // System Reset: Asserted if external reset is low OR clock is not locked
    assign soc_rst_n = rst_n && clk_locked;


    // ========================================================================
    // 2. AXI4-LITE BUS SIGNALS
    // ========================================================================

    // --- Instruction Master Interface (CPU -> Decoder -> ROM/IRAM) ---
    logic [31:0] m0_araddr, m0_rdata;
    logic m0_arvalid, m0_arready, m0_rvalid, m0_rready;

    // --- Data Master Interface (CPU -> Decoder -> IRAM/DRAM/Peripherals) ---
    logic [31:0] m1_awaddr, m1_wdata, m1_araddr, m1_rdata;
    logic [3:0] m1_wstrb;
    logic m1_awvalid, m1_awready, m1_wvalid, m1_wready, m1_bvalid, m1_bready;
    logic m1_arvalid, m1_arready, m1_rvalid, m1_rready;

    // --- Slave Interfaces ---

    // Boot ROM (Instruction Read Only)
    logic [31:0] rom_araddr, rom_rdata;
    logic rom_arvalid, rom_arready, rom_rvalid, rom_rready;

    // Instruction RAM - Port A (CPU Instruction Fetch)
    logic [31:0] iram_a_araddr, iram_a_rdata;
    logic iram_a_arvalid, iram_a_arready, iram_a_rvalid, iram_a_rready;

    // Instruction RAM - Port B (Data Write - Used by Bootloader to copy code)
    logic [31:0] iram_b_awaddr, iram_b_wdata, iram_b_araddr, iram_b_rdata;
    logic [3:0] iram_b_wstrb;
    logic iram_b_awvalid, iram_b_awready, iram_b_wvalid, iram_b_wready, iram_b_bvalid, iram_b_bready;
    logic iram_b_arvalid, iram_b_arready, iram_b_rvalid, iram_b_rready;

    // Data RAM (Standard Data Memory)
    logic [31:0] dram_awaddr, dram_wdata, dram_araddr, dram_rdata;
    logic [3:0] dram_wstrb;
    logic dram_awvalid, dram_awready, dram_wvalid, dram_wready, dram_bvalid, dram_bready;
    logic dram_arvalid, dram_arready, dram_rvalid, dram_rready;

    // Peripheral Subsystem (GPIO, UART, QSPI)
    logic [31:0] periph_awaddr, periph_wdata, periph_araddr, periph_rdata;
    logic [3:0] periph_wstrb;
    logic periph_awvalid, periph_wvalid, periph_bvalid, periph_arvalid, periph_rvalid;
    logic periph_awready, periph_wready, periph_bready, periph_arready, periph_rready;


    // ========================================================================
    // 3. PROCESSOR CORE & BUS INTERCONNECT
    // ========================================================================

    // RISC-V Core Instantiation (CV32E40P Wrapper)
    cv32e40p_axi_top u_cpu_top (
        .clk(clk_50mhz),
        .rst_n(soc_rst_n),
        .boot_addr_i(32'h0000_0000),      // Start executing from ROM
        .mtvec_addr_i(32'h0000_0000),
        .dm_halt_addr_i(32'h0000_0000),
        .hart_id_i(32'h0),
        .dm_exception_addr_i(32'h0000_0000),
        .fetch_enable_i(1'b1),

        // Instruction Master Port -> Connects to Instruction Decoder
        .m_axi_instr_awaddr(), .m_axi_instr_awvalid(), .m_axi_instr_awready(1'b1), // Unused (Write)
        .m_axi_instr_wdata(), .m_axi_instr_wstrb(), .m_axi_instr_wvalid(), .m_axi_instr_wready(1'b1),
        .m_axi_instr_bvalid(1'b0), .m_axi_instr_bready(),
        .m_axi_instr_araddr(m0_araddr), .m_axi_instr_arvalid(m0_arvalid), .m_axi_instr_arready(m0_arready),
        .m_axi_instr_rdata(m0_rdata), .m_axi_instr_rvalid(m0_rvalid), .m_axi_instr_rready(m0_rready),

        // Data Master Port -> Connects to Data Decoder
        .m_axi_data_awaddr(m1_awaddr), .m_axi_data_awvalid(m1_awvalid), .m_axi_data_awready(m1_awready),
        .m_axi_data_wdata(m1_wdata), .m_axi_data_wstrb(m1_wstrb), .m_axi_data_wvalid(m1_wvalid), .m_axi_data_wready(m1_wready),
        .m_axi_data_bvalid(m1_bvalid), .m_axi_data_bready(m1_bready),
        .m_axi_data_araddr(m1_araddr), .m_axi_data_arvalid(m1_arvalid), .m_axi_data_arready(m1_arready),
        .m_axi_data_rdata(m1_rdata), .m_axi_data_rvalid(m1_rvalid), .m_axi_data_rready(m1_rready)
    );

    // Instruction Path Decoder
    // Routes fetch requests to either Boot ROM or Instruction RAM
    axi_instr_decoder u_instr_dec (
        .clk(clk_50mhz), .rst_n(soc_rst_n),
        // Slave Port (From CPU)
        .s_araddr(m0_araddr), .s_arvalid(m0_arvalid), .s_arready(m0_arready),
        .s_rdata(m0_rdata), .s_rvalid(m0_rvalid), .s_rready(m0_rready),
        
        // Master Ports
        .rom_araddr(rom_araddr), .rom_arvalid(rom_arvalid), .rom_arready(rom_arready),
        .rom_rdata(rom_rdata), .rom_rvalid(rom_rvalid), .rom_rready(rom_rready),
        
        .iram_araddr(iram_a_araddr), .iram_arvalid(iram_a_arvalid), .iram_arready(iram_a_arready),
        .iram_rdata(iram_a_rdata), .iram_rvalid(iram_a_rvalid), .iram_rready(iram_a_rready)
    );

    // Data Path Decoder
    // Routes load/store requests to IRAM (write), DRAM, or Peripherals
    axi_data_decoder u_data_dec (
        .clk(clk_50mhz), .rst_n(soc_rst_n),
        // Slave Port (From CPU)
        .s_awaddr(m1_awaddr), .s_awvalid(m1_awvalid), .s_awready(m1_awready),
        .s_wdata(m1_wdata), .s_wstrb(m1_wstrb), .s_wvalid(m1_wvalid), .s_wready(m1_wready),
        .s_bvalid(m1_bvalid), .s_bready(m1_bready),
        .s_araddr(m1_araddr), .s_arvalid(m1_arvalid), .s_arready(m1_arready),
        .s_rdata(m1_rdata), .s_rvalid(m1_rvalid), .s_rready(m1_rready),

        // Master Ports (Targets)
        .iram_awaddr(iram_b_awaddr), .iram_awvalid(iram_b_awvalid), .iram_awready(iram_b_awready),
        .iram_wdata(iram_b_wdata), .iram_wstrb(iram_b_wstrb), .iram_wvalid(iram_b_wvalid), .iram_wready(iram_b_wready),
        .iram_bvalid(iram_b_bvalid), .iram_bready(iram_b_bready),
        .iram_araddr(iram_b_araddr), .iram_arvalid(iram_b_arvalid), .iram_arready(iram_b_arready),
        .iram_rdata(iram_b_rdata), .iram_rvalid(iram_b_rvalid), .iram_rready(iram_b_rready),

        .dram_awaddr(dram_awaddr), .dram_awvalid(dram_awvalid), .dram_awready(dram_awready),
        .dram_wdata(dram_wdata), .dram_wstrb(dram_wstrb), .dram_wvalid(dram_wvalid), .dram_wready(dram_wready),
        .dram_bvalid(dram_bvalid), .dram_bready(dram_bready),
        .dram_araddr(dram_araddr), .dram_arvalid(dram_arvalid), .dram_arready(dram_arready),
        .dram_rdata(dram_rdata), .dram_rvalid(dram_rvalid), .dram_rready(dram_rready),

        .periph_awaddr(periph_awaddr), .periph_awvalid(periph_awvalid), .periph_awready(periph_awready),
        .periph_wdata(periph_wdata), .periph_wstrb(periph_wstrb), .periph_wvalid(periph_wvalid), .periph_wready(periph_wready),
        .periph_bvalid(periph_bvalid), .periph_bready(periph_bready),
        .periph_araddr(periph_araddr), .periph_arvalid(periph_arvalid), .periph_arready(periph_arready),
        .periph_rdata(periph_rdata), .periph_rvalid(periph_rvalid), .periph_rready(periph_rready)
    );


    // ========================================================================
    // 4. MEMORY SUBSYSTEM
    // ========================================================================

    // Boot ROM
    // Contains the initial bootloader logic (Assembly)
    boot_rom u_boot_rom (
        .clk(clk_50mhz), .rst_n(soc_rst_n),
        .araddr(rom_araddr), .arvalid(rom_arvalid), .arready(rom_arready),
        .rdata(rom_rdata), .rvalid(rom_rvalid), .rready(rom_rready)
    );

    // Instruction RAM (Dual Port)
    // Port A: Read-Only for CPU Instruction Fetch
    // Port B: Read/Write for CPU Data Access (used during boot copy)
    dual_port_ram_axi #(.MEM_SIZE_BYTES(8192)) u_inst_ram (
        .clk(clk_50mhz), .rst_n(soc_rst_n),
        // Port A
        .a_araddr(iram_a_araddr), .a_arvalid(iram_a_arvalid), .a_arready(iram_a_arready),
        .a_rdata(iram_a_rdata), .a_rvalid(iram_a_rvalid), .a_rready(iram_a_rready),
        // Port B
        .b_awaddr(iram_b_awaddr), .b_awvalid(iram_b_awvalid), .b_awready(iram_b_awready),
        .b_wdata(iram_b_wdata), .b_wstrb(iram_b_wstrb), .b_wvalid(iram_b_wvalid), .b_wready(iram_b_wready),
        .b_bvalid(iram_b_bvalid), .b_bready(iram_b_bready),
        .b_araddr(iram_b_araddr), .b_arvalid(iram_b_arvalid), .b_arready(iram_b_arready),
        .b_rdata(iram_b_rdata), .b_rvalid(iram_b_rvalid), .b_rready(iram_b_rready)
    );

    // Data RAM (Simple RAM)
    // Used for Stack, Heap, and Variables
    simple_ram #(.MEM_SIZE_BYTES(8192)) u_data_ram (
        .clk(clk_50mhz), .rst_n(soc_rst_n),
        .awaddr(dram_awaddr), .awvalid(dram_awvalid), .awready(dram_awready),
        .wdata(dram_wdata), .wstrb(dram_wstrb), .wvalid(dram_wvalid), .wready(dram_wready),
        .bvalid(dram_bvalid), .bready(dram_bready),
        .araddr(dram_araddr), .arvalid(dram_arvalid), .arready(dram_arready),
        .rdata(dram_rdata), .rvalid(dram_rvalid), .rready(dram_rready)
    );


    // ========================================================================
    // 5. PERIPHERAL SUBSYSTEM
    // ========================================================================
    logic [15:0] gpio_led_signals;

    // Peripheral Wrapper
    // Contains: GPIO, UART, Timer, and QSPI Master
    periph_wrapper u_periph (
        .clk(clk_50mhz), .rst_n(soc_rst_n),
        // AXI Slave Interface
        .s_awaddr(periph_awaddr), .s_awvalid(periph_awvalid), .s_awready(periph_awready),
        .s_wdata(periph_wdata),
        .s_wstrb(periph_wstrb), 
        .s_wvalid(periph_wvalid), .s_wready(periph_wready),
        .s_bvalid(periph_bvalid), .s_bready(periph_bready),
        .s_araddr(periph_araddr), .s_arvalid(periph_arvalid), .s_arready(periph_arready),
        .s_rdata(periph_rdata), .s_rvalid(periph_rvalid), .s_rready(periph_rready),
        
        // IO Connections
        .gpio_in(sw_in), .gpio_out(gpio_led_signals),
        .uart0_rx(uart0_rx), .uart0_tx(uart0_tx),
        .uart1_rx(uart1_rx), .uart1_tx(uart1_tx),
        
        // QSPI Flash Signals
        .qspi_sck(qspi_sck),
        .qspi_cs_n(qspi_cs_n),
        .qspi_dq(qspi_dq)
    );

    // System Status LEDs
    // LED[15]: Clock Locked (System Healthy)
    // LED[14]: System Reset State (Active High for visibility)
    // LED[13:0]: Application controlled LEDs
    assign gpio_out_pins[15] = clk_locked;
    assign gpio_out_pins[14] = soc_rst_n;
    assign gpio_out_pins[13:0] = gpio_led_signals[13:0];


    // ========================================================================
    // 6. DEBUG MONITORS (SIMULATION ONLY)
    // ========================================================================

    // Instruction Bus Monitor
    axi_checker u_instr_monitor (
        .clk(clk_50mhz), .rst_n(soc_rst_n),
        .araddr(m0_araddr), .arvalid(m0_arvalid), .arready(m0_arready),
        .rdata(m0_rdata),   .rvalid(m0_rvalid),   .rready(m0_rready),
        // Write channel unused for instruction path
        .awaddr(32'b0), .awvalid(1'b0), .awready(1'b0),
        .wdata(32'b0),  .wvalid(1'b0),  .wready(1'b0),
        .bvalid(1'b0),  .bready(1'b0)
    );

    // Data Bus Monitor
    axi_checker u_data_monitor (
        .clk(clk_50mhz), .rst_n(soc_rst_n),
        .araddr(m1_araddr), .arvalid(m1_arvalid), .arready(m1_arready),
        .rdata(m1_rdata),   .rvalid(m1_rvalid),   .rready(m1_rready),
        .awaddr(m1_awaddr), .awvalid(m1_awvalid), .awready(m1_awready),
        .wdata(m1_wdata),   .wvalid(m1_wvalid),   .wready(m1_wready),
        .bvalid(m1_bvalid), .bready(m1_bready)
    );

endmodule