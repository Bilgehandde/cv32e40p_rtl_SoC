# CV32E40P RTL SoC
### RISC-V System-on-Chip

![Language](https://img.shields.io/badge/Language-SystemVerilog-blue)
![Core](https://img.shields.io/badge/Core-RISC--V_CV32E40P-green)
![Platform](https://img.shields.io/badge/FPGA-Artix--7_Basys3-orange)
![Design](https://img.shields.io/badge/Method-Pure_RTL-red)

This repository contains a fully custom RISC-V System-on-Chip (SoC)
designed and implemented entirely at the RTL level.

The system is based on the CV32E40P industrial-grade RISC-V core from the
OpenHW Group and is implemented purely in SystemVerilog.

Unlike conventional FPGA designs that rely on Vivado IP Integrator,
Block Automation, or proprietary IP cores, this project intentionally
avoids pre-built IPs to demonstrate full architectural control,
protocol-level understanding, and cycle-accurate hardware design.

---

## 🧠 System Overview

- Processor Core: CV32E40P (RV32IMC)
- Architecture Style: Harvard-like (Split Instruction & Data paths)
- Bus Protocol: Custom OBI to AXI4-Lite Bridge
- Design Methodology: Pure RTL (No Block Design / No IP Integrator)
- Boot Method: QSPI-based First Stage Bootloader (FSBL) written in Assembly
- Target Board: Digilent Basys 3 (Artix-7)

This SoC is designed to reflect real-world embedded processor systems,
including external non-volatile memory booting, memory-mapped peripherals,
and strict bus-level handshaking.

---

## 🛠 Hardware Implementation & Performance

The design has been successfully implemented and physically verified
on the Basys 3 FPGA. The system meets all timing requirements and operates
stably on real hardware.

### ⏱ Timing Summary
- WNS (Worst Negative Slack): 2.424 ns
- TNS (Total Negative Slack): 0.000 ns
- WHS (Worst Hold Slack): 0.048 ns
- THS (Total Hold Slack): 0.000 ns

### 📊 Resource Utilization
- LUT (Look-up Tables): 5838
- FF (Flip-Flops): 2761
- BRAM: 6.5
- DSP Slices: 5

The resource footprint confirms that the system is efficient and scalable
within mid-range Artix-7 devices.

---

## 🧩 High-Level Architecture

The SoC architecture is designed to minimize instruction fetch latency
and avoid the Von Neumann bottleneck by separating instruction and data paths.

### 1. Custom Interconnect (Split Decoders)

Instead of using a generic AXI crossbar, the system employs two dedicated
address decoders:

- Instruction Decoder:
  A purely combinational, zero-latency block that routes instruction fetch
  requests directly to Boot ROM or Instruction RAM. This avoids additional
  pipeline stalls and allows single-cycle instruction fetch from on-chip memory.

- Data Decoder:
  An FSM-based decoder responsible for handling load/store transactions to
  RAM and memory-mapped peripherals. It manages handshake timing, backpressure,
  and variable-latency devices such as UART and QSPI Flash.

This split-decoder approach provides deterministic performance while
keeping the control logic simple and analyzable.

---

### 2. Dual-Port Instruction RAM

To enable self-modifying code during boot, the Instruction RAM is implemented
as a true dual-port Block RAM:

- Port A (Read-Only):
  Connected to the CPU instruction fetch interface.

- Port B (Write-Only):
  Connected to the data bus, allowing the CPU to write instructions into
  executable memory during the boot process.

This mechanism enables a clean and efficient Flash-to-RAM copy operation
without stalling instruction fetch.

---

### 3. Peripheral Subsystem

All peripherals are memory-mapped starting at address 0x1000_0000.
A dedicated peripheral wrapper performs address decoding and routes
transactions to the following devices:

- GPIO:
  Controls LEDs and reads switch inputs.

- Timer:
  Provides cycle counting and periodic system timing.

- UART:
  Enables serial communication for debugging and visibility.

- Custom QSPI Master:
  A fully RTL, bit-banged SPI engine designed to interface with the
  Macronix mx25l3273f Flash memory.

The QSPI controller handles timing alignment, busy-flag synchronization,
and endianness conversion entirely in hardware.

---

## 🗺️ Memory Map

| Region            | Base Address | Size  | Access | Description |
|------------------|--------------|-------|--------|-------------|
| Boot ROM         | 0x0000_0000  | 512 B | R      | Reset Vector & FSBL |
| Instruction RAM  | 0x0010_0000  | 8 KB  | R/W    | Executable Application Memory |
| Data RAM         | 0x0020_0000  | 8 KB  | R/W    | Stack, Heap, Variables |
| GPIO             | 0x1000_0000  | 256 B | R/W    | LED & Switch Control |
| Timer            | 0x1000_1000  | 256 B | R/W    | System Timer |
| UART             | 0x1000_2000  | 256 B | R/W    | Serial Communication |
| QSPI             | 0x1000_4000  | 256 B | R/W    | External Flash Controller |

---

## 🔄 Boot Sequence (System Bring-Up Flow)

The system boots without an operating system and follows a deterministic,
bare-metal boot sequence:

1. Reset:
   The CPU starts execution from address 0x0000_0000 (Boot ROM).

2. QSPI Initialization:
   The First Stage Bootloader configures the QSPI controller registers.

3. Polling Loop:
   Software polls the hardware BUSY_FLAG at address 0x1000_4028 to
   synchronize with Flash read transactions.

4. Endianness Correction:
   The QSPI hardware automatically converts Flash big-endian byte order
   into little-endian format expected by the RISC-V core.

5. Copy Operation:
   Application code is read from external Flash starting at offset
   0x0030_0000 and copied word-by-word into Instruction RAM at 0x0010_0000.

6. Jump to Application:
   The bootloader executes a jalr instruction to 0x0010_0000, transferring
   control to the user application. Successful execution is confirmed by
   the 0xAA LED pattern on hardware.

---

### 🔍 Hardware-Software Co-Verification
To ensure system reliability before silicon implementation:
- **Flash Memory Offsetting:** The application firmware is intentionally placed at a `0x0030_0000` offset within the QSPI Flash to prevent collisions with the FPGA bitstream.
- **Simulation Environment:** A cycle-accurate behavioral SPI Flash model (`spiflash_model.sv`) is used in the testbench. This model mimics the timing characteristics of the physical Macronix chip, allowing the FSBL to be fully debugged in simulation before being programmed onto the Basys 3 hardware.

## 🧪 Simulation Notes

A cycle-aware SPI Flash behavioral model is used during simulation to
expose timing, sampling, and alignment issues.

Several bugs related to SPI clock phase, sampling edge selection,
bit-ordering, and endianness were identified and resolved by aligning
the master and model behavior. This ensured consistency between simulation
and real hardware behavior.

---

## ⚠️ Known Limitations

- QSPI controller currently supports read-only operation.
- AXI interfaces allow only a single outstanding transaction.
- No instruction or data cache is implemented.
- No interrupt controller (PLIC) is used at this stage.
- Flash access is CPU-driven (no DMA).

These limitations are intentional to keep the system simple, transparent,
and fully analyzable.

---

## 📁 Project Structure

```text
cv32e40p_rtl_soc/
├── rtl/                        # Synthesizable SystemVerilog Source Code
│   ├── soc_top.sv              # Top-Level System Module (with STARTUPE2)
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
│   └── spiflash_model.sv       # Flash Behavioral Simulation Model
│
├── constr/                     # FPGA Constraints
│   └── basys3_pins.xdc         # Physical Pinout and Clock Definitions
│
└── README.md                   # Project Documentation
