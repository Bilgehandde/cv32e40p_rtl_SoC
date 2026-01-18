`timescale 1ns / 1ps

module simple_ram #(
    parameter MEM_SIZE_BYTES = 8192,
    parameter INIT_FILE      = ""
)(
    input  logic        clk,
    input  logic        rst_n,

    // WRITE CHANNEL
    input  logic [31:0] awaddr,
    input  logic        awvalid,
    output logic        awready,

    input  logic [31:0] wdata,
    input  logic [3:0]  wstrb,
    input  logic        wvalid,
    output logic        wready,

    output logic        bvalid,
    input  logic        bready,

    // READ CHANNEL
    input  logic [31:0] araddr,
    input  logic        arvalid,
    output logic        arready,

    output logic [31:0] rdata,
    output logic        rvalid,
    input  logic        rready
);

    localparam DEPTH = MEM_SIZE_BYTES / 4;
    (* ram_style = "block" *) logic [31:0] mem [0:DEPTH-1];

    initial begin
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    // REGISTER'LAR
    logic bvalid_reg;
    logic rvalid_reg;
    logic [31:0] rdata_reg; // Çýkýþ Registerý

    assign bvalid  = bvalid_reg;
    assign rvalid  = rvalid_reg;
    assign rdata   = rdata_reg;

    assign awready = ~bvalid_reg;
    assign wready  = ~bvalid_reg;
    assign arready = ~rvalid_reg;

    // =====================================================
    // MEMORY ACCESS (SYNC)
    // =====================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            bvalid_reg <= 1'b0;
            rvalid_reg <= 1'b0;
            rdata_reg  <= 32'b0; // Reset anýnda temizle
        end else begin
            // --- WRITE OPERATION ---
            if (awvalid && wvalid && awready) begin
                if (wstrb[0]) mem[awaddr[12:2]][7:0]   <= wdata[7:0];
                if (wstrb[1]) mem[awaddr[12:2]][15:8]  <= wdata[15:8];
                if (wstrb[2]) mem[awaddr[12:2]][23:16] <= wdata[23:16];
                if (wstrb[3]) mem[awaddr[12:2]][31:24] <= wdata[31:24];
                bvalid_reg <= 1'b1;
            end
            else if (bvalid_reg && bready) begin
                bvalid_reg <= 1'b0;
            end

            // --- READ OPERATION ---
            if (arvalid && arready) begin
                rdata_reg  <= mem[araddr[12:2]];
                rvalid_reg <= 1'b1;
            end
            else if (rvalid_reg && rready) begin
                rvalid_reg <= 1'b0;
            end
        end
    end

endmodule