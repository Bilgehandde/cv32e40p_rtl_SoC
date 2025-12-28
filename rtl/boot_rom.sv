`timescale 1ns / 1ps

module boot_rom (
    input  logic clk,
    input  logic rst_n,

    // Read Interface
    input  logic [31:0] araddr, input logic arvalid, output logic arready,
    output logic [31:0] rdata,  output logic rvalid, input logic rready
);
    // 1. ROM TANIMI
    (* ram_style = "block" *) logic [31:0] mem [0:255];

    // 2. PROGRAM YÜKLEME
    initial begin
        mem[0] = 32'h100002b7; // LUI x5, 0x10000
        mem[1] = 32'h0ff00313; // ADDI x6, x0, 255
        mem[2] = 32'h0062a223; // SW x6, 4(x5) -> LED YAK
        mem[3] = 32'h0042a383; // LW x7, 4(x5) -> OKU
        mem[4] = 32'h0000006f; // JAL x0, 0
        mem[5] = 32'h00000013; // NOP
        // Geri kalanýný elle doldurmaya gerek yok, FPGA 0 baþlatýr.
    end

    assign arready = 1'b1;

    // 3. ROM CORE (DATA ACCESS) - SADECE CLK!
    // Reset yok!
    always_ff @(posedge clk) begin
        if (arvalid) begin
            rdata <= mem[araddr[9:2]];
        end
    end

    // 4. CONTROL SIGNALS - RESETLÝ
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rvalid <= 1'b0;
        end else begin
            if (arvalid)     rvalid <= 1'b1;
            else if (rready) rvalid <= 1'b0;
        end
    end

endmodule