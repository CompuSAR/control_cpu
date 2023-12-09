`timescale 1ns / 1ps

module timer_int_ctrl#(
    parameter CLOCK_HZ=50000000
)
(
    input clock,

    // Request
    input [15:0]        req_addr_i,
    input [31:0]        req_data_i,
    input               req_write_i,
    input               req_valid_i,
    output logic        req_ready_o,

    // Response
    output logic[31:0]  rsp_data_o,
    output logic        rsp_valid_o,

    // Self explanatory
    output logic        interrupt_o
);

logic[63:0] cycles_counter = 64'h0;
logic[31:0] cycles_counter_saved;
logic       cycles_counter_save_flag;
logic[63:0] wait_cycle, wait_cycle_next;
logic[31:0] pending_address, pending_address_next;
logic prev_valid = 1'b0, prev_valid_next;

assign interrupt_o = wait_expired;

always_ff@(posedge clock) begin
    cycles_counter <= cycles_counter+1;

    prev_valid <= prev_valid_next;
    pending_address <= pending_address_next;

    if( cycles_counter_save_flag )
        cycles_counter_saved <= cycles_counter[63:32];

    wait_cycle <= wait_cycle_next;
end

always_comb begin
    // Keep state for next cycle

    if( req_valid_i && req_ready_o ) begin
        if( req_write_i ) begin
            prev_valid_next = prev_valid;
            pending_address_next = pending_address;
        end else begin
            pending_address_next = req_addr_i;
            prev_valid_next = 1'b1;
        end
    end else if( prev_valid && !rsp_valid_o ) begin
        prev_valid_next = 1'b1;
        pending_address_next = pending_address;
    end else begin
        prev_valid_next = 1'b0;
        pending_address_next = 32'hX;
    end
end

logic wait_expired;

always_ff@(posedge clock) begin
    wait_expired <= wait_cycle <= cycles_counter;
end

always_comb begin
    // Handle response
    cycles_counter_save_flag = 1'b0;
    rsp_data_o = 32'hX;
    rsp_valid_o = 1'bX;

    if( prev_valid ) begin
        rsp_valid_o = 1'b1;
        case( pending_address )
            16'h0000: begin     // Halt
                if(!wait_expired) begin
                    rsp_valid_o = 1'b0;
                end else begin
                    rsp_valid_o = 1'b1;
                    rsp_data_o = cycles_counter[31:0];
                    cycles_counter_save_flag = 1'b1;
                end
            end
            16'h0004:           // Clock frequency
                rsp_data_o = CLOCK_HZ;
            16'h0008: begin     // Cycle count low
                rsp_data_o = cycles_counter[31:0];
                cycles_counter_save_flag = 1'b1;
            end
            16'h000c:           // Cycle count high
                rsp_data_o = cycles_counter_saved;
            16'h0010:           // Wait cycle low
                rsp_data_o = wait_cycle[31:0];
            16'h0014:           // Wait cycle high
                rsp_data_o = wait_cycle[63:32];
        endcase
    end
end

always_comb begin
    // Handle request

    req_ready_o = 1'bX;
    wait_cycle_next = wait_cycle;
    if( req_valid_i ) begin
        req_ready_o = 1'b1;  // Accept request by default

        if( req_write_i ) begin
            // Write
            case(req_addr_i)
                16'h0010: // Wait cycle low
                    wait_cycle_next[31:0] = req_data_i;
                16'h0014: // Wait cycle high
                    wait_cycle_next[63:32] = req_data_i;
            endcase
        end
    end
end

endmodule
