## Clock signal 100 MHz
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { CLK_100MHZ_FPGA }];
create_clock -add -name clk_100mhz_fpga -period 10.00 -waveform {0 5} [get_ports { CLK_100MHZ_FPGA }];

## LEDs (Using the first 6 LEDs above the switches)
set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { LEDS[0] }];
set_property -dict { PACKAGE_PIN K15   IOSTANDARD LVCMOS33 } [get_ports { LEDS[1] }];
set_property -dict { PACKAGE_PIN J13   IOSTANDARD LVCMOS33 } [get_ports { LEDS[2] }];
set_property -dict { PACKAGE_PIN N14   IOSTANDARD LVCMOS33 } [get_ports { LEDS[3] }];
set_property -dict { PACKAGE_PIN R18   IOSTANDARD LVCMOS33 } [get_ports { LEDS[4] }];
set_property -dict { PACKAGE_PIN V17   IOSTANDARD LVCMOS33 } [get_ports { LEDS[5] }];

## Buttons
# BUTTONS[0] is mapped to BTNC (Center Button) - Used for Reset in z1top
set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { BUTTONS[0] }];
# BUTTONS[1] is mapped to BTNU (Up Button)
set_property -dict { PACKAGE_PIN M18   IOSTANDARD LVCMOS33 } [get_ports { BUTTONS[1] }];
# BUTTONS[2] is mapped to BTND (Down Button)
set_property -dict { PACKAGE_PIN P18   IOSTANDARD LVCMOS33 } [get_ports { BUTTONS[2] }];
# BUTTONS[3] is mapped to BTNL (Left Button)
set_property -dict { PACKAGE_PIN P17   IOSTANDARD LVCMOS33 } [get_ports { BUTTONS[3] }];

## Switches (Using SW0 and SW1)
# SW0 selects the mode (Memory Controller vs. Optional Piano)
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { SWITCHES[0] }];
set_property -dict { PACKAGE_PIN L16   IOSTANDARD LVCMOS33 } [get_ports { SWITCHES[1] }];

## UART (Onboard USB-UART Bridge)
# FPGA_SERIAL_RX receives data from the computer (Connected to UART_TXD_IN)
set_property -dict { PACKAGE_PIN C4    IOSTANDARD LVCMOS33 } [get_ports { FPGA_SERIAL_RX }];
# FPGA_SERIAL_TX sends data to the computer (Connected to UART_RXD_OUT)
set_property -dict { PACKAGE_PIN D4    IOSTANDARD LVCMOS33 } [get_ports { FPGA_SERIAL_TX }];

## Audio Out (Optional - Mono Audio Out port on Nexys A7)
set_property -dict { PACKAGE_PIN A11   IOSTANDARD LVCMOS33 } [get_ports { AUD_PWM }];
set_property -dict { PACKAGE_PIN D12   IOSTANDARD LVCMOS33 } [get_ports { AUD_SD }];