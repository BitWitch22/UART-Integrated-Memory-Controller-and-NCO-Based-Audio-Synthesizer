/*
 * FPGA Piano System - CEP Project
 * * A complete FPGA implementation of a digital piano system using SystemVerilog.
 * This project demonstrates digital signal processing, hardware synthesis, 
 * and real-time audio generation.
 *
 * FEATURES:
 * - Digital Audio Synthesis: NCO-based tone generation (24-bit phase accumulation)
 * - Piano Scale Support: ROM-based piano scale frequency lookup
 * - Audio Output: PWM-based DAC
 * - UART Communication: Serial interface for control (115,200 bps)
 * - Input Handling: Debounced button parser and synchronizers
 *
 * IMPLEMENTATION PRINCIPLES:
 * - Explicit Register Instantiation (EECS151 Standard)
 * - Synchronous Design (Positive edge-triggered)
 * - Clock Domain Crossing (CDC) synchronization
 *
 * AUTHOR: EECS151 Course, UC Berkeley
 * LAST UPDATED: June 2026
 * TARGET: Z1 FPGA Development Board (100 MHz)
 */