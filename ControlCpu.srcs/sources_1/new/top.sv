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


module top
(
    input board_clock,
    input nReset,
    input uart_output,

    output logic running,

    output uart_tx,
    input uart_rx,

    // DDR3 SDRAM
    output  wire            ddr3_reset_n,
    output  wire    [0:0]   ddr3_cke,
    output  wire    [0:0]   ddr3_ck_p,
    output  wire    [0:0]   ddr3_ck_n,
    //output  wire    [0:0]   ddr3_cs_n,
    output  wire            ddr3_ras_n,
    output  wire            ddr3_cas_n,
    output  wire            ddr3_we_n,
    output  wire    [2:0]   ddr3_ba,
    output  wire    [13:0]  ddr3_addr,
    output  wire    [0:0]   ddr3_odt,
    output  wire    [1:0]   ddr3_dm,
    inout   wire    [1:0]   ddr3_dqs_p,
    inout   wire    [1:0]   ddr3_dqs_n,
    inout   wire    [15:0]  ddr3_dq
);
localparam CTRL_CLOCK_HZ = 100000000;

function automatic [3:0] convert_byte_write( logic we, logic[1:0] address, logic[1:0] size );
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
        convert_byte_write = 4'b0;
endfunction

function automatic [15:0] convert_long_write_mask( logic [3:0] base_mask, logic [3:0] address);
    case( address[3:2] )
        2'b00: convert_long_write_mask = { 12'b0, base_mask };
        2'b01: convert_long_write_mask = { 8'b0, base_mask, 4'b0 };
        2'b10: convert_long_write_mask = { 4'b0, base_mask, 8'b0 };
        2'b11: convert_long_write_mask = { base_mask, 12'b0 };
    endcase
endfunction

//-----------------------------------------------------------------
// Clocking / Reset
//-----------------------------------------------------------------
logic ctrl_cpu_clock, clocks_locked;
wire clk_w = ctrl_cpu_clock;
wire ddr_clock;
wire rst_w = !clocks_locked;
wire clk_ddr_w;
wire clk_ddr_dqs_w;
wire clk_ref_w;

