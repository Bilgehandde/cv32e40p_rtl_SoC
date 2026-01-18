`timescale 1ns / 1ps

module axi_checker (
    input logic clk,
    input logic rst_n,
    
    // =======================================================================
    // READ CHANNELS
    // =======================================================================
    input logic [31:0] araddr,
    input logic        arvalid,
    input logic        arready,
    
    input logic [31:0] rdata,
    input logic        rvalid,
    input logic        rready,

    // =======================================================================
    // WRITE CHANNELS
    // =======================================================================
    input logic [31:0] awaddr,
    input logic        awvalid,
    input logic        awready,
    
    input logic [31:0] wdata,
    input logic        wvalid,
    input logic        wready,
    
    input logic        bvalid,
    input logic        bready
);

    // =======================================================================
    // 1. UNKNOWN STATE (X) CHECK
    // =======================================================================
    // Protocol Violation Check: Control signals must never be X during reset/operation.
    property p_no_x_on_valid;
        @(posedge clk) disable iff (!rst_n)
        !$isunknown(arvalid) && !$isunknown(rvalid) && 
        !$isunknown(awvalid) && !$isunknown(wvalid) && !$isunknown(bvalid);
    endproperty
    
    ASSERT_NO_X: assert property (p_no_x_on_valid)
        else $error("[%t] ERROR: X state detected on AXI Valid signals!", $time);

    // =======================================================================
    // 2. TIMEOUT (DEADLOCK) CHECK
    // =======================================================================
    // If a handshake waits too long, something is broken (e.g., Slave not mapped).
    integer wait_count_ar = 0;
    integer wait_count_aw = 0;
    integer wait_count_w  = 0;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            wait_count_ar <= 0; 
            wait_count_aw <= 0; 
            wait_count_w  <= 0;
        end else begin
            // --- READ ADDRESS TIMEOUT ---
            // Valid is high, but Ready is low for >100 cycles
            if (arvalid && !arready) begin
                wait_count_ar <= wait_count_ar + 1;
                if (wait_count_ar > 100) begin
                    $error("[%t] CRITICAL ERROR: READ ADDRESS TIMEOUT! (Slave not responding). Addr: %h", $time, araddr);
                    $stop;
                end
            end else begin
                wait_count_ar <= 0;
            end

            // --- WRITE ADDRESS TIMEOUT ---
            if (awvalid && !awready) begin
                wait_count_aw <= wait_count_aw + 1;
                if (wait_count_aw > 100) begin
                    $error("[%t] CRITICAL ERROR: WRITE ADDRESS TIMEOUT! (Slave not responding). Addr: %h", $time, awaddr);
                    $stop;
                end
            end else begin
                wait_count_aw <= 0;
            end

            // --- WRITE DATA TIMEOUT ---
            if (wvalid && !wready) begin
                wait_count_w <= wait_count_w + 1;
                if (wait_count_w > 100) begin
                    $error("[%t] CRITICAL ERROR: WRITE DATA TIMEOUT! (Slave not accepting data). Data: %h", $time, wdata);
                    $stop;
                end
            end else begin
                wait_count_w <= 0;
            end
        end
    end

    // =======================================================================
    // 3. TRANSACTION LOGGING (CONSOLE OUTPUT)
    // =======================================================================
    // Prints transaction details to the Tcl Console for easy debugging.
    always @(posedge clk) begin
        if (rst_n) begin
            // --- READ LOGGING ---
            if (arvalid && arready)
                $display("[%t] [READ  REQ] -> Read Request : Addr=%h", $time, araddr);
            
            if (rvalid && rready)
                $display("[%t] [READ  DAT] <- Read Data    : Data=%h", $time, rdata);

            // --- WRITE LOGGING ---
            if (awvalid && awready)
                $display("[%t] [WRITE REQ] -> Write Request: Addr=%h", $time, awaddr);
            
            if (wvalid && wready)
                $display("[%t] [WRITE DAT] -> Write Data   : Data=%h", $time, wdata);
            
            if (bvalid && bready)
                $display("[%t] [WRITE RSP] <- Write Done (Response OK)", $time);
        end
    end

endmodule