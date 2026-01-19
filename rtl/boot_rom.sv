`timescale 1ns / 1ps

/**
 * Module: boot_rom
 * Description:
 * SoC Hardware Bootloader stored in on-chip Block RAM.
 * Encapsulates the RISC-V assembly routine for system initialization and 
 * QSPI-to-IRAM firmware migration.
 */
module boot_rom (
    input  logic         clk,
    input  logic         rst_n,
    input  logic [31:0]  araddr,
    input  logic         arvalid,
    output logic         arready,
    output logic [31:0]  rdata,
    output logic         rvalid,
    input  logic         rready
);

    // Boot Routine Storage (Inferred BRAM)
    (* rom_style = "block" *) logic [31:0] rom [0:127];
    logic [31:0] rdata_internal;

    initial begin
        // [0..3]: Register setup for QSPI and IRAM pointers
        rom[0]  = 32'h10004437; rom[1]  = 32'h001004b7;
        rom[2]  = 32'h00300937; rom[3]  = 32'h00600993; 
        // [4..16]: Core copy loop and status polling
        rom[4]  = 32'h01242223; rom[5]  = 32'h00300293;
        rom[6]  = 32'h00542023; rom[7]  = 32'h02842303;
        rom[8]  = 32'h00137313; rom[9]  = 32'hfe031ce3;
        rom[10] = 32'h00842303; rom[11] = 32'h0064a023;
        rom[12] = 32'h00448493; rom[13] = 32'h00490913;
        rom[14] = 32'hfff98993; rom[15] = 32'h00098463;
        rom[16] = 32'hfd1ff06f; 
        // [17..18]: Final jump to application space
        rom[17] = 32'h001002b7; rom[18] = 32'h00028067;
        for (int i = 19; i < 128; i++) rom[i] = 32'h00000013;
    end

    // Synchronous Read Pipeline
    always_ff @(posedge clk) begin
        if (arvalid && arready) rdata_internal <= rom[araddr[8:2]];
    end

    // Protocol Handshaking Stage
    logic rvalid_reg;
    assign {rdata, rvalid, arready} = {rdata_internal, rvalid_reg, ~rvalid_reg};

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) rvalid_reg <= 1'b0;
        else if (arvalid && arready) rvalid_reg <= 1'b1;
        else if (rready) rvalid_reg <= 1'b0;
    end
endmodule