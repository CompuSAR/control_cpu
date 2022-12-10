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
    output logic req_ack,
    output logic rsp_ready,

    output logic passthrough_sram_enable,
    input passthrough_sram_req_ack,
    input passthrough_sram_rsp_ready,
    input [31:0] passthrough_sram_data,

    output logic passthrough_ddr_enable,
    input passthrough_ddr_req_ack,
    input passthrough_ddr_rsp_ready,
    input [63:0] passthrough_ddr_data,

    output uart_tx,
    input uart_rx,

    input [31:0] gpio_in,

    output logic [31:0] ddr_ctrl_out = 0,
    input [31:0] ddr_ctrl_in
    );

logic [31:0] previous_address, previous_address_next;
logic previous_valid=0, previous_valid_next, previous_write;

logic [31:0] ddr_ctrl_out_next;

always_ff@(posedge clock) begin
    previous_address <= previous_address_next;
    previous_valid <= previous_valid_next;
    previous_write <= write;

    ddr_ctrl_out <= ddr_ctrl_out_next;
end

logic uart_send_data_ready;

uart_send#(.ClockDivider(723)) // 115,200 BAUD at 83.3333Mhz clock
uart_output(
    .clock(clock),
    .data_in(data_in[7:0]),
    .data_in_ready(uart_send_data_ready),

    .out_bit(uart_tx)
);

task default_state_previous();
    rsp_ready = 1'b1;
endtask

task default_state_current();
    uart_send_data_ready = 1'b0;
    req_ack = 1'b1;
    previous_address_next = address;
    previous_valid_next = address_valid;

    ddr_ctrl_out_next = ddr_ctrl_out;
endtask

function logic is_ddr(logic [31:0]address);
    is_ddr = address[31] == 0;
endfunction

function logic is_sram(logic [31:0]address);
    is_sram = address[31:30] == 2'b10;
endfunction

function logic is_io(logic [31:0]address);
    is_io = address[31:30] == 2'b11;
endfunction

always_comb begin
    default_state_previous();

    // Previous cycle analysis
    rsp_ready = 1'bX;
    data_out = 32'bX;

    if( previous_valid ) begin
        if( is_ddr(previous_address) ) begin
            data_out = previous_address[4] ? passthrough_ddr_data[63:32] : passthrough_ddr_data[31:0];
            rsp_ready = passthrough_ddr_rsp_ready;
        end else if( is_sram(previous_address) ) begin
            data_out = passthrough_sram_data;
            rsp_ready = passthrough_sram_rsp_ready;
        end else begin
            case( previous_address[19:0] )
                20'h0: begin                // UART
                    rsp_ready = 1'b1;
                    if( !previous_write ) begin
                        data_out = 32'b0;
                    end
                end
                20'h10000: begin            // DDR control
                    rsp_ready = 1'b1;
                    if( !previous_write ) begin
                        data_out = ddr_ctrl_in;
                    end
                end
                20'h20000: begin        // GPIO
                    rsp_ready = 1'b1;
                    if( !previous_write ) begin
                        data_out = gpio_in;
                    end
                end
                20'h30000: begin        // HALT
                    rsp_ready = 1'b0;
                end
            endcase
        end
    end
end

always_comb begin
    default_state_current();

    // Current cycle analysis
    if( previous_valid && !rsp_ready && !previous_write ) begin
        previous_valid_next = 1'b1;
        previous_address_next = previous_address;
        req_ack = 1'b0;
    end

    if( is_ddr(address) ) begin
        passthrough_ddr_enable = address_valid;
        req_ack = passthrough_ddr_req_ack;
    end else if( is_sram(address) ) begin
        passthrough_sram_enable = address_valid;
        req_ack = passthrough_sram_req_ack;
    end else if(address_valid) begin
        case( address[19:0] )
            20'h0: begin                // UART
                if( write ) begin
                    req_ack = uart_output.receive_ready;
                    uart_send_data_ready = 1'b1;
                end else begin
                    req_ack = 1;        // XXX No UART receive yet
                end
            end
            20'h10000: begin            // DDR control
                if( write ) begin
                    req_ack = 1'b1;
                    ddr_ctrl_out_next = data_in;
                end else begin
                    req_ack = 1'b1;
                end
            end
            20'h20000: begin        // GPIO
                req_ack = 1'b1;
            end
            20'h30000: begin        // HALT
                req_ack = 1'b0;
            end
        endcase
    end
end

endmodule
