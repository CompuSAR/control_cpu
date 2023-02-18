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


module io_block#(
    parameter CLOCK_HZ = 50000000
)
(
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
    input [31:0] passthrough_ddr_data,

    output logic passthrough_ddr_ctrl_enable,
    input passthrough_ddr_ctrl_req_ack,
    input passthrough_ddr_ctrl_rsp_ready,
    input [31:0] passthrough_ddr_ctrl_data,

    output logic passthrough_gpio_enable,
    input passthrough_gpio_req_ack,
    input passthrough_gpio_rsp_ready,
    input [31:0] passthrough_gpio_rsp_data,

    output logic passthrough_irq_enable,
    input passthrough_irq_req_ack,
    input passthrough_irq_rsp_ready,
    input [31:0] passthrough_irq_rsp_data,

    output uart_tx,
    input uart_rx
    );

logic [31:0] previous_address, previous_address_next;
logic previous_valid=1'b0;

always_ff@(posedge clock) begin
    previous_address <= previous_address_next;

    if( previous_valid && !rsp_ready )
        // Previous cycle still waiting for response. Don't advance.
        previous_valid <= 1'b1;
    else if( address_valid && req_ack )
        previous_valid = !write;
    else
        previous_valid = 1'b0;
end

logic uart_send_data_ready;

uart_send#(.ClockDivider(CLOCK_HZ/115200)) // 115,200 BAUD at 100Mhz clock
uart_output(
    .clock(clock),
    .data_in(data_in[7:0]),
    .data_in_ready(uart_send_data_ready),

    .out_bit(uart_tx)
);

task default_state_current();
    uart_send_data_ready = 1'b0;
    req_ack = 1'b1;
    previous_address_next = address;

    passthrough_ddr_enable = 1'b0;
    passthrough_ddr_ctrl_enable = 1'b0;
    passthrough_sram_enable = 1'b0;
    passthrough_gpio_enable = 1'b0;
    passthrough_irq_enable = 1'b0;
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
    // Previous cycle analysis
    rsp_ready = 1'bX;
    data_out = 32'bX;

    if( previous_valid ) begin
        if( is_ddr(previous_address) ) begin
            data_out = passthrough_ddr_data;
            rsp_ready = passthrough_ddr_rsp_ready;
        end else if( is_sram(previous_address) ) begin
            data_out = passthrough_sram_data;
            rsp_ready = passthrough_sram_rsp_ready;
        end else begin
            case( previous_address[23:16] )
                8'h0: begin                     // UART
                    rsp_ready = 1'b1;
                    data_out = 32'b0;
                end
                8'h1: begin                     // DDR control
                    rsp_ready = 1'b1;
                    data_out = passthrough_ddr_ctrl_data;
                end
                8'h2: begin                     // GPIO
                    rsp_ready = passthrough_gpio_rsp_ready;
                    data_out = passthrough_gpio_rsp_data;
                end
                8'h3: begin                     // Interrupt controller
                    rsp_ready = passthrough_irq_rsp_ready;
                    data_out = passthrough_irq_rsp_data;
                end
            endcase
        end
    end
end

always_comb begin
    default_state_current();

    // Current cycle analysis
    if( previous_valid && !rsp_ready ) begin
        // Previous cycle still waiting for response. Don't advance.
        previous_address_next = previous_address;
        req_ack = 1'b0;
    end else begin
        if( is_ddr(address) ) begin
            passthrough_ddr_enable = address_valid;
            req_ack = passthrough_ddr_req_ack;
        end else if( is_sram(address) ) begin
            passthrough_sram_enable = address_valid;
            req_ack = passthrough_sram_req_ack;
        end else if(address_valid) begin
            case( address[23:16] )
                8'h0: begin                // UART
                    if( write ) begin
                        req_ack = uart_output.receive_ready;
                        uart_send_data_ready = 1'b1;
                    end else begin
                        req_ack = 1;        // XXX No UART receive yet
                    end
                end
                8'h1: begin                // DDR control
                    passthrough_ddr_ctrl_enable = 1'b1;
                    req_ack = 1'b1;
                end
                8'h2: begin                 // GPIO
                    passthrough_gpio_enable = 1'b1;
                    req_ack = passthrough_gpio_req_ack;
                end
                8'h3: begin                 // Interrupt/timer controller
                    passthrough_irq_enable = 1'b1;
                    req_ack = passthrough_irq_req_ack;
                end
            endcase
        end
    end
end

endmodule
