create_clock -period 20.000 [get_ports board_clock]
set_property PACKAGE_PIN H13 [get_ports board_clock]
set_property IOSTANDARD LVCMOS33 [get_ports board_clock]

set_property PACKAGE_PIN F4 [get_ports nReset]
set_property IOSTANDARD LVCMOS15 [get_ports nReset]

set_property PACKAGE_PIN L14 [get_ports uart_output]
set_property IOSTANDARD LVCMOS33 [get_ports uart_output]
set_property PULLUP true [get_ports uart_output]

set_property PACKAGE_PIN E11 [get_ports debug]
set_property IOSTANDARD LVCMOS33 [get_ports debug]

set_property PACKAGE_PIN P10 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]

set_property PACKAGE_PIN N10 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

############## NET - IOSTANDARD ##################
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]

#############SPI Configurate Setting##################
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]


create_clock -period 3.299 -name VIRTUAL_ddr_clock -waveform {0.000 1.649}
#set_output_delay -clock [get_clocks VIRTUAL_ddr_clock] -clock_fall -min -add_delay -4.949 [get_ports ddr3_cas_n]
#set_output_delay -clock [get_clocks VIRTUAL_ddr_clock] -clock_fall -max -add_delay -1.464 [get_ports ddr3_cas_n]
#set_output_delay -clock [get_clocks VIRTUAL_ddr_clock] -clock_fall -min -add_delay -4.949 [get_ports ddr3_ras_n]
#set_output_delay -clock [get_clocks VIRTUAL_ddr_clock] -clock_fall -max -add_delay -1.464 [get_ports ddr3_ras_n]
#set_output_delay -clock [get_clocks VIRTUAL_ddr_clock] -clock_fall -min -add_delay -4.949 [get_ports ddr3_we_n]
#set_output_delay -clock [get_clocks VIRTUAL_ddr_clock] -clock_fall -max -add_delay -1.464 [get_ports ddr3_we_n]

create_clock -period 3.299 -name {ddr3_dqs_p[0]} -waveform {0.000 1.650} [get_ports {ddr3_dqs_p[0]}]
create_clock -period 3.299 -name {ddr3_dqs_p[1]} -waveform {0.000 1.650} [get_ports {ddr3_dqs_p[1]}]
set_input_delay -clock [get_clocks {ddr3_dqs_p[0]}] -clock_fall -min -add_delay -0.296 [get_ports {ddr3_dq[*]}]
set_input_delay -clock [get_clocks {ddr3_dqs_p[0]}] -clock_fall -max -add_delay 0.200 [get_ports {ddr3_dq[*]}]
set_input_delay -clock [get_clocks {ddr3_dqs_p[0]}] -min -add_delay -0.296 [get_ports {ddr3_dq[*]}]
set_input_delay -clock [get_clocks {ddr3_dqs_p[0]}] -max -add_delay 0.200 [get_ports {ddr3_dq[*]}]
set_input_delay -clock [get_clocks {ddr3_dqs_p[1]}] -clock_fall -min -add_delay -0.296 [get_ports {ddr3_dq[*]}]
set_input_delay -clock [get_clocks {ddr3_dqs_p[1]}] -clock_fall -max -add_delay 0.200 [get_ports {ddr3_dq[*]}]
set_input_delay -clock [get_clocks {ddr3_dqs_p[1]}] -min -add_delay -0.296 [get_ports {ddr3_dq[*]}]
set_input_delay -clock [get_clocks {ddr3_dqs_p[1]}] -max -add_delay 0.200 [get_ports {ddr3_dq[*]}]
