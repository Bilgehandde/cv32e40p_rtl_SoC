`timescale 1ns / 1ps

module axi_gpio (
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
    input  logic [3:0]  s_wstrb,   // Unused in simple GPIO (assume full word write)

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
    
    // =======================================================================
    // EXTERNAL IO PINS
    // =======================================================================
    input  logic [15:0] gpio_in,  // Switches
    output logic [15:0] gpio_out  // LEDs
);

    // Internal Register for Output (LEDs)
    logic [15:0] gpio_reg;
    assign gpio_out = gpio_reg;

    // =======================================================================
    // "ALWAYS READY" LOGIC
    // =======================================================================
    // Strategy: We are fast enough to accept any request in a single cycle.
    // Asserting Ready constantly simplifies the handshake state machine.
    assign s_awready = 1'b1;
    assign s_wready  = 1'b1;
    assign s_arready = 1'b1;

    // =======================================================================
    // WRITE CHANNEL LOGIC
    // =======================================================================
    logic bvalid_reg;
    assign s_bvalid = bvalid_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_reg   <= 16'h0000;
            bvalid_reg <= 1'b0;
        end else begin
            // Write Transaction Start
            // Condition: Address Valid AND Data Valid AND We haven't responded yet
            if (s_awvalid && s_wvalid && !bvalid_reg) begin
                
                // Address Decoding (Offset based)
                // 0x4: Output Data Register
                if (s_awaddr[3:0] == 4'h4) begin
                    gpio_reg <= s_wdata[15:0];
                end
                
                // Assert Response Valid (Transaction Accepted)
                bvalid_reg <= 1'b1;
            end 
            
            // Handshake Completion
            // Condition: We asserted Valid AND Master asserted Ready
            else if (bvalid_reg && s_bready) begin
                bvalid_reg <= 1'b0; // Deassert Valid
            end
        end
    end

    // =======================================================================
    // READ CHANNEL LOGIC
    // =======================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_rdata  <= 32'b0;
            s_rvalid <= 1'b0;
        end else begin
            // Read Transaction Start
            // Condition: Address Valid AND We haven't responded yet
            if (s_arvalid && !s_rvalid) begin
                s_rvalid <= 1'b1; // Data is ready
                
                // Address Decoding
                case (s_araddr[3:0])
                    4'h0: s_rdata <= {16'b0, gpio_in};  // Offset 0: Read Input (Switches)
                    4'h4: s_rdata <= {16'b0, gpio_reg}; // Offset 4: Read Output (LED State)
                    default: s_rdata <= 32'b0;
                endcase
            end 
            
            // Handshake Completion
            // Condition: We asserted Valid AND Master asserted Ready
            else if (s_rvalid && s_rready) begin
                s_rvalid <= 1'b0; // Deassert Valid
            end
        end
    end

endmodule