`timescale 1ns / 1ps

module tb_soc;
    // Sinyaller
    logic clk_100mhz; // Kristal giri�ini sim�le eder
    logic rst_n;
    logic [15:0] gpio_out;
    
    // �zleme parametreleri
    localparam [15:0] EXPECTED_LED = 16'h00FF;
    integer timeout_counter = 0;

    // DUT (System on Chip)
    soc_top uut (
        .clk           (clk_100mhz),
        .rst_n         (rst_n),
        .gpio_out_pins (gpio_out)
    );

    // 100 MHz Saat (10ns periyot)
    initial clk_100mhz = 0;
    always #5 clk_100mhz = ~clk_100mhz;

    // Test Senaryosu
    initial begin
        rst_n = 0;
        #200; // PLL'in (Clock Wizard) oturmas� i�in s�re ver
        
        @(posedge clk_100mhz);
        rst_n <= 1;
        $display("[%0t ns] Reset birakildi. Islemci 50 MHz ile calisiyor...", $time);

        // Ba�ar� veya Zaman A��m� takibi
        forever begin
            @(posedge uut.clk_50mhz); // SoC i�indeki ger�ek saati baz al
            if (gpio_out == EXPECTED_LED) begin
                $display("[%0t ns] TEST BASARILI: LEDler 0x%h oldu!", $time, gpio_out);
                #1000;
                $finish;
            end
            
            timeout_counter++;
            if (timeout_counter > 10000) begin // 10000 �evrim bekle (yakla��k 200us)
                $display("[%0t ns] HATA: Zaman asimi!", $time);
                $finish;
            end
        end
    end
endmodule
