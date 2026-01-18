`timescale 1ns / 1ps

// Modül Ýsmi: pulp_clock_gating
// Bu isim, çaðýran dosyadaki (clock_divider) isimle BÝREBÝR AYNI olmalýdýr.
module pulp_clock_gating (
    input  logic clk_i,
    input  logic en_i,
    input  logic test_en_i,
    output logic clk_o
);

    logic clk_en;

    // -------------------------------------------------------------
    // Latch Tabanlý Clock Gating (Glitch-Free)
    // -------------------------------------------------------------
    // Clock High iken enable deðiþirse çýkýþta "iðne" (glitch) oluþur.
    // Latch kullanarak enable sinyalini Clock Low iken güncelliyoruz.
    // Böylece Clock High olduðunda enable sinyali çoktan sabitlenmiþ olur.
    
    always_latch begin
        if (clk_i == 1'b0) begin
            clk_en <= en_i | test_en_i;
        end
    end

    // Saati geçir (1) veya kes (0)
    assign clk_o = clk_i & clk_en;

endmodule