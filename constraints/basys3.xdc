## ========================================================================
## Basys 3 XDC File for SoC Top
## Device: Artix-7 (xc7a35tcpg236-1)
## ========================================================================

## ========================================================================
## 1. CLOCK (100 MHz System Clock)
## ========================================================================
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## ========================================================================
## 2. RESET (Active Low) - Switch 15 (R2) KULLANIMI
## ========================================================================
# Not: Modülde 'rst_n' (Active Low) tanýmlý.
# Switch 15 (R2) YUKARI (1) iken sistem çalýþýr, AÞAÐI (0) iken resetlenir.
set_property PACKAGE_PIN R2 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

## ========================================================================
## 3. SWITCHES (sw_in[15:0])
## ========================================================================
# sw_in[0] - sw_in[14] standart yerlerinde.
set_property PACKAGE_PIN V17 [get_ports {sw_in[0]}]
set_property PACKAGE_PIN V16 [get_ports {sw_in[1]}]
set_property PACKAGE_PIN W16 [get_ports {sw_in[2]}]
set_property PACKAGE_PIN W17 [get_ports {sw_in[3]}]
set_property PACKAGE_PIN W15 [get_ports {sw_in[4]}]
set_property PACKAGE_PIN V15 [get_ports {sw_in[5]}]
set_property PACKAGE_PIN W14 [get_ports {sw_in[6]}]
set_property PACKAGE_PIN W13 [get_ports {sw_in[7]}]
set_property PACKAGE_PIN V2  [get_ports {sw_in[8]}]
set_property PACKAGE_PIN T3  [get_ports {sw_in[9]}]
set_property PACKAGE_PIN T2  [get_ports {sw_in[10]}]
set_property PACKAGE_PIN R3  [get_ports {sw_in[11]}]
set_property PACKAGE_PIN W2  [get_ports {sw_in[12]}]
set_property PACKAGE_PIN U1  [get_ports {sw_in[13]}]
set_property PACKAGE_PIN T1  [get_ports {sw_in[14]}]

# DÝKKAT: Switch 15 (R2) reset için kullanýldýðýndan,
# sw_in[15] sinyalini ORTA BUTON (BTNC - U18)'e atadýk.
set_property PACKAGE_PIN U18 [get_ports {sw_in[15]}]

set_property IOSTANDARD LVCMOS33 [get_ports {sw_in[*]}]

## ========================================================================
## 4. LEDs (gpio_out_pins[15:0])
## ========================================================================
set_property PACKAGE_PIN U16 [get_ports {gpio_out_pins[0]}]
set_property PACKAGE_PIN E19 [get_ports {gpio_out_pins[1]}]
set_property PACKAGE_PIN U19 [get_ports {gpio_out_pins[2]}]
set_property PACKAGE_PIN V19 [get_ports {gpio_out_pins[3]}]
set_property PACKAGE_PIN W18 [get_ports {gpio_out_pins[4]}]
set_property PACKAGE_PIN U15 [get_ports {gpio_out_pins[5]}]
set_property PACKAGE_PIN U14 [get_ports {gpio_out_pins[6]}]
set_property PACKAGE_PIN V14 [get_ports {gpio_out_pins[7]}]
set_property PACKAGE_PIN V13 [get_ports {gpio_out_pins[8]}]
set_property PACKAGE_PIN V3  [get_ports {gpio_out_pins[9]}]
set_property PACKAGE_PIN W3  [get_ports {gpio_out_pins[10]}]
set_property PACKAGE_PIN U3  [get_ports {gpio_out_pins[11]}]
set_property PACKAGE_PIN P3  [get_ports {gpio_out_pins[12]}]
set_property PACKAGE_PIN N3  [get_ports {gpio_out_pins[13]}]
set_property PACKAGE_PIN P1  [get_ports {gpio_out_pins[14]}]
set_property PACKAGE_PIN L1  [get_ports {gpio_out_pins[15]}]

set_property IOSTANDARD LVCMOS33 [get_ports {gpio_out_pins[*]}]

## ========================================================================
## 5. UART INTERFACES
## ========================================================================

# UART 0: USB-RS232 Bridge (Bilgisayar ile haberleþme)
set_property PACKAGE_PIN B18 [get_ports uart0_rx]
set_property PACKAGE_PIN A18 [get_ports uart0_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart0_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart0_tx]

# UART 1: PMOD Header JA (Üst Sýra)
# JA1 (Pin 1) -> RX, JA2 (Pin 2) -> TX
set_property PACKAGE_PIN J1 [get_ports uart1_rx]
set_property PACKAGE_PIN L2 [get_ports uart1_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart1_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart1_tx]

## ========================================================================
## 6. QSPI FLASH INTERFACE (Internal Flash)
## ========================================================================
# Chip Select
set_property PACKAGE_PIN K19 [get_ports qspi_cs_n]
set_property IOSTANDARD LVCMOS33 [get_ports qspi_cs_n]

# Data Lines (Quad SPI)
set_property PACKAGE_PIN D18 [get_ports {qspi_dq[0]}]
set_property PACKAGE_PIN D19 [get_ports {qspi_dq[1]}]
set_property PACKAGE_PIN G18 [get_ports {qspi_dq[2]}]
set_property PACKAGE_PIN F18 [get_ports {qspi_dq[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {qspi_dq[*]}]

# -------------------------------------------------------------------------
# KRÝTÝK UYARI: QSPI SCK (Clock)
# -------------------------------------------------------------------------
# Basys 3 üzerindeki dahili Flash'ýn clock pini (C11), FPGA konfigürasyonu
# için kullanýlan özel bir pindir (CCLK).
#
# Eðer Verilog kodunuzda STARTUPE2 primitive'ini KULLANMIYORSANIZ ve doðrudan
# bir porttan çýkýþ veriyorsanýz, aþaðýdaki satýrý aktif etmeyi deneyebilirsiniz.
# Ancak Vivado "Dedicated Route" hatasý verebilir.
#
## ========================================================================
## 7. CONFIGURATION SETTINGS
## ========================================================================
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]

## ========================================================================
## 8. TIMING EXCEPTIONS
## ========================================================================
# Asenkron giriþ/çýkýþlar için timing analizini yoksay
set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports {sw_in[*]}]
set_false_path -from [get_ports uart0_rx]
set_false_path -from [get_ports uart1_rx]
set_false_path -to   [get_ports {gpio_out_pins[*]}]
set_false_path -to   [get_ports uart0_tx]
set_false_path -to   [get_ports uart1_tx]