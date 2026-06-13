# FPGA Piano System - CEP Project

A complete FPGA implementation of a digital piano system using Verilog on a Z1 development board. This project demonstrates digital signal processing, hardware synthesis, and real-time audio generation.

## Project Overview

This project implements a functional piano synthesizer on an FPGA with audio output via PWM, UART communication for control, push-button input, LED feedback, and switch configuration. The system generates musical tones using a Numerically Controlled Oscillator (NCO) with sine wave lookup tables.

## Features

- **Digital Audio Synthesis**: NCO-based tone generation with 24-bit phase accumulation
- **Piano Scale Support**: ROM-based piano scale frequency lookup
- **Audio Output**: PWM-based DAC for audio signal generation
- **UART Communication**: Serial interface for data transmission and control
- **Button Input**: Debounced button parser for user input handling
- **Synchronization**: Cross-domain synchronization for switch inputs
- **Memory Control**: System memory controller for FPGA operations
- **FIFO Buffering**: First-In-First-Out data buffer for smooth data flow
- **LED Feedback**: 6 LEDs for system status indication
- **Configurable Clock**: 100 MHz FPGA clock with configurable parameters

## Project Structure

```
CEP/
├── README.md                  # This file
├── EECS151.v                  # Standard library for EECS151 register definitions
├── src/                       # Source Verilog modules
│   ├── z1top.v               # Top-level module for Z1 FPGA board
│   ├── button_parser.v       # Button input parser with debouncing
│   ├── debouncer.v           # Switch debounce logic
│   ├── edge_detector.v       # Rising/falling edge detection
│   ├── synchronizer.v        # Clock domain crossing synchronizer
│   ├── uart.v                # UART interface module
│   ├── uart_receiver.v       # UART serial receiver
│   ├── uart_transmitter.v    # UART serial transmitter
│   ├── fifo.v                # First-In-First-Out buffer
│   ├── mem_controller.v      # Memory controller
│   ├── nco.v                 # Numerically Controlled Oscillator for tone generation
│   ├── piano_scale_rom.v     # Piano frequency lookup table (ROM)
│   ├── fixed_length_piano.v  # Fixed-length piano note handler
│   ├── dac.v                 # Digital-to-Analog Converter
│   └── z1top.xdc             # XDC constraints file for Z1 board
└── sim/                       # Simulation testbenches
    ├── fifo_tb.v             # FIFO testbench
    ├── mem_controller_tb.v   # Memory controller testbench
    ├── piano_system_tb.v     # Full piano system testbench
    ├── system_tb.v           # General system testbench
    ├── uart_transmitter_tb.v # UART transmitter testbench
    └── uart2uart_tb.v        # UART loopback testbench
```

## Core Components

### Top-Level Module (z1top.v)
- **Clock Frequency**: 100 MHz
- **UART Baud Rate**: 115,200 bps
- **Button Sampling**: 500 µs intervals
- **Button Debounce**: 100 ms hold time
- **Interfaces**:
  - CLK_100MHZ_FPGA: Main FPGA clock
  - BUTTONS: 4-bit button input (3 buttons + reset)
  - SWITCHES: 2-bit switch input
  - LEDS: 6-bit LED output
  - AUD_PWM: PWM audio output
  - AUD_SD: Audio shutdown control
  - FPGA_SERIAL_RX/TX: UART serial interface

### Audio Synthesis Pipeline

1. **Piano Scale ROM** (`piano_scale_rom.v`): Stores frequency values for musical notes
2. **NCO** (`nco.v`): Generates phase values using a 24-bit phase accumulator with frequency control word
3. **Sine Wave ROM**: 256-entry sine lookup table (10-bit output)
4. **DAC** (`dac.v`): Converts 10-bit digital samples to analog audio via PWM
5. **Audio Output**: Drives AUD_PWM for speaker connection

### Input/Output Subsystems

- **Button Parser** (`button_parser.v`): Debounces 4 button inputs with configurable sample and pulse periods
- **Synchronizer** (`synchronizer.v`): Safely crosses clock domains for switch inputs
- **UART** (`uart.v`, `uart_receiver.v`, `uart_transmitter.v`): Serial communication at 115.2 kbps
- **FIFO** (`fifo.v`): Buffering for smooth data flow between clock domains
- **LED Output**: Status indicators driven by system state

## Hardware Requirements

- **Z1 FPGA Development Board** with:
  - 100 MHz crystal oscillator
  - 4 pushbuttons
  - 2 toggle switches
  - 6 LEDs
  - UART serial connection
  - PWM audio output (via DAC or direct PWM)

## Pin Configuration

