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
    input nReset,

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

//-----------------------------------------------------------------
// Clocking / Reset
//-----------------------------------------------------------------
logic ctrl_cpu_clock, clocks_locked;
wire clk_w = ctrl_cpu_clock;
wire rst_w = !clocks_locked;
wire clk_ddr_w;
wire clk_ddr_dqs_w;
wire clk_ref_w;

clk_converter clocks(
    .clk_in1(board_clock), .reset(1'b0),
    .clk_ctrl_cpu(ctrl_cpu_clock),
    .clk_ddr_w(clk_ddr_w),
    .clk_ref_w(clk_ref_w),
    .clk_ddr_dqs_w(clk_ddr_dqs_w),
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

    .iBus_cmd_ready(ctrl_iBus_cmd_ready),
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

io_block iob(
    .clock(ctrl_cpu_clock),

    .address(control_cpu.dBus_cmd_payload_address),
    .address_valid(control_cpu.dBus_cmd_valid),
    .write(control_cpu.dBus_cmd_payload_wr),
    .data_in(control_cpu.dBus_cmd_payload_data),
    .data_out(ctrl_dBus_rsp_data),
    .enable(control_cpu.dBus_cmd_valid),

    .req_ack(ctrl_dBus_cmd_ready),
    .rsp_ready(ctrl_dBus_rsp_ready),

    .passthrough_sram_req_ack(1'b1),
    .passthrough_sram_rsp_ready(sram_dBus_rsp_ready),
    .passthrough_sram_data(sram_dBus_rsp_data),

    .passthrough_ddr_req_ack(control_cpu.dBus_cmd_payload_wr ? (axi4_wready_w && axi4_awready_w) : axi4_arready_w),
    .passthrough_ddr_rsp_ready(axi4_rvalid_w || axi4_bvalid_w),
    .passthrough_ddr_data(axi4_rdata_w),

    .uart_tx(uart_tx),
    .uart_rx(uart_rx)
);

always_ff@(posedge ctrl_cpu_clock)
begin
    ctrl_iBus_cmd_ready <= control_cpu.iBus_cmd_valid;
    ctrl_iBus_rsp_valid <= control_cpu.iBus_cmd_valid;
    sram_dBus_rsp_ready <= iob.passthrough_sram_enable;
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

ddr3_axi
#(
     .DDR_WRITE_LATENCY(4)
    ,.DDR_READ_LATENCY(4)
    ,.DDR_MHZ(100)
)
u_ddr
(
    // Inputs
     .clk_i(clk_w)
    ,.rst_i(rst_w)
    ,.inport_awvalid_i(axi4_awvalid_w)
    ,.inport_awaddr_i(axi4_awaddr_w)
    ,.inport_awid_i(axi4_awid_w)
    ,.inport_awlen_i(axi4_awlen_w)
    ,.inport_awburst_i(axi4_awburst_w)
    ,.inport_wvalid_i(axi4_wvalid_w)
    ,.inport_wdata_i(axi4_wdata_w)
    ,.inport_wstrb_i(axi4_wstrb_w)
    ,.inport_wlast_i(axi4_wlast_w)
    ,.inport_bready_i(axi4_bready_w)
    ,.inport_arvalid_i(axi4_arvalid_w)
    ,.inport_araddr_i(axi4_araddr_w)
    ,.inport_arid_i(axi4_arid_w)
    ,.inport_arlen_i(axi4_arlen_w)
    ,.inport_arburst_i(axi4_arburst_w)
    ,.inport_rready_i(axi4_rready_w)
    ,.dfi_rddata_i(dfi_rddata_w)
    ,.dfi_rddata_valid_i(dfi_rddata_valid_w)
    ,.dfi_rddata_dnv_i(dfi_rddata_dnv_w)

    // Outputs
    ,.inport_awready_o(axi4_awready_w)
    ,.inport_wready_o(axi4_wready_w)
    ,.inport_bvalid_o(axi4_bvalid_w)
    ,.inport_bresp_o(axi4_bresp_w)
    ,.inport_bid_o(axi4_bid_w)
    ,.inport_arready_o(axi4_arready_w)
    ,.inport_rvalid_o(axi4_rvalid_w)
    ,.inport_rdata_o(axi4_rdata_w)
    ,.inport_rresp_o(axi4_rresp_w)
    ,.inport_rid_o(axi4_rid_w)
    ,.inport_rlast_o(axi4_rlast_w)
    ,.dfi_address_o(dfi_address_w)
    ,.dfi_bank_o(dfi_bank_w)
    ,.dfi_cas_n_o(dfi_cas_n_w)
    ,.dfi_cke_o(dfi_cke_w)
    ,.dfi_cs_n_o(dfi_cs_n_w)
    ,.dfi_odt_o(dfi_odt_w)
    ,.dfi_ras_n_o(dfi_ras_n_w)
    ,.dfi_reset_n_o(dfi_reset_n_w)
    ,.dfi_we_n_o(dfi_we_n_w)
    ,.dfi_wrdata_o(dfi_wrdata_w)
    ,.dfi_wrdata_en_o(dfi_wrdata_en_w)
    ,.dfi_wrdata_mask_o(dfi_wrdata_mask_w)
    ,.dfi_rddata_en_o(dfi_rddata_en_w)
);

ddr3_dfi_phy
#(
     .DQS_TAP_DELAY_INIT(27)
    ,.DQ_TAP_DELAY_INIT(0)
    ,.TPHY_RDLAT(5)
)
u_phy
(
     .clk_i(clk_w)
    ,.rst_i(rst_w)

    ,.clk_ddr_i(clk_ddr_w)
    ,.clk_ddr90_i(clk_ddr_dqs_w)
    ,.clk_ref_i(clk_ref_w)

    ,.cfg_valid_i(1'b0)
    ,.cfg_i(32'b0)

    ,.dfi_address_i(dfi_address_w)
    ,.dfi_bank_i(dfi_bank_w)
    ,.dfi_cas_n_i(dfi_cas_n_w)
    ,.dfi_cke_i(dfi_cke_w)
    ,.dfi_cs_n_i(dfi_cs_n_w)
    ,.dfi_odt_i(dfi_odt_w)
    ,.dfi_ras_n_i(dfi_ras_n_w)
    ,.dfi_reset_n_i(dfi_reset_n_w)
    ,.dfi_we_n_i(dfi_we_n_w)
    ,.dfi_wrdata_i(dfi_wrdata_w)
    ,.dfi_wrdata_en_i(dfi_wrdata_en_w)
    ,.dfi_wrdata_mask_i(dfi_wrdata_mask_w)
    ,.dfi_rddata_en_i(dfi_rddata_en_w)
    ,.dfi_rddata_o(dfi_rddata_w)
    ,.dfi_rddata_valid_o(dfi_rddata_valid_w)
    ,.dfi_rddata_dnv_o(dfi_rddata_dnv_w)

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

endmodule
