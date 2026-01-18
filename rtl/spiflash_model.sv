`timescale 1ns / 1ps

module spiflash_model (
    input  logic        cs_n,
    input  logic        clk,
    inout  wire [3:0]   dq
);
    // 1KB Flash Hafýza
    logic [7:0] memory [0:1023]; 

    initial begin
        // Hafýzayý temizle
        for (int i=0; i<1024; i++) memory[i] = 8'h00;

        // --- APP CODE (LED Yakan Kod) ---
        // 1. lui a0, 0x10000 -> 0x10000537
        memory[0]=8'h37; memory[1]=8'h05; memory[2]=8'h00; memory[3]=8'h10;
        // 2. li  a1, 0xAA    -> 0x0aa00593
        memory[4]=8'h93; memory[5]=8'h05; memory[6]=8'ha0; memory[7]=8'h0a;
        // 3. sw  a1, 4(a0)   -> 0x00b52223
        memory[8]=8'h23; memory[9]=8'h22; memory[10]=8'hb5; memory[11]=8'h00;
        // 4. j   .           -> 0x0000006f (Sonsuz Döngü)
        memory[12]=8'h6f; memory[13]=8'h00; memory[14]=8'h00; memory[15]=8'h00;
    end

    // Sinyaller
    logic [7:0]  cmd;
    logic [23:0] addr;
    logic [31:0] bit_cnt;
    logic        sending_data;
    logic        dq1_out_reg;

    // Reset
    always @(posedge cs_n) begin
        bit_cnt <= 0;
        sending_data <= 0;
        cmd <= 0;
        addr <= 0;
        dq1_out_reg <= 1'b1; 
    end

    // MISO (DQ1) Output
    assign dq[1] = (!cs_n && sending_data) ? dq1_out_reg : 1'bz;

    // 1. INPUT (Rising Edge) - Komut ve Adres Al
    always @(posedge clk) begin
        if (!cs_n) begin
            if (bit_cnt < 8)       cmd <= {cmd[6:0], dq[0]};
            else if (bit_cnt < 32) addr <= {addr[22:0], dq[0]};
            
            // Sayaç burada artar!
            bit_cnt <= bit_cnt + 1;
        end
    end

    // 2. OUTPUT (Falling Edge) - Veri Bas [FIXED]
    always @(negedge clk) begin
        if (!cs_n) begin
            // 32 bitlik header (8 cmd + 24 addr) bitti mi?
            // Sayaç posedge'de 32 oldu, þimdi negedge'deyiz.
            if (bit_cnt >= 32) begin 
                sending_data <= 1;
                
                // Matematik Düzeltmesi: (bit_cnt - 32)
                // Ýlk bit (Index 0, Bit 7) tam bu anda basýlýr.
                if ((addr + ((bit_cnt - 32)/8)) < 1024)
                    dq1_out_reg <= memory[addr + ((bit_cnt - 32)/8)][7 - ((bit_cnt - 32) % 8)];
                else
                    dq1_out_reg <= 0;
            end
        end
    end
endmodule