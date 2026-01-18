`timescale 1ns / 1ps

module axi_qspi_master (
    input  logic        aclk,
    input  logic        aresetn,

    // AXI4-Lite Interface
    input  logic [31:0] s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,
    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,

    input  logic [31:0] s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    // QSPI Physical
    output logic        qspi_sck,
    output logic        qspi_cs_n,
    inout  wire  [3:0]  qspi_dq
);

    logic [31:0] reg_ctrl; 
    logic [31:0] reg_addr; 
    logic [31:0] reg_data; 
    logic start_pulse;
    logic busy_reg; // Kayýtlý Bayrak

    // SPI Signals
    logic spi_clk_reg, spi_clk_prev;
    logic [7:0]  shift_cmd;
    logic [23:0] shift_addr;
    logic [31:0] bit_cnt;
    logic [3:0]  dq_out, dq_oe;

    typedef enum logic [2:0] {IDLE, CMD, ADDR, DATA, DONE} state_t;
    state_t state;

    // ---------------- AXI WRITE ----------------
    assign s_axi_awready = 1'b1; assign s_axi_wready = 1'b1; assign s_axi_bresp = 2'b00;
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin s_axi_bvalid<=0; reg_ctrl<=0; reg_addr<=0; start_pulse<=0; end
        else begin
            start_pulse <= 0; 
            if (s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid) begin
                if (s_axi_awaddr[7:0] == 8'h00) begin reg_ctrl <= s_axi_wdata; start_pulse <= 1; end
                else if (s_axi_awaddr[7:0] == 8'h04) reg_addr <= s_axi_wdata;
                s_axi_bvalid <= 1;
            end else if (s_axi_bready) s_axi_bvalid <= 0;
        end
    end

    // ---------------- AXI READ ----------------
    assign s_axi_arready = 1'b1; assign s_axi_rresp = 2'b00;
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin s_axi_rvalid<=0; s_axi_rdata<=0; end
        else begin
            if (s_axi_arvalid && !s_axi_rvalid) begin
                case (s_axi_araddr[7:0])
                    8'h00: s_axi_rdata <= reg_ctrl;
                    8'h04: s_axi_rdata <= reg_addr;
                    8'h08: s_axi_rdata <= reg_data;
                    8'h28: s_axi_rdata <= {31'b0, busy_reg}; // Stable Read
                    default: s_axi_rdata <= 0;
                endcase
                s_axi_rvalid <= 1;
            end else if (s_axi_rready) s_axi_rvalid <= 0;
        end
    end

    // ---------------- SPI CLOCK ----------------
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin spi_clk_reg<=0; spi_clk_prev<=0; end
        else begin spi_clk_reg <= ~spi_clk_reg; spi_clk_prev <= spi_clk_reg; end
    end
    assign qspi_sck = (state == IDLE || state == DONE) ? 1'b0 : spi_clk_reg;
    wire sck_fall = (spi_clk_prev == 1 && spi_clk_reg == 0);
    wire sck_rise = (spi_clk_prev == 0 && spi_clk_reg == 1);

    assign qspi_dq[0] = dq_oe[0] ? dq_out[0] : 1'bz; 
    assign qspi_dq[1] = 1'bz; assign qspi_dq[2] = 1'bz; assign qspi_dq[3] = 1'bz;

    // ---------------- FSM (TIMING FIX) ----------------
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state <= IDLE; qspi_cs_n <= 1; dq_oe <= 0;
            reg_data <= 0; bit_cnt <= 0; dq_out <= 0;
            busy_reg <= 0;
        end else begin
            
            // Set logic (Priority on Start)
            if (start_pulse) busy_reg <= 1'b1;
            // Clear logic: DATA state içinde yapýlýyor!

            case (state)
                IDLE: begin
                    qspi_cs_n <= 1; dq_oe <= 0;
                    if (start_pulse) begin
                        reg_data <= 0; shift_cmd <= 8'h03; shift_addr <= reg_addr[23:0];
                        bit_cnt <= 7; qspi_cs_n <= 0; state <= CMD;
                        dq_oe <= 4'b0001; dq_out[0] <= 1'b0; // Look-ahead
                    end
                end

                CMD: if (sck_fall) begin
                    if (bit_cnt == 0) begin bit_cnt<=23; state<=ADDR; dq_out[0]<=shift_addr[23]; end
                    else begin bit_cnt<=bit_cnt-1; dq_out[0]<=shift_cmd[bit_cnt-1]; end
                end

                ADDR: if (sck_fall) begin
                    if (bit_cnt == 0) begin bit_cnt<=31; dq_oe<=0; state<=DATA; end
                    else begin bit_cnt<=bit_cnt-1; dq_out[0]<=shift_addr[bit_cnt-1]; end
                end

                DATA: begin
                    if (sck_rise) begin
                        $display("[QSPI DEBUG] Time: %0t, Bit: %0d, Sampled DQ[1]: %b", $time, bit_cnt, qspi_dq[1]);
                        reg_data[bit_cnt] <= qspi_dq[1];
                    end
                    if (sck_fall) begin
                        if (bit_cnt == 0) begin
                            state <= DONE;
                            // busy_reg burada hala 1 kalmalý
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                DONE: begin
                    qspi_cs_n <= 1;
                    // Byte Swap
                    reg_data <= {reg_data[7:0], reg_data[15:8], reg_data[23:16], reg_data[31:24]};
                    busy_reg <= 1'b0; // <--- DOÐRU YER: Veri hazýrlandýktan sonra indir.
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule