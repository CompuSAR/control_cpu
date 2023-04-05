`timescale 1ns / 1ps

module cache#(
        CACHELINE_BITS = 128,
        NUM_CACHELINES = 1024,
        INIT_FILE = "",
        STATE_INIT = "",
        NUM_PORTS = 1
    )(
        input                                                           clock_i,

        input [15:0]                                                    ctrl_cmd_addr_i,
        input                                                           ctrl_cmd_valid_i,
        output                                                          ctrl_cmd_ready_o,
        input                                                           ctrl_cmd_write_i,
        input [31:0]                                                    ctrl_cmd_data_i,
        output                                                          ctrl_rsp_valid_o,
        output [31:0]                                                   ctrl_rsp_data_o,

        input [$clog2(NUM_CACHELINES)-1:0]                              port_cmd_addr_i[NUM_PORTS],
        input                                                           port_cmd_valid_i[NUM_PORTS],
        output                                                          port_cmd_ready_o[NUM_PORTS],
        input [CACHELINE_BITS/8-1:0]                                    port_cmd_write_mask_i[NUM_PORTS],
        input [CACHELINE_BITS-1:0]                                      port_cmd_data_i[NUM_PORTS],
        output                                                          port_rsp_ready[NUM_PORTS],
        output [CACHELINE_BITS-1:0]                                     port_rsp_data_o[NUM_PORTS],

        output [$clog2(NUM_CACHELINES)-1:0]                             backend_cmd_addr_o,
        output                                                          backend_cmd_valid_o,
        input                                                           backend_cmd_ready_i,
        output                                                          backend_cmd_write_o,
        output [CACHELINE_BITS-1:0]                                     backend_cmd_write_data_o,
        input                                                           backend_rsp_ready,
        input                                                           backend_rsp_data_i
    );

xpm_memory_tdpram#(
    .CLOCKING_MODE("common_clock"),
    .ECC_MODE("no_ecc"),
//    .CASCADE_HEIGHT(1),
    .MEMORY_INIT_FILE(INIT_FILE),
    .MEMORY_PRIMITIVE("block"),
    .MEMORY_SIZE(CACHELINE_BITS * NUM_CACHELINES),
//    .SIM_ASSERT_CHK(1),
    .USE_MEM_INIT(INIT_FILE != ""),

    .ADDR_WIDTH_A($clog2(NUM_CACHELINES)),
    .READ_DATA_WIDTH_A(CACHELINE_BITS),
    .READ_LATENCY_A(1),
    .WRITE_DATA_WIDTH_A(CACHELINE_BITS),
    .BYTE_WRITE_WIDTH_A(8),
    .WRITE_MODE_A("read_first"),

    .ADDR_WIDTH_B($clog2(NUM_CACHELINES)),
    .READ_DATA_WIDTH_B(CACHELINE_BITS),
    .READ_LATENCY_B(1),
    .WRITE_DATA_WIDTH_B(CACHELINE_BITS),
    .BYTE_WRITE_WIDTH_B(CACHELINE_BITS),
    .WRITE_MODE_B("read_first"),

    .WRITE_PROTECT(1)
) cache_mem(
    .clka( clock_i )

);


endmodule
