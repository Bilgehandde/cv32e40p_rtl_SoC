module tb_soc;

    // ========================================================================
    // 1. SIMULATION PARAMETERS
    // ========================================================================
    localparam CLK_PERIOD_NS = 20;      // 50 MHz
    localparam TIMEOUT_CYCLES = 50000;  // Fail if boot doesn't complete by then

    // ========================================================================
    // 2. SIGNALS & INTERFACES
    // ========================================================================
    logic clk;
    logic rst_n;
    
    // IO Signals
    logic [15:0] sw_in;
    logic uart0_rx, uart1_rx;
    
    wire [15:0] gpio_out_pins;
    wire uart0_tx, uart1_tx;

    // QSPI Interface
    wire qspi_cs_n;
    wire qspi_sck;     
    wire [3:0] qspi_dq;

    // Pull-ups for QSPI lines (Required for Quad I/O simulation)
    pullup(qspi_dq[0]);
    pullup(qspi_dq[1]);
    pullup(qspi_dq[2]);
    pullup(qspi_dq[3]);

    // ========================================================================
    // 3. DUT INSTANTIATION
    // ========================================================================
    soc_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .sw_in(sw_in),
        .gpio_out_pins(gpio_out_pins),
        .uart0_rx(uart0_rx), .uart0_tx(uart0_tx),
        .uart1_rx(uart1_rx), .uart1_tx(uart1_tx),
        .qspi_cs_n(qspi_cs_n),
        .qspi_dq(qspi_dq)
    );

    // ========================================================================
    // 3.1. HIERARCHICAL ACCESS (SPYING) - KRÝTÝK DÜZELTME
    // ========================================================================
    assign qspi_sck = uut.u_periph.qspi_sck;

    // ========================================================================
    // 4. SPI FLASH MODEL
    // ========================================================================
    // SPI Flash Model (Contains the Application Code)
    spiflash_model u_flash_chip (
        .cs_n(qspi_cs_n),
        .clk(qspi_sck), 
        .dq(qspi_dq)
    );

    // ========================================================================
    // 5. CLOCK GENERATION
    // ========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD_NS/2) clk = ~clk;
    end

    // ========================================================================
    // 6. WHITE-BOX MONITORING (INTERNAL PROBES)
    // ========================================================================
    // PC Signal
    wire [31:0] cpu_instr_addr = uut.m0_araddr;

    // IRAM Write Interface
    wire        iram_wvalid = uut.u_inst_ram.b_wvalid;
    wire        iram_wready = uut.u_inst_ram.b_wready; 
    wire [31:0] iram_waddr  = uut.u_inst_ram.b_awaddr;
    wire [31:0] iram_wdata  = uut.u_inst_ram.b_wdata;

    integer copied_word_cnt = 0;

    // ========================================================================
    // 7. SELF-CHECKING LOGIC
    // ========================================================================
    
    // A) Monitor Bootloader Copy Process
    always @(posedge clk) begin
        if (iram_wvalid && iram_wready) begin
            copied_word_cnt++;
            $display("[T=%0t] [BOOTLOADER] Copying Word #%0d to IRAM Addr: 0x%h | Data: 0x%h", 
                     $time, copied_word_cnt, iram_waddr, iram_wdata);

            case (copied_word_cnt)
                1: assert(iram_wdata == 32'h10000537) else $error("Data Mismatch Word 1!");
                2: assert(iram_wdata == 32'h0aa00593) else $error("Data Mismatch Word 2!");
                3: assert(iram_wdata == 32'h00b52223) else $error("Data Mismatch Word 3!");
                4: assert(iram_wdata == 32'h0000006f) else $error("Data Mismatch Word 4!");
            endcase
        end
    end

    // B) Monitor CPU Jump
    initial begin
        wait (rst_n == 1);
        wait (cpu_instr_addr == 32'h0010_0000);
        $display("\n-----------------------------------------------------------");
        $display("[SUCCESS] CPU jumped to Application Base Address (0x00100000)!");
        $display("-----------------------------------------------------------");
    end

    // C) Monitor GPIO Output
    initial begin
        wait (rst_n == 1);
        wait ((gpio_out_pins & 16'h00FF) == 16'h00AA);
        $display("\n-----------------------------------------------------------");
        $display("[SUCCESS] GPIO LEDs output correct pattern: 0xAA");
        $display("-----------------------------------------------------------");
        #1000;
        $display("[INFO] Testbench Completed Successfully.");
        $finish;
    end

    // ========================================================================
    // 8. MAIN STIMULUS
    // ========================================================================
    initial begin
        rst_n = 0;
        sw_in = 16'h0000;
        uart0_rx = 1; 
        uart1_rx = 1; 

        $display("===========================================================");
        $display(" SOC SYSTEM TESTBENCH START");
        $display("===========================================================");

        repeat (50) @(posedge clk);
        rst_n = 1;
        $display("[INFO] System Reset Released.");

        repeat (TIMEOUT_CYCLES) @(posedge clk);

        $display("\n[ERROR] TIMEOUT! System did not boot within %0d cycles.", TIMEOUT_CYCLES);
        $fatal(1);
    end

endmodule