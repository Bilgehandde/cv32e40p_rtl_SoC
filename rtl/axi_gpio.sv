`timescale 1ns / 1ps

module axi_gpio (
    input  logic clk, input logic rst_n,
    input  logic [31:0] s_awaddr, input logic s_awvalid, output logic s_awready,
    input  logic [31:0] s_wdata,  input logic s_wvalid,  output logic s_wready,
    output logic        s_bvalid, input logic s_bready,
    input  logic [31:0] s_araddr, input logic s_arvalid, output logic s_arready,
    output logic [31:0] s_rdata,  output logic s_rvalid, input logic s_rready,
    input  logic [15:0] gpio_in, output logic [15:0] gpio_out
);
    logic [15:0] reg_odr;
    assign s_awready = 1'b1; assign s_wready = 1'b1; assign s_arready = 1'b1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin reg_odr <= 16'b0; s_bvalid <= 1'b0; end
        else begin
            if (s_awvalid && s_wvalid) begin
                if (s_awaddr[3:0] == 4'h04) reg_odr <= s_wdata[15:0];
                s_bvalid <= 1'b1;
            end else if (s_bready) s_bvalid <= 1'b0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin s_rvalid <= 1'b0; s_rdata <= 32'b0; end
        else begin
            if (s_arvalid) begin
                s_rvalid <= 1'b1;
                case (s_araddr[3:0])
                    4'h00: s_rdata <= {16'b0, gpio_in};
                    4'h04: s_rdata <= {16'b0, reg_odr};
                    default: s_rdata <= 32'b0;
                endcase
            end else if (s_rready) s_rvalid <= 1'b0;
        end
    end
    assign gpio_out = reg_odr;
endmodule