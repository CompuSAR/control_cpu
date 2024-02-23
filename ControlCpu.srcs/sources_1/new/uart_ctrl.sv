`timescale 1ns / 1ps

module uart_ctrl#(
    parameter ClockDivider = 50
)
(
    input clock,

    input [15:0] req_addr_i,
    input req_valid_i,
    input req_write_i,
    input [31:0] req_data_i,
    output req_ack_o,

    output logic rsp_valid_o,
    output logic[31:0] rsp_data_o,

    output logic intr_send_ready_o,

    output uart_tx,
    input uart_rx
);

localparam REG_UART_DATA        = 16'h0000;
localparam REG_UART_STATUS      = 16'h0004;

assign req_ack_o = intr_send_ready_o || req_addr_i!=16'h0;

logic [7:0] uart_send_data;
logic uart_send_data_ready = 1'b0;

uart_send#(.ClockDivider(ClockDivider))
uart_send(
    .clock(clock),
    .data_in(uart_send_data),
    .data_in_ready(uart_send_data_ready),
    
    .out_bit(uart_tx),
    .receive_ready(intr_send_ready_o)
);

always_ff@(posedge clock) begin
    uart_send_data_ready <= 1'b0;
    rsp_valid_o <= 1'b0;
    rsp_data_o <= 32'hXXXXXXXX;

    if( req_ack_o && req_valid_i ) begin
        // We have a control request
        if( req_write_i ) begin
            // Write
            case( req_addr_i )
                REG_UART_DATA: begin
                    uart_send_data_ready <= 1'b1;
                    uart_send_data <= req_data_i;
                end
            endcase
        end else begin
            rsp_valid_o <= 1'b1;
            // Read
            case( req_addr_i )
                REG_UART_STATUS: rsp_data_o <= { {31{1'b0}}, intr_send_ready_o };
                default: rsp_data_o <= 32'hXXXXXXXX;
            endcase
        end
    end
end

endmodule
