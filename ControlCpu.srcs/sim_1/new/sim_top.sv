`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/23/2022 11:06:24 AM
// Design Name: 
// Module Name: sim_top
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


module sim_top(

    );

logic clock, nReset;
logic running;

assign nReset = 1;

top top_module(.board_clock(clock), .nReset(nReset), .running(running));

initial begin
    clock = 0;
    forever
    begin
        #10 clock = 1;
        #10 clock = 0;
    end
end

endmodule
