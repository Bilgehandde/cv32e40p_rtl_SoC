`timescale 1ns / 1ps

module axi_gpio (
    input  logic clk,
    input  logic rst_n,

    // AXI Slave Interface
    input  logic [31:0] s_awaddr, 
    input  logic        s_awvalid, 
    output logic        s_awready, // <--- EKLENDÝ (Wrapper bunu arýyor)

    input  logic [31:0] s_wdata,  
    input  logic        s_wvalid,
    output logic        s_wready,  // <--- EKLENDÝ (Wrapper bunu arýyor)

    output logic        s_bvalid, 
    input  logic        s_bready, 
    
    input  logic [31:0] s_araddr, 
    input  logic        s_arvalid, 
    output logic        s_arready, // <--- EKLENDÝ (Wrapper bunu arýyor)
    
    output logic [31:0] s_rdata,  
    output logic        s_rvalid, 
    input  logic        s_rready,
    
    input  logic [3:0]  s_wstrb,
    
    // GPIO Pins
    input  logic [15:0] gpio_in,
    output logic [15:0] gpio_out
);

    // Registerler
    logic [15:0] gpio_reg;
    assign gpio_out = gpio_reg;

    // ==========================================================
    // "ALWAYS READY" MANTIÐI (KÝLÝTLENMEYÝ ÖNLER)
    // ==========================================================
    // Master'a "Bekleme yapma, ben hep hazýrým" diyoruz.
    assign s_awready = 1'b1;
    assign s_wready  = 1'b1;
    assign s_arready = 1'b1;

    // --- YAZMA KANALI (WRITE CHANNEL) ---
    // Cevap sinyalini bir register'da tutuyoruz.
    logic bvalid_reg;
    assign s_bvalid = bvalid_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_reg <= 16'h0000;
            bvalid_reg <= 1'b0;
        end else begin
            // 1. Yazma Baþlatma: Valid sinyalleri geldi ve henüz cevap vermedik
            // (Ready kontrolüne gerek yok çünkü zaten 1)
            if (s_awvalid && s_wvalid && !bvalid_reg) begin
                // Adresin son 4 bitine bak (0x4 -> Output Register)
                if (s_awaddr[3:0] == 4'h4) begin
                    gpio_reg <= s_wdata[15:0];
                end
                // Ýþlemciye "Ýþlem Tamam" bayraðýný kaldýr
                bvalid_reg <= 1'b1;
            end
            
            // 2. Yazma Bitirme: Biz bayraðý kaldýrdýk VE Ýþlemci bunu gördü (Ready)
            else if (bvalid_reg && s_bready) begin
                // Bayraðý indir, iþlem bitti.
                bvalid_reg <= 1'b0;
            end
        end
    end

    // --- OKUMA KANALI (READ CHANNEL) ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_rdata <= 32'b0;
            s_rvalid <= 1'b0;
        end else begin
            // Okuma isteði geldi (s_arvalid) ve henüz cevap vermedik (!s_rvalid)
            if (s_arvalid && !s_rvalid) begin
                s_rvalid <= 1'b1;
                case (s_araddr[3:0])
                    4'h0: s_rdata <= {16'b0, gpio_in};
                    4'h4: s_rdata <= {16'b0, gpio_reg};
                    default: s_rdata <= 32'b0;
                endcase
            end else if (s_rvalid && s_rready) begin
                s_rvalid <= 1'b0;
            end
        end
    end

endmodule