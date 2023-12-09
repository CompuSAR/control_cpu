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

    output logic[3:0] debug,

    output uart_tx,
    input uart_rx,

    // SPI flash
    output                  spi_cs_n,
    inout [3:0]             spi_dq,
`ifndef SYNTHESIS
    output                  spi_clk,
`endif

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
//localparam CTRL_CLOCK_HZ = 101041667;
//localparam CTRL_CLOCK_HZ = 86607143;
localparam CTRL_CLOCK_HZ = 75781250;

`ifdef SYNTHESIS
wire spi_clk;
`endif

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
wire ddr_clock;
wire rst_w = !clocks_locked;
wire clk_ddr_dqs_w;
wire clk_ref_w;
wire clock_feedback;

clk_converter clocks(
    .clk_in1(board_clock), .reset(1'b0),
    .clk_ctrl_cpu(ctrl_cpu_clock),
    .clk_ddr(ddr_clock),
    .clkfb_in(clock_feedback),
    .clkfb_out(clock_feedback),
    .locked(clocks_locked)
);

localparam CACHE_PORTS_NUM = 3;
localparam CACHELINE_BITS = 128;
localparam CACHELINE_BYTES = CACHELINE_BITS/8;
localparam NUM_CACHELINES = 16*1024*8/CACHELINE_BITS;
localparam DDR_MEM_SIZE = 256*1024*1024;

localparam INST_CACHE_NUM_CACHELINES = 1024*8/CACHELINE_BITS;

logic                                   cache_port_cmd_valid_s[CACHE_PORTS_NUM];
logic [31:0]                            cache_port_cmd_addr_s[CACHE_PORTS_NUM];
logic                                   cache_port_cmd_ready_n[CACHE_PORTS_NUM];
logic [CACHELINE_BYTES-1:0]             cache_port_cmd_write_mask_s[CACHE_PORTS_NUM];
logic [CACHELINE_BITS-1:0]              cache_port_cmd_write_data_s[CACHE_PORTS_NUM];
logic                                   cache_port_rsp_valid_n[CACHE_PORTS_NUM];
logic [CACHELINE_BITS-1:0]              cache_port_rsp_read_data_n[CACHE_PORTS_NUM];

localparam CACHE_PORT_IDX_DBUS = 0;
localparam CACHE_PORT_IDX_IBUS = 1;
localparam CACHE_PORT_IDX_SPI_FLASH = 2;

logic                                   inst_cache_port_cmd_valid_s[0:0];
logic [31:0]                            inst_cache_port_cmd_addr_s[0:0];
logic                                   inst_cache_port_cmd_ready_n[0:0];
logic [CACHELINE_BYTES-1:0]             inst_cache_port_cmd_write_mask_s[0:0];
logic [CACHELINE_BITS-1:0]              inst_cache_port_cmd_write_data_s[0:0];
logic                                   inst_cache_port_rsp_valid_n[0:0];
logic [CACHELINE_BITS-1:0]              inst_cache_port_rsp_read_data_n[0:0];

logic           ctrl_iBus_rsp_payload_error;
logic [31:0]    ctrl_iBus_rsp_payload_inst;

logic           ctrl_dBus_cmd_valid;
logic [31:0]    ctrl_dBus_cmd_payload_address;
logic           ctrl_dBus_cmd_payload_wr;
logic [31:0]    ctrl_dBus_cmd_payload_data;
logic [1:0]     ctrl_dBus_cmd_payload_size;


logic           ctrl_dBus_cmd_ready;
logic           ctrl_dBus_rsp_valid;
logic           ctrl_dBus_rsp_error;
logic [31:0]    ctrl_dBus_rsp_data;

logic           ctrl_timer_interrupt;
logic           ctrl_interrupt;
logic           ctrl_software_interrupt;

logic [31:0]    iob_ddr_read_data;


VexRiscv control_cpu(
    .clk(ctrl_cpu_clock),
    .reset(!nReset || !clocks_locked),

    .timerInterrupt(ctrl_timer_interrupt),
    .externalInterrupt(1'b0),
    .softwareInterrupt(1'b0),

    .iBus_cmd_ready(inst_cache_port_cmd_ready_n[0]),
    .iBus_cmd_valid(inst_cache_port_cmd_valid_s[0]),
    .iBus_cmd_payload_pc(inst_cache_port_cmd_addr_s[0]),
    .iBus_rsp_valid(inst_cache_port_rsp_valid_n[0]),
    .iBus_rsp_payload_error(ctrl_iBus_rsp_payload_error),
    .iBus_rsp_payload_inst(ctrl_iBus_rsp_payload_inst),

    .dBus_cmd_valid(ctrl_dBus_cmd_valid),
    .dBus_cmd_payload_address(ctrl_dBus_cmd_payload_address),
    .dBus_cmd_payload_wr(ctrl_dBus_cmd_payload_wr),
    .dBus_cmd_payload_data(ctrl_dBus_cmd_payload_data),
    .dBus_cmd_payload_size(ctrl_dBus_cmd_payload_size),
    .dBus_cmd_ready(ctrl_dBus_cmd_ready),
    .dBus_rsp_ready(ctrl_dBus_rsp_valid),
    .dBus_rsp_error(ctrl_dBus_rsp_error),
    .dBus_rsp_data(ctrl_dBus_rsp_data)
);

bus_width_adjust#(.OUT_WIDTH(CACHELINE_BITS)) iBus_width_adjuster(
        .clock_i(ctrl_cpu_clock),
        .in_cmd_valid_i(inst_cache_port_cmd_valid_s[0]),
        .in_cmd_addr_i(inst_cache_port_cmd_addr_s[0]),
        .in_cmd_write_mask_i(4'b0000),
        .in_cmd_write_data_i(32'h0),
        .in_rsp_read_data_o(ctrl_iBus_rsp_payload_inst),

        .out_cmd_ready_i(inst_cache_port_cmd_ready_n[0]),
        .out_cmd_write_mask_o(),
        .out_cmd_write_data_o(),
        .out_rsp_valid_i(inst_cache_port_rsp_valid_n[0]),
        .out_rsp_read_data_i(inst_cache_port_rsp_read_data_n[0])
    );
assign inst_cache_port_cmd_write_mask_s[0] = 0;

assign cache_port_cmd_addr_s[CACHE_PORT_IDX_DBUS] = ctrl_dBus_cmd_payload_address;
bus_width_adjust#(.OUT_WIDTH(CACHELINE_BITS)) dBus_width_adjuster(
        .clock_i(ctrl_cpu_clock),
        .in_cmd_valid_i(cache_port_cmd_valid_s[CACHE_PORT_IDX_DBUS]),
        .in_cmd_addr_i(ctrl_dBus_cmd_payload_address),
        .in_cmd_write_mask_i(
            convert_byte_write(
                ctrl_dBus_cmd_payload_wr,
                ctrl_dBus_cmd_payload_address[1:0],
                ctrl_dBus_cmd_payload_size
            )
        ),
        .in_cmd_write_data_i(ctrl_dBus_cmd_payload_data),
        .in_rsp_read_data_o(iob_ddr_read_data),

        .out_cmd_ready_i(ctrl_dBus_cmd_ready),
        .out_cmd_write_mask_o(cache_port_cmd_write_mask_s[CACHE_PORT_IDX_DBUS]),
        .out_cmd_write_data_o(cache_port_cmd_write_data_s[CACHE_PORT_IDX_DBUS]),
        .out_rsp_valid_i(ctrl_dBus_rsp_valid),
        .out_rsp_read_data_i(cache_port_rsp_read_data_n[CACHE_PORT_IDX_DBUS])
    );

assign ctrl_iBus_rsp_payload_error = 0;
assign ctrl_dBus_rsp_error = 0;

logic ddr_ready, ddr_rsp_valid, ddr_write_data_ready;
logic ddr_ctrl_cmd_valid, ddr_ctrl_cmd_ready, ddr_ctrl_rsp_valid;
logic [31:0] ddr_ctrl_rsp_data;
logic ddr_data_cmd_valid, ddr_data_cmd_ack, ddr_cmd_write, ddr_data_rsp_valid;
logic [31:0] ddr_data_cmd_address;
logic [127:0] ddr_cmd_write_data, ddr_data_rsp_read_data;
logic irq_enable, irq_req_ack, irq_rsp_valid;
logic [31:0] irq_rsp_data;
logic spi_enable, spi_req_ack, spi_rsp_valid;
logic [31:0] spi_rsp_data;
logic gpio_enable, gpio_req_ack, gpio_rsp_valid;
logic [31:0] gpio_rsp_data;

io_block#(.CLOCK_HZ(CTRL_CLOCK_HZ)) iob(
    .clock(ctrl_cpu_clock),

    .address(ctrl_dBus_cmd_payload_address),
    .address_valid(ctrl_dBus_cmd_valid),
    .write(ctrl_dBus_cmd_payload_wr),
    .data_in(ctrl_dBus_cmd_payload_data),
    .data_out(ctrl_dBus_rsp_data),

    .req_ack(ctrl_dBus_cmd_ready),
    .rsp_valid(ctrl_dBus_rsp_valid),

    .passthrough_ddr_enable(cache_port_cmd_valid_s[CACHE_PORT_IDX_DBUS]),
    .passthrough_ddr_req_ack(cache_port_cmd_ready_n[CACHE_PORT_IDX_DBUS]),
    .passthrough_ddr_rsp_valid(cache_port_rsp_valid_n[CACHE_PORT_IDX_DBUS]),
    .passthrough_ddr_data(iob_ddr_read_data),

    .passthrough_ddr_ctrl_enable(ddr_ctrl_cmd_valid),
    .passthrough_ddr_ctrl_req_ack(ddr_ctrl_cmd_ready),
    .passthrough_ddr_ctrl_rsp_valid(ddr_ctrl_rsp_valid),
    .passthrough_ddr_ctrl_data(ddr_ctrl_rsp_data),

    .passthrough_irq_enable(irq_enable),
    .passthrough_irq_req_ack(irq_req_ack),
    .passthrough_irq_rsp_data(irq_rsp_data),
    .passthrough_irq_rsp_valid(irq_rsp_valid),

    .passthrough_spi_enable(spi_enable),
    .passthrough_spi_req_ack(spi_req_ack),
    .passthrough_spi_rsp_data(spi_rsp_data),
    .passthrough_spi_rsp_valid(spi_rsp_valid),

    .passthrough_gpio_enable(gpio_enable),
    .passthrough_gpio_req_ack(gpio_req_ack),
    .passthrough_gpio_rsp_data(gpio_rsp_data),
    .passthrough_gpio_rsp_valid(gpio_rsp_valid),

    .uart_tx(uart_tx),
    .uart_rx(uart_rx)
);

cache#(
    .CACHELINE_BITS(CACHELINE_BITS),
    .NUM_CACHELINES(INST_CACHE_NUM_CACHELINES),
    .BACKEND_SIZE_BYTES(DDR_MEM_SIZE),
    .NUM_PORTS(1)
) inst_cache(
    .clock_i(ctrl_cpu_clock),

    .ctrl_cmd_addr_i(),
    .ctrl_cmd_valid_i(),
    .ctrl_cmd_ready_o(),
    .ctrl_cmd_write_i(),
    .ctrl_cmd_data_i(),
    .ctrl_rsp_valid_o(),
    .ctrl_rsp_data_o(),

    .port_cmd_valid_i(inst_cache_port_cmd_valid_s),
    .port_cmd_addr_i(inst_cache_port_cmd_addr_s),
    .port_cmd_ready_o(inst_cache_port_cmd_ready_n),
    .port_cmd_write_mask_i(inst_cache_port_cmd_write_mask_s),
    .port_cmd_write_data_i(inst_cache_port_cmd_write_data_s),
    .port_rsp_valid_o(inst_cache_port_rsp_valid_n),
    .port_rsp_read_data_o(inst_cache_port_rsp_read_data_n),

    .backend_cmd_valid_o(cache_port_cmd_valid_s[CACHE_PORT_IDX_IBUS]),
    .backend_cmd_addr_o(cache_port_cmd_addr_s[CACHE_PORT_IDX_IBUS]),
    .backend_cmd_ready_i(cache_port_cmd_ready_n[CACHE_PORT_IDX_IBUS]),
    .backend_cmd_write_o(),
    .backend_cmd_write_data_o(),
    .backend_rsp_valid_i(cache_port_rsp_valid_n[CACHE_PORT_IDX_IBUS]),
    .backend_rsp_read_data_i(cache_port_rsp_read_data_n[CACHE_PORT_IDX_IBUS])
);

assign cache_port_cmd_write_mask_s[CACHE_PORT_IDX_IBUS] = { CACHELINE_BYTES{1'b0} };

cache#(
    .CACHELINE_BITS(CACHELINE_BITS),
    .NUM_CACHELINES(NUM_CACHELINES),
    .BACKEND_SIZE_BYTES(DDR_MEM_SIZE),
    .INIT_FILE("boot_loader.mem"),
    .STATE_INIT("boot_loader_state.mem"),
    .NUM_PORTS(CACHE_PORTS_NUM)
) cache(
    .clock_i(ctrl_cpu_clock),

    .ctrl_cmd_addr_i(),
    .ctrl_cmd_valid_i(),
    .ctrl_cmd_ready_o(),
    .ctrl_cmd_write_i(),
    .ctrl_cmd_data_i(),
    .ctrl_rsp_valid_o(),
    .ctrl_rsp_data_o(),

    .port_cmd_valid_i(cache_port_cmd_valid_s),
    .port_cmd_addr_i(cache_port_cmd_addr_s),
    .port_cmd_ready_o(cache_port_cmd_ready_n),
    .port_cmd_write_mask_i(cache_port_cmd_write_mask_s),
    .port_cmd_write_data_i(cache_port_cmd_write_data_s),
    .port_rsp_valid_o(cache_port_rsp_valid_n),
    .port_rsp_read_data_o(cache_port_rsp_read_data_n),

    .backend_cmd_valid_o(ddr_data_cmd_valid),
    .backend_cmd_addr_o(ddr_data_cmd_address),
    .backend_cmd_ready_i(ddr_data_cmd_ack),
    .backend_cmd_write_o(ddr_data_cmd_write),
    .backend_cmd_write_data_o(ddr_cmd_write_data),
    .backend_rsp_valid_i(ddr_data_rsp_valid),
    .backend_rsp_read_data_i(ddr_data_rsp_read_data)
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
wire ddr_phy_data_transfer, ddr_phy_data_write, ddr_phy_write_level, ddr_phy_dqs_out;
wire [15:0] ddr_phy_dq_i[7:0], ddr_phy_dq_o[1:0];
wire [31:0] ddr_phy_delay_inc;

sddr_ctrl#(
    .tRCD(5),                           // 13.75ns
    .tRC(15),                           // 48.75ns
    .tRP(5),                            // 13.75ns
    .tRFC(49),                          // 160ns minimum
    .tREFI(78*CTRL_CLOCK_HZ/10000000)   // 7.8us at CPU clock
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
    .ctrl_rsp_valid(ddr_ctrl_rsp_valid),
    .ctrl_rsp_data(ddr_ctrl_rsp_data),

    .data_cmd_valid(ddr_data_cmd_valid),
    .data_cmd_ack(ddr_data_cmd_ack),
    .data_cmd_data_i(ddr_cmd_write_data),
    .data_cmd_address(ddr_data_cmd_address[27:0]),
    .data_cmd_write(ddr_data_cmd_write),
    .data_rsp_valid(ddr_data_rsp_valid),
    .data_rsp_data_o(ddr_data_rsp_read_data),

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
    .data_write_o(ddr_phy_data_write),
    .write_level_o(ddr_phy_write_level),
    .delay_inc_o(ddr_phy_delay_inc),
    .dqs_out_o(ddr_phy_dqs_out)
);

sddr_phy_xilinx ddr_phy(
     .in_cpu_clock_i(ctrl_cpu_clock)
    ,.in_ddr_clock_i(ddr_clock)
//     .in_ddr_clock_i(ctrl_cpu_clock)
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
    ,.ctl_write_level_i(ddr_phy_write_level)
    ,.ctl_delay_inc_i(ddr_phy_delay_inc)
    ,.ctl_out_dqs_i(ddr_phy_dqs_out)

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
    .rsp_valid_o(irq_rsp_valid),

    .interrupt_o(ctrl_timer_interrupt)
);

gpio#(.NUM_IN_PORTS(1)) gpio(
    .clock_i(ctrl_cpu_clock),
    .req_addr_i(ctrl_dBus_cmd_payload_address[15:0]),
    .req_data_i(ctrl_dBus_cmd_payload_data),
    .req_write_i(ctrl_dBus_cmd_payload_wr),
    .req_valid_i(gpio_enable),
    .req_ready_o(gpio_req_ack),

    .rsp_data_o(gpio_rsp_data),
    .rsp_valid_o(gpio_rsp_valid),

    .gp_in( '{ { 31'b0, uart_output } } ),
    .gp_out()
);

