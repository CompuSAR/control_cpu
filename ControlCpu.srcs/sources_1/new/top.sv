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

    output logic debug,

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
localparam CTRL_CLOCK_HZ = 101041667;
//localparam CTRL_CLOCK_HZ =86607143;

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
wire ddr_clock, ddr_clock_90deg;
wire rst_w = !clocks_locked;
wire clk_ddr_dqs_w;
wire clk_ref_w;
wire clock_feedback;

clk_converter clocks(
    .clk_in1(board_clock), .reset(1'b0),
    .clk_ctrl_cpu(ctrl_cpu_clock),
    .clk_ddr(ddr_clock),
    .clk_ddr_90deg(ddr_clock_90deg),
    .clkfb_in(clock_feedback),
    .clkfb_out(clock_feedback),
    .locked(clocks_locked)
);

logic           ctrl_iBus_cmd_ready;
logic           ctrl_iBus_cmd_valid;
logic [31:0]    ctrl_iBus_cmd_pc;
logic           ctrl_iBus_rsp_valid;
logic           ctrl_iBus_rsp_payload_error;
logic [31:0]    ctrl_iBus_rsp_payload_inst;

logic           ctrl_dBus_cmd_valid;
logic [31:0]    ctrl_dBus_cmd_payload_address;
logic           ctrl_dBus_cmd_payload_wr;
logic [31:0]    ctrl_dBus_cmd_payload_data;
logic [1:0]     ctrl_dBus_cmd_payload_size;


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
    .iBus_cmd_valid(ctrl_iBus_cmd_valid),
    .iBus_cmd_payload_pc(ctrl_iBus_cmd_pc),
    .iBus_rsp_valid(ctrl_iBus_rsp_valid),
    .iBus_rsp_payload_error(ctrl_iBus_rsp_payload_error),
    .iBus_rsp_payload_inst(ctrl_iBus_rsp_payload_inst),

    .dBus_cmd_valid(ctrl_dBus_cmd_valid),
    .dBus_cmd_payload_address(ctrl_dBus_cmd_payload_address),
    .dBus_cmd_payload_wr(ctrl_dBus_cmd_payload_wr),
    .dBus_cmd_payload_data(ctrl_dBus_cmd_payload_data),
    .dBus_cmd_payload_size(ctrl_dBus_cmd_payload_size),
    .dBus_cmd_ready(ctrl_dBus_cmd_ready),
    .dBus_rsp_ready(ctrl_dBus_rsp_ready),
    .dBus_rsp_error(ctrl_dBus_rsp_error),
    .dBus_rsp_data(ctrl_dBus_rsp_data)
);

assign ctrl_iBus_rsp_payload_error = 0;
assign ctrl_dBus_rsp_error = 0;

logic sram_enable;
logic sram_dBus_rsp_ready;
logic [31:0] sram_dBus_rsp_data;
logic ddr_ready, ddr_rsp_ready, ddr_write_data_ready;
logic ddr_ctrl_cmd_valid, ddr_ctrl_cmd_ready, ddr_ctrl_rsp_ready;
logic [31:0] ddr_ctrl_rsp_data;
logic ddr_data_cmd_valid, ddr_data_cmd_ack, ddr_data_rsp_ready;
logic [127:0] ddr_data_rsp_data;
logic irq_enable, irq_req_ack, irq_rsp_ready;
logic [31:0] irq_rsp_data;
logic gpio_enable, gpio_req_ack, gpio_rsp_ready;
logic [31:0] gpio_rsp_data;

