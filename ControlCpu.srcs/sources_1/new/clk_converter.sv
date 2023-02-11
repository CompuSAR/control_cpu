`timescale 1ns / 1ps

module clk_converter(
    input clk_in1,
    input reset,

    output clk_ctrl_cpu,
    output clk_ddr,
    output clk_ddr_90deg,
    output clk_ddr_180deg,
    output clk_ddr_270deg,

    output clkfb_out,
    input clkfb_in,

    output locked
);

MMCME2_BASE#(
    .DIVCLK_DIVIDE(4),
    .CLKFBOUT_MULT_F(48.5),
    .CLKIN1_PERIOD(20.000),     // 50MHz input clock
    .CLKOUT1_DIVIDE(6),         // 101.041666667MHz output
    .CLKOUT2_DIVIDE(2),         // 303.125MHz output
    .CLKOUT3_DIVIDE(2),         // 303.125MHz output
    .CLKOUT3_PHASE(90)
) mmcm(
    .CLKIN1(clk_in1),

    .CLKFBIN(clkfb_in),
    .CLKFBOUT(clkfb_out),

    .CLKOUT1(clk_ctrl_cpu),
    .CLKOUT2(clk_ddr),
    .CLKOUT2B(clk_ddr_180deg),
    .CLKOUT3(clk_ddr_90deg),
    .CLKOUT3B(clk_ddr_270deg),

    .PWRDWN(1'b0),
    .RST(reset),
    .LOCKED(locked)
);

endmodule
