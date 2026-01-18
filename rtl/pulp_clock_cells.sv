`timescale 1ns / 1ps

// ========================================================================
// 1. PULP CLOCK MUX 2 (Saat Seçici)
// ========================================================================
// Ýki saat kaynaðý arasýnda seçim yapar.
module pulp_clock_mux2 (
    input  logic clk0_i, // Seçim 0
    input  logic clk1_i, // Seçim 1
    input  logic sel_i,  // Seçici Sinyal
    output logic clk_o   // Çýkýþ Saati
);
    // Simülasyon için basit MUX davranýþý:
    assign clk_o = (sel_i) ? clk1_i : clk0_i;

endmodule

// ========================================================================
// 2. PULP CLOCK XOR 2 (Saat Karýþtýrýcý)
// ========================================================================
// Ýki saati XOR iþlemine sokar.
module pulp_clock_xor2 (
    input  logic clk0_i,
    input  logic clk1_i,
    output logic clk_o
);
    assign clk_o = clk0_i ^ clk1_i;

endmodule

// ========================================================================
// 3. PULP CLOCK INVERTER (Saat Tersleyici)
// ========================================================================
// Saatin fazýný ters çevirir (180 derece).
module pulp_clock_inverter (
    input  logic clk_i,
    output logic clk_o
);
    assign clk_o = ~clk_i;

endmodule