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

wire spi_ref_clock_p, spi_ref_clock_n, pll_feedback;
PLLE2_BASE#(
    .CLKFBOUT_MULT(16),
    .CLKFBOUT_PHASE(0),
    .CLKIN1_PERIOD(20), // 50 Mhz
    .CLKOUT0_DIVIDE(16),
    .CLKOUT0_PHASE(0),
    .CLKOUT1_DIVIDE(16),
    .CLKOUT1_PHASE(180)
) clock_alignment(
    .CLKIN1(spi_ref_clock_i),
    .CLKFBIN(pll_feedback),
    .RST(1'b0),
    .PWRDWN(1'b0),

    .CLKOUT0(spi_ref_clock_p),
    .CLKOUT1(spi_ref_clock_n),

    .CLKFBOUT(pll_feedback)
);

/*********************************************************************************
* CPU clock logic
*********************************************************************************/

// SPI commands scan the bytes LSB but the bits in the byte MSB, so we need to
// shuffle the bits around a bit.
logic [MEM_DATA_WIDTH-1:0] dma_cmd_data_mixed, dma_rsp_data_mixed;

reg [31:0] cpu_dma_addr_send, cpu_dma_addr_recv, cpu_num_send_cycles, cpu_num_recv_cycles, cpu_transfer_mode;
reg [31:0] spi_num_send_cycles, spi_num_recv_cycles, spi_transfer_mode;
reg cpu_transaction_active = 1'b0;

wire cpu_qspi_state = cpu_transfer_mode[16];

xpm_cdc_array_single#(
    .WIDTH(32),
    .SIM_ASSERT_CHK(1)
) cdc_num_send_cycles(
    .src_clk(cpu_clock_i),
    .src_in(cpu_num_send_cycles),

    .dest_clk(spi_ref_clock_p),
    .dest_out(spi_num_send_cycles)
), cdc_num_recv_cycles(
    .src_clk(cpu_clock_i),
    .src_in(cpu_num_recv_cycles),

    .dest_clk(spi_ref_clock_p),
    .dest_out(spi_num_recv_cycles)
), cdc_transfer_mode(
    .src_clk(cpu_clock_i),
    .src_in(cpu_transfer_mode),

    .dest_clk(spi_ref_clock_p),
    .dest_out(spi_transfer_mode)
);

logic [MEM_DATA_WIDTH-1:0]      cpu_dma_read_data, spi_dma_read_data;
logic                           cpu_dma_read_valid = 1'b0, spi_dma_read_valid;
logic                           cpu_dma_read_ack, spi_dma_read_ack = 1'b0;

logic [MEM_DATA_WIDTH-1:0]      cpu_dma_write_data;
logic                           cpu_dma_write_valid, spi_dma_write_valid = 1'b0;
logic                           cpu_dma_write_ack = 1'b0, spi_dma_write_ack;

logic [31:0]                    cpu_send_counter = 0, cpu_recv_counter = 0;

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

    .dest_clk(spi_ref_clock_p),
    .dest_out(spi_dma_read_data),
    .dest_req(spi_dma_read_valid),
    .dest_ack(spi_dma_read_ack)
), cdc_dma_write_info(
    .src_clk(spi_ref_clock_p),
    .src_in(spi_shift_buffer),
    .src_send(spi_dma_write_valid),
    .src_rcv(spi_dma_write_ack),

    .dest_clk(cpu_clock_i),
    .dest_out(cpu_dma_write_data),
    .dest_req(cpu_dma_write_valid),
    .dest_ack(cpu_dma_write_ack)
);

task cpu_set_invalid_state();
endtask

wire[31:0] cpu_num_send_bits = cpu_qspi_state ? cpu_num_send_cycles * 4 : cpu_num_send_cycles;
wire[31:0] cpu_num_recv_bits = cpu_qspi_state ? cpu_num_recv_cycles * 4 : cpu_num_recv_cycles;
logic[31:0] cpu_rounded_send_bits, cpu_rounded_recv_bits;
assign cpu_rounded_send_bits = cpu_num_send_bits + (MEM_DATA_WIDTH - 1);
assign cpu_rounded_recv_bits = cpu_num_recv_bits + (MEM_DATA_WIDTH - 1);

task start_transaction();
    cpu_transaction_active <= 1'b1;

    cpu_send_counter <= cpu_rounded_send_bits[31:$clog2(MEM_DATA_WIDTH)];
    cpu_recv_counter <= cpu_rounded_recv_bits[31:$clog2(MEM_DATA_WIDTH)];
endtask

task wait_transaction();
    ctrl_rsp_data_o <= 32'b0;