io_block#(.CLOCK_HZ(CTRL_CLOCK_HZ)) iob(
    .clock(ctrl_cpu_clock),

    .address(ctrl_dBus_cmd_payload_address),
    .address_valid(ctrl_dBus_cmd_valid),
    .write(ctrl_dBus_cmd_payload_wr),
    .data_in(ctrl_dBus_cmd_payload_data),
    .data_out(ctrl_dBus_rsp_data),

    .req_ack(ctrl_dBus_cmd_ready),
    .rsp_ready(ctrl_dBus_rsp_ready),

    .passthrough_sram_enable(sram_enable),
    .passthrough_sram_req_ack(1'b1),
    .passthrough_sram_rsp_ready(sram_dBus_rsp_ready),
    .passthrough_sram_data(sram_dBus_rsp_data),

    .passthrough_ddr_enable(ddr_data_cmd_valid),
    .passthrough_ddr_req_ack(ddr_data_cmd_ack),
    .passthrough_ddr_rsp_ready(ddr_data_rsp_ready),
    .passthrough_ddr_data(ddr_data_rsp_data[31:0]),

    .passthrough_ddr_ctrl_enable(ddr_ctrl_cmd_valid),
    .passthrough_ddr_ctrl_req_ack(ddr_ctrl_cmd_ready),
    .passthrough_ddr_ctrl_rsp_ready(ddr_ctrl_rsp_ready),
    .passthrough_ddr_ctrl_data(ddr_ctrl_rsp_data),

    .passthrough_irq_enable(irq_enable),
    .passthrough_irq_req_ack(irq_req_ack),
    .passthrough_irq_rsp_data(irq_rsp_data),
    .passthrough_irq_rsp_ready(irq_rsp_ready),

    .passthrough_gpio_enable(gpio_enable),
    .passthrough_gpio_req_ack(gpio_req_ack),
    .passthrough_gpio_rsp_data(gpio_rsp_data),
    .passthrough_gpio_rsp_ready(gpio_rsp_ready),

    .uart_tx(uart_tx),
    .uart_rx(uart_rx)
);

always_ff@(posedge ctrl_cpu_clock)
begin
    ctrl_iBus_rsp_valid <= ctrl_iBus_cmd_valid;
    sram_dBus_rsp_ready <= sram_enable;
end

