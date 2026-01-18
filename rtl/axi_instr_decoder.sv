`timescale 1ns / 1ps

module axi_instr_decoder (
    input  logic clk,
    input  logic rst_n,

    // =======================================================================
    // MASTER INTERFACE (Connected to CPU Instruction Port)
    // =======================================================================
    // Read Address Channel
    input  logic [31:0] s_araddr, 
    input  logic        s_arvalid, 
    output logic        s_arready,
    
    // Read Data Channel
    output logic [31:0] s_rdata,  
    output logic        s_rvalid,  
    input  logic        s_rready,

    // =======================================================================
    // SLAVE 0: BOOT ROM (Hardcoded Assembly)
    // =======================================================================
    output logic [31:0] rom_araddr, 
    output logic        rom_arvalid, 
    input  logic        rom_arready,
    
    input  logic [31:0] rom_rdata,  
    input  logic        rom_rvalid,  
    output logic        rom_rready,

    // =======================================================================
    // SLAVE 1: INSTRUCTION RAM (Main Memory - Port A)
    // =======================================================================
    output logic [31:0] iram_araddr, 
    output logic        iram_arvalid, 
    input  logic        iram_arready,
    
    input  logic [31:0] iram_rdata,  
    input  logic        iram_rvalid,  
    output logic        iram_rready
);

    // =======================================================================
    // 1. ADDRESS DECODING (Combinational)
    // =======================================================================
    // Base Address Matching:
    // 0x000... -> Select Boot ROM
    // 0x001... -> Select Instruction RAM
    logic sel_rom;
    logic sel_iram;

    assign sel_rom  = (s_araddr[31:20] == 12'h000);
    assign sel_iram = (s_araddr[31:20] == 12'h001);

    // =======================================================================
    // 2. READ ADDRESS CHANNEL ROUTING (Master -> Slave)
    // =======================================================================
    // The address and valid signals are broadcast to all slaves, 
    // but only the selected slave receives 'valid' as High.
    // This creates a Zero-Latency path.
    
    // Route to ROM
    assign rom_araddr  = s_araddr;
    assign rom_arvalid = s_arvalid && sel_rom;
    
    // Route to IRAM
    assign iram_araddr  = s_araddr;
    assign iram_arvalid = s_arvalid && sel_iram;

    // Ready MUX: Route the 'ready' signal from the selected slave back to CPU.
    // If accessing an unmapped area (hole), return '1' immediately to prevent hang.
    assign s_arready = sel_rom  ? rom_arready :
                       sel_iram ? iram_arready : 
                       1'b1; // Default Ready (swallow request)

    // =======================================================================
    // 3. READ DATA CHANNEL ROUTING (Slave -> Master)
    // =======================================================================
    // Since the CPU issues in-order requests, we can simply route 
    // whichever slave asserts 'rvalid' back to the master.
    
    always_comb begin
        // Default Assignments (Idle)
        s_rdata     = 32'b0;
        s_rvalid    = 1'b0;
        rom_rready  = 1'b0;
        iram_rready = 1'b0;

        // Priority Logic: Check who is responding
        if (rom_rvalid) begin
            // --- Response from ROM ---
            s_rdata     = rom_rdata;
            s_rvalid    = 1'b1;
            
            // Pass the CPU's ready signal back to ROM
            rom_rready  = s_rready; 
        
        end else if (iram_rvalid) begin
            // --- Response from IRAM ---
            s_rdata     = iram_rdata;
            s_rvalid    = 1'b1;
            
            // Pass the CPU's ready signal back to IRAM
            iram_rready = s_rready;
        end
    end

endmodule