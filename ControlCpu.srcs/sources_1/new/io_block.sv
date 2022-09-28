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

    output logic passthrough_enable,
    input passthrough_req_ack,
    input passthrough_rsp_ready,
    input [31:0] passthrough_data,

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

uart_send#(.ClockDivider(1302)) // 115,200 BAUD at 150Mhz clock
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
    if( !address_valid ) begin
        req_ack = 1'bX;
        passthrough_enable = 1'b0;
    end else if( !address[31] ) begin
        passthrough_enable = address_valid;
        req_ack = passthrough_req_ack;
    end else begin
        passthrough_enable = 1'b0;
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
    if( !previous_valid ) begin
        rsp_ready = 1'bX;
    end else begin
        if( !previous_address[31] ) begin
            data_out = passthrough_data;
            rsp_ready = passthrough_rsp_ready;
        end else begin
            data_out = 32'b0;

            case( address )
                32'h0: begin                // UART
                    if( write ) begin
                    end else begin
                    end
                end
            endcase
        end
    end
end

endmodule
