`timescale 1ns / 1ps

module axi_qspi_master (
    input  logic        aclk,
    input  logic        aresetn,

    // =======================================================================
    // AXI4-LITE SLAVE INTERFACE
    // =======================================================================
    // Write Address
    input  logic [31:0] s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready, // Always Ready

    // Write Data
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,  // Always Ready

    // Write Response
    output logic [1:0]  s_axi_bresp,   // Always OKAY (00)
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,

    // Read Address
    input  logic [31:0] s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready, // Always Ready

    // Read Data
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,   // Always OKAY (00)
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    // =======================================================================
    // PHYSICAL QSPI PINS (To External Flash)
    // =======================================================================
    output logic        qspi_sck,  // Serial Clock
    output logic        qspi_cs_n, // Chip Select (Active Low)
    inout  wire  [3:0]  qspi_dq    // Data Lines (DQ0=MOSI, DQ1=MISO)
);

    // =======================================================================
    // INTERNAL REGISTERS
    // =======================================================================
    logic [31:0] reg_ctrl;   // Control Register (Write 0x3 to Start)
    logic [31:0] reg_addr;   // Flash Address to read from
    logic [31:0] reg_data;   // Data read from Flash
    logic        start_pulse; // Trigger signal
    logic        busy_reg;    // Status Flag (1=Busy, 0=Ready)

    // SPI Engine Signals
    logic        spi_clk_reg, spi_clk_prev;
    logic [7:0]  shift_cmd;
    logic [23:0] shift_addr;
    logic [31:0] bit_cnt;
    logic [3:0]  dq_out, dq_oe;

    // FSM States
    typedef enum logic [2:0] {IDLE, CMD, ADDR, DATA, DONE} state_t;
    state_t state;

    // =======================================================================
    // AXI WRITE LOGIC
    // =======================================================================
    assign s_axi_awready = 1'b1; 
    assign s_axi_wready  = 1'b1; 
    assign s_axi_bresp   = 2'b00; // OKAY

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin 
            s_axi_bvalid <= 0; 
            reg_ctrl     <= 0; 
            reg_addr     <= 0; 
            start_pulse  <= 0; 
        end else begin
            start_pulse <= 0; // Auto-clear pulse
            
            if (s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid) begin
                // Address Decoding
                if (s_axi_awaddr[7:0] == 8'h00) begin 
                    reg_ctrl    <= s_axi_wdata; 
                    start_pulse <= 1'b1; // Trigger SPI Transaction
                end
                else if (s_axi_awaddr[7:0] == 8'h04) begin
                    reg_addr    <= s_axi_wdata;
                end
                
                s_axi_bvalid <= 1'b1;
            end else if (s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // =======================================================================
    // AXI READ LOGIC
    // =======================================================================
    assign s_axi_arready = 1'b1; 
    assign s_axi_rresp   = 2'b00; // OKAY

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin 
            s_axi_rvalid <= 0; 
            s_axi_rdata  <= 0; 
        end else begin
            if (s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                
                // Read Register Map
                case (s_axi_araddr[7:0])
                    8'h00: s_axi_rdata <= reg_ctrl;
                    8'h04: s_axi_rdata <= reg_addr;
                    8'h08: s_axi_rdata <= reg_data; // Result Data
                    // Critical for Bootloader polling:
                    8'h28: s_axi_rdata <= {31'b0, busy_reg}; 
                    default: s_axi_rdata <= 0;
                endcase
            end else if (s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

    // =======================================================================
    // SPI CLOCK GENERATION
    // =======================================================================
    // Generates a clock at half the system frequency (50MHz / 2 = 25MHz)
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin 
            spi_clk_reg  <= 0; 
            spi_clk_prev <= 0; 
        end else begin 
            spi_clk_reg  <= ~spi_clk_reg; 
            spi_clk_prev <= spi_clk_reg; 
        end
    end

    // Only output clock during active transaction
    assign qspi_sck = (state == IDLE || state == DONE) ? 1'b0 : spi_clk_reg;
    
    // Edge Detectors
    wire sck_fall = (spi_clk_prev == 1 && spi_clk_reg == 0); // Setup Data
    wire sck_rise = (spi_clk_prev == 0 && spi_clk_reg == 1); // Sample Data

    // =======================================================================
    // IO BUFFERS (Tri-State Control)
    // =======================================================================
    // Standard SPI Mode:
    // DQ0 = MOSI (Output from FPGA)
    // DQ1 = MISO (Input to FPGA)
    assign qspi_dq[0] = dq_oe[0] ? dq_out[0] : 1'bz; 
    assign qspi_dq[1] = 1'bz; // Always Input (MISO)
    assign qspi_dq[2] = 1'bz; // WP_n (High-Z / Pull-up on board)
    assign qspi_dq[3] = 1'bz; // HOLD_n (High-Z / Pull-up on board)

    // =======================================================================
    // SPI MASTER FSM
    // =======================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state    <= IDLE; 
            qspi_cs_n <= 1; 
            dq_oe    <= 0;
            reg_data <= 0; 
            bit_cnt  <= 0; 
            dq_out   <= 0;
            busy_reg <= 0;
        end else begin
            
            // Set Busy Flag on Start Pulse
            if (start_pulse) busy_reg <= 1'b1;

            case (state)
                // -----------------------------------------------------------
                // 1. IDLE: Wait for Trigger
                // -----------------------------------------------------------
                IDLE: begin
                    qspi_cs_n <= 1; 
                    dq_oe     <= 0;
                    if (start_pulse) begin
                        reg_data   <= 0; 
                        shift_cmd  <= 8'h03; // Command: READ DATA
                        shift_addr <= reg_addr[23:0]; // 24-bit Address
                        bit_cnt    <= 7; 
                        qspi_cs_n  <= 0; // Assert CS
                        state      <= CMD;
                        
                        // Setup first bit of command
                        dq_oe      <= 4'b0001; // Enable DQ0 Output
                        dq_out[0]  <= 1'b0;    // Standard SPI Mode starts low
                    end
                end

                // -----------------------------------------------------------
                // 2. CMD: Send 0x03 (8 bits)
                // -----------------------------------------------------------
                CMD: if (sck_fall) begin
                    if (bit_cnt == 0) begin 
                        bit_cnt   <= 23; 
                        state     <= ADDR; 
                        dq_out[0] <= shift_addr[23]; // Setup first address bit
                    end else begin 
                        bit_cnt   <= bit_cnt - 1; 
                        dq_out[0] <= shift_cmd[bit_cnt-1]; 
                    end
                end

                // -----------------------------------------------------------
                // 3. ADDR: Send 24-bit Address
                // -----------------------------------------------------------
                ADDR: if (sck_fall) begin
                    if (bit_cnt == 0) begin 
                        bit_cnt <= 31; 
                        dq_oe   <= 0; // Switch to Input Mode for DATA phase
                        state   <= DATA; 
                    end else begin 
                        bit_cnt   <= bit_cnt - 1; 
                        dq_out[0] <= shift_addr[bit_cnt-1]; 
                    end
                end

                // -----------------------------------------------------------
                // 4. DATA: Receive 32 bits (1 Word)
                // -----------------------------------------------------------
                DATA: begin
                    // Sample MISO (DQ1) on Rising Edge
                    if (sck_rise) begin
                        // Debug print for simulation
                        // $display("[QSPI] Sampling Bit %0d: %b", bit_cnt, qspi_dq[1]);
                        reg_data[bit_cnt] <= qspi_dq[1];
                    end
                    
                    // Decrement Counter on Falling Edge
                    if (sck_fall) begin
                        if (bit_cnt == 0) begin
                            state <= DONE;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                // -----------------------------------------------------------
                // 5. DONE: Endianness Swap & Cleanup
                // -----------------------------------------------------------
                DONE: begin
                    qspi_cs_n <= 1; // Deassert CS
                    
                    // **CRITICAL ENDIANNESS FIX**
                    // Flash sends MSB first (Big Endian).
                    // RISC-V expects LSB at lowest address (Little Endian).
                    // We swap bytes here so the CPU reads valid instructions.
                    reg_data <= {reg_data[7:0], reg_data[15:8], reg_data[23:16], reg_data[31:24]};
                    
                    // Clear Busy Flag (Allow CPU to proceed)
                    busy_reg <= 1'b0; 
                    state    <= IDLE;
                end
            endcase
        end
    end
endmodule