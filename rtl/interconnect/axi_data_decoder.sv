`timescale 1ns / 1ps

module axi_data_decoder (
    input  logic clk,
    input  logic rst_n,

    // =======================================================================
    // MASTER INTERFACE (Connected to CPU Data Port)
    // =======================================================================
    // Write Address Channel
    input  logic [31:0] s_awaddr, 
    input  logic        s_awvalid, 
    output logic        s_awready,
    
    // Write Data Channel
    input  logic [31:0] s_wdata,  
    input  logic [3:0]  s_wstrb,  
    input  logic        s_wvalid,  
    output logic        s_wready,
    
    // Write Response Channel
    output logic        s_bvalid, 
    input  logic        s_bready,

    // Read Address Channel
    input  logic [31:0] s_araddr, 
    input  logic        s_arvalid, 
    output logic        s_arready,
    
    // Read Data Channel
    output logic [31:0] s_rdata,  
    output logic        s_rvalid,  
    input  logic        s_rready,

    // =======================================================================
    // SLAVE 1: IRAM PORT B (Data Access - 0x0010_0000)
    // =======================================================================
    output logic [31:0] iram_awaddr, output logic iram_awvalid, input  logic iram_awready,
    output logic [31:0] iram_wdata,  output logic [3:0] iram_wstrb, output logic iram_wvalid, input  logic iram_wready,
    input  logic        iram_bvalid, output logic iram_bready,
    output logic [31:0] iram_araddr, output logic iram_arvalid, input  logic iram_arready,
    input  logic [31:0] iram_rdata,  input  logic iram_rvalid,  output logic iram_rready,

    // =======================================================================
    // SLAVE 2: DRAM (Data RAM - 0x0020_0000)
    // =======================================================================
    output logic [31:0] dram_awaddr, output logic dram_awvalid, input  logic dram_awready,
    output logic [31:0] dram_wdata,  output logic [3:0] dram_wstrb, output logic dram_wvalid, input  logic dram_wready,
    input  logic        dram_bvalid, output logic dram_bready,
    output logic [31:0] dram_araddr, output logic dram_arvalid, input  logic dram_arready,
    input  logic [31:0] dram_rdata,  input  logic dram_rvalid,  output logic dram_rready,

    // =======================================================================
    // SLAVE 3: PERIPHERALS (GPIO, UART, QSPI - 0x1000_0000)
    // =======================================================================
    output logic [31:0] periph_awaddr, output logic periph_awvalid, input  logic periph_awready,
    output logic [31:0] periph_wdata,  output logic [3:0] periph_wstrb, output logic periph_wvalid, input  logic periph_wready,
    input  logic        periph_bvalid, output logic periph_bready,
    output logic [31:0] periph_araddr, output logic periph_arvalid, input  logic periph_arready,
    input  logic [31:0] periph_rdata,  input  logic periph_rvalid,  output logic periph_rready
);

    // =======================================================================
    // 1. WRITE CHANNEL ROUTING (Address & Data) - Combinational
    // =======================================================================
    // Routes the Write Request to the appropriate Slave based on Address.
    always_comb begin
        // Default Assignments (Idle)
        iram_awvalid   = 0; iram_wvalid   = 0; 
        iram_awaddr    = s_awaddr; iram_wdata = s_wdata; iram_wstrb = s_wstrb; iram_bready = s_bready;
        
        dram_awvalid   = 0; dram_wvalid   = 0; 
        dram_awaddr    = s_awaddr; dram_wdata = s_wdata; dram_wstrb = s_wstrb; dram_bready = s_bready;
        
        periph_awvalid = 0; periph_wvalid = 0; 
        periph_awaddr  = s_awaddr; periph_wdata = s_wdata; periph_wstrb = s_wstrb; periph_bready = s_bready;
        
        s_awready = 0; s_wready = 0; 

        // Decode Address (Upper 12 bits)
        case (s_awaddr[31:20])
            12'h001: begin // IRAM (0x001xxxxx)
                iram_awvalid = s_awvalid; 
                iram_wvalid  = s_wvalid;
                s_awready    = iram_awready; 
                s_wready     = iram_wready; 
            end
            12'h002: begin // DRAM (0x002xxxxx)
                dram_awvalid = s_awvalid; 
                dram_wvalid  = s_wvalid;
                s_awready    = dram_awready; 
                s_wready     = dram_wready; 
            end
            12'h100: begin // PERIPHERALS (0x100xxxxx)
                periph_awvalid = s_awvalid; 
                periph_wvalid  = s_wvalid;
                s_awready      = periph_awready; 
                s_wready       = periph_wready; 
            end
            default: begin
                // Decode Error / Hole: Fake an immediate accept to prevent hang
                s_awready = 1'b1; 
                s_wready  = 1'b1; 
            end
        endcase
    end

    // =======================================================================
    // 1.5. WRITE RESPONSE ROUTING
    // =======================================================================
    // Routes the 'bvalid' response from the active Slave back to the Master.
    // Note: This relies on 's_awaddr' remaining stable during the transaction, 
    // which is true for our blocking OBI-to-AXI bridge.
    always_comb begin
        s_bvalid = 0;
        
        case (s_awaddr[31:20])
            12'h001: s_bvalid = iram_bvalid;    // Response from IRAM
            12'h002: s_bvalid = dram_bvalid;    // Response from DRAM
            12'h100: s_bvalid = periph_bvalid;  // Response from Peripherals
            default: s_bvalid = 1'b0;           // No response for invalid address
        endcase
    end

    // =======================================================================
    // 2. READ CHANNEL ROUTING - FSM Based
    // =======================================================================
    // We use a State Machine for reads to latch the target slave.
    // This ensures that even if the CPU changes the address bus while waiting
    // for data (latency), we still route the response from the correct slave.
    
    typedef enum logic [1:0] { 
        RD_IDLE, 
        RD_IRAM, 
        RD_DRAM, 
        RD_PERIPH 
    } rd_state_t;

    rd_state_t rd_state;
    logic [31:0] latched_araddr;

    // --- State Logic ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_state       <= RD_IDLE;
            latched_araddr <= 0;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    // Wait for new Read Request
                    if (s_arvalid) begin
                        latched_araddr <= s_araddr; // Capture Address
                        
                        // Decode Address and transition to specific Slave State
                        case (s_araddr[31:20])
                            12'h001: rd_state <= RD_IRAM;
                            12'h002: rd_state <= RD_DRAM;
                            12'h100: rd_state <= RD_PERIPH;
                            default: rd_state <= RD_IDLE; // Ignore invalid address
                        endcase
                    end
                end
                
                default: begin
                    // Wait for Slave to provide Data (Handshake Complete)
                    // If 'rvalid' and 'rready' are both high, transaction is done.
                    if (s_rvalid && s_rready) begin
                        rd_state <= RD_IDLE;
                    end
                end
            endcase
        end
    end

    // --- Output Logic: Address Phase ---
    // Ready to accept new address only when IDLE
    assign s_arready = (rd_state == RD_IDLE);

    always_comb begin
        // Default: No requests active
        iram_arvalid   = 0; iram_araddr   = latched_araddr;
        dram_arvalid   = 0; dram_araddr   = latched_araddr;
        periph_arvalid = 0; periph_araddr = latched_araddr;

        // Assert 'arvalid' only to the active slave based on state
        case (rd_state)
            RD_IRAM:   iram_arvalid   = 1;
            RD_DRAM:   dram_arvalid   = 1;
            RD_PERIPH: periph_arvalid = 1;
        endcase
    end

    // --- Output Logic: Data Phase ---
    always_comb begin
        s_rvalid = 0; s_rdata = 0;
        iram_rready = 0; dram_rready = 0; periph_rready = 0;

        // Route Data/Valid from Active Slave to Master
        // Route Ready from Master to Active Slave
        case (rd_state)
            RD_IRAM: begin 
                s_rvalid    = iram_rvalid; 
                s_rdata     = iram_rdata; 
                iram_rready = s_rready; 
            end
            RD_DRAM: begin 
                s_rvalid    = dram_rvalid; 
                s_rdata     = dram_rdata; 
                dram_rready = s_rready; 
            end
            RD_PERIPH: begin 
                s_rvalid    = periph_rvalid; 
                s_rdata     = periph_rdata; 
                periph_rready = s_rready; 
            end
        endcase
    end

endmodule