wire spi_flash_dma_write;
spi_ctrl#(.MEM_DATA_WIDTH(CACHELINE_BITS)) spi_flash(
    .cpu_clock_i(ctrl_cpu_clock),
    .spi_ref_clock_i(board_clock),
    .irq(),

    .debug(debug),

    .ctrl_cmd_valid_i(spi_enable),
    .ctrl_cmd_address_i(ctrl_dBus_cmd_payload_address[15:0]),
    .ctrl_cmd_data_i(ctrl_dBus_cmd_payload_data),
    .ctrl_cmd_write_i(ctrl_dBus_cmd_payload_wr),
    .ctrl_cmd_ack_o(spi_req_ack),

    .ctrl_rsp_valid_o(spi_rsp_valid),
    .ctrl_rsp_data_o(spi_rsp_data),

    .spi_cs_n_o(spi_cs_n),
    .spi_dq_io(spi_dq),
    .spi_clk_o(spi_clk),

    .dma_cmd_valid_o(cache_port_cmd_valid_s[CACHE_PORT_IDX_SPI_FLASH]),
    .dma_cmd_address_o(cache_port_cmd_addr_s[CACHE_PORT_IDX_SPI_FLASH]),
    .dma_cmd_data_o(cache_port_cmd_write_data_s[CACHE_PORT_IDX_SPI_FLASH]),
    .dma_cmd_write_o(spi_flash_dma_write),
    .dma_cmd_ack_i(cache_port_cmd_ready_n[CACHE_PORT_IDX_SPI_FLASH]),

    .dma_rsp_valid_i(cache_port_rsp_valid_n[CACHE_PORT_IDX_SPI_FLASH]),
    .dma_rsp_data_i(cache_port_rsp_read_data_n[CACHE_PORT_IDX_SPI_FLASH])
);

STARTUPE2 startup_cfg(
    .GSR(1'b0),
    .GTS(1'b0),
    .KEYCLEARB(1'b0),
    .PACK(1'b0),
    .PREQ(),
    .USRCCLKO(spi_clk),
    .USRCCLKTS(spi_cs_n),
    .USRDONEO(1'b1),
    .USRDONETS(1'b1)
);

genvar i;
generate
    for(i=0; i<CACHELINE_BYTES; ++i)
        assign cache_port_cmd_write_mask_s[CACHE_PORT_IDX_SPI_FLASH][i] = spi_flash_dma_write;
endgenerate

endmodule
