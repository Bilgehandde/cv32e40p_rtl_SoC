`timescale 1ns / 1ps

module axi_timer (
    input  logic clk,
    input  logic rst_n,

    // =======================================================================
    // AXI SLAVE INTERFACE
    // =======================================================================
    // Write Address
    input  logic [31:0] s_awaddr, 
    input  logic        s_awvalid, 
    output logic        s_awready, // Always Ready

    // Write Data
    input  logic [31:0] s_wdata,  
    input  logic        s_wvalid,
    output logic        s_wready,  // Always Ready
    input  logic [3:0]  s_wstrb,

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
    input  logic        s_rready
);

    // =======================================================================
    // INTERNAL REGISTERS
    // =======================================================================
    logic [31:0] reg_ctrl;     // Bit 0: Enable, Bit 1: Reset
    logic [31:0] reg_count;    // 32-bit Counter Value
    logic [31:0] reg_prescale; // Prescaler Value (Reserved for future use)

    // =======================================================================
    // "ALWAYS READY" LOGIC
    // =======================================================================
    assign s_awready = 1'b1;
    assign s_wready  = 1'b1;
    assign s_arready = 1'b1;

    // =======================================================================
    // TIMER LOGIC (Core Functionality)
    // =======================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_count <= 32'b0;
        end else begin
            // Reset takes priority
            if (reg_ctrl[1]) begin 
                reg_count <= 32'b0;
            end 
            // Count Up if Enabled
            else if (reg_ctrl[0]) begin 
                reg_count <= reg_count + 1;
            end
        end
    end

    // =======================================================================
    // WRITE CHANNEL LOGIC
    // =======================================================================
    logic bvalid_reg;
    assign s_bvalid = bvalid_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_ctrl     <= 32'b0;
            reg_prescale <= 32'b0;
            bvalid_reg   <= 1'b0;
        end else begin
            // Start Write Transaction
            if (s_awvalid && s_wvalid && !bvalid_reg) begin
                
                // Address Decoding
                case (s_awaddr[3:0])
                    4'h0: reg_ctrl     <= s_wdata; // Control Register
                    4'h8: reg_prescale <= s_wdata; // Prescale Register
                endcase
                
                bvalid_reg <= 1'b1;
            end 
            
            // Complete Write Transaction
            else if (bvalid_reg && s_bready) begin
                bvalid_reg <= 1'b0;
                
                // Self-Clearing Reset Logic:
                // If reset bit was set, clear it immediately after transaction
                reg_ctrl[1] <= 1'b0; 
            end
        end
    end

    // =======================================================================
    // READ CHANNEL LOGIC
    // =======================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_rvalid <= 1'b0;
            s_rdata  <= 32'b0;
        end else begin
            // Start Read Transaction
            if (s_arvalid && !s_rvalid) begin
                s_rvalid <= 1'b1;
                
                // Address Decoding
                case (s_araddr[3:0])
                    4'h0: s_rdata <= reg_ctrl;     // Read Control Status
                    4'h4: s_rdata <= reg_count;    // Read Current Count
                    4'h8: s_rdata <= reg_prescale; // Read Prescaler
                    default: s_rdata <= 32'b0;
                endcase
            end 
            
            // Complete Read Transaction
            else if (s_rvalid && s_rready) begin
                s_rvalid <= 1'b0;
            end
        end
    end

endmodule