# 🚀 RISC-V SoC for TEKNOFEST Chip Design Competition

![Board](https://img.shields.io/badge/Board-Digilent_Basys_3-red)
![Core](https://img.shields.io/badge/RISC--V-CV32E40P-blue)
![Status](https://img.shields.io/badge/Status-Synthesis_Verified-green)

This project represents a custom **System-on-Chip (SoC)** design implemented on the Digilent Basys 3 FPGA, developed as part of the **TEKNOFEST Chip Design Competition**.

The design is built around the industrial-grade **CV32E40P RISC-V Core** (OpenHW Group), integrated with a custom AXI4-Lite bus architecture and specialized optimizations for FPGA hardware.

## 🎯 Project Goal

The primary objective is to design, verify, and implement a functional microcontroller system on an FPGA. This project demonstrates the successful integration of an open-source RISC-V core into a custom SoC environment, proving its stability and performance for embedded applications.

## 🏗️ System Architecture

The SoC operates at **50 MHz** and consists of the following integrated components:

* **Processor:** CV32E40P (RV32IMC Extensions enabled).
* **Interconnect:** Custom AXI4-Lite Bus (connecting the CPU to memory and peripherals).
* **Memory:**
    * **Boot ROM:** Hardware Hardcoded Bootloader for system initialization.
    * **System RAM:** On-Chip Block RAM for instruction and data storage.
* **Peripherals:**
    * **GPIO Controller:** Manages the on-board LEDs and Switches for user I/O.
    * **System Timer:** AXI-based timer module.

## ⚡ FPGA Optimization & Stability

Unlike standard ASIC designs, running a complex processor core on an FPGA requires careful handling of clock signals to prevent system crashes.

In this project, the **CV32E40P core was adapted for the Artix-7 architecture**. The clock gating logic and system reset structure were optimized to ensure a **fully synchronous and stable operation**. As a result, the system runs error-free at 50 MHz with verified timing margins.

## License & Credits
Core: CV32E40P by OpenHW Group (Solderpad Hardware License).

## 📂 Directory Structure

```text
RISCV_Basys3_SoC/
├── constraints/        # Physical constraints (XDC) for Basys 3
├── rtl/
│   ├── cv32e40p_core/  # CV32E40P source files (Optimized for FPGA)
│   ├── soc_top.sv      # Top-level SoC wrapper
│   ├── periph_wrapper.sv # Peripheral Controller (GPIO)
│   ├── axi_interconnect.sv # AXI Bus Logic
│   └── ...             # Memory and other logic
├── scripts/            # Tcl scripts to recreate the project
|__ tb/
└── README.md           # Project Documentation