blk_mem sram(
    .addra( ctrl_dBus_cmd_payload_address[14:2] ),
    .clka( ctrl_cpu_clock),
    .dina( ctrl_dBus_cmd_payload_data ),
    .douta( sram_dBus_rsp_data ),
    .ena( sram_enable ),
    .wea( convert_byte_write(
        ctrl_dBus_cmd_payload_wr,
        ctrl_dBus_cmd_payload_address,
        ctrl_dBus_cmd_payload_size)
    ),

    .addrb( ctrl_iBus_cmd_pc[14:2] ),
    .clkb( ctrl_cpu_clock ),
    .dinb( 32'hX ),
    .doutb( ctrl_iBus_rsp_payload_inst ),
    .enb( ctrl_iBus_cmd_valid ),
    .web( 4'b0 )
);

//-----------------------------------------------------------------
// DDR Core + PHY
//-----------------------------------------------------------------
wire ddr_reset_n;
wire ddr_phy_reset_n;

wire ddr_phy_cke;
wire ddr_phy_odt;
wire ddr_phy_ras_n;
wire ddr_phy_cas_n;
wire ddr_phy_we_n;

wire ddr_phy_cs_n;
wire [2:0] ddr_phy_ba;
wire [13:0] ddr_phy_addr;
wire [1:0] ddr_phy_dqs_i, ddr_phy_dqs_o;
wire ddr_phy_data_transfer, ddr_phy_data_write;
wire [15:0] ddr_phy_dq_i[1:0], ddr_phy_dq_o[1:0];

sddr_ctrl#(
    .tRCD(5),           // 13.75ns
    .tRC(15),           // 48.75ns
    .tRP(5),            // 13.75ns
    .tRFC(49),          // 160ns minimum
    .tREFI(674)         // 7.8us at CPU clock
) ddr_ctrl(
    .cpu_clock_i(ctrl_cpu_clock),
    .ddr_clock_i(ddr_clock),
    .ddr_reset_n_o(ddr_reset_n),
    .ddr_phy_reset_n_o(ddr_phy_reset_n),

    .ctrl_cmd_valid(ddr_ctrl_cmd_valid),
    .ctrl_cmd_address(ctrl_dBus_cmd_payload_address[15:0]),
    .ctrl_cmd_data(ctrl_dBus_cmd_payload_data),
    .ctrl_cmd_write(ctrl_dBus_cmd_payload_wr),
    .ctrl_cmd_ack(ddr_ctrl_cmd_ready),
    .ctrl_rsp_ready(ddr_ctrl_rsp_ready),
    .ctrl_rsp_data(ddr_ctrl_rsp_data),

    .data_cmd_valid(ddr_data_cmd_valid),
    .data_cmd_ack(ddr_data_cmd_ack),
    .data_cmd_data_i( {96'h0123456789abcdefeca86420, ctrl_dBus_cmd_payload_data} ),
    .data_cmd_address({ ctrl_dBus_cmd_payload_address, 2'b00 }),
    .data_cmd_write(ctrl_dBus_cmd_payload_wr),
    .data_rsp_ready(ddr_data_rsp_ready),
    .data_rsp_data_o(ddr_data_rsp_data),

    .ddr3_cs_n_o(ddr_phy_cs_n),
    .ddr3_cke_o(ddr_phy_cke),
    .ddr3_ras_n_o(ddr_phy_ras_n),
    .ddr3_cas_n_o(ddr_phy_cas_n),
    .ddr3_we_n_o(ddr_phy_we_n),
    .ddr3_ba_o(ddr_phy_ba),
    .ddr3_addr_o(ddr_phy_addr),
    .ddr3_odt_o(ddr_phy_odt),
    .ddr3_dq_o(ddr_phy_dq_o),
    .ddr3_dq_i(ddr_phy_dq_i),

    .data_transfer_o(ddr_phy_data_transfer),
    .data_write_o(ddr_phy_data_write)
);

sddr_phy_xilinx ddr_phy(
     .in_cpu_clock_i(ctrl_cpu_clock)
    ,.in_ddr_clock_i(ddr_clock)
//     .in_ddr_clock_i(ctrl_cpu_clock)
    ,.in_ddr_clock_90deg_i(ddr_clock_90deg)
    ,.in_ddr_reset_n_i(ddr_reset_n)
    ,.in_phy_reset_n_i(ddr_phy_reset_n)

    ,.ctl_cs_n_i(ddr_phy_cs_n)
    ,.ctl_odt_i(ddr_phy_odt)
    ,.ctl_cke_i(ddr_phy_cke)
    ,.ctl_ras_n_i(ddr_phy_ras_n)
    ,.ctl_cas_n_i(ddr_phy_cas_n)
    ,.ctl_we_n_i(ddr_phy_we_n)
    ,.ctl_addr_i(ddr_phy_addr)
    ,.ctl_ba_i(ddr_phy_ba)
    ,.ctl_dq_i(ddr_phy_dq_o)
    ,.ctl_dq_o(ddr_phy_dq_i)

    ,.ctl_data_transfer_i(ddr_phy_data_transfer)
    ,.ctl_data_write_i(ddr_phy_data_write)

    ,.ddr3_ck_p_o(ddr3_ck_p)
    ,.ddr3_ck_n_o(ddr3_ck_n)
    ,.ddr3_cke_o(ddr3_cke)
    ,.ddr3_reset_n_o(ddr3_reset_n)
    ,.ddr3_ras_n_o(ddr3_ras_n)
    ,.ddr3_cas_n_o(ddr3_cas_n)
    ,.ddr3_we_n_o(ddr3_we_n)
    ,.ddr3_cs_n_o()                     // No chip select in design
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
    .req_addr_i(ctrl_dBus_cmd_payload_address[15:0]),
    .req_data_i(ctrl_dBus_cmd_payload_data),
    .req_write_i(ctrl_dBus_cmd_payload_wr),
    .req_valid_i(irq_enable),
    .req_ready_o(irq_req_ack),

    .rsp_data_o(irq_rsp_data),
    .rsp_valid_o(irq_rsp_ready)
);

gpio#(.NUM_IN_PORTS(1)) gpio(
    .clock_i(ctrl_cpu_clock),
    .req_addr_i(ctrl_dBus_cmd_payload_address[15:0]),
    .req_data_i(ctrl_dBus_cmd_payload_data),
    .req_write_i(ctrl_dBus_cmd_payload_wr),
    .req_valid_i(gpio_enable),
    .req_ready_o(gpio_req_ack),

    .rsp_data_o(gpio_rsp_data),
    .rsp_valid_o(gpio_rsp_ready),

    .gp_in( '{ { 31'b0, uart_output } } ),
    .gp_out()
);

endmodule
