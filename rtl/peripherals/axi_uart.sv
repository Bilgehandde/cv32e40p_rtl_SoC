`timescale 1ns / 1ps

module axi_uart (
    input  logic clk,
    input  logic rst_n,

    // =======================================================================
    // AXI4-LITE SLAVE INTERFACE
    // =======================================================================
    // Write Address
    input  logic [31:0] s_awaddr, 
    input  logic        s_awvalid, 
    output logic        s_awready, // Always Ready

    // Write Data
    input  logic [31:0] s_wdata,  
    input  logic        s_wvalid,  
    output logic        s_wready,  // Always Ready

    // Write Response
    output logic        s_bvalid, 
    input  logic        s_bready,

    // Read Address
    input  logic [31:0] s_araddr, 
    input  logic        s_arvalid, 
    output logic        s_arready, // Always Ready

    // Read Data
    output logic [31:0] s_rdata,  
    output logic        s_rvalid, 
    input  logic        s_rready,
    
    // Unused Strobe
    input  logic [3:0]  s_wstrb,

    // =======================================================================
    // PHYSICAL UART PINS
    // =======================================================================
    input  logic rx, // Serial Input
    output logic tx  // Serial Output
);

    // =======================================================================
    // INTERNAL REGISTERS
    // =======================================================================
    logic [31:0] reg_clk_div;     // Clock Divider for Baud Rate
    logic [7:0]  rx_data;         // Received Byte
    logic        rx_valid_flag;   // Flag: New data available
    logic        tx_busy_flag;    // Flag: Transmit in progress
    logic        tx_start;        // Pulse to start transmission
    logic [7:0]  tx_data_latched; // Data to be transmitted

    // "Always Ready" Logic
    assign s_awready = 1'b1;
    assign s_wready  = 1'b1;
    assign s_arready = 1'b1;

    // =======================================================================
    // AXI WRITE LOGIC (CPU -> UART)
    // =======================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_clk_div     <= 32'd434; // Default: 115200 baud @ 50MHz
            tx_start        <= 1'b0;
            tx_data_latched <= 8'b0;
            s_bvalid        <= 1'b0;
        end else begin
            tx_start <= 1'b0; // Default: No pulse
            
            // Start Write Transaction
            if (s_awvalid && s_wvalid) begin
                case (s_awaddr[3:0])
                    // Offset 0x00: Transmit Data
                    4'h0: begin 
                        if (!tx_busy_flag) begin
                            tx_data_latched <= s_wdata[7:0];
                            tx_start        <= 1'b1; // Trigger TX FSM
                        end
                    end
                    // Offset 0x08: Clock Divider
                    4'h8: reg_clk_div <= s_wdata; 
                endcase
                s_bvalid <= 1'b1;
            end 
            // Complete Write Transaction
            else if (s_bready) begin
                s_bvalid <= 1'b0;
            end
        end
    end

    // =======================================================================
    // AXI READ LOGIC (UART -> CPU)
    // =======================================================================
    logic rx_done_tick; // Signal from RX FSM indicating new byte

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_rvalid      <= 1'b0;
            s_rdata       <= 32'b0;
            rx_valid_flag <= 1'b0; 
        end else begin
            // Update Valid Flag if new data arrived from wire
            if (rx_done_tick) rx_valid_flag <= 1'b1;

            // Start Read Transaction
            if (s_arvalid) begin
                s_rvalid <= 1'b1;
                case (s_araddr[3:0])
                    // Offset 0x00: Read Received Data
                    4'h0: begin 
                        s_rdata       <= {24'b0, rx_data}; 
                        rx_valid_flag <= 1'b0; // Clear flag on read
                    end
                    // Offset 0x04: Status Register
                    // Bit 0: TX Busy, Bit 1: RX Valid
                    4'h4: s_rdata <= {30'b0, rx_valid_flag, tx_busy_flag};
                    // Offset 0x08: Read Divider
                    4'h8: s_rdata <= reg_clk_div;
                    default: s_rdata <= 32'b0;
                endcase
            end 
            // Complete Read Transaction
            else if (s_rready) begin
                s_rvalid <= 1'b0;
            end
        end
    end

    // =======================================================================
    // UART TRANSMIT (TX) LOGIC
    // =======================================================================
    logic [15:0] tx_cnt;     // Baud rate counter
    logic [3:0]  tx_bit_idx; // Bit index (0-9)
    logic [9:0]  tx_shifter; // Shift register (Start + Data + Stop)

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_busy_flag <= 1'b0;
            tx           <= 1'b1; // Idle High
            tx_cnt       <= 0;
            tx_bit_idx   <= 0;
        end else begin
            // Start Transmission
            if (tx_start && !tx_busy_flag) begin
                tx_busy_flag <= 1'b1;
                // Frame: Stop(1) + Data(8) + Start(0) -> LSB shifted out first
                tx_shifter   <= {1'b1, tx_data_latched, 1'b0};
                tx_cnt       <= 0;
                tx_bit_idx   <= 0;
            end 
            // Shift Bits
            else if (tx_busy_flag) begin
                if (tx_cnt < reg_clk_div[15:0]) begin
                    tx_cnt <= tx_cnt + 1;
                end else begin
                    tx_cnt <= 0;
                    tx     <= tx_shifter[tx_bit_idx]; // Output LSB
                    
                    if (tx_bit_idx < 9) begin
                        tx_bit_idx <= tx_bit_idx + 1;
                    end else begin
                        tx_busy_flag <= 1'b0; // Done
                        tx           <= 1'b1; // Return to Idle
                    end
                end
            end
        end
    end

    // =======================================================================
    // UART RECEIVE (RX) LOGIC
    // =======================================================================
    logic [15:0] rx_cnt;
    logic [3:0]  rx_bit_idx;
    logic        rx_busy;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_busy      <= 1'b0;
            rx_cnt       <= 0;
            rx_bit_idx   <= 0;
            rx_data      <= 0;
            rx_done_tick <= 0;
        end else begin
            rx_done_tick <= 0; // Default low

            if (!rx_busy) begin
                // Detect Start Bit (Falling Edge)
                if (rx == 1'b0) begin 
                    rx_busy    <= 1'b1;
                    rx_cnt     <= 0;
                    rx_bit_idx <= 0;
                end
            end else begin
                if (rx_cnt < reg_clk_div[15:0]) begin
                    rx_cnt <= rx_cnt + 1;
                end else begin
                    rx_cnt <= 0;
                    
                    // Sample Data (Skip Start Bit at index 0)
                    if (rx_bit_idx == 0) begin 
                        // Start bit sampled (middle)
                    end else if (rx_bit_idx <= 8) begin 
                        rx_data[rx_bit_idx-1] <= rx; 
                    end
                    
                    if (rx_bit_idx < 9) begin
                         rx_bit_idx <= rx_bit_idx + 1;
                    end else begin
                         rx_busy      <= 1'b0;
                         rx_done_tick <= 1'b1; // Signal byte received
                    end
                end
            end
        end
    end

endmodule