clk_converter clocks(
    .clk_in1(board_clock), .reset(1'b0),
    .clk_ctrl_cpu(ctrl_cpu_clock),
    .clk_ddr_w(clk_ddr_w),
    .locked(clocks_locked)
);

logic           ctrl_iBus_cmd_ready;
logic           ctrl_iBus_rsp_valid;
logic           ctrl_iBus_rsp_payload_error;
logic [31:0]    ctrl_iBus_rsp_payload_inst;

logic           ctrl_dBus_cmd_ready;
logic           ctrl_dBus_rsp_ready;
logic           ctrl_dBus_rsp_error;
logic [31:0]    ctrl_dBus_rsp_data;

logic           ctrl_timer_interrupt;
logic           ctrl_interrupt;
logic           ctrl_software_interrupt;


VexRiscv control_cpu(
    .clk(ctrl_cpu_clock),
    .reset(!nReset || !clocks_locked),

    .timerInterrupt(1'b0),
    .externalInterrupt(1'b0),
    .softwareInterrupt(1'b0),

    .iBus_cmd_ready(1'b1),
    .iBus_rsp_valid(ctrl_iBus_rsp_valid),
    .iBus_rsp_payload_error(ctrl_iBus_rsp_payload_error),
    .iBus_rsp_payload_inst(ctrl_iBus_rsp_payload_inst),

    .dBus_cmd_ready(ctrl_dBus_cmd_ready),
    .dBus_rsp_ready(ctrl_dBus_rsp_ready),
    .dBus_rsp_error(ctrl_dBus_rsp_error),
    .dBus_rsp_data(ctrl_dBus_rsp_data)
);

assign ctrl_iBus_rsp_payload_error = 0;
assign ctrl_dBus_rsp_error = 0;

logic sram_dBus_rsp_ready;
logic [31:0] sram_dBus_rsp_data;
logic [31:0] ddr_ctrl_in = 0;
logic [31:0] ddr_ctrl_out;
logic [63:0] ddr_read_data;
logic ddr_ready, ddr_rsp_ready, ddr_write_data_ready;
logic irq_enable, irq_req_ack, irq_rsp_ready;
logic [31:0] irq_rsp_data;

io_block#(.CLOCK_HZ(CTRL_CLOCK_HZ)) iob(
    .clock(ctrl_cpu_clock),

    .address(control_cpu.dBus_cmd_payload_address),
    .address_valid(control_cpu.dBus_cmd_valid),
    .write(control_cpu.dBus_cmd_payload_wr),
    .data_in(control_cpu.dBus_cmd_payload_data),
    .data_out(ctrl_dBus_rsp_data),

    .req_ack(ctrl_dBus_cmd_ready),
    .rsp_ready(ctrl_dBus_rsp_ready),

    .passthrough_sram_req_ack(1'b1),
    .passthrough_sram_rsp_ready(sram_dBus_rsp_ready),
    .passthrough_sram_data(sram_dBus_rsp_data),

    .passthrough_ddr_req_ack(),
    .passthrough_ddr_rsp_ready(),
    .passthrough_ddr_data(),

    .passthrough_irq_enable(irq_enable),
    .passthrough_irq_req_ack(irq_req_ack),
    .passthrough_irq_rsp_data(irq_rsp_data),
    .passthrough_irq_rsp_ready(irq_rsp_ready),

    .uart_tx(uart_tx),
    .uart_rx(uart_rx),

    .gpio_in({31'b0, uart_output}),

    .ddr_ctrl_in(ddr_ctrl_in),
    .ddr_ctrl_out(ddr_ctrl_out)
);

always_ff@(posedge ctrl_cpu_clock)
begin
    ctrl_iBus_rsp_valid <= control_cpu.iBus_cmd_valid;
    sram_dBus_rsp_ready <= iob.passthrough_sram_enable;
    if( control_cpu.dBus_cmd_valid )
        req_id <= req_id + 1;
end

blk_mem sram(
    .addra( control_cpu.dBus_cmd_payload_address[14:2] ),
    .clka( ctrl_cpu_clock),
    .dina( control_cpu.dBus_cmd_payload_data ),
    .douta( sram_dBus_rsp_data ),
    .ena( iob.passthrough_sram_enable ),
    .wea( convert_byte_write(
        control_cpu.dBus_cmd_payload_wr,
        control_cpu.dBus_cmd_payload_address,
        control_cpu.dBus_cmd_payload_size)
    ),

    .addrb( control_cpu.iBus_cmd_payload_pc[14:2] ),
    .clkb( ctrl_cpu_clock ),
    .dinb( 32'hX ),
    .doutb( ctrl_iBus_rsp_payload_inst ),
    .enb( control_cpu.iBus_cmd_valid ),
    .web( 4'b0 )
);

/*
cache_port::port_in cache_ports_in[1:0];

cache#(.NUM_PORTS(2))(
    .clock(ctrl_cpu_clock),
    .ports_in(cache_ports_in)
);

assign cache_ports_in[0].valid = iob.passthrough_enable;
assign cache_ports_in[0].address = control_cpu.dBus_cmd_payload_address;
assign cache_ports_in[0].write = control_cpu.dBus_cmd_payload_wr;
assign cache_ports_in[0].write_data = control_cpu.dBus_cmd_payload_data;
*/



//-----------------------------------------------------------------
// DDR Core + PHY
//-----------------------------------------------------------------
wire [ 13:0]   dfi_address_w;
wire [  2:0]   dfi_bank_w;
wire           dfi_cas_n_w;
wire           dfi_cke_w;
wire           dfi_cs_n_w;
wire           dfi_odt_w;
wire           dfi_ras_n_w;
wire           dfi_reset_n_w;
wire           dfi_we_n_w;
wire [ 31:0]   dfi_wrdata_w;
wire           dfi_wrdata_en_w;
wire [  3:0]   dfi_wrdata_mask_w;
wire           dfi_rddata_en_w;
wire [ 31:0]   dfi_rddata_w;
wire           dfi_rddata_valid_w;
wire [  1:0]   dfi_rddata_dnv_w;

wire           axi4_awready_w;
wire           axi4_arready_w;
wire  [  7:0]  axi4_arlen_w = 8'h00;    // XXX Burst length of 1
wire           axi4_wvalid_w = iob.passthrough_ddr_enable && control_cpu.dBus_cmd_payload_wr;
wire  [ 31:0]  axi4_araddr_w = control_cpu.dBus_cmd_payload_address;
wire  [  1:0]  axi4_bresp_w;
wire  [ 31:0]  axi4_wdata_w = control_cpu.dBus_cmd_payload_data;
wire           axi4_rlast_w;
wire           axi4_awvalid_w = axi4_wvalid_w;
wire  [  3:0]  axi4_rid_w = 4'h0;
wire  [  1:0]  axi4_rresp_w;
wire           axi4_bvalid_w;
wire  [  3:0]  axi4_wstrb_w = convert_byte_write(
                    control_cpu.dBus_cmd_payload_wr,
                    control_cpu.dBus_cmd_payload_address,
                    control_cpu.dBus_cmd_payload_size);
wire  [15:0]  write_mask_128bit = convert_long_write_mask(axi4_wstrb_w, control_cpu.dBus_cmd_payload_address);
wire  [  1:0]  axi4_arburst_w = 2'b1;   // INCRemental burst
wire           axi4_arvalid_w = iob.passthrough_ddr_enable && !control_cpu.dBus_cmd_payload_wr;
wire  [  3:0]  axi4_awid_w = 3'b0;
wire  [  3:0]  axi4_bid_w;
wire  [  3:0]  axi4_arid_w = 3'b0;
wire           axi4_rready_w = 1'b1;
wire  [  7:0]  axi4_awlen_w = 8'h00;    // XXX Burst length of 1
wire           axi4_wlast_w = 1'b1;     // XXX Burst length of 1 means we are always the last one
wire  [ 31:0]  axi4_rdata_w;
wire           axi4_bready_w = 1'b1;
wire  [ 31:0]  axi4_awaddr_w = control_cpu.dBus_cmd_payload_address;
wire           axi4_wready_w;
wire  [  1:0]  axi4_awburst_w = 1'b1;   // INCRemental burst
wire           axi4_rvalid_w;

logic [15:0]   req_id = 0;


sddr_phy_xilinx ddr_phy(
//     .in_ddr_clock_i(clk_ddr_w)
     .in_ddr_clock_i(ctrl_cpu_clock)
    ,.in_ddr_reset_n_i(ddr_ctrl_out[0])
    ,.in_phy_reset_n_i(ddr_ctrl_out[1])

    ,.ddr3_ck_p_o(ddr3_ck_p)
    ,.ddr3_ck_n_o(ddr3_ck_n)
    ,.ddr3_cke_o(ddr3_cke)
    ,.ddr3_reset_n_o(ddr3_reset_n)
    ,.ddr3_ras_n_o(ddr3_ras_n)
    ,.ddr3_cas_n_o(ddr3_cas_n)
    ,.ddr3_we_n_o(ddr3_we_n)
    ,.ddr3_cs_n_o()
    ,.ddr3_ba_o(ddr3_ba)
    ,.ddr3_addr_o(ddr3_addr[13:0])
    ,.ddr3_odt_o(ddr3_odt)
    ,.ddr3_dm_o(ddr3_dm)
    ,.ddr3_dq_io(ddr3_dq)
    ,.ddr3_dqs_p_io(ddr3_dqs_p)
    ,.ddr3_dqs_n_io(ddr3_dqs_n)
    );

timer_int_ctrl#(.CLOCK_HZ(CTRL_CLOCK_HZ)) timer_interrupt(
    .clock(ctrl_cpu_clock),
    .req_addr_i(control_cpu.dBus_cmd_payload_address[15:0]),
    .req_data_i(control_cpu.dBus_cmd_payload_data),
    .req_write_i(control_cpu.dBus_cmd_payload_wr),
    .req_valid_i(irq_enable),
    .req_ready_o(irq_req_ack),

    .rsp_data_o(irq_rsp_data),
    .rsp_valid_o(irq_rsp_ready)
);

endmodule
