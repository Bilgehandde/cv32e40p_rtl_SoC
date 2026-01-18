`timescale 1ns / 1ps

module obi_to_axi (
    input  logic        clk,
    input  logic        rst_n,

    // =========================================================
    // OBI (Slave Interface) - Connected to CPU Core
    // =========================================================
    input  logic        obi_req_i,    // Request
    input  logic        obi_we_i,     // Write Enable
    input  logic [3:0]  obi_be_i,     // Byte Enable
    input  logic [31:0] obi_addr_i,   // Address
    input  logic [31:0] obi_wdata_i,  // Write Data
    output logic        obi_gnt_o,    // Grant (Request Accepted)
    output logic        obi_rvalid_o, // Read Valid (Data Ready / Write Done)
    output logic [31:0] obi_rdata_o,  // Read Data

    // =========================================================
    // AXI4-Lite (Master Interface) - Connected to Interconnect
    // =========================================================
    // Write Address Channel
    output logic [31:0] m_axi_awaddr,
    output logic        m_axi_awvalid,
    input  logic        m_axi_awready,

    // Write Data Channel
    output logic [31:0] m_axi_wdata,
    output logic [3:0]  m_axi_wstrb,
    output logic        m_axi_wvalid,
    input  logic        m_axi_wready,

    // Write Response Channel
    input  logic        m_axi_bvalid,
    output logic        m_axi_bready,

    // Read Address Channel
    output logic [31:0] m_axi_araddr,
    output logic        m_axi_arvalid,
    input  logic        m_axi_arready,

    // Read Data Channel
    input  logic [31:0] m_axi_rdata,
    input  logic        m_axi_rvalid,
    output logic        m_axi_rready
);

    // =========================================================
    // STATE MACHINE DEFINITION
    // =========================================================
    typedef enum logic { 
        TRANS_PHASE, // Phase 1: Send Address/Data Request
        RESP_PHASE   // Phase 2: Wait for Response (Data or Ack)
    } state_t;

    state_t state_q, state_d;

    // Transaction Type Memory (1: Write, 0: Read)
    // We need to remember this because AXI splits Write/Read channels,
    // but OBI expects a unified response.
    logic is_write_q; 

    // =========================================================
    // 1. COMBINATIONAL OUTPUT ASSIGNMENTS
    // =========================================================
    
    // Passthrough Signals (No logic needed)
    assign m_axi_awaddr = obi_addr_i;
    assign m_axi_araddr = obi_addr_i;
    assign m_axi_wdata  = obi_wdata_i;
    assign m_axi_wstrb  = obi_be_i;

    // Direct Data Path: AXI Read Data flows directly to OBI
    assign obi_rdata_o  = m_axi_rdata; 

    // *** CRITICAL LOGIC: RVALID GENERATION ***
    // OBI 'rvalid' signals transaction completion.
    // It asserts ONLY when we are in RESP_PHASE and the AXI slave responds.
    assign obi_rvalid_o = (state_q == RESP_PHASE) && (
                          (is_write_q  && m_axi_bvalid && m_axi_bready) || 
                          (!is_write_q && m_axi_rvalid && m_axi_rready)
                        );

    // =========================================================
    // 2. STATE MACHINE & AXI CONTROL LOGIC
    // =========================================================
    always_comb begin
        // Default Assignments
        state_d   = state_q;
        obi_gnt_o = 1'b0;
        
        // Default AXI Master Outputs (Inactive)
        m_axi_awvalid = 1'b0; 
        m_axi_wvalid  = 1'b0; 
        m_axi_arvalid = 1'b0;
        m_axi_bready  = 1'b0; 
        m_axi_rready  = 1'b0;

        case (state_q)
            
            // -----------------------------------------------------
            // PHASE 1: TRANSACTION REQUEST (Address Phase)
            // -----------------------------------------------------
            TRANS_PHASE: begin
                // Check if Processor (OBI) is requesting a transaction
                if (obi_req_i) begin
                    
                    if (obi_we_i) begin
                        // --- WRITE TRANSACTION ---
                        m_axi_awvalid = 1'b1; // Valid Address
                        m_axi_wvalid  = 1'b1; // Valid Data
                        
                        // Wait for Slave to accept Address AND Data
                        if (m_axi_awready && m_axi_wready) begin
                            obi_gnt_o = 1'b1;    // Acknowledge request to CPU
                            state_d   = RESP_PHASE; // Move to wait for response
                        end
                    end else begin
                        // --- READ TRANSACTION ---
                        m_axi_arvalid = 1'b1; // Valid Address
                        
                        // Wait for Slave to accept Address
                        if (m_axi_arready) begin
                            obi_gnt_o = 1'b1;    // Acknowledge request to CPU
                            state_d   = RESP_PHASE; // Move to wait for data
                        end
                    end
                end
            end

            // -----------------------------------------------------
            // PHASE 2: RESPONSE WAIT (Data Phase)
            // -----------------------------------------------------
            RESP_PHASE: begin
                if (is_write_q) begin
                    // --- Waiting for Write Response (BVALID) ---
                    m_axi_bready = 1'b1; // We are ready to accept response
                    
                    if (m_axi_bvalid) begin
                        // Transaction Complete (obi_rvalid_o becomes 1 combinatorially)
                        state_d = TRANS_PHASE; // Go back to IDLE
                    end
                end else begin
                    // --- Waiting for Read Data (RVALID) ---
                    m_axi_rready = 1'b1; // We are ready to accept data
                    
                    if (m_axi_rvalid) begin
                         // Transaction Complete (obi_rvalid_o becomes 1 combinatorially)
                         state_d = TRANS_PHASE; // Go back to IDLE
                    end
                end
            end

        endcase
    end

    // =========================================================
    // 3. SEQUENTIAL LOGIC (State & Type Storage)
    // =========================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q    <= TRANS_PHASE;
            is_write_q <= 1'b0;
        end else begin
            state_q <= state_d;
            
            // Store Transaction Type when Grant is issued.
            // We need to know if it was a Read or Write during RESP_PHASE.
            if (state_q == TRANS_PHASE && obi_gnt_o) begin
                is_write_q <= obi_we_i;
            end
        end
    end

endmodule