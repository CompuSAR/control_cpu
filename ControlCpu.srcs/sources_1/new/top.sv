`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/22/2022 06:24:17 PM
// Design Name: 
// Module Name: top
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


module top(
    input board_clock,
    input reset,
    output logic running
    );

function convert_byte_write( logic we, logic[2:0] address, logic[1:0] size );
    if( we ) begin
        logic[3:0] mask;
        case(size)
            0: mask = 4'b0001;
            1: mask = 4'b0011;
            2: mask = 4'b1111;
            3: mask = 4'b0000;
        endcase

        convert_byte_write = mask<<address;
    end else
        convert_byte_write = 0;
endfunction

logic ctrl_cpu_clock, clocks_locked;
clk_converter clocks(.clk_in1(board_clock), .reset(reset), .clk_out1(ctrl_cpu_clock), .locked(clocks_locked) );

logic           ctrl_iBus_cmd_valid;
logic           ctrl_iBus_cmd_ready;
logic [31:0]    ctrl_iBus_cmd_payload_pc;
logic           ctrl_iBus_rsp_valid;
logic           ctrl_iBus_rsp_payload_error;
logic [31:0]    ctrl_iBus_rsp_payload_inst;

logic           ctrl_dBus_cmd_valid;
logic           ctrl_dBus_cmd_ready;
logic           ctrl_dBus_cmd_payload_wr;
logic [31:0]    ctrl_dBus_cmd_payload_address;
logic [31:0]    ctrl_dBus_cmd_payload_data;
logic [1:0]     ctrl_dBus_cmd_payload_size;
logic           ctrl_dBus_rsp_ready;
logic           ctrl_dBus_rsp_error;
logic [31:0]    ctrl_dBus_rsp_data;

logic           ctrl_timer_interrupt;
logic           ctrl_interrupt;
logic           ctrl_software_interrupt;


VexRiscv control_cpu(
    .iBus_cmd_valid(ctrl_iBus_cmd_valid),
    .iBus_cmd_ready(ctrl_iBus_cmd_ready),
    .iBus_cmd_payload_pc(ctrl_iBus_cmd_payload_pc),
    .iBus_rsp_valid(ctrl_iBus_rsp_valid),
    .iBus_rsp_payload_error(ctrl_iBus_rsp_payload_error),
    .iBus_rsp_payload_inst(ctrl_iBus_rsp_payload_inst),

    .dBus_cmd_valid(ctrl_dBus_cmd_valid),
    .dBus_cmd_ready(ctrl_dBus_cmd_ready),
    .dBus_cmd_payload_wr(ctrl_dBus_cmd_payload_wr),
    .dBus_cmd_payload_address(ctrl_dBus_cmd_payload_address),
    .dBus_cmd_payload_data(ctrl_dBus_cmd_payload_data),
    .dBus_cmd_payload_size(ctrl_dBus_cmd_payload_size),
    .dBus_rsp_ready(ctrl_dBus_rsp_ready),
    .dBus_rsp_error(ctrl_dBus_rsp_error),
    .dBus_rsp_data(ctrl_dBus_rsp_data),

    .clk(ctrl_cpu_clock),
    .reset(reset & clocks_locked),

    .timerInterrupt(0),
    .externalInterrupt(0),
    .softwareInterrupt(0)
);

assign ctrl_iBus_cmd_ready = 1;
assign ctrl_iBus_rsp_valid = 1;
assign ctrl_iBus_rsp_payload_error = 0;
assign ctrl_dBus_cmd_ready = 1;
assign ctrl_dBus_rsp_ready = 1;
assign ctrl_dBus_rsp_error = 0;

blk_mem memory(
    .addra( ctrl_dBus_cmd_payload_address[15:3] ),
    .clka( ctrl_cpu_clock),
    .dina( ctrl_dBus_cmd_payload_data ),
    .douta( ctrl_dBus_rsp_data ),
    .ena( ctrl_dBus_cmd_valid ),
    .wea( convert_byte_write(ctrl_dBus_cmd_payload_wr, ctrl_dBus_cmd_payload_address, ctrl_dBus_cmd_payload_size) ),

    .addrb( ctrl_iBus_cmd_payload_pc[15:3] ),
    .clkb( ctrl_cpu_clock ),
    .dinb( 32'hX ),
    .doutb( ctrl_iBus_rsp_payload_inst ),
    .enb( ctrl_iBus_cmd_valid ),
    .web( 0 )
);

assign running = ctrl_dBus_cmd_valid;

endmodule
