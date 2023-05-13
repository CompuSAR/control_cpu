`timescale 1ns / 1ps

module spi_ctrl#(
    parameter MEM_DATA_WIDTH = 32
)
(
    // Control interface
    input                       cpu_clock_i,
    input                       spi_ref_clock_i,
    output                      irq,

    input                       ctrl_cmd_valid_i,
    input [15:0]                ctrl_cmd_address_i,
    input [31:0]                ctrl_cmd_data_i,
    input                       ctrl_cmd_write_i,
    output                      ctrl_cmd_ack_o,

    output                      ctrl_rsp_valid_o,
    output [31:0]               ctrl_rsp_data_o,

    // SPI interface
    output                      spi_cs_n_o,
    inout [3:0]                 spi_dq_io,
    output                      spi_clk_o,

    // DMA interface
    output                      dma_cmd_valid_o,
    output [31:0]               dma_cmd_address_o,
    output [MEM_DATA_WIDTH-1:0] dma_cmd_data_o,
    output                      dma_cmd_write_o,
    input                       dma_cmd_ack_i,

    input                       dma_rsp_valid_i,
    input [MEM_DATA_WIDTH-1:0]  dma_rsp_data_i
);

assign ctrl_cmd_ack_o = 1'b0;
assign ctrl_rsp_valid_o = 1'b0;

assign dma_cmd_valid_o = 1'b0;

endmodule
