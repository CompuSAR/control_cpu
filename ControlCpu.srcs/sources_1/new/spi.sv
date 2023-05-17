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

    output logic                ctrl_rsp_valid_o,
    output logic[31:0]          ctrl_rsp_data_o,

    // SPI interface
    output logic                spi_cs_n_o,
    inout [3:0]                 spi_dq_io,
    output                      spi_clk_o,

    // DMA interface
    output logic                dma_cmd_valid_o,
    output logic[31:0]          dma_cmd_address_o,
    output logic[MEM_DATA_WIDTH-1:0] dma_cmd_data_o,
    output logic                dma_cmd_write_o,
    input                       dma_cmd_ack_i,

    input                       dma_rsp_valid_i,
    input [MEM_DATA_WIDTH-1:0]  dma_rsp_data_i
);

logic spi_clk_enable = 1'b1;

BUFGCE spi_clock_buf(
    .O(spi_clk_o),
    .I(spi_ref_clock_i),
    .CE(spi_clk_enable)
);

assign dma_cmd_valid_o = 1'b0;

reg [31:0] cpu_dma_addr_send, cpu_dma_addr_recv, cpu_num_send_cycles, cpu_num_recv_cycles, cpu_transfer_mode;
reg [31:0] spi_num_send_cycles, spi_num_recv_cycles, spi_transfer_mode;
reg cpu_transaction_active = 1'b0, spi_transaction_active = 1'b0;

xpm_cdc_array_single#(
    .WIDTH(32)
) cdc_num_send_cycles(
    .src_clk(cpu_clock_i),
    .src_in(cpu_num_send_cycles),

    .dest_clk(spi_ref_clock_i),
    .dest_out(spi_num_send_cycles)
), cdc_num_recv_cycles(
    .src_clk(cpu_clock_i),
    .src_in(cpu_num_recv_cycles),

    .dest_clk(spi_ref_clock_i),
    .dest_out(spi_num_recv_cycles)
), cdc_transfer_mode(
    .src_clk(cpu_clock_i),
    .src_in(cpu_transfer_mode),

    .dest_clk(spi_ref_clock_i),
    .dest_out(spi_transfer_mode)
);

logic [MEM_DATA_WIDTH-1:0]      cpu_dma_read_data, spi_dma_read_data;
logic                           cpu_dma_read_valid = 1'b0, spi_dma_read_valid;
logic                           cpu_dma_read_ack, spi_dma_read_ack = 1'b0;

logic [MEM_DATA_WIDTH-1:0]      cpu_dma_write_data, spi_dma_write_data;
logic                           cpu_dma_write_valid, spi_dma_write_valid = 1'b0;
logic                           cpu_dma_write_ack = 1'b0, spi_dma_write_ack;

logic [15:0]                    spi_dummy_counter = 0;
logic [31:0]                    cpu_send_counter = 0, spi_send_counter = 0, cpu_recv_counter = 0, spi_recv_counter = 0;
logic [$clog2(MEM_DATA_WIDTH)-1:0] spi_shift_fill = 0;

xpm_cdc_handshake#(
    .DEST_EXT_HSK(1),
    .SIM_ASSERT_CHK(1),
    .WIDTH(MEM_DATA_WIDTH)
) cdc_dma_read_info(
    .src_clk(cpu_clock_i),
    .src_in(cpu_dma_read_data),
    .src_send(cpu_dma_read_valid),
    .src_rcv(cpu_dma_read_ack),

    .dest_clk(spi_ref_clock_i),
    .dest_out(spi_dma_read_data),
    .dest_req(spi_dma_read_valid),
    .dest_ack(spi_dma_read_ack)
), cdc_dma_write_info(
    .src_clk(spi_ref_clock_i),
    .src_in(spi_dma_write_data),
    .src_send(spi_dma_write_valid),
    .src_rcv(spi_dma_write_ack),

    .dest_clk(cpu_clock_i),
    .dest_out(cpu_dma_write_data),
    .dest_req(cpu_dma_write_valid),
    .dest_ack(cpu_dma_write_ack)
);

task set_invalid_state();
endtask

wire[31:0] num_send_bits = qspi_state ? cpu_num_send_cycles * 4 : cpu_num_send_cycles;
wire[31:0] rounded_send_bits = num_send_bits + MEM_DATA_WIDTH - 1;
task start_transaction();
    cpu_transaction_active <= 1'b1;

    cpu_send_counter <= rounded_send_bits[31:$clog2(MEM_DATA_WIDTH)];
    cpu_recv_counter <= cpu_num_recv_cycles;
endtask

task wait_transaction();
    ctrl_rsp_data_o <= 32'b0;
