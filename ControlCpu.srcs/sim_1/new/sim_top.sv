`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/23/2022 11:06:24 AM
// Design Name: 
// Module Name: sim_top
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


module sim_top(

    );

logic clock, nReset;
logic debug;

assign nReset = 1;

wire    [1:0]   ddr3_dqs_p;
wire    [1:0]   ddr3_dqs_n;
wire    [15:0]  ddr3_dq;

top top_module(.board_clock(clock), .nReset(nReset), .uart_output(1'b0), .debug(debug), .ddr3_dqs_p(ddr3_dqs_p), .ddr3_dqs_n(ddr3_dqs_n), .ddr3_dq(ddr3_dq));

ddr3_model ddr(
    .rst_n      (top_module.ddr3_reset_n),
    .ck         (top_module.ddr3_ck_p),
    .ck_n       (top_module.ddr3_ck_n),
    .cke        (top_module.ddr3_cke),
    .cs_n       (1'b0),
    .ras_n      (top_module.ddr3_ras_n),
    .cas_n      (top_module.ddr3_cas_n),
    .we_n       (top_module.ddr3_we_n),
    .dm_tdqs    (top_module.ddr3_dm),
    .ba         (top_module.ddr3_ba),
    .addr       (top_module.ddr3_addr),
    .dq         (ddr3_dq),
    .dqs        (ddr3_dqs_p),
    .dqs_n      (ddr3_dqs_n),
    .tdqs_n     (),
    .odt        (top_module.ddr3_odt)
);

typedef enum logic[3:0] {
    MRS = 4'b0000,
    REF = 4'b0001,
    PRE = 4'b0010,
    ACT = 4'b0011,
    WR  = 4'b0100,
    RD  = 4'b0101,
    NOP = 4'b0111,
    ZQC = 4'b0110
} DdrCmd;
DdrCmd ddr_cmd;

always_comb
    $cast( ddr_cmd, {1'b0 ,top_module.ddr3_ras_n ,top_module.ddr3_cas_n ,top_module.ddr3_we_n} );

/*
ddr3 ddr(
    .rst_n      (top_module.ddr3_reset_n),
    .ck         (top_module.ddr3_ck_p),
    .ck_n       (top_module.ddr3_ck_n),
    .cke        (top_module.ddr3_cke),
    .cs_n       (0),
    .ras_n      (top_module.ddr3_ras_n),
    .we_n       (top_module.ddr3_we_n),
    .dm_tdqs    (top_module.ddr3_dm),
    .ba         (top_module.ddr3_ba),
    .addr       (top_module.ddr3_addr),
    .dq         (ddr3_dq),
    .dqs        (ddr3_dqs_p),
    .dqs_n      (ddr3_dqs_n),
    .tdqs_n     (),
    .odt        (top_module.ddr3_odt)
);
*/

initial begin
    clock = 0;
    forever
    begin
        #10 clock = 1;
        #10 clock = 0;
    end
end

endmodule
