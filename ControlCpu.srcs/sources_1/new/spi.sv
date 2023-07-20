`timescale 1ns / 1ps

module spi_ctrl#(
    parameter MEM_DATA_WIDTH = 32
)
(
    // Control interface
    input                       cpu_clock_i,
    input                       spi_ref_clock_i,
    output                      irq,

    output logic[3:0]           debug,

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
    output [MEM_DATA_WIDTH-1:0] dma_cmd_data_o,
    output logic                dma_cmd_write_o,
    input                       dma_cmd_ack_i,

    input                       dma_rsp_valid_i,
    input [MEM_DATA_WIDTH-1:0]  dma_rsp_data_i
);

localparam MEM_DATA_WIDTH_BYTES = MEM_DATA_WIDTH/8;

logic spi_clk_enable;

assign debug[0] = spi_clk_o;
assign debug[1] = spi_cs_n_o;
assign debug[2] = spi_clk_enable;
assign debug[3] = spi_dq_i[1];

BUFGCE spi_clock_buf(
    .O(spi_clk_o),
    .I(spi_ref_clock_i),
    .CE(spi_clk_enable)
);

// SPI commands scan the bytes LSB but the bits in the byte MSB, so we need to
// shuffle the bits around a bit.
logic [MEM_DATA_WIDTH-1:0] dma_cmd_data_mixed, dma_rsp_data_mixed;

reg [31:0] cpu_dma_addr_send, cpu_dma_addr_recv, cpu_num_send_cycles, cpu_num_recv_cycles, cpu_transfer_mode;
reg [31:0] spi_num_send_cycles, spi_num_recv_cycles, spi_transfer_mode;
reg cpu_transaction_active = 1'b0, spi_transaction_active = 1'b0;

wire cpu_qspi_state = cpu_transfer_mode[16];
logic spi_qspi_state = 1'bX;

xpm_cdc_array_single#(
    .WIDTH(32),
    .SIM_ASSERT_CHK(1)
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

logic [MEM_DATA_WIDTH-1:0]      cpu_dma_write_data;
logic                           cpu_dma_write_valid, spi_dma_write_valid = 1'b0;
logic                           cpu_dma_write_ack = 1'b0, spi_dma_write_ack;

logic [15:0]                    spi_dummy_counter = 0;
logic [31:0]                    cpu_send_counter = 0, spi_send_counter = 0, cpu_recv_counter = 0, spi_recv_counter = 0;
logic [$clog2(MEM_DATA_WIDTH):0] spi_shift_fill = 0;
wire spi_shift_fill_empty = spi_shift_fill==0;

wire cpu_send_idle = !cpu_dma_read_valid && !cpu_dma_read_ack;

xpm_cdc_handshake#(
    .DEST_EXT_HSK(1),
    .WIDTH(MEM_DATA_WIDTH),
    .SIM_ASSERT_CHK(1)
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
    .src_in(spi_recv_buffer),
    .src_send(spi_dma_write_valid),
    .src_rcv(spi_dma_write_ack),

    .dest_clk(cpu_clock_i),
    .dest_out(cpu_dma_write_data),
    .dest_req(cpu_dma_write_valid),
    .dest_ack(cpu_dma_write_ack)
);

task set_invalid_state();
endtask

wire[31:0] num_send_bits = cpu_qspi_state ? cpu_num_send_cycles * 4 : cpu_num_send_cycles;
wire[31:0] num_recv_bits = cpu_qspi_state ? cpu_num_recv_cycles * 4 : cpu_num_recv_cycles;
logic[31:0] rounded_send_bits, rounded_recv_bits;
assign rounded_send_bits = num_send_bits + (MEM_DATA_WIDTH - 1);
assign rounded_recv_bits = num_recv_bits + (MEM_DATA_WIDTH - 1);

task start_transaction();
    cpu_transaction_active <= 1'b1;

    cpu_send_counter <= rounded_send_bits[31:$clog2(MEM_DATA_WIDTH)];
    cpu_recv_counter <= rounded_recv_bits[31:$clog2(MEM_DATA_WIDTH)];
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
        // DMA read in progress
        data_buffer <= dma_rsp_data_mixed;
        data_buffer_full <= 1'b1;
        cpu_send_counter <= cpu_send_counter-1;
        cpu_dma_addr_send <= cpu_dma_addr_send + MEM_DATA_WIDTH_BYTES;
        dma_read_in_progress <= 1'b0;
    end

    if( dma_cmd_valid_o && dma_cmd_write_o && dma_cmd_ack_i ) begin
        // DMA write sent
        cpu_dma_addr_recv <= cpu_dma_addr_recv + MEM_DATA_WIDTH_BYTES;
    end

    if( data_buffer_full && cpu_send_idle )
        cpu_dma_read_valid <= 1'b1;

    if( data_buffer_full && cpu_dma_read_valid && cpu_dma_read_ack )
        data_buffer_full <= 1'b0;

    if( dma_cmd_valid_o && dma_cmd_write_o && dma_cmd_ack_i ) begin
        cpu_dma_write_ack <= 1'b1;
        cpu_dma_addr_send <= cpu_dma_addr_send + MEM_DATA_WIDTH_BYTES;
        cpu_recv_counter <= cpu_recv_counter - 1;
    end

    if( cpu_transaction_active && cpu_send_counter==0 && cpu_recv_counter==0 )
        cpu_transaction_active <= 1'b0;
end

always_comb begin
    spi_clk_enable = 1'b0;

    if( spi_transaction_active ) begin
        if( spi_send_counter!=0 ) begin
            // In send stage of transaction
            if( spi_shift_fill!=0 )
                spi_clk_enable = 1'b1;
        end else begin
            // In recv stage of transaction
            if( spi_shift_fill!=MEM_DATA_WIDTH )
                spi_clk_enable = 1'b1;
        end
    end
end

always_comb begin
    dma_read_in_progress_next = dma_read_in_progress;
    dma_cmd_valid_o = 1'b0;
    dma_cmd_data_mixed = { MEM_DATA_WIDTH{1'bX} };
    dma_cmd_write_o = 1'bX;
    dma_cmd_address_o = 32'bX;

    if( cpu_transaction_active ) begin
        if( cpu_send_counter>0 ) begin
            // DMA read
            if( !data_buffer_full ) begin
                if( cpu_send_idle && !dma_read_in_progress ) begin
                    dma_cmd_valid_o = 1'b1;
                    dma_cmd_address_o = cpu_dma_addr_send;
                    dma_cmd_write_o = 1'b0;

                    if( dma_cmd_ack_i )
                        dma_read_in_progress_next = 1'b1;
                end
            end
        end else begin
            // DMA write
            if( cpu_dma_write_valid && !cpu_dma_write_ack ) begin
                dma_cmd_valid_o = 1'b1;
                dma_cmd_write_o = 1'b1;
                dma_cmd_data_mixed = cpu_dma_write_data;
                dma_cmd_address_o = cpu_dma_addr_recv;
            end
        end
    end
end

logic[MEM_DATA_WIDTH-1:0] spi_send_shift_buffer, spi_recv_shift_buffer, spi_recv_buffer;
logic spi_recv_buffer_loaded = 1'b0;

wire spi_recv_buffer_reset = 1'b0; // !spi_recv_buffer_loaded && spi_recv_buffer_loaded_next;
wire spi_send_buffer_load = spi_dma_read_valid && !spi_dma_read_ack && spi_shift_fill_empty;

logic [3:0] spi_dq_o, spi_dq_i;
logic spi_dq_dir = 1'b1;

IOBUF dq0_buffer(.T(spi_qspi_state ? spi_dq_dir : 1'b0), .I(spi_dq_o[0]), .O(spi_dq_i[0]), .IO(spi_dq_io[0]));
IOBUF dq1_buffer(.T(spi_qspi_state ? spi_dq_dir : 1'b1), .I(spi_dq_o[1]), .O(spi_dq_i[1]), .IO(spi_dq_io[1]));
IOBUF dq2_buffer(.T(spi_qspi_state ? spi_dq_dir : 1'b0), .I(spi_qspi_state ? spi_dq_o[2] : 1'b1), .O(spi_dq_i[2]), .IO(spi_dq_io[2]));
IOBUF dq3_buffer(.T(spi_qspi_state ? spi_dq_dir : 1'b0), .I(spi_qspi_state ? spi_dq_o[3] : 1'b1), .O(spi_dq_i[3]), .IO(spi_dq_io[3]));

always_ff@(negedge spi_ref_clock_i) begin
    spi_cs_n_o <= !spi_transaction_active;
    spi_dq_dir <= spi_send_counter>0 ? 1'b0 : 1'b1;

    spi_dq_o <= spi_send_shift_buffer[3:0];
end

genvar i, j;
generate

// Remix bits: Pure LSB to mixed LSByte-MSbit
for( i=0; i<MEM_DATA_WIDTH_BYTES; i+=1 ) begin
    for( j=0; j<8; j++ ) begin
        // Send data shifts down and needs the bits in each byte reversed
        assign dma_rsp_data_mixed[i*8+7-j] = dma_rsp_data_i[i*8+j];
        // Recv data shifts up, and needs the byte order reversed
        assign dma_cmd_data_o[i*8+j] = dma_cmd_data_mixed[(MEM_DATA_WIDTH_BYTES-i-1)*8+j];
    end
end

// Shift down send buffer
for( i=0; i<MEM_DATA_WIDTH-5; i++ ) begin : read_shift_gen
    always_ff@(posedge spi_ref_clock_i) begin
        if( spi_clk_enable ) begin
            if( spi_qspi_state )
                spi_send_shift_buffer[i] <= spi_send_shift_buffer[i+4];
            else
                spi_send_shift_buffer[i] <= spi_send_shift_buffer[i+1];
        end

        if( spi_send_buffer_load )
            spi_send_shift_buffer[i] <= spi_dma_read_data[i];
    end
end : read_shift_gen

for( i=MEM_DATA_WIDTH-5; i<MEM_DATA_WIDTH-1; i++ ) begin : read_shift_gen_h
    always_ff@(posedge spi_ref_clock_i) begin
        if( spi_clk_enable ) begin
            if( spi_qspi_state )
                spi_send_shift_buffer[i] <= 1'bX;
            else
                spi_send_shift_buffer[i] <= spi_send_shift_buffer[i+1];
        end

        if( spi_send_buffer_load )
            spi_send_shift_buffer[i] <= spi_dma_read_data[i];
    end
end : read_shift_gen_h

always_ff@(posedge spi_ref_clock_i) begin
    if( spi_clk_enable )
        spi_send_shift_buffer[MEM_DATA_WIDTH-1] <= 1'bX;

    if( spi_send_buffer_load )
        spi_send_shift_buffer[MEM_DATA_WIDTH-1] <= spi_dma_read_data[MEM_DATA_WIDTH-1];
end

// Shift up recv buffer
always_ff@(posedge spi_ref_clock_i) begin
    if( spi_clk_enable ) begin
        if( spi_qspi_state )
            spi_recv_shift_buffer[0] <= spi_dq_i[0];
        else
            spi_recv_shift_buffer[0] <= spi_dq_i[1];
    end
end

for( i=1; i<4; i++ ) begin
    always_ff@(posedge spi_ref_clock_i) begin
        if( spi_clk_enable ) begin
            if( spi_qspi_state ) begin
                // 4 bit SPI mode
                spi_recv_shift_buffer[i] <= spi_dq_i[i];
            end else begin
                // Single bit SPI mode
                if( spi_recv_buffer_reset )
                    spi_recv_shift_buffer[i] <= 1'b0;
                else
                    spi_recv_shift_buffer[i] <= spi_recv_shift_buffer[i-1];
            end
        end
    end
end

for( i=4; i<MEM_DATA_WIDTH; i++ ) begin
    always_ff@(posedge spi_ref_clock_i) begin
        if( spi_clk_enable) begin
            if( spi_qspi_state )
                spi_recv_shift_buffer[i] <= spi_recv_shift_buffer[i-4];
            else
                spi_recv_shift_buffer[i] <= spi_recv_shift_buffer[i-1];

            if( spi_recv_buffer_reset )
                spi_recv_shift_buffer[i] <= 1'b0;
        end
    end
end

endgenerate

task send_buffer_from_cpu(input new_transaction);
    if( new_transaction )
        spi_shift_fill <= spi_num_send_cycles<MEM_DATA_WIDTH ? spi_num_send_cycles : MEM_DATA_WIDTH;
    else
        spi_shift_fill <= spi_send_counter<MEM_DATA_WIDTH ? spi_send_counter : MEM_DATA_WIDTH;
    spi_dma_read_ack <= 1'b1;
endtask

task recv_buffer_to_cpu();
    if( !spi_recv_buffer_loaded ) begin
        spi_recv_buffer <= spi_recv_shift_buffer;
        spi_recv_buffer_loaded <= 1'b1;
        buffer_loaded_while_with_no_cdc_ack:
            assert( !spi_dma_write_ack )
            else
                $error("%m check failed");
        spi_dma_write_valid <= 1'b1;
        spi_shift_fill <= 0;
    end else begin
        // Backpressure
    end
endtask

always_ff@(posedge spi_ref_clock_i) begin
    if( !spi_dma_read_valid && spi_dma_read_ack )
        spi_dma_read_ack <= 1'b0;

    if( !spi_transaction_active ) begin
        // No active transaction
        if( spi_shift_fill>0 ) begin
            // Still have data from previous transaction
            recv_buffer_to_cpu();
        end else if( spi_dma_read_valid && !spi_dma_read_ack ) begin
            // New transaction started
            spi_send_counter <= spi_num_send_cycles; // Must send at least one bit
            spi_recv_counter <= spi_num_recv_cycles;
            spi_dummy_counter <= spi_transfer_mode[15:0];
            spi_qspi_state <= spi_transfer_mode[16];

            spi_transaction_active <= 1'b1;

            send_buffer_from_cpu(1'b1);
        end
    end else begin
        // Transaction active
        if( spi_send_counter>0 ) begin
            // Send stage of request
            if( spi_shift_fill_empty ) begin
                if( spi_dma_read_valid && !spi_dma_read_ack ) begin
                    spi_send_counter <= spi_send_counter;
                    send_buffer_from_cpu(1'b0);
                end
            end else begin
                // Send tick
                spi_shift_fill <= spi_shift_fill-1;
                spi_send_counter <= spi_send_counter-1;
            end
        end else if( spi_dummy_counter>0 ) begin
            // Dummy tick
            spi_dummy_counter <= spi_dummy_counter-1;
        end else if( spi_recv_counter>0 ) begin
            // Recv stage of request
            if( spi_shift_fill==MEM_DATA_WIDTH || spi_recv_counter==0 )
                recv_buffer_to_cpu();
            else if( spi_clk_enable ) begin
                spi_recv_counter <= spi_recv_counter-1;
                spi_shift_fill <= spi_shift_fill+1;
            end

            if( spi_recv_counter==1 )
                spi_transaction_active <= 1'b0;
        end else begin
            // All done
            if( spi_shift_fill>0 )
                recv_buffer_to_cpu();

            spi_transaction_active <= 1'b0;
        end
    end

    if( spi_recv_buffer_loaded ) begin
        if( spi_dma_write_ack ) begin
            // Our last CDC finished
            spi_recv_buffer_loaded <= 1'b0;
            spi_dma_write_valid <= 1'b0;
        end else begin
            // Start a new CDC
            spi_dma_write_valid <= 1'b1;
        end
    end
end

endmodule
