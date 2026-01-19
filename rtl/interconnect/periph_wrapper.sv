`timescale 1ns / 1ps

module periph_wrapper (
    input  logic clk,
    input  logic rst_n,

    // AXI SLAVE INTERFACE
    input  logic [31:0] s_awaddr, input s_awvalid, output logic s_awready,
    input  logic [31:0] s_wdata,  input [3:0] s_wstrb, input s_wvalid, output logic s_wready,
    output logic        s_bvalid, input s_bready,
    input  logic [31:0] s_araddr, input s_arvalid, output logic s_arready,
    output logic [31:0] s_rdata,  output logic s_rvalid, input s_rready,

    // EXTERNAL IO
    input  logic [15:0] gpio_in, output logic [15:0] gpio_out,
    input  logic uart0_rx, output logic uart0_tx,
    input  logic uart1_rx, output logic uart1_tx,
    
    // QSPI
    output logic qspi_sck, output logic qspi_cs_n, inout wire [3:0] qspi_dq
);

    // ADDRESS DECODING (4KB Pages)
    // 0: GPIO, 1: Timer, 2: UART0, 3: UART1, 4: QSPI
    wire [2:0] w_sel = s_awaddr[14:12];
    wire [2:0] r_sel = s_araddr[14:12];

    logic [2:0] w_sel_latch; 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) w_sel_latch <= 0;
        else if (s_awvalid) w_sel_latch <= w_sel;
    end

    // Internal Mux Signals
    logic [4:0] awready_vec, wready_vec, bvalid_vec, arready_vec, rvalid_vec;
    logic [31:0] rdata_vec [4:0];

    // --- GPIO (ID=0) ---
    axi_gpio u_gpio (
        .clk(clk), .rst_n(rst_n),
        .s_awaddr(s_awaddr), .s_awvalid(s_awvalid && w_sel==0), .s_awready(awready_vec[0]),
        .s_wdata(s_wdata), .s_wstrb(s_wstrb), .s_wvalid(s_wvalid && w_sel==0), .s_wready(wready_vec[0]),
        .s_bvalid(bvalid_vec[0]), .s_bready(s_bready),
        .s_araddr(s_araddr), .s_arvalid(s_arvalid && r_sel==0), .s_arready(arready_vec[0]),
        .s_rdata(rdata_vec[0]), .s_rvalid(rvalid_vec[0]), .s_rready(s_rready),
        .gpio_in(gpio_in), .gpio_out(gpio_out)
    );

    // --- TIMER (ID=1) ---
    axi_timer u_timer (
        .clk(clk), .rst_n(rst_n),
        .s_awaddr(s_awaddr), .s_awvalid(s_awvalid && w_sel==1), .s_awready(awready_vec[1]),
        .s_wdata(s_wdata), .s_wstrb(s_wstrb), .s_wvalid(s_wvalid && w_sel==1), .s_wready(wready_vec[1]),
        .s_bvalid(bvalid_vec[1]), .s_bready(s_bready),
        .s_araddr(s_araddr), .s_arvalid(s_arvalid && r_sel==1), .s_arready(arready_vec[1]),
        .s_rdata(rdata_vec[1]), .s_rvalid(rvalid_vec[1]), .s_rready(s_rready)
    );

    // --- UART0 (ID=2) ---
    axi_uart u_uart0 (
        .clk(clk), .rst_n(rst_n),
        .s_awaddr(s_awaddr), .s_awvalid(s_awvalid && w_sel==2), .s_awready(awready_vec[2]),
        .s_wdata(s_wdata), .s_wstrb(s_wstrb), .s_wvalid(s_wvalid && w_sel==2), .s_wready(wready_vec[2]),
        .s_bvalid(bvalid_vec[2]), .s_bready(s_bready),
        .s_araddr(s_araddr), .s_arvalid(s_arvalid && r_sel==2), .s_arready(arready_vec[2]),
        .s_rdata(rdata_vec[2]), .s_rvalid(rvalid_vec[2]), .s_rready(s_rready),
        .rx(uart0_rx), .tx(uart0_tx)
    );

    // --- UART1 (ID=3) ---
    axi_uart u_uart1 (
        .clk(clk), .rst_n(rst_n),
        .s_awaddr(s_awaddr), .s_awvalid(s_awvalid && w_sel==3), .s_awready(awready_vec[3]),
        .s_wdata(s_wdata), .s_wstrb(s_wstrb), .s_wvalid(s_wvalid && w_sel==3), .s_wready(wready_vec[3]),
        .s_bvalid(bvalid_vec[3]), .s_bready(s_bready),
        .s_araddr(s_araddr), .s_arvalid(s_arvalid && r_sel==3), .s_arready(arready_vec[3]),
        .s_rdata(rdata_vec[3]), .s_rvalid(rvalid_vec[3]), .s_rready(s_rready),
        .rx(uart1_rx), .tx(uart1_tx)
    );

    // --- QSPI (ID=4) - OPTIMIZED ---
    axi_qspi_master u_qspi (
        .aclk(clk), .aresetn(rst_n),
        .s_axi_awaddr(s_awaddr), .s_axi_awvalid(s_awvalid && w_sel==4), .s_axi_awready(awready_vec[4]),
        .s_axi_wdata(s_wdata), .s_axi_wstrb(s_wstrb), .s_axi_wvalid(s_wvalid && w_sel==4), .s_axi_wready(wready_vec[4]),
        .s_axi_bvalid(bvalid_vec[4]), .s_axi_bready(s_bready),
        .s_axi_araddr(s_araddr), .s_axi_arvalid(s_arvalid && r_sel==4), .s_axi_arready(arready_vec[4]),
        .s_axi_rdata(rdata_vec[4]), .s_axi_rvalid(rvalid_vec[4]), .s_axi_rready(s_rready),
        .qspi_sck(qspi_sck), .qspi_cs_n(qspi_cs_n), .qspi_dq(qspi_dq)
    );

    // --- MUX LOGIC ---
    always_comb begin
        s_awready = (w_sel < 5) ? awready_vec[w_sel] : 0;
        s_wready  = (w_sel < 5) ? wready_vec[w_sel]  : 0;
        s_bvalid  = (w_sel_latch < 5) ? bvalid_vec[w_sel_latch] : 0;
        
        s_arready = (r_sel < 5) ? arready_vec[r_sel] : 0;
        
        s_rdata = 0; s_rvalid = 0;
        // Basit Priority Encoder yerine one-hot check daha hizlidir ama bu yeterli
        if (rvalid_vec[0])      {s_rvalid, s_rdata} = {1'b1, rdata_vec[0]};
        else if (rvalid_vec[1]) {s_rvalid, s_rdata} = {1'b1, rdata_vec[1]};
        else if (rvalid_vec[2]) {s_rvalid, s_rdata} = {1'b1, rdata_vec[2]};
        else if (rvalid_vec[3]) {s_rvalid, s_rdata} = {1'b1, rdata_vec[3]};
        else if (rvalid_vec[4]) {s_rvalid, s_rdata} = {1'b1, rdata_vec[4]};
    end

endmodule