endtask

assign ctrl_cmd_ack_o = !cpu_transaction_active;

logic cpu_dma_read_in_progress = 1'b0, cpu_dma_read_in_progress_next;
logic [MEM_DATA_WIDTH-1:0] cpu_data_buffer;
logic cpu_data_buffer_full = 1'b0;

assign cpu_dma_read_data = cpu_data_buffer;

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
                default: cpu_set_invalid_state();
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
            endcase
        end
    end

    if( cpu_dma_read_valid && cpu_dma_read_ack )
        cpu_dma_read_valid <= 1'b0;

    if( cpu_dma_write_ack && !cpu_dma_write_valid )
        cpu_dma_write_ack <= 1'b0;

    cpu_dma_read_in_progress <= cpu_dma_read_in_progress_next;

    if( cpu_dma_read_in_progress && dma_rsp_valid_i ) begin
        // DMA read in progress
        cpu_data_buffer <= dma_rsp_data_mixed;
        cpu_data_buffer_full <= 1'b1;
        cpu_send_counter <= cpu_send_counter-1;
        cpu_dma_addr_send <= cpu_dma_addr_send + MEM_DATA_WIDTH_BYTES;
        cpu_dma_read_in_progress <= 1'b0;
    end

    if( dma_cmd_valid_o && dma_cmd_write_o && dma_cmd_ack_i ) begin
        // DMA write sent
        cpu_dma_addr_recv <= cpu_dma_addr_recv + MEM_DATA_WIDTH_BYTES;
    end

    if( cpu_data_buffer_full && cpu_send_idle )
        cpu_dma_read_valid <= 1'b1;

    if( cpu_data_buffer_full && cpu_dma_read_valid && cpu_dma_read_ack )
        cpu_data_buffer_full <= 1'b0;

    if( dma_cmd_valid_o && dma_cmd_write_o && dma_cmd_ack_i ) begin
        cpu_dma_write_ack <= 1'b1;
        cpu_dma_addr_send <= cpu_dma_addr_send + MEM_DATA_WIDTH_BYTES;
        cpu_recv_counter <= cpu_recv_counter - 1;
    end

    if( cpu_transaction_active && cpu_send_counter==0 && cpu_recv_counter==0 )
        cpu_transaction_active <= 1'b0;
end

