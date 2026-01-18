`timescale 1ns / 1ps

module periph_wrapper (
    input  logic clk,
    input  logic rst_n,

    // =======================================================================
    // AXI SLAVE INTERFACE (Connected to Data Decoder)
    // =======================================================================
    // Write Address
    input  logic [31:0] s_awaddr,
    input  logic        s_awvalid,
    output logic        s_awready,

    // Write Data
    input  logic [31:0] s_wdata,
    input  logic [3:0]  s_wstrb,
    input  logic        s_wvalid,
    output logic        s_wready,

    // Write Response
    output logic        s_bvalid,
    input  logic        s_bready,

    // Read Address
    input  logic [31:0] s_araddr,
    input  logic        s_arvalid,
    output logic        s_arready,

    // Read Data
    output logic [31:0] s_rdata,
    output logic        s_rvalid,
    input  logic        s_rready,

    // =======================================================================
    // EXTERNAL IO PINS
    // =======================================================================
    input  logic [15:0] gpio_in,
    output logic [15:0] gpio_out,
    
    input  logic uart0_rx, output logic uart0_tx,
    input  logic uart1_rx, output logic uart1_tx,
    
    // QSPI Flash Interface
    output logic qspi_sck,
    output logic qspi_cs_n,
    inout  wire  [3:0] qspi_dq
);

    // =======================================================================
    // 1. ADDRESS DECODING & SELECTION LOGIC
    // =======================================================================
    // Memory Map:
    // GPIO:  0x1000_0xxx (Sel = 0)
    // Timer: 0x1000_1xxx (Sel = 1)
    // UART0: 0x1000_2xxx (Sel = 2)
    // UART1: 0x1000_3xxx (Sel = 3)
    // QSPI:  0x1000_4xxx (Sel = 4)

    // Write Address Decoders
    wire gpio_sel  = (s_awaddr[14:12] == 3'h0);
    wire timer_sel = (s_awaddr[14:12] == 3'h1);
    wire uart0_sel = (s_awaddr[14:12] == 3'h2);
    wire uart1_sel = (s_awaddr[14:12] == 3'h3);
    wire qspi_sel  = (s_awaddr[14:12] == 3'h4);

    // Read Address Decoders
    wire gpio_r_sel  = (s_araddr[14:12] == 3'h0);
    wire timer_r_sel = (s_araddr[14:12] == 3'h1);
    wire uart0_r_sel = (s_araddr[14:12] == 3'h2);
    wire uart1_r_sel = (s_araddr[14:12] == 3'h3);
    wire qspi_r_sel  = (s_araddr[14:12] == 3'h4);

    // Write Response Routing Memory
    // We need to latch which slave was selected during the address phase
    // to route the BVALID response correctly in the response phase.
    logic [2:0] slave_sel_latch; 

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slave_sel_latch <= 3'b000;
        end else begin
            // Capture selection when a valid write address is presented
            if (s_awvalid) begin
                slave_sel_latch <= s_awaddr[14:12];
            end
        end
    end

    // =======================================================================
    // 2. PERIPHERAL INSTANTIATIONS
    // =======================================================================
    
    // --- Internal Signals for Muxing ---
    logic gpio_awready, gpio_wready, gpio_bvalid, gpio_arready, gpio_rvalid;
    logic [31:0] gpio_rdata;

    logic timer_awready, timer_wready, timer_bvalid, timer_arready, timer_rvalid;
    logic [31:0] timer_rdata;

    logic uart0_awready, uart0_wready, uart0_bvalid, uart0_arready, uart0_rvalid;
    logic [31:0] uart0_rdata;

    logic uart1_awready, uart1_wready, uart1_bvalid, uart1_arready, uart1_rvalid;
    logic [31:0] uart1_rdata;
    
    logic qspi_awready, qspi_wready, qspi_bvalid, qspi_arready, qspi_rvalid;
    logic [31:0] qspi_rdata;

    // --- GPIO Controller ---
    axi_gpio u_gpio (
        .clk(clk), .rst_n(rst_n),
        .s_awaddr(s_awaddr),
        .s_awvalid(s_awvalid && gpio_sel), // Only enable if selected
        .s_awready(gpio_awready),
        .s_wdata(s_wdata), .s_wstrb(s_wstrb),
        .s_wvalid(s_wvalid && gpio_sel),
        .s_wready(gpio_wready),
        .s_bvalid(gpio_bvalid), .s_bready(s_bready),
        .s_araddr(s_araddr),
        .s_arvalid(s_arvalid && gpio_r_sel),
        .s_arready(gpio_arready),
        .s_rdata(gpio_rdata), .s_rvalid(gpio_rvalid), .s_rready(s_rready),
        .gpio_in(gpio_in), .gpio_out(gpio_out)
    );

    // --- Timer Module ---
    axi_timer u_timer (
        .clk(clk), .rst_n(rst_n),
        .s_awaddr(s_awaddr), .s_awvalid(s_awvalid && timer_sel), .s_awready(timer_awready),
        .s_wdata(s_wdata), .s_wstrb(s_wstrb), .s_wvalid(s_wvalid && timer_sel), .s_wready(timer_wready),
        .s_bvalid(timer_bvalid), .s_bready(s_bready),
        .s_araddr(s_araddr), .s_arvalid(s_arvalid && timer_r_sel), .s_arready(timer_arready),
        .s_rdata(timer_rdata), .s_rvalid(timer_rvalid), .s_rready(s_rready)
    );

    // --- UART 0 ---
    axi_uart u_uart0 (
        .clk(clk), .rst_n(rst_n),
        .s_awaddr(s_awaddr), .s_awvalid(s_awvalid && uart0_sel), .s_awready(uart0_awready),
        .s_wdata(s_wdata), .s_wstrb(s_wstrb), .s_wvalid(s_wvalid && uart0_sel), .s_wready(uart0_wready),
        .s_bvalid(uart0_bvalid), .s_bready(s_bready),
        .s_araddr(s_araddr), .s_arvalid(s_arvalid && uart0_r_sel), .s_arready(uart0_arready),
        .s_rdata(uart0_rdata), .s_rvalid(uart0_rvalid), .s_rready(s_rready),
        .rx(uart0_rx), .tx(uart0_tx)
    );

    // --- UART 1 ---
    axi_uart u_uart1 (
        .clk(clk), .rst_n(rst_n),
        .s_awaddr(s_awaddr), .s_awvalid(s_awvalid && uart1_sel), .s_awready(uart1_awready),
        .s_wdata(s_wdata), .s_wstrb(s_wstrb), .s_wvalid(s_wvalid && uart1_sel), .s_wready(uart1_wready),
        .s_bvalid(uart1_bvalid), .s_bready(s_bready),
        .s_araddr(s_araddr), .s_arvalid(s_arvalid && uart1_r_sel), .s_arready(uart1_arready),
        .s_rdata(uart1_rdata), .s_rvalid(uart1_rvalid), .s_rready(s_rready),
        .rx(uart1_rx), .tx(uart1_tx)
    );

    // --- QSPI Master Controller ---
    axi_qspi_master u_qspi (
        .aclk(clk), .aresetn(rst_n),
        .s_axi_awaddr(s_awaddr), .s_axi_awvalid(s_awvalid && qspi_sel), .s_axi_awready(qspi_awready),
        .s_axi_wdata(s_wdata), .s_axi_wstrb(s_wstrb), .s_axi_wvalid(s_wvalid && qspi_sel), .s_axi_wready(qspi_wready),
        .s_axi_bvalid(qspi_bvalid), .s_axi_bready(s_bready),
        .s_axi_araddr(s_araddr), .s_axi_arvalid(s_arvalid && qspi_r_sel), .s_axi_arready(qspi_arready),
        .s_axi_rdata(qspi_rdata), .s_axi_rvalid(qspi_rvalid), .s_axi_rready(s_rready),
        .qspi_sck(qspi_sck), .qspi_cs_n(qspi_cs_n), .qspi_dq(qspi_dq)
    );


    // =======================================================================
    // 3. MULTIPLEXING LOGIC (Route Responses back to Master)
    // =======================================================================

    // --- Write Ready Mux ---
    // Route the 'Ready' signal from the currently selected slave
    always_comb begin
        s_awready = 0;
        s_wready  = 0;
        if (gpio_sel)       begin s_awready = gpio_awready; s_wready = gpio_wready; end
        else if (timer_sel) begin s_awready = timer_awready; s_wready = timer_wready; end
        else if (uart0_sel) begin s_awready = uart0_awready; s_wready = uart0_wready; end
        else if (uart1_sel) begin s_awready = uart1_awready; s_wready = uart1_wready; end
        else if (qspi_sel)  begin s_awready = qspi_awready; s_wready = qspi_wready; end
    end

    // --- Write Response Mux ---
    // Use the latched selection to route the response (BVALID)
    always_comb begin
        s_bvalid = 0;
        case (slave_sel_latch)
            3'h0: s_bvalid = gpio_bvalid;
            3'h1: s_bvalid = timer_bvalid;
            3'h2: s_bvalid = uart0_bvalid;
            3'h3: s_bvalid = uart1_bvalid;
            3'h4: s_bvalid = qspi_bvalid;
            default: s_bvalid = 0;
        endcase
    end

    // --- Read Ready Mux ---
    always_comb begin
        s_arready = 0;
        if (gpio_r_sel)       s_arready = gpio_arready;
        else if (timer_r_sel) s_arready = timer_arready;
        else if (uart0_r_sel) s_arready = uart0_arready;
        else if (uart1_r_sel) s_arready = uart1_arready;
        else if (qspi_r_sel)  s_arready = qspi_arready;
    end

    // --- Read Data Mux ---
    // Route Data/Valid from whichever slave is responding
    always_comb begin
        s_rdata  = 32'b0;
        s_rvalid = 1'b0;

        if (gpio_rvalid) begin 
            s_rdata  = gpio_rdata; 
            s_rvalid = 1'b1; 
        end else if (timer_rvalid) begin 
            s_rdata  = timer_rdata; 
            s_rvalid = 1'b1; 
        end else if (uart0_rvalid) begin 
            s_rdata  = uart0_rdata; 
            s_rvalid = 1'b1; 
        end else if (uart1_rvalid) begin 
            s_rdata  = uart1_rdata; 
            s_rvalid = 1'b1; 
        end else if (qspi_rvalid) begin 
            s_rdata  = qspi_rdata; 
            s_rvalid = 1'b1; 
        end
    end

endmodule