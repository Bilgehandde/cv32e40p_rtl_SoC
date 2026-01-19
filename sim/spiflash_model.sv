`timescale 1ns / 1ps

/**
 * Module: spiflash_model
 * Description:
 * Professional Behavioral Model for a Standard SPI Flash (e.g., W25Qxx series).
 * Optimized to work with the axi_qspi_master (Clock-Divider Architecture).
 *
 * Features:
 * - SPI Mode 0 Sampling (Rising Edge) and Driving (Falling Edge).
 * - Address Masking: Maps any flash offset to a local 1KB memory buffer for simulation efficiency.
 * - Delta-cycle delay (#1) added to MISO driving to prevent simulation race conditions.
 */
module spiflash_model (
    input  logic       cs_n, // Chip Select (Active Low)
    input  logic       clk,  // Serial Clock (SCK)
    inout  wire [3:0]  dq    // Data Lines (Standard SPI: DQ0=MOSI, DQ1=MISO)
);

    // =======================================================================
    // 1. MEMORY STORAGE (Local 1KB Buffer)
    // =======================================================================
    logic [7:0] memory [0:1023]; 

    // Pre-load firmware instructions (RISC-V Machine Code)
    initial begin
        for (int i=0; i<1024; i++) memory[i] = 8'h00;

        // RISC-V Program: Write 0xAA to GPIO Output (LEDs)
        // 1. lui a0, 0x10000 -> 0x10000537
        memory[0]=8'h37; memory[1]=8'h05; memory[2]=8'h00; memory[3]=8'h10;
        // 2. li a1, 0xAA     -> 0x0aa00593
        memory[4]=8'h93; memory[5]=8'h05; memory[6]=8'ha0; memory[7]=8'h0a;
        // 3. sw a1, 4(a0)    -> 0x00b52223
        memory[8]=8'h23; memory[9]=8'h22; memory[10]=8'hb5; memory[11]=8'h00;
        // 4. j .             -> 0x0000006f
        memory[12]=8'h6f; memory[13]=8'h00; memory[14]=8'h00; memory[15]=8'h00;
    end

    // =======================================================================
    // 2. INTERNAL SIGNALS
    // =======================================================================
    logic [7:0]  cmd;
    logic [23:0] addr;
    logic [31:0] bit_cnt;      
    logic        sending_data; 
    logic        dq1_out_reg;  

    // =======================================================================
    // 3. SPI PROTOCOL LOGIC
    // =======================================================================

    // Reset internal state when Chip Select is de-asserted (High)
    always @(posedge cs_n) begin
        bit_cnt      <= 0;
        sending_data <= 0;
        cmd          <= 0;
        addr         <= 0;
        dq1_out_reg  <= 1'b0;
    end

    // Standard Tri-state buffer for MISO line
    assign dq[1] = (!cs_n && sending_data) ? dq1_out_reg : 1'bz;

    // MOSI INPUT LOGIC: Sample data on the RISING edge
    always @(posedge clk) begin
        if (!cs_n) begin
            // Phase 1: Capture 8-bit Command
            if (bit_cnt < 8) begin
                cmd <= {cmd[6:0], dq[0]};
            end
            // Phase 2: Capture 24-bit Address
            else if (bit_cnt < 32) begin
                addr <= {addr[22:0], dq[0]};
            end
            
            bit_cnt <= bit_cnt + 1;
        end
    end

    // MISO OUTPUT LOGIC: Drive data on the FALLING edge
    always @(negedge clk) begin
        // Local variables for address/bit calculations
        automatic integer byte_offset;
        automatic integer bit_index;
        automatic logic [9:0] effective_addr;

        if (!cs_n) begin
            // Phase 3: Transmit Data bits starting from Bit 32
            if (bit_cnt >= 32) begin 
                sending_data <= 1;
                
                // Calculate which byte and bit to send
                byte_offset = (bit_cnt - 32) / 8;
                bit_index   = 7 - ((bit_cnt - 32) % 8); // Flash sends MSB first

                // Effective address logic (maps any offset to the 1KB buffer)
                effective_addr = (addr + byte_offset) % 1024;

                /**
                 * DELTA CYCLE DELAY (#1):
                 * Ensures that dq1_out_reg updates slightly after the clock edge 
                 * to avoid race conditions with the Master's sampling logic.
                 */
                #1 dq1_out_reg <= memory[effective_addr][bit_index];
            end
        end
    end

endmodule