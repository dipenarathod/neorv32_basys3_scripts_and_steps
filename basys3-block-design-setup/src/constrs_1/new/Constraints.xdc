## Clock signal
set_property PACKAGE_PIN W5 [get_ports clk_i]
set_property IOSTANDARD LVCMOS33 [get_ports clk_i]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk_i]

## Reset button (use the center button)
set_property PACKAGE_PIN U18 [get_ports rstn_i]
set_property IOSTANDARD LVCMOS33 [get_ports rstn_i]

set_property PACKAGE_PIN U3 [get_ports {gpio_o[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[7]}]
set_property PACKAGE_PIN W3 [get_ports {gpio_o[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[6]}]
set_property PACKAGE_PIN V3 [get_ports {gpio_o[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[5]}]
set_property PACKAGE_PIN V13 [get_ports {gpio_o[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[4]}]
set_property PACKAGE_PIN V19 [get_ports {gpio_o[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[3]}]
set_property PACKAGE_PIN U19 [get_ports {gpio_o[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[2]}]
set_property PACKAGE_PIN E19 [get_ports {gpio_o[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[1]}]
set_property PACKAGE_PIN U16 [get_ports {gpio_o[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[0]}]

## UART TX Pin (using PMOD connector JA)
set_property PACKAGE_PIN J1 [get_ports uart0_txd_o]
set_property IOSTANDARD LVCMOS33 [get_ports uart0_txd_o]

## UART RX Pin (using PMOD connector JA)
set_property PACKAGE_PIN L2 [get_ports uart0_rxd_i]
set_property IOSTANDARD LVCMOS33 [get_ports uart0_rxd_i]