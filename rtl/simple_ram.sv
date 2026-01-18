`timescale 1ns / 1ps

module simple_ram #(
    parameter MEM_SIZE_BYTES = 8192, // Default: 8KB
    parameter INIT_FILE      = ""    // Optional: Hex file to pre-load
)(
    input  logic        clk,
    input  logic        rst_n,

    // =======================================================================
    // WRITE CHANNEL (Address, Data, Response)
    // =======================================================================
    input  logic [31:0] awaddr,
    input  logic        awvalid,
    output logic        awready,

    input  logic [31:0] wdata,
    input  logic [3:0]  wstrb,
    input  logic        wvalid,
    output logic        wready,

    output logic        bvalid,
    input  logic        bready,

    // =======================================================================
    // READ CHANNEL (Address, Data)
    // =======================================================================
    input  logic [31:0] araddr,
    input  logic        arvalid,
    output logic        arready,

    output logic [31:0] rdata,
    output logic        rvalid,
    input  logic        rready
);

    // Calculate Memory Depth (Number of 32-bit Words)
    localparam DEPTH = MEM_SIZE_BYTES / 4;

    // Memory Array (Inferred as Block RAM)
    (* ram_style = "block" *) logic [31:0] mem [0:DEPTH-1];

    // Optional: Initialize memory from file (Simulation/Synthesis)
    initial begin
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    // =======================================================================
    // INTERNAL REGISTERS & SIGNALS
    // =======================================================================
    logic        bvalid_reg;
    logic        rvalid_reg;
    logic [31:0] rdata_reg;

    // Output Assignments
    assign bvalid  = bvalid_reg;
    assign rvalid  = rvalid_reg;
    assign rdata   = rdata_reg;

    // Ready Generation
    // Simple Logic: We are ready if we are NOT currently holding a valid response.
    // This allows for a simple 1-transaction-at-a-time behavior.
    assign awready = ~bvalid_reg;
    assign wready  = ~bvalid_reg;
    assign arready = ~rvalid_reg;

    // =======================================================================
    // MEMORY ACCESS LOGIC (Synchronous)
    // =======================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bvalid_reg <= 1'b0;
            rvalid_reg <= 1'b0;
            rdata_reg  <= 32'b0; 
        end else begin
            
            // ---------------------------------------------------------------
            // WRITE OPERATION
            // ---------------------------------------------------------------
            // Triggered when Address + Data + Ready are all present
            if (awvalid && wvalid && awready) begin
                // Byte-Enable Write Logic (Little Endian)
                // [12:2] extracts the index for 8KB (2^13 bytes)
                if (wstrb[0]) mem[awaddr[12:2]][7:0]   <= wdata[7:0];
                if (wstrb[1]) mem[awaddr[12:2]][15:8]  <= wdata[15:8];
                if (wstrb[2]) mem[awaddr[12:2]][23:16] <= wdata[23:16];
                if (wstrb[3]) mem[awaddr[12:2]][31:24] <= wdata[31:24];
                
                // Assert Write Response Valid
                bvalid_reg <= 1'b1;
            end 
            // Deassert valid when Master accepts response
            else if (bvalid_reg && bready) begin
                bvalid_reg <= 1'b0;
            end

            // ---------------------------------------------------------------
            // READ OPERATION
            // ---------------------------------------------------------------
            // Triggered when Read Address is Valid and Ready
            if (arvalid && arready) begin
                // Read full word
                rdata_reg  <= mem[araddr[12:2]];
                rvalid_reg <= 1'b1;
            end 
            // Deassert valid when Master accepts data
            else if (rvalid_reg && rready) begin
                rvalid_reg <= 1'b0;
            end
        end
    end

endmodule