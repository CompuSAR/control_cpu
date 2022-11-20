`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/27/2022 04:45:40 PM
// Design Name: 
// Module Name: io_block
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module io_block(
    input clock,

    input [31:0] address,
    input address_valid,
    input write,
    input [31:0] data_in,
    output logic [31:0] data_out,
    input enable,
    output logic req_ack,
    output logic rsp_ready,

    output logic passthrough_sram_enable,
    input passthrough_sram_req_ack,
    input passthrough_sram_rsp_ready,
    input [31:0] passthrough_sram_data,

    output logic passthrough_ddr_enable,
    input passthrough_ddr_req_ack,
    input passthrough_ddr_rsp_ready,
    input [31:0] passthrough_ddr_data,

    output uart_tx,
    input uart_rx
    );

logic [31:0] previous_address;
logic previous_valid;

always_ff@(posedge clock) begin
    previous_address <= address;
    previous_valid <= address_valid;
end

logic uart_send_data_ready;

uart_send#(.ClockDivider(868)) // 115,200 BAUD at 100Mhz clock
uart_output(
    .clock(clock),
    .data_in(data_in[7:0]),
    .data_in_ready(uart_send_data_ready),

    .out_bit(uart_tx)
);

task default_state();
    uart_send_data_ready = 1'b0;
    req_ack = 1'b1;
    rsp_ready = 1'b1;
endtask

always_comb begin
    default_state();

    // Current cycle analysis
    passthrough_sram_enable = 1'b0;
    passthrough_ddr_enable = 1'b0;
    req_ack = 1'bX;
    if( !address[31] ) begin
        passthrough_ddr_enable = address_valid;
        req_ack = passthrough_ddr_req_ack;
    end else if( !address[30] ) begin
        passthrough_sram_enable = address_valid;
        req_ack = passthrough_sram_req_ack;
    end else begin
        case( address[19:0] )
            20'h0: begin                // UART
                if( write ) begin
                    req_ack = uart_output.receive_ready;
                    uart_send_data_ready = 1'b1;
                end else begin
                    req_ack = 1;        // XXX No UART receive yet
                end
            end
        endcase
    end

    // Previous cycle analysis
    rsp_ready = 1'bX;
    data_out = 32'bX;
    if( previous_valid ) begin
        if( !previous_address[31] ) begin
            data_out = passthrough_ddr_data;
            rsp_ready = passthrough_ddr_rsp_ready;
        end else if( !previous_address[30] ) begin
            data_out = passthrough_sram_data;
            rsp_ready = passthrough_sram_rsp_ready;
        end else begin
            case( previous_address[19:0] )
                20'h0: begin                // UART
                    if( write ) begin
                    end else begin
                        data_out = 32'b0;
                        rsp_ready = 1'b1;
                    end
                end
            endcase
        end
    end
end

endmodule
