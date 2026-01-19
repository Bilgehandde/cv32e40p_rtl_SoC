`timescale 1ns / 1ps

module cv32e40p_axi_top (
    input  logic        clk,
    input  logic        rst_n,

    // Core Configuration Signals
    input  logic [31:0] boot_addr_i,        // Reset Vector Address
    input  logic [31:0] mtvec_addr_i,       // Interrupt Vector Address
    input  logic [31:0] dm_halt_addr_i,     // Debug Halt Address
    input  logic [31:0] hart_id_i,          // Hardware Thread ID
    input  logic [31:0] dm_exception_addr_i,// Debug Exception Address
    input  logic        fetch_enable_i,     // Enable Instruction Fetch

    // =======================================================================
    // AXI4-LITE MASTER INTERFACE - INSTRUCTION PATH
    // =======================================================================
    // Write Channels (Unused for Instruction Fetch, but required for compliance)
    output logic [31:0] m_axi_instr_awaddr,
    output logic        m_axi_instr_awvalid,
    input  logic        m_axi_instr_awready,
    
    output logic [31:0] m_axi_instr_wdata,
    output logic [3:0]  m_axi_instr_wstrb,
    output logic        m_axi_instr_wvalid,
    input  logic        m_axi_instr_wready,
    
    input  logic        m_axi_instr_bvalid,
    output logic        m_axi_instr_bready,
    
    // Read Channels (Used for Fetching Instructions)
    output logic [31:0] m_axi_instr_araddr,
    output logic        m_axi_instr_arvalid,
    input  logic        m_axi_instr_arready,
    
    input  logic [31:0] m_axi_instr_rdata,
    input  logic        m_axi_instr_rvalid,
    output logic        m_axi_instr_rready,

    // =======================================================================
    // AXI4-LITE MASTER INTERFACE - DATA PATH
    // =======================================================================
    // Write Channels (Load/Store)
    output logic [31:0] m_axi_data_awaddr,
    output logic        m_axi_data_awvalid,
    input  logic        m_axi_data_awready,
    
    output logic [31:0] m_axi_data_wdata,
    output logic [3:0]  m_axi_data_wstrb,
    output logic        m_axi_data_wvalid,
    input  logic        m_axi_data_wready,
    
    input  logic        m_axi_data_bvalid,
    output logic        m_axi_data_bready,
    
    // Read Channels (Load)
    output logic [31:0] m_axi_data_araddr,
    output logic        m_axi_data_arvalid,
    input  logic        m_axi_data_arready,
    
    input  logic [31:0] m_axi_data_rdata,
    input  logic        m_axi_data_rvalid,
    output logic        m_axi_data_rready
);

    // =======================================================================
    // INTERNAL SIGNALS (OBI - Open Bus Interface)
    // =======================================================================
    
    // Instruction Interface Signals
    logic        instr_req;
    logic        instr_gnt;
    logic        instr_rvalid;
    logic [31:0] instr_addr;
    logic [31:0] instr_rdata;

    // Data Interface Signals
    logic        data_req;
    logic        data_gnt;
    logic        data_rvalid;
    logic        data_we;
    logic [3:0]  data_be;
    logic [31:0] data_addr;
    logic [31:0] data_wdata;
    logic [31:0] data_rdata;

    // =======================================================================
    // 1. PROCESSOR CORE INSTANTIATION (CV32E40P)
    // =======================================================================
    cv32e40p_top u_core (
        .clk_i          (clk),
        .rst_ni         (rst_n),
        .pulp_clock_en_i(1'b1), // Clock Gating Disabled for FPGA
        .scan_cg_en_i   (1'b0),
        
        .boot_addr_i    (boot_addr_i),
        .mtvec_addr_i   (mtvec_addr_i),
        .dm_halt_addr_i (dm_halt_addr_i),
        .hart_id_i      (hart_id_i),
        .dm_exception_addr_i(dm_exception_addr_i),
        .fetch_enable_i (fetch_enable_i),
        .core_sleep_o   (), // Unused

        // Instruction Bus (OBI)
        .instr_req_o    (instr_req),
        .instr_gnt_i    (instr_gnt),
        .instr_rvalid_i (instr_rvalid),
        .instr_addr_o   (instr_addr),
        .instr_rdata_i  (instr_rdata),

        // Data Bus (OBI)
        .data_req_o     (data_req),
        .data_gnt_i     (data_gnt),
        .data_rvalid_i  (data_rvalid),
        .data_we_o      (data_we),
        .data_be_o      (data_be),
        .data_addr_o    (data_addr),
        .data_wdata_o   (data_wdata),
        .data_rdata_i   (data_rdata),

        .irq_i          (32'h0), // Interrupts Disabled
        .debug_req_i    (1'b0)   // Debug Request Disabled
    );

    // =======================================================================
    // 2. INSTRUCTION BRIDGE (OBI -> AXI4-LITE)
    // =======================================================================
    // Converts OBI Fetch requests to AXI Read Transactions
    obi_to_axi u_instr_bridge (
        .clk(clk), .rst_n(rst_n),
        
        // OBI Slave Side
        .obi_req_i(instr_req), 
        .obi_we_i(1'b0),         // Instruction path never writes
        .obi_be_i(4'b1111),      // Always full word fetch
        .obi_addr_i(instr_addr), 
        .obi_wdata_i(32'h0),
        .obi_gnt_o(instr_gnt), 
        .obi_rvalid_o(instr_rvalid), 
        .obi_rdata_o(instr_rdata),
        
        // AXI Master Side
        .m_axi_awaddr(m_axi_instr_awaddr), .m_axi_awvalid(m_axi_instr_awvalid), .m_axi_awready(m_axi_instr_awready),
        .m_axi_wdata(m_axi_instr_wdata),   .m_axi_wstrb(m_axi_instr_wstrb),     .m_axi_wvalid(m_axi_instr_wvalid), .m_axi_wready(m_axi_instr_wready),
        .m_axi_bvalid(m_axi_instr_bvalid), .m_axi_bready(m_axi_instr_bready),
        .m_axi_araddr(m_axi_instr_araddr), .m_axi_arvalid(m_axi_instr_arvalid), .m_axi_arready(m_axi_instr_arready),
        .m_axi_rdata(m_axi_instr_rdata),   .m_axi_rvalid(m_axi_instr_rvalid),   .m_axi_rready(m_axi_instr_rready)
    );

    // =======================================================================
    // 3. DATA BRIDGE (OBI -> AXI4-LITE)
    // =======================================================================
    // Converts OBI Load/Store requests to AXI Read/Write Transactions
    obi_to_axi u_data_bridge (
        .clk(clk), .rst_n(rst_n),
        
        // OBI Slave Side
        .obi_req_i(data_req), 
        .obi_we_i(data_we), 
        .obi_be_i(data_be),
        .obi_addr_i(data_addr), 
        .obi_wdata_i(data_wdata),
        .obi_gnt_o(data_gnt), 
        .obi_rvalid_o(data_rvalid), 
        .obi_rdata_o(data_rdata),
        
        // AXI Master Side
        .m_axi_awaddr(m_axi_data_awaddr), .m_axi_awvalid(m_axi_data_awvalid), .m_axi_awready(m_axi_data_awready),
        .m_axi_wdata(m_axi_data_wdata),   .m_axi_wstrb(m_axi_data_wstrb),     .m_axi_wvalid(m_axi_data_wvalid),   .m_axi_wready(m_axi_data_wready),
        .m_axi_bvalid(m_axi_data_bvalid), .m_axi_bready(m_axi_data_bready),
        .m_axi_araddr(m_axi_data_araddr), .m_axi_arvalid(m_axi_data_arvalid), .m_axi_arready(m_axi_data_arready),
        .m_axi_rdata(m_axi_data_rdata),   .m_axi_rvalid(m_axi_data_rvalid),   .m_axi_rready(m_axi_data_rready)
    );

endmodule