always_comb begin
    cpu_dma_read_in_progress_next = cpu_dma_read_in_progress;
    dma_cmd_valid_o = 1'b0;
    dma_cmd_data_mixed = { MEM_DATA_WIDTH{1'bX} };
    dma_cmd_write_o = 1'bX;
    dma_cmd_address_o = 32'bX;

    if( cpu_transaction_active ) begin
        if( cpu_send_counter>0 ) begin
            // DMA read
            if( !cpu_data_buffer_full ) begin
                if( cpu_send_idle && !cpu_dma_read_in_progress ) begin
                    dma_cmd_valid_o = 1'b1;
                    dma_cmd_address_o = cpu_dma_addr_send;
                    dma_cmd_write_o = 1'b0;

                    if( dma_cmd_ack_i )
                        cpu_dma_read_in_progress_next = 1'b1;
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

endgenerate

/*********************************************************************************
* SPI clock logic
*********************************************************************************/

/*
* Bit 0: SPI chip select (active low)
* Bit 1: SPI clock enable
* Bit 2: Send
* Bit 3: Recv
*/
enum logic[3:0] {
    IDLE =              4'b0001,
    SEND_ACTIVE =       4'b0110,
    SEND_PENDING =      4'b0100,
    DUMMY =             4'b0010,
    RECV_ACTIVE =       4'b1010,
    RECV_PENDING =      4'b1000,
    IDLE_PENDING =      4'b1001
} spi_state = IDLE, spi_state_next;

assign spi_cs_n_o = spi_state[0];

logic [31:0] spi_send_cycles = 0, spi_recv_cycles = 0;
logic [16:0] spi_dummy_cycles = 0;
logic spi_quad_mode = 1'b0;
logic [MEM_DATA_WIDTH-1:0] spi_shift_buffer;
logic [$clog2(MEM_DATA_WIDTH):0] spi_buffer_fill = 0;
logic spi_load_buffer;


always_comb begin
    spi_state_next = spi_state;
    spi_load_buffer = 1'b0;

    case(spi_state)
        IDLE: begin
            if( spi_dma_read_valid && !spi_dma_read_ack ) begin
                spi_state_next = SEND_ACTIVE;
                spi_load_buffer = 1'b1;
            end
        end
        SEND_ACTIVE: begin
            if( spi_send_cycles==0 ) begin
                // Send part done
                if( spi_dummy_cycles!=0 )
                    spi_state_next = DUMMY;
                else if( spi_recv_cycles!=0 ) begin
                    spi_state_next = RECV_ACTIVE;
                end else
                    spi_state_next = IDLE;
            end else begin
                // Send part not done
                if( spi_buffer_fill==0 ) begin
                    spi_load_buffer = 1'b1;
                    spi_state_next = SEND_PENDING;
                end
            end
        end
        SEND_PENDING: begin
            spi_load_buffer = 1'b1;

            if( spi_dma_read_valid && !spi_dma_read_ack )
                spi_state_next = SEND_ACTIVE;
        end
        DUMMY: begin
            if( spi_dummy_cycles==1 ) begin
                if( spi_recv_cycles==0 )
                    spi_state_next = RECV_ACTIVE;
                else
                    spi_state_next = IDLE;
            end
        end
        RECV_ACTIVE: begin
            if( spi_recv_cycles==1 ) begin
                spi_state_next = IDLE_PENDING;
            end else if( spi_buffer_fill==MEM_DATA_WIDTH ) begin
                spi_state_next = RECV_PENDING;
            end
        end
        RECV_PENDING: begin
            if( spi_dma_write_valid && spi_dma_write_ack )
                spi_state_next = RECV_ACTIVE;
        end
        IDLE_PENDING: begin
            if( spi_dma_write_valid && spi_dma_write_ack )
                spi_state_next = IDLE;
        end
    endcase
end

task ack_buffer_from_cpu(input new_transaction);
    if( new_transaction )
        spi_buffer_fill <= spi_num_send_cycles<MEM_DATA_WIDTH ? spi_num_send_cycles : MEM_DATA_WIDTH;
    else
        spi_buffer_fill <= spi_send_cycles<MEM_DATA_WIDTH ? spi_send_cycles : MEM_DATA_WIDTH;

    spi_dma_read_ack <= 1'b1;
endtask

always_ff@(posedge spi_ref_clock_p) begin
    spi_state <= spi_state_next;

    if( spi_dma_read_ack && !spi_dma_read_valid )
        spi_dma_read_ack <= 1'b0;

    if( spi_state != spi_state_next ) begin
        // State transition
        case( spi_state )
            IDLE: begin
                spi_send_cycles <= spi_num_send_cycles - 1;
                spi_recv_cycles <= spi_num_recv_cycles;
                spi_dummy_cycles <= spi_transfer_mode[15:0];
                spi_quad_mode <= spi_transfer_mode[16];

                ack_buffer_from_cpu(1'b1);
            end
            SEND_ACTIVE: begin
                if( spi_state_next==SEND_PENDING && spi_dma_read_valid && !spi_dma_read_ack ) begin
                    ack_buffer_from_cpu(1'b0);
                    spi_state <= SEND_ACTIVE;
                end
                spi_buffer_fill <= 0;
            end
            RECV_ACTIVE: begin
                if( spi_state_next[3] ) begin // Need to flush
                    if( !spi_dma_write_ack )
                        spi_dma_write_valid <= 1'b1;
                end
                spi_buffer_fill <= 0;
            end
            RECV_PENDING: spi_dma_write_valid <= 1'b0;
            IDLE_PENDING: spi_dma_write_valid <= 1'b0;
        endcase
    end else begin
        // Stable state
        case( spi_state )
            SEND_ACTIVE: begin
                spi_send_cycles <= spi_send_cycles - 1;
                spi_buffer_fill <= spi_buffer_fill - 1;
            end
            RECV_ACTIVE: begin
                spi_recv_cycles <= spi_recv_cycles - 1;
                spi_buffer_fill <= spi_buffer_fill + (spi_quad_mode ? 4 : 1);
            end
            RECV_PENDING: spi_dma_write_valid <= !spi_dma_write_ack;
            IDLE_PENDING: spi_dma_write_valid <= !spi_dma_write_ack;
        endcase
    end
end

BUFGCE spi_clock_buf(
    .O(spi_clk_o),
    .I(spi_ref_clock_n),
    .CE(spi_state[1])
);

logic[3:0] spi_dq_o, spi_dq_raw_i, spi_dq_i;

assign spi_dq_o = spi_state[2] ? spi_shift_buffer[3:0] : 4'b1111;

wire spi_dq_dir = !spi_state[2];
IOBUF dq0_buffer(.T(spi_quad_mode ? spi_dq_dir : 1'b0), .I(spi_dq_o[0]), .O(spi_dq_raw_i[0]), .IO(spi_dq_io[0]));
IOBUF dq1_buffer(.T(spi_quad_mode ? spi_dq_dir : 1'b1), .I(spi_dq_o[1]), .O(spi_dq_raw_i[1]), .IO(spi_dq_io[1]));
IOBUF dq2_buffer(.T(spi_quad_mode ? spi_dq_dir : 1'b0), .I(spi_quad_mode ? spi_dq_o[2] : 1'b1), .O(spi_dq_raw_i[2]), .IO(spi_dq_io[2]));
IOBUF dq3_buffer(.T(spi_quad_mode ? spi_dq_dir : 1'b0), .I(spi_quad_mode ? spi_dq_o[3] : 1'b1), .O(spi_dq_raw_i[3]), .IO(spi_dq_io[3]));

always_ff@(posedge spi_ref_clock_n)
    spi_dq_i <= spi_dq_raw_i;


generate

for( i=0; i<1; ++i ) begin
    always_ff@(posedge spi_ref_clock_p) begin
        if( spi_load_buffer ) begin
            spi_shift_buffer[i] <= spi_dma_read_data[i];
        end else begin
            case(spi_state)
                SEND_ACTIVE: spi_shift_buffer[i] <= (spi_quad_mode ? spi_shift_buffer[i+4] : spi_shift_buffer[i+1]);
                RECV_ACTIVE: spi_shift_buffer[i] <= (spi_quad_mode ? spi_dq_i[0] : spi_dq_i[1]);
                DUMMY: spi_shift_buffer[i] <= 1'bX;
            endcase
        end
    end
end

for( i=1; i<4; ++i ) begin
    always_ff@(posedge spi_ref_clock_p) begin
        if( spi_load_buffer ) begin
            spi_shift_buffer[i] <= spi_dma_read_data[i];
        end else begin
            case(spi_state)
                SEND_ACTIVE: spi_shift_buffer[i] <= (spi_quad_mode ? spi_shift_buffer[i+4] : spi_shift_buffer[i+1]);
                RECV_ACTIVE: spi_shift_buffer[i] <= (spi_quad_mode ? spi_dq_i[i] : spi_shift_buffer[i-1]);
                DUMMY: spi_shift_buffer[i] <= 1'bX;
            endcase
        end
    end
end

for( i=4; i<(MEM_DATA_WIDTH-4); ++i ) begin
    always_ff@(posedge spi_ref_clock_p) begin
        if( spi_load_buffer ) begin
            spi_shift_buffer[i] <= spi_dma_read_data[i];
        end else begin
            case(spi_state)
                SEND_ACTIVE: spi_shift_buffer[i] <= (spi_quad_mode ? spi_shift_buffer[i+4] : spi_shift_buffer[i+1]);
                RECV_ACTIVE: spi_shift_buffer[i] <= (spi_quad_mode ? spi_shift_buffer[i-4] : spi_shift_buffer[i-1]);
                DUMMY: spi_shift_buffer[i] <= 1'bX;
            endcase
        end
    end
end

for( i=MEM_DATA_WIDTH-4; i<(MEM_DATA_WIDTH-1); ++i ) begin
    always_ff@(posedge spi_ref_clock_p) begin
        if( spi_load_buffer ) begin
            spi_shift_buffer[i] <= spi_dma_read_data[i];
        end else begin
            case(spi_state)
                SEND_ACTIVE: spi_shift_buffer[i] <= (spi_quad_mode ? 1'bX : spi_shift_buffer[i+1]);
                RECV_ACTIVE: spi_shift_buffer[i] <= (spi_quad_mode ? spi_shift_buffer[i-4] : spi_shift_buffer[i-1]);
                DUMMY: spi_shift_buffer[i] <= 1'bX;
            endcase
        end
    end
end

for( i=MEM_DATA_WIDTH-1; i<MEM_DATA_WIDTH; ++i ) begin
    always_ff@(posedge spi_ref_clock_p) begin
        if( spi_load_buffer ) begin
            spi_shift_buffer[i] <= spi_dma_read_data[i];
        end else begin
            case(spi_state)
                SEND_ACTIVE: spi_shift_buffer[i] <= 1'bX;
                RECV_ACTIVE: spi_shift_buffer[i] <= (spi_quad_mode ? spi_shift_buffer[i-4] : spi_shift_buffer[i-1]);
                DUMMY: spi_shift_buffer[i] <= 1'bX;
            endcase
        end
    end
end

endgenerate

assign debug[0] = spi_clk_o;
assign debug[1] = spi_cs_n_o;
assign debug[2] = spi_dq_i[0];
assign debug[3] = spi_dq_i[1];

endmodule