endtask

assign ctrl_cmd_ack_o = !cpu_transaction_active;

logic dma_read_in_progress = 1'b0, dma_read_in_progress_next;
logic [MEM_DATA_WIDTH-1:0] data_buffer;
logic data_buffer_full = 1'b0;

assign cpu_dma_read_data = data_buffer;

always_ff@(posedge cpu_clock_i) begin
    ctrl_rsp_valid_o <= 1'b0;

    if( ctrl_cmd_valid_i && ctrl_cmd_ack_o ) begin
        if( ctrl_cmd_write_i ) begin
            // Write
            case( ctrl_cmd_address_i )
                16'h0000: start_transaction();
                16'h0004: cpu_dma_addr_send <= ctrl_cmd_data_i;
                16'h0008: cpu_num_send_cycles <= ctrl_cmd_data_i;
                16'h000c: cpu_dma_addr_recv <= ctrl_cmd_data_i;
                16'h0010: cpu_num_recv_cycles <= ctrl_cmd_data_i;
                16'h0014: cpu_transfer_mode <= ctrl_cmd_data_i;
                default: set_invalid_state();
            endcase
        end else begin
            // Read
            ctrl_rsp_valid_o <= 1'b1;
            case( ctrl_cmd_address_i )
                16'h0000: wait_transaction();
                16'h0004: ctrl_rsp_data_o <= cpu_dma_addr_send;
                16'h0008: ctrl_rsp_data_o <= cpu_num_send_cycles;
                16'h000c: ctrl_rsp_data_o <= cpu_dma_addr_recv;
                16'h0010: ctrl_rsp_data_o <= cpu_num_recv_cycles;
                16'h0014: ctrl_rsp_data_o <= cpu_transfer_mode;
                default: set_invalid_state();
            endcase
        end
    end

    if( cpu_dma_read_valid && cpu_dma_read_ack )
        cpu_dma_read_valid <= 1'b0;

    if( cpu_dma_write_ack && !cpu_dma_write_valid )
        cpu_dma_write_ack <= 1'b0;

    dma_read_in_progress <= dma_read_in_progress_next;

    if( dma_read_in_progress && dma_rsp_valid_i ) begin
        data_buffer <= dma_rsp_data_i;
        data_buffer_full <= 1'b1;
        cpu_send_counter <= cpu_send_counter-1;
        cpu_dma_addr_send <= cpu_dma_addr_send + MEM_DATA_WIDTH/8;
        dma_read_in_progress <= 1'b0;
    end

    if( data_buffer_full && !cpu_dma_read_valid && !cpu_dma_read_ack )
        cpu_dma_read_valid <= 1'b1;

    if( data_buffer_full && cpu_dma_read_valid && cpu_dma_read_ack )
        data_buffer_full <= 1'b0;
end

