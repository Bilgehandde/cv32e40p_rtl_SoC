`timescale 1ns / 1ps

module obi_to_axi (
    input  logic        clk,
    input  logic        rst_n,

    // ================= OBI (Slave Interface) =================
    input  logic        obi_req_i,
    input  logic        obi_we_i,
    input  logic [3:0]  obi_be_i,
    input  logic [31:0] obi_addr_i,
    input  logic [31:0] obi_wdata_i,
    output logic        obi_gnt_o,
    output logic        obi_rvalid_o, // Register deðil, wire olacak
    output logic [31:0] obi_rdata_o,  // Register deðil, wire olacak

    // ================= AXI4-Lite (Master Interface) =================
    // Write Address Channel
    output logic [31:0] m_axi_awaddr,
    output logic        m_axi_awvalid,
    input  logic        m_axi_awready,

    // Write Data Channel
    output logic [31:0] m_axi_wdata,
    output logic [3:0]  m_axi_wstrb,
    output logic        m_axi_wvalid,
    input  logic        m_axi_wready,

    // Write Response Channel
    input  logic        m_axi_bvalid,
    output logic        m_axi_bready,

    // Read Address Channel
    output logic [31:0] m_axi_araddr,
    output logic        m_axi_arvalid,
    input  logic        m_axi_arready,

    // Read Data Channel
    input  logic [31:0] m_axi_rdata,
    input  logic        m_axi_rvalid,
    output logic        m_axi_rready
);

  // =========================================================
  // DURUM MAKÝNESÝ
  // =========================================================
  typedef enum logic { TRANS_PHASE, RESP_PHASE } state_t;
  state_t state_q, state_d;

  logic is_write_q;       // Ýþlem tipi hafýzasý (1: Yazma, 0: Okuma)

  // =========================================================
  // 1. COMBINATIONAL OUTPUTS (Senin istediðin mantýk burada)
  // =========================================================
  
  // AXI sinyallerini direkt OBI'den geçir
  assign m_axi_awaddr = obi_addr_i;
  assign m_axi_araddr = obi_addr_i;
  assign m_axi_wdata  = obi_wdata_i;
  assign m_axi_wstrb  = obi_be_i;

  // Data Okuma: AXI'den gelen veri direkt OBI'ye aksýn
  assign obi_rdata_o  = m_axi_rdata; 

  // *** KRÝTÝK NOKTA: RVALID ÜRETÝMÝ ***
  // Sadece RESP_PHASE (Cevap bekleme) durumundayken;
  // Eðer Yazma ise (BVALID ve BREADY)
  // Eðer Okuma ise (RVALID ve RREADY) 1 olsun.
  assign obi_rvalid_o = (state_q == RESP_PHASE) && (
                          (is_write_q  && m_axi_bvalid && m_axi_bready) || 
                          (!is_write_q && m_axi_rvalid && m_axi_rready)
                        );

  // =========================================================
  // 2. STATE MACHINE & AXI KONTROL
  // =========================================================
  always_comb begin
    state_d = state_q;
    obi_gnt_o = 1'b0;
    
    // Default AXI Valid/Ready sinyalleri
    m_axi_awvalid = 1'b0; 
    m_axi_wvalid  = 1'b0; 
    m_axi_arvalid = 1'b0;
    m_axi_bready  = 1'b0; 
    m_axi_rready  = 1'b0;

    case (state_q)
      
      // -----------------------------------------------------
      // FAZ 1: TRANSFER (Ýstek Gönderme)
      // -----------------------------------------------------
      TRANS_PHASE: begin
        // Ýþlemci istek attý mý?
        if (obi_req_i) begin
          if (obi_we_i) begin
            // --- YAZMA ÝÞLEMÝ (Write) ---
            m_axi_awvalid = 1'b1; // Adres Valid
            m_axi_wvalid  = 1'b1; // Data Valid
            
            // AXI "Hazýrým" dediði anda Grant verip duruma geçiyoruz
            if (m_axi_awready && m_axi_wready) begin
              obi_gnt_o = 1'b1; 
              state_d   = RESP_PHASE; 
            end
          end else begin
            // --- OKUMA ÝÞLEMÝ (Read) ---
            m_axi_arvalid = 1'b1; // Adres Valid
            
            // AXI "Hazýrým" dediði anda Grant verip duruma geçiyoruz
            if (m_axi_arready) begin
              obi_gnt_o = 1'b1;
              state_d   = RESP_PHASE; 
            end
          end
        end
      end

      // -----------------------------------------------------
      // FAZ 2: CEVAP BEKLEME (Response)
      // -----------------------------------------------------
      RESP_PHASE: begin
        if (is_write_q) begin
          // --- Yazma Cevabý Bekleniyor ---
          m_axi_bready = 1'b1; // Biz cevabý almaya hazýrýz
          
          if (m_axi_bvalid) begin
            // BVALID geldiði anda (yukarýdaki assign obi_rvalid_o = 1 olur)
            state_d = TRANS_PHASE; // Ýþlem bitti, baþa dön
          end
        end else begin
          // --- Okuma Cevabý Bekleniyor ---
          m_axi_rready = 1'b1; // Biz veriyi almaya hazýrýz
          
          if (m_axi_rvalid) begin
             // RVALID geldiði anda (yukarýdaki assign obi_rvalid_o = 1 olur)
             state_d = TRANS_PHASE; // Ýþlem bitti, baþa dön
          end
        end
      end

    endcase
  end

  // =========================================================
  // 3. SEQUENTIAL LOGIC (Sadece Durum ve Tip Saklama)
  // =========================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q    <= TRANS_PHASE;
      is_write_q <= 1'b0;
    end else begin
      state_q <= state_d;
      
      // Grant verdiðimiz anda iþlemin tipini (Yazma mý Okuma mý?) hafýzaya alýyoruz
      // Çünkü RESP_PHASE'de bu bilgiye ihtiyacýmýz olacak.
      if (state_q == TRANS_PHASE && obi_gnt_o) begin
        is_write_q <= obi_we_i;
      end
    end
  end

endmodule