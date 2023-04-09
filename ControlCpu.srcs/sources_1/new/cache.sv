`timescale 1ns / 1ps

module cache#(
        ADDR_BITS = 32,
        CACHELINE_BITS = 128,
        NUM_CACHELINES = 1024,
        BACKEND_SIZE_BYTES = 0,
        INIT_FILE = "none",
        STATE_INIT = "none",
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

        input                                                           port_cmd_valid_i[NUM_PORTS],
        input [ADDR_BITS-1:0]                                           port_cmd_addr_i[NUM_PORTS],
        output                                                          port_cmd_ready_o[NUM_PORTS],
        input [CACHELINE_BITS/8-1:0]                                    port_cmd_write_mask_i[NUM_PORTS],
        input [CACHELINE_BITS-1:0]                                      port_cmd_write_data_i[NUM_PORTS],
        output                                                          port_rsp_valid_o[NUM_PORTS],
        output [CACHELINE_BITS-1:0]                                     port_rsp_read_data_o[NUM_PORTS],

        output logic                                                    backend_cmd_valid_o,
        output [ADDR_BITS-1:0]                                          backend_cmd_addr_o,
        input                                                           backend_cmd_ready_i,
        output                                                          backend_cmd_write_o,
        output [CACHELINE_BITS-1:0]                                     backend_cmd_write_data_o,
        input                                                           backend_rsp_valid_i,
        input                                                           backend_rsp_read_data_i
    );

localparam LINES_ADDR_BITS = $clog2(NUM_CACHELINES);
localparam BACKEND_COMPLEMENTARY_ADDRESS = $clog2(BACKEND_SIZE_BYTES) - LINES_ADDR_BITS - $clog2(CACHELINE_BITS/8);

localparam EMPTY_WRITE_MASK = { CACHELINE_BITS/8{1'b0} };

localparam ADDR_CACHELINE_OFFSET_LOW = 0;
localparam ADDR_CACHELINE_OFFSET_HIGH = $clog2(CACHELINE_BITS/8) - 1;
localparam ADDR_CACHELINE_ADDR_LOW = ADDR_CACHELINE_OFFSET_HIGH + 1;
localparam ADDR_CACHELINE_ADDR_HIGH = ADDR_CACHELINE_ADDR_LOW + LINES_ADDR_BITS - 1;
localparam ADDR_COMPLEMENTARY_LOW = ADDR_CACHELINE_ADDR_HIGH + 1;
localparam ADDR_COMPLEMENTARY_HIGH = $clog2(BACKEND_SIZE_BYTES) - 1;

function logic[ADDR_CACHELINE_ADDR_HIGH:ADDR_CACHELINE_ADDR_LOW] extract_cacheline_addr(input [ADDR_BITS-1:0] address);
    extract_cacheline_addr = address[ADDR_CACHELINE_ADDR_HIGH:ADDR_CACHELINE_ADDR_LOW];
endfunction

function logic[ADDR_COMPLEMENTARY_HIGH:ADDR_COMPLEMENTARY_LOW] extract_complement_addr(input [ADDR_BITS-1:0] address);
    extract_complement_addr = address[ADDR_COMPLEMENTARY_HIGH:ADDR_COMPLEMENTARY_LOW];
endfunction

typedef struct packed {
    logic                                               initialized;
    logic                                               dirty;
    logic [BACKEND_COMPLEMENTARY_ADDRESS-1:0]           source_address;
} CachelineMetadata;

logic [LINES_ADDR_BITS-1:0]             md_north_addr, md_south_addr;
CachelineMetadata                       md_south_din;
CachelineMetadata                       md_north_dout, md_south_dout;
logic                                   md_north_enable, md_south_enable;
logic                                   md_south_we;

logic [LINES_ADDR_BITS-1:0]             cache_port_addr, cache_mem_addr;
logic [CACHELINE_BITS-1:0]              cache_port_din, cache_mem_din;
logic                                   cache_port_enable;
logic                                   cache_mem_enable;
logic [CACHELINE_BITS/8-1:0]            cache_port_we, cache_mem_we;

logic [CACHELINE_BITS-1:0]              port_rsp_data;

xpm_memory_dpdistram#(
    .CLOCKING_MODE("common_clock"),
    .MEMORY_INIT_FILE(STATE_INIT),
    .MEMORY_SIZE($bits(CachelineMetadata) * NUM_CACHELINES),
//    .SIM_ASSERT_CHK(1),
    .USE_MEM_INIT(STATE_INIT != "none"),

    .ADDR_WIDTH_A($clog2(NUM_CACHELINES)),
    .READ_DATA_WIDTH_A($bits(CachelineMetadata)),
    .READ_LATENCY_A(0),
    .WRITE_DATA_WIDTH_A($bits(CachelineMetadata)),
    .BYTE_WRITE_WIDTH_A($bits(CachelineMetadata)),

    .ADDR_WIDTH_B($clog2(NUM_CACHELINES)),
    .READ_DATA_WIDTH_B($bits(CachelineMetadata)),
    .READ_LATENCY_B(0)
) cache_metadata(
    .clka( clock_i ),
    .addra( md_south_addr ),
    .dina( md_south_din ),
    .douta( md_south_dout ),
    .ena( md_south_enable ),
    .regcea( 1'b1 ),
    .rsta( 1'b0 ),
    .wea( md_south_we ),

    .clkb( clock_i ),
    .addrb( md_north_addr ),
    .doutb( md_north_dout ),
    .enb( md_north_enable ),
    .regceb( 1'b1 ),
    .rstb( 1'b0 )
);

xpm_memory_tdpram#(
    .CLOCKING_MODE("common_clock"),
    .ECC_MODE("no_ecc"),
//    .CASCADE_HEIGHT(1),
    .MEMORY_INIT_FILE(INIT_FILE),
    .MEMORY_PRIMITIVE("block"),
    .MEMORY_SIZE(CACHELINE_BITS * NUM_CACHELINES),
//    .SIM_ASSERT_CHK(1),
    .USE_MEM_INIT(INIT_FILE != "none"),

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
    .clka( clock_i ),
    .addra( cache_port_addr ),
    .dina( cache_port_din ),
    .douta( port_rsp_data ),
    .ena( cache_port_enable ),
    .injectdbiterra( 1'b0 ),
    .injectsbiterra( 1'b0 ),
    .regcea( 1'b1 ),
    .rsta( 1'b0 ),
    .wea( cache_port_we ),

    .clkb( clock_i ),
    .addrb( cache_mem_addr ),
    .dinb( cache_mem_din ),
    .enb( cache_mem_enable ),
    .injectdbiterrb( 1'b0 ),
    .injectsbiterrb( 1'b0 ),
    .regceb( 1'b1 ),
    .rstb( 1'b0 ),
    .web( cache_mem_we ),

    .sleep( 1'b0 )
);

enum { IDLE, EVICTING, FETCHING, RESULT } command_state = IDLE, command_state_next;
wire command_active = command_state!=IDLE && command_state!=RESULT;
logic set_command_active;
struct {
    logic [ADDR_COMPLEMENTARY_HIGH-ADDR_CACHELINE_ADDR_HIGH:0]  address;
    logic [CACHELINE_BITS/8-1:0]                                write_mask;
    logic [CACHELINE_BITS-1:0]                                  write_data;

    logic [$clog2(NUM_PORTS)-1:0]                               active_port;
} active_command;

genvar i;
generate
    for(i=0; i<NUM_PORTS; i++) begin : port_state
        wire pending, prev_pending;

        assign pending = port_cmd_valid_i[i];
        assign port_cmd_ready_o[i] = !prev_pending && !command_active;
        assign port_rsp_read_data_o[i] = port_rsp_data;
        assign port_rsp_valid_o[i] = command_state==RESULT && active_command.active_port==i;

        wire [$clog2(NUM_PORTS)-1:0] next_active;
        wire [$clog2(NUM_PORTS)-1:0] active_port = pending && !prev_pending ? i : next_active;
    end : port_state

    assign port_state[0].prev_pending = 1'b0;
    for(i=1; i<NUM_PORTS; i++) begin
        assign port_state[i].prev_pending = port_state[i-1].pending || port_state[i-1].prev_pending;
    end

    assign port_state[NUM_PORTS-1].next_active = 0;
    for(i=0; i<NUM_PORTS-1; i++) begin
        assign port_state[i].next_active = port_state[i+1].active_port;
    end
endgenerate

wire [$clog2(NUM_PORTS)-1:0] active_port = port_state[0].active_port;

task cache_write(input [ADDR_BITS-1:0] address, input [CACHELINE_BITS-1:0]data, input [CACHELINE_BITS/8-1:0] mask);
    command_state_next = IDLE;

    md_south_addr = extract_cacheline_addr(address);
    md_south_din.initialized = 1'b1;
    md_south_din.dirty = 1'b1;
    md_south_din.source_address = extract_complement_addr(address);
    md_south_enable = 1'b1;
    md_south_we = 1'b1;

    cache_port_addr = extract_cacheline_addr(address);
    cache_port_din = data;
    cache_port_we = mask;
    cache_port_enable = 1'b1;
endtask

always_comb begin
    md_north_enable = 1'b0;
    md_south_enable = 1'b0;
    set_command_active = 1'b0;
    backend_cmd_valid_o = 1'b0;
    cache_port_enable = 1'b0;
    cache_mem_enable = 1'b0;

    case(command_state)
        IDLE: begin end
        RESULT: begin
            command_state_next=IDLE;
        end
    endcase

    if( port_cmd_valid_i[active_port] && port_cmd_ready_o[active_port] ) begin
        // We have a pending command
        md_north_addr = extract_cacheline_addr(port_cmd_addr_i[active_port]);
        md_north_enable = 1'b1;

        set_command_active = 1'b1;

        if( md_north_dout.initialized ) begin
            // Cacheline has data
            if( md_north_dout.source_address == extract_complement_addr(port_cmd_addr_i[active_port]) ) begin
                // Cache hit
                if( port_cmd_write_mask_i[active_port]==0 ) begin
                    // Read
                    command_state_next = RESULT;

                    cache_port_addr = extract_cacheline_addr(port_cmd_addr_i[active_port]);
                    cache_port_enable = 1'b1;
                    cache_port_we = 1'b0;
                end else begin
                    // Write
                    // Our north port for the metadata doesn't have a write
                    // port, so we're routing the dirtying through the
                    // otherwise idle stored command
                    cache_write(
                        port_cmd_addr_i[active_port],
                        port_cmd_write_data_i[active_port],
                        port_cmd_write_mask_i[active_port]);
                end
            end else begin
                // Cache miss

                if( md_north_dout.dirty )
                    command_state_next = EVICTING;
                else begin
                    // Current cacheline is not dirty
                    case( port_cmd_write_mask_i[active_port] )
                        {CACHELINE_BITS/8{1'b0}}: command_state_next = FETCHING; // Read
                        {CACHELINE_BITS/8{1'b1}}: cache_write( // Write to all bits
                                                        port_cmd_addr_i[active_port],
                                                        port_cmd_write_data_i[active_port],
                                                        port_cmd_write_mask_i[active_port]);
                        default: command_state_next = FETCHING;
                    endcase
                end
            end
        end else begin
            // Cacheline empty
            case( port_cmd_write_mask_i[active_port] )
                {CACHELINE_BITS/8{1'b0}}: command_state_next = FETCHING; // Read
                {CACHELINE_BITS/8{1'b1}}: cache_write( // Write to all bits
                                                port_cmd_addr_i[active_port],
                                                port_cmd_write_data_i[active_port],
                                                port_cmd_write_mask_i[active_port]);
                default: command_state_next = FETCHING;
            endcase
        end
    end
end

always_ff@(posedge clock_i) begin
    command_state <= command_state_next;

    if( set_command_active ) begin
        active_command.active_port <= active_port;
        active_command.address <= port_cmd_addr_i[active_port][ADDR_COMPLEMENTARY_HIGH:ADDR_CACHELINE_ADDR_LOW];
        active_command.write_mask <= port_cmd_write_mask_i[active_port];
        active_command.write_data <= port_cmd_write_data_i[active_port];
    end else begin
    end
end

endmodule
