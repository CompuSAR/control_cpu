create_clock -period 20.000 [get_ports board_clock]
set_property PACKAGE_PIN H13 [get_ports board_clock]
set_property IOSTANDARD LVCMOS33 [get_ports board_clock]

set_property PACKAGE_PIN F4 [get_ports nReset]
set_property IOSTANDARD LVCMOS15 [get_ports nReset]

set_property PACKAGE_PIN L14 [get_ports enable_uart_output]
set_property IOSTANDARD LVCMOS33 [get_ports enable_uart_output]
set_property PULLTYPE PULLUP [get_ports enable_uart_output]

set_property PACKAGE_PIN E11 [get_ports {leds[1]}]
set_property PACKAGE_PIN M10 [get_ports {leds[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[0]}]

set_property PACKAGE_PIN M13 [get_ports {debug[0]}]
set_property PACKAGE_PIN L12 [get_ports {debug[1]}]
set_property PACKAGE_PIN K11 [get_ports {debug[2]}]
set_property PACKAGE_PIN J13 [get_ports {debug[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug}]

set_property PACKAGE_PIN P10 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]

set_property PACKAGE_PIN N10 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

set_property PACKAGE_PIN C11 [get_ports spi_cs_n]
# set_property PACKAGE_PIN A8 [get_ports spi_clk]
set_property PACKAGE_PIN B11 [get_ports {spi_dq[0]}]
set_property PACKAGE_PIN B12 [get_ports {spi_dq[1]}]
set_property PACKAGE_PIN D10 [get_ports {spi_dq[2]}]
set_property PACKAGE_PIN C10 [get_ports {spi_dq[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports spi_*]

############## NET - IOSTANDARD ##################
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]

#############SPI Configurate Setting##################
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]


create_clock -period 3.299 -name VIRTUAL_ddr_clock -waveform {0.000 1.649}

set_output_delay -clock [get_clocks board_clock] -max -add_delay -1.500 [get_ports {spi_dq[*]}]
#set_output_delay -clock [get_clocks board_clock] -max -add_delay 1.750 [get_ports {spi_dq[*]}]
set_output_delay -clock [get_clocks board_clock] -min -add_delay 0 [get_ports spi_cs_n]
set_output_delay -clock [get_clocks board_clock] -max -add_delay 0 [get_ports spi_cs_n]

#set_input_delay -clock [get_clocks board_clock] -min -add_delay 2.300 [get_ports {spi_dq[*]}]
#set_input_delay -clock [get_clocks board_clock] -max -add_delay 8.500 [get_ports {spi_dq[*]}]