always_comb begin
    dma_read_in_progress_next = dma_read_in_progress;
    dma_cmd_valid_o = 1'b0;
    dma_cmd_data_o = { MEM_DATA_WIDTH{1'bX} };
    dma_cmd_write_o = 1'bX;

    if( cpu_transaction_active ) begin
        if( cpu_send_counter>0 ) begin
            if( !data_buffer_full ) begin
                if( !dma_read_in_progress ) begin
                    dma_cmd_valid_o = 1'b1;
                    dma_cmd_address_o = cpu_dma_addr_send;
                    dma_cmd_write_o = 1'b0;

                    if( dma_cmd_ack_i )
                        dma_read_in_progress_next = 1'b1;
                end
            end
        end
    end
end

logic[MEM_DATA_WIDTH-1:0] spi_shift_buffer;

wire qspi_state = spi_transfer_mode[16];

logic [3:0] spi_dq_o, spi_dq_i;
logic spi_dq_dir = 1'b1;

assign spi_dq_o = spi_shift_buffer[3:0];
IOBUF dq0_buffer(.T(qspi_state ? spi_dq_dir : 1'b0), .I(spi_dq_o[0]), .O(spi_dq_i[0]), .IO(spi_dq_io[0]));
IOBUF dq1_buffer(.T(qspi_state ? spi_dq_dir : 1'b1), .I(spi_dq_o[1]), .O(spi_dq_i[1]), .IO(spi_dq_io[1]));
IOBUF dq2_buffer(.T(qspi_state ? spi_dq_dir : 1'b0), .I(qspi_state ? spi_dq_o[2] : 1'b1), .O(spi_dq_i[2]), .IO(spi_dq_io[2]));
IOBUF dq3_buffer(.T(qspi_state ? spi_dq_dir : 1'b0), .I(qspi_state ? spi_dq_o[3] : 1'b1), .O(spi_dq_i[3]), .IO(spi_dq_io[3]));

always_ff@(negedge spi_ref_clock_i) begin
    spi_cs_n_o <= !spi_transaction_active;
    spi_dq_dir <= spi_send_counter>0 ? 1'b0 : 1'b1;
end

genvar i;
generate

for( i=0; i<MEM_DATA_WIDTH-5; i++ ) begin : read_shift_gen
    always_ff@(negedge spi_ref_clock_i) begin
        if( spi_clk_enable ) begin
            if( qspi_state )
                spi_shift_buffer[i] <= spi_shift_buffer[i+4];
            else
                spi_shift_buffer[i] <= spi_shift_buffer[i+1];
        end

        if( spi_dma_read_valid && !spi_dma_read_ack && spi_shift_fill==0 )
            spi_shift_buffer[i] <= spi_dma_read_data[i];
    end
end : read_shift_gen

for( i=MEM_DATA_WIDTH-5; i<MEM_DATA_WIDTH-1; i++ ) begin : read_shift_gen_h
    always_ff@(negedge spi_ref_clock_i) begin
        if( spi_clk_enable ) begin
            if( qspi_state )
                spi_shift_buffer[i] <= 1'b0;
            else
                spi_shift_buffer[i] <= spi_shift_buffer[i+1];
        end

        if( spi_dma_read_valid && !spi_dma_read_ack && spi_shift_fill==0 )
            spi_shift_buffer[i] <= spi_dma_read_data[i];
    end
end : read_shift_gen_h

always_ff@(negedge spi_ref_clock_i) begin
    if( spi_clk_enable )
        spi_shift_buffer[MEM_DATA_WIDTH-1] <= 1'b0;

    if( spi_dma_read_valid && !spi_dma_read_ack && spi_shift_fill==0 )
        spi_shift_buffer[MEM_DATA_WIDTH-1] <= spi_dma_read_data[MEM_DATA_WIDTH-1];
end

endgenerate

task send_buffer_from_cpu(input new_transaction);
    if( new_transaction )
        spi_shift_fill <= spi_num_send_cycles<MEM_DATA_WIDTH ? spi_num_send_cycles : MEM_DATA_WIDTH;
    else
        spi_shift_fill <= spi_send_counter<MEM_DATA_WIDTH ? spi_send_counter : MEM_DATA_WIDTH;
    spi_dma_read_ack <= 1'b1;
    spi_clk_enable <= 1'b1;
endtask

task recv_buffer_to_cpu();
    if( !spi_dma_write_ack ) begin
        spi_dma_write_valid <= 1'b1;
        spi_shift_fill <= 0;
        spi_clk_enable <= 1'b1;
    end else
        spi_clk_enable <= 1'b0;
endtask

always_ff@(posedge spi_ref_clock_i) begin
    if( !spi_dma_read_valid && spi_dma_read_ack )
        spi_dma_read_ack <= 1'b0;
    if( spi_dma_write_valid && spi_dma_write_ack )
        spi_dma_write_valid <= 1'b1;

    if( !spi_transaction_active ) begin
        // No active transaction
        if( spi_shift_fill>0 ) begin
            // Still have data from previous transaction
            recv_buffer_to_cpu();
        end else if( spi_dma_read_valid && !spi_dma_read_ack ) begin
            // New transaction started
            spi_send_counter <= spi_num_send_cycles - 1; // Must send at least one bit
            spi_recv_counter <= spi_num_recv_cycles;
            spi_dummy_counter <= spi_transfer_mode[15:0];

            spi_transaction_active <= 1'b1;

            send_buffer_from_cpu(1'b1);
        end
    end else begin
        if( spi_send_counter>0 ) begin
            // Send stage of request
            if( spi_shift_fill==0 ) begin
                if( spi_dma_read_valid && !spi_dma_read_ack )
                    send_buffer_from_cpu(1'b0);
                else
                    // Buffer underrun. Stop the clock
                    spi_clk_enable <= 1'b0;
            end else begin
                spi_shift_fill <= spi_shift_fill-1;
                spi_send_counter <= spi_send_counter-1;
            end
        end else if( spi_dummy_counter>0 ) begin
            spi_dummy_counter <= spi_dummy_counter-1;
        end else if( spi_recv_counter>0 ) begin
            if( spi_shift_fill==MEM_DATA_WIDTH || spi_recv_counter==0 )
                recv_buffer_to_cpu();
        end else begin
            // All done
            if( spi_shift_fill>0 )
                recv_buffer_to_cpu();

            spi_transaction_active <= 1'b0;
        end
    end
end

endmodule
