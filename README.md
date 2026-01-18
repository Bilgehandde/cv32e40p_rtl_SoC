# CV32E40P RTL SoC
### RISC-V System-on-Chip 

![Language](https://img.shields.io/badge/Language-SystemVerilog-blue)
![Core](https://img.shields.io/badge/Core-RISC--V_CV32E40P-green)
![Platform](https://img.shields.io/badge/FPGA-Artix--7_Basys3-orange)
![Design](https://img.shields.io/badge/Method-Pure_RTL-red)

This repository contains a **fully custom RISC-V System-on-Chip (SoC)**.
The design is based on the **CV32E40P industrial-grade RISC-V core** from the **OpenHW Group** and is implemented entirely in **pure SystemVerilog (RTL)**.

Unlike conventional FPGA designs that rely on Vivado IP Integrator, Block Automation, or proprietary IPs, this project intentionally avoids pre-built IP cores to demonstrate **full architectural control**, **protocol-level understanding**, and **cycle-accurate system design**.

---

## 🧠 System Overview

- **Processor Core:** CV32E40P (RV32IMC)
- **Architecture Style:** Harvard-like (Split Instruction & Data paths via custom interconnect)
- **Bus Protocol:** Custom OBI to AXI4-Lite Bridge
- **Design Style:** Pure RTL (No Block Design / IP Integrator)
- **Boot Method:** QSPI-based First Stage Bootloader (FSBL) written in Assembly
- **Target Board:** Digilent Basys 3 (Artix-7)

---

## 🧩 High-Level Architecture

The system is designed to overcome the Von Neumann bottleneck by employing a split-bus topology. Key architectural components include:

### 1. Custom Interconnect (Split Decoders)
Instead of a standard AXI Crossbar, the system uses two specialized decoders to maximize performance:
* **Instruction Decoder:** A purely combinational block with **Zero-Latency**. It routes instruction fetch requests from the CPU directly to Boot ROM or Instruction RAM immediately.
* **Data Decoder:** An FSM-based block that handles Load/Store operations. It manages the handshake logic for slower peripherals (UART, Flash) and variable-latency memories.

### 2. Dual-Port Instruction RAM
To enable the bootloader to load the application code into the execution memory, the Instruction RAM utilizes a **Dual-Port Block RAM** architecture:
* **Port A (Read-Only):** Connected to the CPU Instruction Fetch interface.
* **Port B (Write-Only):** Connected to the Data Bus. This allows the CPU to write instructions into memory as data during the boot process.

### 3. Peripheral Subsystem
All peripherals are memory-mapped starting at `0x1000_0000`. A wrapper module performs address decoding and routes transactions to:
* **GPIO:** Controls LEDs and reads Switches.
* **Timer:** Provides a system tick and cycle counting.
* **UART:** Handles serial communication for debugging.
* **Custom QSPI Master:** A bit-banged SPI engine designed to interface with the W25Q32 Flash memory.

---

## 🗺️ Memory Map

| Region | Base Address | Size | Access | Description |
|:---|:---|:---|:---|:---|
| **Boot ROM** | `0x0000_0000` | 512 B | R | Reset Vector & Hardcoded FSBL |
| **Instruction RAM** | `0x0010_0000` | 8 KB | R/W | Main Application Memory (Executable) |
| **Data RAM** | `0x0020_0000` | 8 KB | R/W | Stack, Heap, and Variables |
| **GPIO** | `0x1000_0000` | 256 B | R/W | LED & Switch Control |
| **Timer** | `0x1000_1000` | 256 B | R/W | System Timer |
| **UART** | `0x1000_2000` | 256 B | R/W | Serial Communication |
| **QSPI** | `0x1000_4000` | 256 B | R/W | External Flash Controller |

---

## 🔄 Boot Sequence (How the System Starts)

The system does not have an OS. It uses a bare-metal boot sequence:

1.  **Reset:**
    The CPU comes out of reset and fetches the first instruction from `0x0000_0000` (Boot ROM).

2.  **QSPI Initialization:**
    The FSBL code initializes the Custom QSPI Master registers.

3.  **Polling Loop:**
    Since Flash memory is slower than the CPU, the software polls the hardware `BUSY` flag (mapped to `0x1000_4028`) to synchronize data transfer.

4.  **Endianness Correction:**
    The QSPI hardware automatically swaps bytes (Big-Endian from Flash to Little-Endian for RISC-V) before presenting data to the CPU.

5.  **Copy Operation:**
    The CPU reads instructions from External Flash via the QSPI peripheral and writes them into the **Instruction RAM** via the Data Bus.

6.  **Jump to Application:**
    Once copying is complete, the Bootloader executes a `jalr` instruction to `0x0010_0000`, transferring control to the main application.

---

## 📁 Project Structure

```text
cv32e40p_rtl_soc/
├── rtl/                        # Synthesizable SystemVerilog Source Code
│   ├── soc_top.sv              # Top-Level System Module
│   ├── core/                   # Processor Core Files
│   │   ├── cv32e40p_top.sv     # OpenHW Group Core Wrapper
│   │   └── obi_to_axi.sv       # OBI to AXI4-Lite Protocol Bridge
│   ├── interconnect/           # Bus Logic & Decoders
│   │   ├── axi_instr_decoder.sv # Zero-Latency Instruction Decoder
│   │   ├── axi_data_decoder.sv  # FSM-Based Data Decoder
│   │   └── periph_wrapper.sv    # Peripheral Sub-Interconnect
│   ├── memory/                 # Memory Modules
│   │   ├── boot_rom.sv         # Hardcoded Bootloader (Assembly)
│   │   ├── dual_port_ram_axi.sv # Instruction RAM (Dual Port)
│   │   └── simple_ram.sv       # Data RAM
│   └── peripherals/            # I/O Controllers
│       ├── axi_gpio.sv         # LED & Switch Controller
│       ├── axi_timer.sv        # System Timer
│       ├── axi_uart.sv         # UART Serial Controller
│       └── axi_qspi_master.sv  # Custom QSPI Flash Controller (Bit-Banging)
│
├── sim/                        # Simulation Files
│   ├── tb_soc.sv               # Top Level Testbench
│   ├── axi_checker.sv          # Verification IP (Protocol Error Checker)
│   └── spiflash_model.sv       # Winbond W25Q32 Simulation Model
│
├── constr/                     # FPGA Constraints
│   └── basys3_pins.xdc         # Physical Pinout and Clock Definitions
│
└── README.md                   # Project Documentation



