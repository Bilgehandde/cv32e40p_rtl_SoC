## ========================================================================
## 1. SAAT SÝNYALÝ (CLOCK) - 100 MHz Kristal Giriþi (W5 Pini)
## ========================================================================
set_property PACKAGE_PIN W5 [get_ports clk]							
set_property IOSTANDARD LVCMOS33 [get_ports clk]
## ========================================================================
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
## ========================================================================

## ========================================================================
## 2. RESET (Switch 15 - En Soldaki Anahtar)
## ========================================================================
# R2 pini Active Low (Aþaðýdayken Reset, Yukarýdayken Run)
set_property PACKAGE_PIN R2 [get_ports rst_n]						
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

## ========================================================================
## PRIMARY CLOCK (100 MHz)
## ========================================================================
create_clock -name clk -period 10.000 [get_ports clk]

## ========================================================================
## 3. LEDLER (gpio_out_pins[0-15])
## ========================================================================
set_property PACKAGE_PIN U16 [get_ports {gpio_out_pins[0]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {gpio_out_pins[0]}]
set_property PACKAGE_PIN E19 [get_ports {gpio_out_pins[1]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {gpio_out_pins[1]}]
set_property PACKAGE_PIN U19 [get_ports {gpio_out_pins[2]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {gpio_out_pins[2]}]
set_property PACKAGE_PIN V19 [get_ports {gpio_out_pins[3]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {gpio_out_pins[3]}]
set_property PACKAGE_PIN W18 [get_ports {gpio_out_pins[4]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {gpio_out_pins[4]}]
set_property PACKAGE_PIN U15 [get_ports {gpio_out_pins[5]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {gpio_out_pins[5]}]
set_property PACKAGE_PIN U14 [get_ports {gpio_out_pins[6]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {gpio_out_pins[6]}]
set_property PACKAGE_PIN V14 [get_ports {gpio_out_pins[7]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {gpio_out_pins[7]}]
set_property PACKAGE_PIN V13 [get_ports {gpio_out_pins[8]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {gpio_out_pins[8]}]
set_property PACKAGE_PIN V3 [get_ports {gpio_out_pins[9]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {gpio_out_pins[9]}]
set_property PACKAGE_PIN W3 [get_ports {gpio_out_pins[10]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {gpio_out_pins[10]}]
set_property PACKAGE_PIN U3 [get_ports {gpio_out_pins[11]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {gpio_out_pins[11]}]
set_property PACKAGE_PIN P3 [get_ports {gpio_out_pins[12]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {gpio_out_pins[12]}]
set_property PACKAGE_PIN N3 [get_ports {gpio_out_pins[13]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {gpio_out_pins[13]}]
set_property PACKAGE_PIN P1 [get_ports {gpio_out_pins[14]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {gpio_out_pins[14]}]
set_property PACKAGE_PIN L1 [get_ports {gpio_out_pins[15]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {gpio_out_pins[15]}]

## ========================================================================
## 4. ZAMANLAMA OPTÝMÝZASYONLARI (TIMING FIXES)
## ========================================================================
# Bu komutlar Vivado'nun iþlemci çekirdeðindeki (CPU) kritik yollarý çözmeye 
# odaklanmasýný saðlar. LED ve Reset sinyallerini zamanlama hesabýndan muaf tutar.

#set_false_path -from [get_ports rst_n]
#set_false_path -to [get_ports {gpio_out_pins[*]}]

# Eðer hala TIMING-14 hatasý alýrsan (sadece son çare olarak) þu satýrý açabilirsin:
# set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets u_cpu_top/u_core/core_i/sleep_unit_i/core_clock_gate_i/clk_o]