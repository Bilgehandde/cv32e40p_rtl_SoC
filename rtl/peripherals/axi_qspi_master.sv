`timescale 1ns / 1ps

/**
 * Module: axi_qspi_master
 * * Description:
 * A high-performance Quad SPI (QSPI) Master Controller with an AXI4-Lite Slave interface.
 * Designed for RISC-V SoC environments to interface with external NOR Flash memories.
 *
 * Architecture Features:
 * 1. Synchronous Clock Divider: Generates a stable SPI clock (SCK) derived from ACLK.
 * 2. Dual Shift-Register Path: Separate paths for outgoing (CMD/ADDR) and incoming (DATA) streams.
 * 3. Edge-Aligned Logic: Drives data on SCK falling edges and samples on rising edges (SPI Mode 0).
 * 4. RISC-V Byte Alignment: Automatically performs Byte-Swap to convert Flash Big-Endian 
 * stream into Little-Endian words for the processor.
 * 5. AXI4-Lite Compliant: Standard handshake for register-based control and data access.
 */
module axi_qspi_master (
    // --- Global Signals ---
    input  logic        aclk,       // System Clock (e.g., 50MHz)
    input  logic        aresetn,    // Active-low asynchronous reset

    // --- AXI4-Lite Slave Interface ---
    // Write Address Channel
    input  logic [31:0] s_axi_awaddr, 
    input  logic        s_axi_awvalid, 
    output logic        s_axi_awready, 

    // Write Data Channel
    input  logic [31:0] s_axi_wdata,  
    input  logic [3:0]  s_axi_wstrb, 
    input  logic        s_axi_wvalid, 
    output logic        s_axi_wready,

    // Write Response Channel
    output logic [1:0]  s_axi_bresp,  
    output logic        s_axi_bvalid, 
    input  logic        s_axi_bready,

    // Read Address Channel
    input  logic [31:0] s_axi_araddr, 
    input  logic        s_axi_arvalid, 
    output logic        s_axi_arready,

    // Read Data Channel
    output logic [31:0] s_axi_rdata,  
    output logic [1:0]  s_axi_rresp, 
    output logic        s_axi_rvalid, 
    input  logic        s_axi_rready,

    // --- Physical QSPI Interface ---
    output logic        qspi_sck,    // SPI Serial Clock
    output logic        qspi_cs_n,   // Chip Select (Active Low)
    inout  wire  [3:0]  qspi_dq      // Quad I/O Data Lines
);

    // =======================================================================
    // INTERNAL REGISTERS & SIGNALS
    // =======================================================================
    logic [31:0] reg_addr;          // Target Flash Address
    logic [31:0] reg_data;          // Received Data Word
    logic        busy_reg;          // Internal status flag
    logic        start_pulse;       // Internal trigger signal
    logic [5:0]  bit_cnt;           // Global bit counter (64 to 0)
    
    // Shift Registers
    logic [31:0] shift_reg_out;     // Serializes CMD and ADDR
    logic [31:0] shift_reg_in;      // Accumulates incoming data bits

    // =======================================================================
    // SPI CLOCK GENERATION (Clock Divider)
    // =======================================================================
    // Physical SCK = ACLK / 4. Ensures robust timing on FPGA fabric.
    logic [1:0] clk_div;
    logic sck_int;
    
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) clk_div <= 2'b00;
        else if (busy_reg) clk_div <= clk_div + 1;
        else clk_div <= 2'b00;
    end
    
    // SCK gating: Active only during transaction
    assign sck_int = clk_div[1];
    assign qspi_sck = (busy_reg && !qspi_cs_n) ? sck_int : 1'b0;

    // Edge Detection Pulses
    wire sck_rise = (clk_div == 2'b01); // Logical sample point
    wire sck_fall = (clk_div == 2'b11); // Logical drive point

    // =======================================================================
    // FINITE STATE MACHINE (FSM) DEFINITION
    // =======================================================================
    typedef enum logic [1:0] {IDLE, TRANSFER, DONE} state_t;
    state_t state;

    // =======================================================================
    // AXI4-LITE READ/WRITE LOGIC
    // =======================================================================
    assign s_axi_awready = !busy_reg;
    assign s_axi_wready  = !busy_reg;
    assign s_axi_arready = !busy_reg;
    assign s_axi_bresp   = 2'b00; // Always OKAY
    assign s_axi_rresp   = 2'b00; // Always OKAY

    // AXI Register Write Process
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_bvalid <= 1'b0;
            reg_addr     <= 32'h0;
            start_pulse  <= 1'b0;
        end else begin
            start_pulse <= 1'b0;
            if (s_axi_awvalid && s_axi_wvalid && !busy_reg) begin
                // 0x00: Trigger Control Register
                if (s_axi_awaddr[7:0] == 8'h00) start_pulse <= 1'b1;
                // 0x04: Address Register
                else if (s_axi_awaddr[7:0] == 8'h04) reg_addr <= s_axi_wdata;
                s_axi_bvalid <= 1'b1;
            end else if (s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // AXI Register Read Process
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rdata  <= 32'h0;
        end else begin
            if (s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                case(s_axi_araddr[7:0])
                    8'h08: s_axi_rdata <= reg_data;         // Flash Data Output
                    8'h28: s_axi_rdata <= {31'b0, busy_reg}; // Status Register
                    default: s_axi_rdata <= 32'h0;
                endcase
            end else if (s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

    // =======================================================================
    // QSPI BIT-LEVEL ENGINE
    // =======================================================================
    // Currently supports Standard SPI Mode (DQ0: Output, DQ1: Input)
    assign qspi_dq[0] = (!qspi_cs_n && bit_cnt > 31) ? shift_reg_out[31] : 1'bz;
    assign qspi_dq[1] = 1'bz; // Input path (MISO)
    assign qspi_dq[2] = 1'bz; // High-Z for Standard SPI
    assign qspi_dq[3] = 1'bz; // High-Z for Standard SPI

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state        <= IDLE;
            qspi_cs_n    <= 1'b1;
            busy_reg     <= 1'b0;
            bit_cnt      <= 6'd0;
            reg_data     <= 32'h0;
            shift_reg_in <= 32'h0;
        end else begin
            case (state)
                // --- Wait for AXI Trigger ---
                IDLE: begin
                    if (start_pulse) begin
                        busy_reg      <= 1'b1;
                        qspi_cs_n     <= 1'b0;
                        bit_cnt       <= 6'd63; // Total transaction: 8(CMD) + 24(ADDR) + 32(DATA)
                        shift_reg_out <= {8'h03, reg_addr[23:0]}; // Command 0x03 followed by Address
                        state         <= TRANSFER;
                    end
                end

                // --- Execute Serial Transfer ---
                TRANSFER: begin
                    // FALLING EDGE: Setup data on the line (Drive)
                    if (sck_fall) begin
                        // Shift out Command and Address bits
                        if (bit_cnt > 32) shift_reg_out <= {shift_reg_out[30:0], 1'b0};
                    end
                    
                    // RISING EDGE: Sample data from the line (Capture)
                    if (sck_rise) begin
                        // Accumulate data bits during the last 32 cycles
                        if (bit_cnt <= 31) begin
                            shift_reg_in <= {shift_reg_in[30:0], qspi_dq[1]};
                        end
                        
                        // Check for completion
                        if (bit_cnt == 0) state <= DONE;
                        else bit_cnt <= bit_cnt - 1'b1;
                    end
                end

                // --- Clean up and Endian Correction ---
                DONE: begin
                    qspi_cs_n <= 1'b1;
                    busy_reg  <= 1'b0;
                    state     <= IDLE;
                    
                    /**
                     * BYTE SWAP EXPLANATION:
                     * External SPI Flash transmits bytes in chronological order (Byte 0, 1, 2, 3).
                     * RISC-V (Little-Endian) requires the first received byte to be in the LSB [7:0] position.
                     * Input stream: [B0_MSB...B0_LSB]...[B3_MSB...B3_LSB]
                     * Conversion: 0x(B0)(B1)(B2)(B3) -> 0x(B3)(B2)(B1)(B0)
                     */
                    reg_data <= {shift_reg_in[7:0], shift_reg_in[15:8], shift_reg_in[23:16], shift_reg_in[31:24]};
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule