`timescale 1ns / 1ps

module spiflash_model (
    input  logic        cs_n, // Chip Select (Active Low)
    input  logic        clk,  // Serial Clock
    inout  wire [3:0]   dq    // Data Lines (DQ0=MOSI, DQ1=MISO)
);
    // 1KB Flash Memory Storage
    logic [7:0] memory [0:1023]; 

    // =======================================================================
    // 1. MEMORY INITIALIZATION (The "Software")
    // =======================================================================
    initial begin
        // Clear Memory
        for (int i=0; i<1024; i++) memory[i] = 8'h00;

        // --- APPLICATION CODE (Machine Code) ---
        // This is the code that the Bootloader will copy to IRAM.
        // It simply turns on the LEDs with pattern 0xAA.

        // 1. lui a0, 0x10000 -> Load GPIO Base Address (0x10000000)
        // Machine Code: 0x10000537
        memory[0]=8'h37; memory[1]=8'h05; memory[2]=8'h00; memory[3]=8'h10;
        
        // 2. li  a1, 0xAA    -> Load Immediate 0xAA (LED Pattern)
        // Machine Code: 0x0aa00593
        memory[4]=8'h93; memory[5]=8'h05; memory[6]=8'ha0; memory[7]=8'h0a;
        
        // 3. sw  a1, 4(a0)   -> Store Word to GPIO Output Offset (0x4)
        // Machine Code: 0x00b52223
        memory[8]=8'h23; memory[9]=8'h22; memory[10]=8'hb5; memory[11]=8'h00;
        
        // 4. j   .           -> Infinite Loop (Jump to self)
        // Machine Code: 0x0000006f
        memory[12]=8'h6f; memory[13]=8'h00; memory[14]=8'h00; memory[15]=8'h00;
    end

    // =======================================================================
    // INTERNAL SIGNALS
    // =======================================================================
    logic [7:0]  cmd;
    logic [23:0] addr;
    logic [31:0] bit_cnt;      // Global Bit Counter for transaction
    logic        sending_data; // State Flag
    logic        dq1_out_reg;  // Output Buffer

    // =======================================================================
    // RESET LOGIC (Chip Select High = Reset Transaction)
    // =======================================================================
    always @(posedge cs_n) begin
        bit_cnt      <= 0;
        sending_data <= 0;
        cmd          <= 0;
        addr         <= 0;
        dq1_out_reg  <= 1'b1; // Default High-Z/High
    end

    // =======================================================================
    // MISO DRIVER (Tri-State)
    // =======================================================================
    // Only drive DQ1 (MISO) when Chip Select is Low AND we are in Data Phase.
    assign dq[1] = (!cs_n && sending_data) ? dq1_out_reg : 1'bz;

    // =======================================================================
    // INPUT LOGIC (Rising Edge Sampling - MOSI)
    // =======================================================================
    // The Master shifts data out on Falling Edge, so we sample on Rising Edge.
    always @(posedge clk) begin
        if (!cs_n) begin
            // Phase 1: Command (Bits 0-7)
            if (bit_cnt < 8) begin
                cmd <= {cmd[6:0], dq[0]}; // Shift in Command
            end
            // Phase 2: Address (Bits 8-31)
            else if (bit_cnt < 32) begin
                addr <= {addr[22:0], dq[0]}; // Shift in Address
            end
            
            // Increment Bit Counter
            bit_cnt <= bit_cnt + 1;
        end
    end

    // =======================================================================
    // OUTPUT LOGIC (Falling Edge Driving - MISO)
    // =======================================================================
    // The Master samples on Rising Edge, so we drive on Falling Edge.
    always @(negedge clk) begin
        if (!cs_n) begin
            // Phase 3: Data (Bit 32 onwards)
            if (bit_cnt >= 32) begin 
                sending_data <= 1;
                
                // Address Logic:
                // (bit_cnt - 32) gives the number of data bits processed so far.
                // Divide by 8 to get Byte Offset.
                // Modulo 8 to get Bit Index (7 downto 0 for MSB first).
                
                if ((addr + ((bit_cnt - 32)/8)) < 1024) begin
                    dq1_out_reg <= memory[addr + ((bit_cnt - 32)/8)][7 - ((bit_cnt - 32) % 8)];
                end else begin
                    dq1_out_reg <= 0; // Out of bounds return 0
                end
            end
        end
    end

endmodule