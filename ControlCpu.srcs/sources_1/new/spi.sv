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

    output reg                  ctrl_rsp_valid_o,
    output reg[31:0]            ctrl_rsp_data_o,

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

reg [31:0] dma_addr_send, dma_addr_recv, num_send_bytes, num_recv_bytes, transfer_mode;
reg active_transaction = 1'b0;

task start_transaction();
    active_transaction <= 1'b1;
endtask

task wait_transaction();
    ctrl_rsp_data_o <= 32'b0;
endtask

assign ctrl_cmd_ack_o = !active_transaction;

always_ff@(cpu_clock_i) begin
    ctrl_rsp_valid_o <= 1'b0;

    if( ctrl_cmd_valid_i && ctrl_cmd_ack_o ) begin
        if( ctrl_cmd_write_i ) begin
            // Write
            case( ctrl_cmd_address_i )
                16'h0000: start_transaction();
                16'h0004: dma_addr_send <= ctrl_cmd_data_i;
                16'h0008: num_send_bytes <= ctrl_cmd_data_i;
                16'h000c: dma_addr_recv <= ctrl_cmd_data_i;
                16'h0010: num_recv_bytes <= ctrl_cmd_data_i;
                16'h0014: transfer_mode <= ctrl_cmd_data_i;
            endcase
        end else begin
            // Read
            ctrl_rsp_valid_o <= 1'b1;
            case( ctrl_cmd_address_i )
                16'h0000: wait_transaction();
                16'h0004: ctrl_rsp_data_o <= dma_addr_send;
                16'h0008: ctrl_rsp_data_o <= num_send_bytes;
                16'h000c: ctrl_rsp_data_o <= dma_addr_recv;
                16'h0010: ctrl_rsp_data_o <= num_recv_bytes;
                16'h0014: ctrl_rsp_data_o <= transfer_mode;
            endcase
        end
    end
end

endmodule
