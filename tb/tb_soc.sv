`timescale 1ns / 1ps

module tb_soc;

    // =====================================================
    // 1. CLOCK & RESET
    // =====================================================
    logic clk, rst_n;

    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50 MHz (20ns Periyot)
    end

    // =====================================================
    // 2. IO SIGNALS
    // =====================================================
    logic [15:0] sw_in;
    logic uart0_rx, uart1_rx;
    wire [15:0] gpio_out_pins;
    wire uart0_tx, uart1_tx;

    // QSPI Sinyalleri
    wire qspi_cs_n, qspi_sck;
    wire [3:0] qspi_dq;

    // Tri-state hatlarý havada kalmasýn (Pull-up)
    pullup(qspi_dq[0]);
    pullup(qspi_dq[1]);
    pullup(qspi_dq[2]);
    pullup(qspi_dq[3]);

    // =====================================================
    // 3. DUT BAÐLANTISI (soc_top)
    // =====================================================
    soc_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .sw_in(sw_in),
        .gpio_out_pins(gpio_out_pins),
        .uart0_rx(uart0_rx),
        .uart0_tx(uart0_tx),
        .uart1_rx(uart1_rx),
        .uart1_tx(uart1_tx),
        .qspi_sck(qspi_sck),   
        .qspi_cs_n(qspi_cs_n), 
        .qspi_dq(qspi_dq)      
    );

    // Flash Modeli
    spiflash_model u_flash_chip (
        .cs_n(qspi_cs_n),
        .clk(qspi_sck),
        .dq(qspi_dq)
    );

    // =====================================================
    // 4. INTERNAL OBSERVATION (ÝÇ AJANLAR)
    // =====================================================
    integer qspi_start_cnt = 0;
    integer iram_write_cnt = 0;

    logic [31:0] last_iram_addr;
    logic [31:0] last_iram_data;

    // -----------------------------------------------------
    // A) QSPI TRANSACTION MONITOR
    // -----------------------------------------------------
    // DÜZELTME: Sinyal ismi 'start_pulse' olarak güncellendi.
    
    always @(posedge clk) begin
        if (uut.u_periph.u_qspi.start_pulse) begin
            qspi_start_cnt++;
            // DÜZELTME: reg_addr ismini de kontrol ettik (reg_adr deðil, reg_addr)
            $display("[%0t ns] [QSPI START #%0d] Flash Okuma Tetiklendi! (Adres: %h)", 
                     $time, qspi_start_cnt, uut.u_periph.u_qspi.reg_addr);
        end
    end

    // -----------------------------------------------------
    // B) IRAM WRITE MONITOR (EN KRÝTÝK KISIM)
    // -----------------------------------------------------
    // Adres artýþ kontrolü için yardýmcý logic
    logic [31:0] prev_iram_addr;
    
    always @(posedge clk) begin
        if (uut.u_inst_ram.b_awvalid && 
            uut.u_inst_ram.b_wvalid && 
            uut.u_inst_ram.b_awready) begin

            iram_write_cnt++;
            last_iram_addr = uut.u_inst_ram.b_awaddr;
            last_iram_data = uut.u_inst_ram.b_wdata;

            $display("--------------------------------------------------");
            $display("[%0t ns] [IRAM WRITE #%0d] KOPYALANDI!", $time, iram_write_cnt);
            $display("    HEDEF ADRES = %h", last_iram_addr);
            $display("    YAZILAN VERI = %h", last_iram_data);
            $display("--------------------------------------------------");

            // HATA KONTROLÜ: Adres sürekli artmalý (Ýlk yazma hariç)
            if (iram_write_cnt > 1) begin
                if (last_iram_addr < prev_iram_addr) begin
                     $display("\n[FATAL ERROR] IRAM adresi artmiyor! Loop bozuk!");
                     $display("Onceki: %h, Simdiki: %h", prev_iram_addr, last_iram_addr);
                     $fatal(1); 
                end
            end
            prev_iram_addr <= last_iram_addr;
        end
    end

    // -----------------------------------------------------
    // C) PC MONITOR (BOOT -> IRAM GEÇÝÞÝ)
    // -----------------------------------------------------
    always @(posedge clk) begin
        if (rst_n) begin
            // IRAM'in Baþlangýç Adresi: 0x00100000
            if (uut.u_cpu_top.instr_addr == 32'h0010_0000) begin
                $display("\n=======================================================");
                $display("[%0t ns] [SUCCESS] CPU IRAM'E ZIPLADI! BOOT TAMAMLANDI.", $time);
                $display("=======================================================");
                $display("TOPLAM QSPI OKUMA = %0d Kez", qspi_start_cnt);
                $display("TOPLAM IRAM YAZMA = %0d Kelime (Word)", iram_write_cnt);

                // Kontrol: En az 4 komut kopyalanmýþ olmalý (bizim kodda 64)
                if (iram_write_cnt < 4) begin
                    $fatal(1, "HATA: IRAM tam dolmadan atlama yapildi! Bootloader eksik kopyaladi.");
                end

                $display("=== TEST BASARILI ===");
                #1000;
                $finish;
            end
            
            // Tuzak (Trap) Kontrolü
            if (uut.u_cpu_top.instr_addr == 32'hffff_fe44) begin
                 $fatal(1, "HATA: Islemci TRAP vectorune dustu! (Illegal Instruction)");
            end
        end
    end

    // =====================================================
    // 5. TEST SEQUENCE
    // =====================================================
    initial begin
        $display("===============================================");
        $display("       QSPI BOOTLOADER SYSTEM TEST");
        $display("===============================================");

        rst_n = 0;
        sw_in = 0;
        uart0_rx = 1;
        uart1_rx = 1;

        repeat (50) @(posedge clk);
        rst_n = 1;

        $display("[%0t ns] RESET RELEASED. BOOTLOADER BASLIYOR...", $time);

        // Timeout Süresi
        #500_000; 
        
        $display("\n[TIMEOUT] HATA: Sistem belirtilen sürede boot edemedi!");
        $display("Olasý Sebepler:");
        $display("1. Polling döngüsünden (Busy Check) çýkýlamadý.");
        $display("2. CPU 'Trap'e düþtü ama biz yakalayamadýk.");
        $fatal(1);
    end

endmodule