Pin assignments are defined in `z1top.xdc`. Key connections:
- Clock: CLK_100MHZ_FPGA
- Reset: BUTTONS[3]
- Piano Keys: BUTTONS[2:0]
- Mode/Config Switches: SWITCHES[1:0]
- LED Feedback: LEDS[5:0]
- Serial TX: FPGA_SERIAL_TX (to USB/UART converter)
- Serial RX: FPGA_SERIAL_RX (from USB/UART converter)
- Audio Output: AUD_PWM (PWM signal, PWM_SD for amplifier shutdown)

## Communication Protocol

### UART Configuration
- **Baud Rate**: 115,200 bps
- **Data Bits**: 8
- **Stop Bits**: 1
- **Parity**: None
- **Flow Control**: None

### Data Format
- **Character Transmission Time**: ~87 microseconds per character at 115.2 kbps
- **FIFO Buffering**: Stores up to 6 characters to prevent data loss

## System Parameters

All parameters are configurable in `z1top.v`:

```verilog
parameter CLOCK_FREQ = 100_000_000      // 100 MHz
parameter BAUD_RATE = 115_200           // UART speed
parameter B_SAMPLE_CNT_MAX = 50_000     // Button sampling: 500 µs
parameter B_PULSE_CNT_MAX = 100         // Debounce: 100 ms
parameter CYCLES_PER_SECOND = 100_000_000
```

## Simulation

Run testbenches using your Verilog simulator:

```bash
# Example with Verilator or ModelSim
iverilog -o sim.out sim/piano_system_tb.v src/*.v -I.
vvp sim.out
```

**Available Testbenches**:
- `piano_system_tb.v`: Full system integration test
- `uart_transmitter_tb.v`: UART transmission test
- `uart2uart_tb.v`: UART loopback verification
- `fifo_tb.v`: FIFO buffer functionality
- `mem_controller_tb.v`: Memory controller operations
- `system_tb.v`: General system behavior

## Implementation Flow

1. **Synthesis**: Compile Verilog to netlist
2. **Place & Route**: Physical layout on FPGA
3. **Generate Bitstream**: Create configuration file for FPGA
4. **Program**: Load bitstream onto Z1 board via JTAG
5. **Test**: Verify functionality with buttons, serial monitor, and audio output

## Design Principles

This project follows EECS151 course standards:

- **Explicit Register Instantiation**: Uses `REGISTER`, `REGISTER_CE`, `REGISTER_R`, `REGISTER_R_CE` modules instead of inference
- **Blocking Assignments**: Preferred in combinational logic for clarity
- **Modular Design**: Each component is self-contained and testable
- **Synchronous Design**: All sequential logic uses positive edge-triggered clocks
- **Clock Domain Crossing**: Proper synchronization using synchronizer modules

## Troubleshooting

**No Audio Output**:
- Verify AUD_PWM is connected to speaker/amplifier
- Check AUD_SD (shutdown) signal is asserted (low/active)
- Confirm sine.bin file is included in synthesis

**UART Communication Issues**:
- Verify baud rate is set to 115,200 bps
- Check serial port connections (RX/TX crossed if needed)
- Ensure proper USB-to-UART driver installation

**Button Not Responding**:
- Verify button debounce time (B_PULSE_CNT_MAX)
- Check button input connections
- Confirm reset signal is properly configured

## Files Reference

| File | Purpose |
|------|---------|
| `z1top.v` | Top-level design with port definitions |
| `z1top.xdc` | FPGA pin constraints |
| `nco.v` | Tone generation engine |
| `piano_scale_rom.v` | Musical note frequencies |
| `dac.v` | PWM-based audio DAC |
| `uart.v` | Serial communication |
| `fifo.v` | Data buffering |
| `button_parser.v` | Input debouncing |
| `synchronizer.v` | Clock domain crossing |

## Resources

- **EECS151 Standard**: Register and component definitions in `EECS151.v`
- **Block RAM**: Sine wave and piano scale data stored in FPGA BRAM
- **Clock**: 100 MHz primary clock input
- **Synthesis Tool**: Vivado or Quartus (targeting Z1/Xilinx FPGA)

## Author Notes

This project demonstrates practical FPGA design including:
- Real-time audio signal generation
- Synchronous digital design
- Clock domain crossing techniques
- Hardware-software co-design with UART
- Hardware verification through simulation

## License

This project was developed for EECS151 Digital Design course at UC Berkeley.

---

**Last Updated**: June 2026
**Development Board**: Z1 FPGA
**Target Device**: Xilinx FPGA (100 MHz, sufficient BRAM for sine/scale ROMs)
