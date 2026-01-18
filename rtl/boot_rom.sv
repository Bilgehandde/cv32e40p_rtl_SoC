`timescale 1ns / 1ps
module boot_rom (
    input  logic clk,
    input  logic rst_n,

    input  logic [31:0] araddr,
    input  logic        arvalid,
    output logic        arready,

    output logic [31:0] rdata,
    output logic        rvalid,
    input  logic        rready
);

    logic [31:0] rom [0:127];

    initial begin
        // --- 1. HAZIRLIK ---
        rom[0]  = 32'h10004437; // lui s0, 0x10004
        rom[1]  = 32'h001004b7; // lui s1, 0x00100
        rom[2]  = 32'h00000913; // li  s2, 0
        rom[3]  = 32'h00600993; // li s3, 6

        // --- 2. MAIN LOOP (Etiket: LOOP_START -> Adres 0x10) ---
        rom[4]  = 32'h01242223; // sw s2, 4(s0)
        rom[5]  = 32'h00300293; // li t0, 3
        rom[6]  = 32'h00542023; // sw t0, 0(s0)

        // --- 3. POLLING ---
        rom[7]  = 32'h02842303; // lw t1, 40(s0)
        rom[8]  = 32'h00137313; // andi t1, t1, 1
        rom[9]  = 32'hfe031ce3; // bne t1, x0, -8 (Burada sorun yok, çalýþýyor)

        // --- 4. COPY & UPDATE ---
        rom[10] = 32'h00842303; // lw t1, 8(s0)
        rom[11] = 32'h0064a023; // sw t1, 0(s1)
        
        rom[12] = 32'h00448493; // addi s1, s1, 4
        rom[13] = 32'h00490913; // addi s2, s2, 4
        rom[14] = 32'hfff98993; // addi s3, s3, -1
        
        // --- 5. LOOP CONTROL (YENÝ YÖNTEM) ---
        // bne yerine: "Eðer s3 == 0 ise ÇIK, deðilse ZIPLA" mantýðýný ters çeviriyoruz.
        // beq s3, x0, +8 (Eðer bittiyse aþaðý atla - 2 komut ileri)
        rom[15] = 32'h00098463; // beq s3, x0, +8 -> Jump to App
        
        // jal x0, -48 (LOOP_START'a kesin dönüþ - Unconditional Jump)
        // Offset: Hedef(0x10) - ÞuAn(0x40) = -48
        // J-Type Encoding: -48 = 0xFD1FF06F
        rom[16] = 32'hfd1ff06f; // jal x0, -48 (Geriye git)

        // --- 6. JUMP TO APP ---
        // Loop bittiyse buraya düþer (Adres 0x44)
        rom[17] = 32'h001002b7; // lui t0, 0x00100
        rom[18] = 32'h00028067; // jalr x0, 0(t0)

        // NOPs
        for (int i = 19; i < 128; i++) rom[i] = 32'h00000013;
    end
    
    assign arready = 1'b1;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin rvalid <= 0; rdata <= 0; end
        else if (arvalid && arready) begin rdata <= rom[araddr[8:2]]; rvalid <= 1; end
        else if (rready) rvalid <= 0;
    end
endmodule