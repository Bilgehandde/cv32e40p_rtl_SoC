`timescale 1ns / 1ps

module axi_checker (
    input logic clk,
    input logic rst_n,
    
    // --- OKUMA KANALLARI (Read Channels) ---
    input logic [31:0] araddr,
    input logic arvalid,
    input logic arready,
    
    input logic [31:0] rdata,
    input logic rvalid,
    input logic rready,

    // --- YAZMA KANALLARI (Write Channels) - YENÝ! ---
    input logic [31:0] awaddr,
    input logic awvalid,
    input logic awready,
    
    input logic [31:0] wdata,
    input logic wvalid,
    input logic wready,
    
    input logic bvalid,
    input logic bready
);

    // ============================================================
    // 1. X (BILINMEYEN) KONTROLÜ
    // ============================================================
    property p_no_x_on_valid;
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(arvalid) && !$isunknown(rvalid) && 
        !$isunknown(awvalid) && !$isunknown(wvalid) && !$isunknown(bvalid);
    endproperty
    
    ASSERT_NO_X: assert property (p_no_x_on_valid)
        else $error("[%t] HATA: AXI Valid sinyallerinde X (Bilinmeyen) tespit edildi!", $time);

    // ============================================================
    // 2. TIMEOUT (ZAMAN AÞIMI) KONTROLÜ
    // ============================================================
    integer wait_count_ar = 0;
    integer wait_count_aw = 0;
    integer wait_count_w  = 0;
    integer wait_count_b  = 0; // Write Response Timeout
    
    always @(posedge clk) begin
        if (!rst_n) begin
            wait_count_ar <= 0; wait_count_aw <= 0; wait_count_w <= 0; wait_count_b <= 0;
        end else begin
            // --- OKUMA TIMEOUT ---
            if (arvalid && !arready) begin
                wait_count_ar <= wait_count_ar + 1;
                if (wait_count_ar > 100) begin
                    $error("[%t] KRITIK HATA: READ ADRES TIMEOUT! (Slave cevap vermiyor). Adres: %h", $time, araddr);
                    $stop;
                end
            end else wait_count_ar <= 0;

            // --- YAZMA ADRES TIMEOUT ---
            if (awvalid && !awready) begin
                wait_count_aw <= wait_count_aw + 1;
                if (wait_count_aw > 100) begin
                    $error("[%t] KRITIK HATA: WRITE ADRES TIMEOUT! (Slave cevap vermiyor). Adres: %h", $time, awaddr);
                    $stop;
                end
            end else wait_count_aw <= 0;

            // --- YAZMA VERÝ TIMEOUT ---
            if (wvalid && !wready) begin
                wait_count_w <= wait_count_w + 1;
                if (wait_count_w > 100) begin
                    $error("[%t] KRITIK HATA: WRITE DATA TIMEOUT! (Slave veriyi almiyor). Data: %h", $time, wdata);
                    $stop;
                end
            end else wait_count_w <= 0;
            
             // --- YAZMA CEVAP (B) TIMEOUT ---
             // Ýþlemci cevabý bekliyor (BREADY=1) ama Slave cevap (BVALID) vermiyor
            if (bready && !bvalid) begin
                 // Not: BREADY genelde hep 1 olabilir, o yüzden sadece bekleyen bir iþlem varsa saymak daha doðru olur
                 // ama basitlik için þimdilik pas geçiyoruz veya çok uzun tutuyoruz.
            end
        end
    end

    // ============================================================
    // 3. LOGLAMA (Monitor) - DETAYLI RAPOR
    // ============================================================
    always @(posedge clk) begin
        if (rst_n) begin
            // OKUMA ÝÞLEMLERÝ
            if (arvalid && arready)
                $display("[%t] [READ  REQ] -> Okuma Istegi: Adres=%h", $time, araddr);
            if (rvalid && rready)
                $display("[%t] [READ  DAT] <- Veri Okundu : Data=%h", $time, rdata);

            // YAZMA ÝÞLEMLERÝ
            if (awvalid && awready)
                $display("[%t] [WRITE REQ] -> Yazma Istegi: Adres=%h", $time, awaddr);
            if (wvalid && wready)
                $display("[%t] [WRITE DAT] -> Veri Gitti  : Data=%h", $time, wdata);
            if (bvalid && bready)
                $display("[%t] [WRITE RSP] <- Yazma Bitti (Response OK)", $time);
        end
    end

endmodule