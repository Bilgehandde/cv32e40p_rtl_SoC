`timescale 1ns / 1ps

module boot_rom (
    input  logic clk,
    input  logic rst_n,

    // =======================================================================
    // AXI4-LITE SLAVE INTERFACE (Read Only)
    // =======================================================================
    input  logic [31:0] araddr,
    input  logic        arvalid,
    output logic        arready,

    output logic [31:0] rdata,
    output logic        rvalid,
    input  logic        rready
);

    // 128 Words (512 Bytes) is enough for the bootloader
    logic [31:0] rom [0:127];

    initial begin
        // ===================================================================
        // 1. INITIALIZATION
        // ===================================================================
        // s0 = 0x1000_4000 -> QSPI Control Register Base
        rom[0]  = 32'h10004437; // lui s0, 0x10004 
        // s1 = 0x0010_0000 -> IRAM Base (Destination)
        rom[1]  = 32'h001004b7; // lui s1, 0x00100
        // s2 = 0 -> Flash Offset (Source Address)
        rom[2]  = 32'h00000913; // li  s2, 0      
        // s3 = 6 -> Word Count (How many words to copy)
        // NOTE: Increase this value to match your actual application size!
        rom[3]  = 32'h00600993; // li s3, 6       

        // ===================================================================
        // 2. MAIN COPY LOOP (Start Label: LOOP_START)
        // ===================================================================
        // Step A: Set Flash Read Address
        rom[4]  = 32'h01242223; // sw s2, 4(s0) -> Write Offset to QSPI_ADDR
        
        // Step B: Trigger QSPI Transaction
        rom[5]  = 32'h00300293; // li t0, 3     -> Command: Start (1) | Read (2)
        rom[6]  = 32'h00542023; // sw t0, 0(s0) -> Write to QSPI_CTRL

        // ===================================================================
        // 3. POLLING (Wait for Flash)
        // ===================================================================
        // Step C: Read Status Register and Check Busy Bit
        rom[7]  = 32'h02842303; // lw t1, 40(s0)-> Read QSPI_STATUS (Offset 0x28)
        rom[8]  = 32'h00137313; // andi t1, t1, 1 -> Mask Bit[0] (Busy Flag)
        rom[9]  = 32'hfe031ce3; // bne t1, x0, -8 -> If Busy=1, Jump back to 'lw'

        // ===================================================================
        // 4. DATA TRANSFER
        // ===================================================================
        // Step D: Read Data from QSPI and Write to IRAM
        rom[10] = 32'h00842303; // lw t1, 8(s0) -> Read from QSPI_DATA
        rom[11] = 32'h0064a023; // sw t1, 0(s1) -> Write to IRAM

        // ===================================================================
        // 5. UPDATE POINTERS
        // ===================================================================
        rom[12] = 32'h00448493; // addi s1, s1, 4  -> Increment IRAM Ptr
        rom[13] = 32'h00490913; // addi s2, s2, 4  -> Increment Flash Offset
        rom[14] = 32'hfff98993; // addi s3, s3, -1 -> Decrement Word Count

        // ===================================================================
        // 6. LOOP CONTROL (Fixed Logic)
        // ===================================================================
        // Problem Fix: Standard BNE had offset range issues. 
        // We use BEQ to exit, otherwise JAL to loop back.
        
        // If s3 (count) == 0, Jump forward 2 instructions (Exit Loop)
        rom[15] = 32'h00098463; // beq s3, x0, +8 
        
        // Else, Unconditional Jump back to LOOP_START (rom[4])
        // Target: 0x10, Current: 0x40. Offset: -48 bytes.
        rom[16] = 32'hfd1ff06f; // jal x0, -48 

        // ===================================================================
        // 7. JUMP TO APPLICATION
        // ===================================================================
        // Execution reaches here only when Copy is finished.
        rom[17] = 32'h001002b7; // lui t0, 0x00100 -> Load IRAM Base
        rom[18] = 32'h00028067; // jalr x0, 0(t0)  -> Absolute Jump to 0x00100000

        // ===================================================================
        // 8. FILL REMAINDER WITH NOPs
        // ===================================================================
        for (int i = 19; i < 128; i++) begin
            rom[i] = 32'h00000013; // nop (addi x0, x0, 0)
        end
    end
    
    // =======================================================================
    // AXI READ LOGIC
    // =======================================================================
    // Always ready to accept address (Latency = 1 cycle)
    assign arready = 1'b1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rvalid <= 0;
            rdata  <= 0;
        end else begin
            // If address is valid, read from ROM array
            if (arvalid && arready) begin
                // Convert Byte Address to Word Index (Divide by 4)
                rdata  <= rom[araddr[8:2]]; 
                rvalid <= 1'b1;
            end 
            // Handshake complete, deassert valid
            else if (rready) begin
                rvalid <= 1'b0;
            end
        end
    end

endmodule