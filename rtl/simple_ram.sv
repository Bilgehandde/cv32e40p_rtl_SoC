`timescale 1ns / 1ps

module simple_ram #(
    parameter MEM_SIZE_BYTES = 8192,
    parameter INIT_FILE      = ""
) (
    input logic clk,
    input logic rst_n,

    // Write Channel
    input  logic [31:0] awaddr, input logic awvalid, output logic awready,
    input  logic [31:0] wdata,  input logic [3:0] wstrb, input logic wvalid, output logic wready,
    output logic        bvalid, input logic bready,

    // Read Channel
    input  logic [31:0] araddr, input logic arvalid, output logic arready,
    output logic [31:0] rdata,  output logic rvalid, input logic rready
);
    localparam DEPTH = MEM_SIZE_BYTES / 4;

    // 1. RAM TANIMI (BRAM Zorlama)
    (* ram_style = "block" *) logic [31:0] mem [0:DEPTH-1];

    // 2. INITIALIZATION (Varsa Dosyadan Yükle)
    // Döngü ile sýfýrlamayý kaldýrdýk, FPGA zaten 0 baþlar.
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    // 3. READY SÝNYALLERÝ (Hep Hazýr)
    assign awready = 1'b1; 
    assign wready  = 1'b1; 
    assign arready = 1'b1;

    // 4. HAFIZA CORE (DATA ACCESS) - SADECE CLK!
    // Buraya ASLA "rst_n" veya baþka bir þey ekleme.
    always_ff @(posedge clk) begin
        // Yazma
        if (awvalid && wvalid) begin
            if (wstrb[0]) mem[awaddr[31:2]][7:0]   <= wdata[7:0];
            if (wstrb[1]) mem[awaddr[31:2]][15:8]  <= wdata[15:8];
            if (wstrb[2]) mem[awaddr[31:2]][23:16] <= wdata[23:16];
            if (wstrb[3]) mem[awaddr[31:2]][31:24] <= wdata[31:24];
        end
        
        // Okuma (Registered Output for BRAM)
        // Reset yok! BRAM çýkýþýnda reset olmaz.
        if (arvalid) begin
            rdata <= mem[araddr[31:2]];
        end
    end

    // 5. CONTROL SIGNALS (VALID/READY) - RESETLÝ
    // Sadece protokol sinyalleri resetlenir.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bvalid <= 1'b0;
            rvalid <= 1'b0;
        end else begin
            // Write Valid Logic
            if (awvalid && wvalid) bvalid <= 1'b1;
            else if (bready)       bvalid <= 1'b0;

            // Read Valid Logic
            if (arvalid)     rvalid <= 1'b1;
            else if (rready) rvalid <= 1'b0;
        end
    end

endmodule