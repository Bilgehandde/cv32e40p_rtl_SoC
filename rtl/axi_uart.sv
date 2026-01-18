`timescale 1ns / 1ps

module axi_uart (
    input  logic clk,
    input  logic rst_n,

    // AXI4-Lite Slave Interface
    input  logic [31:0] s_awaddr, 
    input  logic        s_awvalid, 
    output logic        s_awready, // <--- EKLENDÝ

    input  logic [31:0] s_wdata,  
    input  logic        s_wvalid,  
    output logic        s_wready,  // <--- EKLENDÝ

    output logic        s_bvalid, 
    input  logic        s_bready,

    input  logic [31:0] s_araddr, 
    input  logic        s_arvalid, 
    output logic        s_arready, // <--- EKLENDÝ

    output logic [31:0] s_rdata,  
    output logic        s_rvalid, 
    input  logic        s_rready,
    
    input  logic [3:0]  s_wstrb,
    
    // UART Fiziksel Pinleri
    input  logic rx,
    output logic tx
);

    // --- REGISTER TANIMLARI ---
    logic [31:0] reg_clk_div;
    logic [7:0]  rx_data;
    logic        rx_valid_flag;
    logic        tx_busy_flag;
    logic        tx_start;
    logic [7:0]  tx_data_latched;

    // AXI Handshake (Basit mod: Hep hazýr)
    assign s_awready = 1'b1;
    assign s_wready  = 1'b1;
    assign s_arready = 1'b1;

    // --- AXI YAZMA ÝÞLEMÝ (CPU -> UART) ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_clk_div <= 32'd434; 
            tx_start    <= 1'b0;
            tx_data_latched <= 8'b0;
            s_bvalid    <= 1'b0;
        end else begin
            tx_start <= 1'b0; // Pulse
            
            if (s_awvalid && s_wvalid) begin
                case (s_awaddr[3:0])
                    4'h0: begin 
                        if (!tx_busy_flag) begin
                            tx_data_latched <= s_wdata[7:0];
                            tx_start <= 1'b1;
                        end
                    end
                    4'h8: reg_clk_div <= s_wdata; 
                endcase
                s_bvalid <= 1'b1;
            end else if (s_bready) begin
                s_bvalid <= 1'b0;
            end
        end
    end

    // --- AXI OKUMA ÝÞLEMÝ (UART -> CPU) ---
    // (RX Bölümünden gelen sinyal)
    logic rx_done_tick; 

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_rvalid <= 1'b0;
            s_rdata  <= 32'b0;
            rx_valid_flag <= 1'b0; 
        end else begin
            if (rx_done_tick) rx_valid_flag <= 1'b1;

            if (s_arvalid) begin
                s_rvalid <= 1'b1;
                case (s_araddr[3:0])
                    4'h0: begin 
                        s_rdata <= {24'b0, rx_data}; 
                        rx_valid_flag <= 1'b0; 
                    end
                    4'h4: s_rdata <= {30'b0, rx_valid_flag, tx_busy_flag};
                    4'h8: s_rdata <= reg_clk_div;
                    default: s_rdata <= 32'b0;
                endcase
            end else if (s_rready) begin
                s_rvalid <= 1'b0;
            end
        end
    end

    // =========================================================
    // UART TX & RX MANTIÐI (Ayný Kaldý)
    // =========================================================
    // ... (Kodun geri kalaný orijinaliyle ayný, dokunmana gerek yok) ...
    // Sadece yukarýdaki Port listesi ve Assign Ready kýsýmlarýný deðiþtirmen yeterli.
    
    // (TX ve RX logic bloklarýný buraya tekrar yapýþtýrmýyorum, eski kodun aynýsý kalabilir)
    
    // --- TX Bölümü ---
    logic [15:0] tx_cnt;
    logic [3:0]  tx_bit_idx;
    logic [9:0]  tx_shifter; 

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_busy_flag <= 1'b0;
            tx           <= 1'b1;
            tx_cnt       <= 0;
            tx_bit_idx   <= 0;
        end else begin
            if (tx_start && !tx_busy_flag) begin
                tx_busy_flag <= 1'b1;
                tx_shifter   <= {1'b1, tx_data_latched, 1'b0};
                tx_cnt       <= 0;
                tx_bit_idx   <= 0;
            end else if (tx_busy_flag) begin
                if (tx_cnt < reg_clk_div[15:0]) begin
                    tx_cnt <= tx_cnt + 1;
                end else begin
                    tx_cnt <= 0;
                    tx      <= tx_shifter[tx_bit_idx];
                    if (tx_bit_idx < 9) begin
                        tx_bit_idx <= tx_bit_idx + 1;
                    end else begin
                        tx_busy_flag <= 1'b0;
                        tx <= 1'b1;
                    end
                end
            end
        end
    end

    // --- RX Bölümü ---
    logic [15:0] rx_cnt;
    logic [3:0]  rx_bit_idx;
    logic        rx_busy;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_busy <= 1'b0;
            rx_cnt  <= 0;
            rx_bit_idx <= 0;
            rx_data <= 0;
            rx_done_tick <= 0;
        end else begin
            rx_done_tick <= 0;
            if (!rx_busy) begin
                if (rx == 1'b0) begin 
                    rx_busy <= 1'b1;
                    rx_cnt  <= 0;
                    rx_bit_idx <= 0;
                end
            end else begin
                if (rx_cnt < reg_clk_div[15:0]) begin
                    rx_cnt <= rx_cnt + 1;
                end else begin
                    rx_cnt <= 0;
                    if (rx_bit_idx == 0) begin 
                         // Start bit
                    end else if (rx_bit_idx <= 8) begin 
                        rx_data[rx_bit_idx-1] <= rx; 
                    end
                    
                    if (rx_bit_idx < 9) begin
                         rx_bit_idx <= rx_bit_idx + 1;
                    end else begin
                         rx_busy <= 1'b0;
                         rx_done_tick <= 1'b1;
                    end
                end
            end
        end
    end

endmodule