#
# ARTICo3 IP library script for Vivado
#
# Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
#             : Arturo Perez <arturo.perez@upm.es>
# Date        : February 2020
#
# Description : This additional script is used to generate an encapsulated
#               subsystem with Xilinx SEM IP to enable fault mitigation and
#               injection.
#

#
# NOTE: Calling script must set the _subsystem_ variable
#
#       set subsystem "SEM_subsystem"
#

# Create subsystem container
create_bd_cell -type hier $subsystem

#
# Top-level block interface
#

# AXI4 interface
create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 $subsystem/s_axi

# Clock and reset
create_bd_pin -dir I -type CLK $subsystem/s_axi_aclk
create_bd_pin -dir I -type RST $subsystem/s_axi_aresetn

# GPIO
create_bd_pin -dir O -type INTR $subsystem/gpio_interrupt

# UART
create_bd_pin -dir I $subsystem/uart_rx
create_bd_pin -dir O $subsystem/uart_tx
create_bd_pin -dir O -type INTR $subsystem/uart_interrupt

#
# Communication and clocking
#

# AXI4 Interconnect
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 $subsystem/axi_sem
set_property -dict [ list CONFIG.NUM_MI {3} CONFIG.NUM_SI {1}] [get_bd_cells $subsystem/axi_sem]

# Clock buffer
create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.1 $subsystem/clkbuff_0
set_property -dict [list CONFIG.C_BUF_TYPE {BUFGCE}] [get_bd_cells $subsystem/clkbuff_0]

# Reset generator
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 $subsystem/reset_0

# Connect AXI4 interface
connect_bd_intf_net -intf_net ${subsystem}_s_axi [get_bd_intf_pins $subsystem/s_axi] [get_bd_intf_pins $subsystem/axi_sem/S00_AXI]

# Connect main clock
connect_bd_net -net ${subsystem}_clk [get_bd_pins $subsystem/s_axi_aclk] \
        [get_bd_pins $subsystem/clkbuff_0/BUFGCE_I] \
        [get_bd_pins $subsystem/axi_sem/ACLK] \
        [get_bd_pins $subsystem/axi_sem/S00_ACLK] \
        [get_bd_pins $subsystem/axi_sem/M02_ACLK]

# Connect main reset
connect_bd_net -net ${subsystem}_resetn [get_bd_pins $subsystem/s_axi_aresetn] \
        [get_bd_pins $subsystem/reset_0/ext_reset_in] \
        [get_bd_pins $subsystem/axi_sem/ARESETN] \
        [get_bd_pins $subsystem/axi_sem/S00_ARESETN] \
        [get_bd_pins $subsystem/axi_sem/M02_ARESETN]

# Connect secondary clock
connect_bd_net -net ${subsystem}_sem_clk [get_bd_pins $subsystem/clkbuff_0/BUFGCE_O] \
        [get_bd_pins $subsystem/reset_0/slowest_sync_clk] \
        [get_bd_pins $subsystem/axi_sem/M00_ACLK] \
        [get_bd_pins $subsystem/axi_sem/M01_ACLK]

# Connect secondary reset
connect_bd_net -net ${subsystem}_sem_resetn [get_bd_pins $subsystem/reset_0/Interconnect_aresetn] \
        [get_bd_pins $subsystem/axi_sem/M00_ARESETN] \
        [get_bd_pins $subsystem/axi_sem/M01_ARESETN]

#
# SEM CEI
#

# Add SEM IP
create_bd_cell -type ip -vlnv xilinx.com:ip:sem_ultra:3.1 $subsystem/sem_ultra_0
set_property -dict [list CONFIG.CLOCK_PERIOD {10000} CONFIG.MODE {mitigation_and_testing}] [get_bd_cells $subsystem/sem_ultra_0]

# Add AXI4 to SEM command IF bridge
create_bd_cell -type ip -vlnv cei.upm.es:artico3:AXI4_2_command_SEM:1.0 $subsystem/axi2sem_0

# Connect to top-level AXI4 interface port
connect_bd_intf_net -intf_net ${subsystem}_s_axi_command [get_bd_intf_pins $subsystem/axi2sem_0/s00_axi] [get_bd_intf_pins $subsystem/axi_sem/M00_AXI]

# Connect SEM IP with AXI2SEM IF
connect_bd_net [get_bd_pins $subsystem/sem_ultra_0/command_code] [get_bd_pins $subsystem/axi2sem_0/command_code]
connect_bd_net [get_bd_pins $subsystem/sem_ultra_0/command_strobe] [get_bd_pins $subsystem/axi2sem_0/command_strobe]
connect_bd_net [get_bd_pins $subsystem/sem_ultra_0/command_busy] [get_bd_pins $subsystem/axi2sem_0/command_busy]

# Create low-level logic operations
create_bd_cell -type ip -vlnv xilinx.com:ip:util_reduced_logic:2.0 $subsystem/and_8
set_property -dict [list CONFIG.C_OPERATION {and} CONFIG.C_SIZE {8} CONFIG.LOGO_FILE {data/sym_andgate.png}] [get_bd_cells $subsystem/and_8]
create_bd_cell -type ip -vlnv xilinx.com:ip:util_reduced_logic:2.0 $subsystem/or_8
set_property -dict [list CONFIG.C_OPERATION {or} CONFIG.C_SIZE {8} CONFIG.LOGO_FILE {data/sym_orgate.png}] [get_bd_cells $subsystem/or_8]
create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 $subsystem/not_1
set_property -dict [list CONFIG.C_OPERATION {not} CONFIG.C_SIZE {1} CONFIG.LOGO_FILE {data/sym_notgate.png}] [get_bd_cells $subsystem/not_1]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 $subsystem/xlconcat_0
set_property -dict [list CONFIG.NUM_PORTS {8}] [get_bd_cells $subsystem/xlconcat_0]

# Create logic tieoffs
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 $subsystem/xlconstant_0
set_property -dict [list CONFIG.CONST_VAL {0}] [get_bd_cells $subsystem/xlconstant_0]

# Connect logic tieoffs
connect_bd_net -net ${subsystem}_constant_0 [get_bd_pins $subsystem/xlconstant_0/dout] \
        [get_bd_pins $subsystem/sem_ultra_0/aux_error_cr_es] \
        [get_bd_pins $subsystem/sem_ultra_0/aux_error_cr_ne] \
        [get_bd_pins $subsystem/sem_ultra_0/aux_error_uc]

# Connect low-level logic operations
connect_bd_net -net ${subsystem}_status_initialization [get_bd_pins $subsystem/xlconcat_0/In0] \
        [get_bd_pins $subsystem/sem_ultra_0/status_initialization]
connect_bd_net -net ${subsystem}_status_observation [get_bd_pins $subsystem/xlconcat_0/In1] \
        [get_bd_pins $subsystem/sem_ultra_0/status_observation]
connect_bd_net -net ${subsystem}_status_correction [get_bd_pins $subsystem/xlconcat_0/In2] \
        [get_bd_pins $subsystem/sem_ultra_0/status_correction]
connect_bd_net -net ${subsystem}_status_classification [get_bd_pins $subsystem/xlconcat_0/In3] \
        [get_bd_pins $subsystem/sem_ultra_0/status_classification]
connect_bd_net -net ${subsystem}_status_injection [get_bd_pins $subsystem/xlconcat_0/In4] \
        [get_bd_pins $subsystem/sem_ultra_0/status_injection]
connect_bd_net -net ${subsystem}_status_essential [get_bd_pins $subsystem/xlconcat_0/In5] \
        [get_bd_pins $subsystem/sem_ultra_0/status_essential]
connect_bd_net -net ${subsystem}_status_uncorrectable [get_bd_pins $subsystem/xlconcat_0/In6] \
        [get_bd_pins $subsystem/sem_ultra_0/status_uncorrectable]
connect_bd_net -net ${subsystem}_status_detect_only [get_bd_pins $subsystem/xlconcat_0/In7] \
        [get_bd_pins $subsystem/sem_ultra_0/status_detect_only]

connect_bd_net -net ${subsystem}_xlconcat_0_dout [get_bd_pins $subsystem/xlconcat_0/dout] \
        [get_bd_pins $subsystem/and_8/Op1] \
        [get_bd_pins $subsystem/or_8/Op1]
connect_bd_net -net ${subsystem}_or_8_Res [get_bd_pins $subsystem/or_8/Res] \
        [get_bd_pins $subsystem/not_1/Op1]

# Connect to secondary clock
connect_bd_net [get_bd_pins $subsystem/clkbuff_0/BUFGCE_O] \
        [get_bd_pins $subsystem/axi2sem_0/s00_axi_aclk] \
        [get_bd_pins $subsystem/sem_ultra_0/icap_clk]

# Connect to secondary reset
connect_bd_net -net ${subsystem}_sem_periph_resetn [get_bd_pins $subsystem/reset_0/peripheral_aresetn] \
        [get_bd_pins $subsystem/axi2sem_0/s00_axi_aresetn]

#
# Rest of the block diagram
#

# Add AXI GPIO
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 $subsystem/sem_xgpio
set_property -dict [list CONFIG.C_GPIO_WIDTH {14} \
                         CONFIG.C_IS_DUAL {1} \
                         CONFIG.C_INTERRUPT_PRESENT {1} \
                         CONFIG.C_GPIO2_WIDTH {1} \
                         CONFIG.C_ALL_INPUTS_2 {1}] [get_bd_cells $subsystem/sem_xgpio]

# Add UART to SEM IP monitor interface
create_bd_cell -type ip -vlnv cei.upm.es:artico3:sem_ultra_0_uart:1.0 $subsystem/uart2sem_0

# Connect UART and SEM IP monitor interface
connect_bd_net -net ${subsystem}_monitor_txfull [get_bd_pins $subsystem/sem_ultra_0/monitor_txfull] \
        [get_bd_pins $subsystem/uart2sem_0/monitor_txfull]
connect_bd_net -net ${subsystem}_monitor_rxdata [get_bd_pins $subsystem/sem_ultra_0/monitor_rxdata] \
        [get_bd_pins $subsystem/uart2sem_0/monitor_rxdata]
connect_bd_net -net ${subsystem}_monitor_rxempty [get_bd_pins $subsystem/sem_ultra_0/monitor_rxempty] \
        [get_bd_pins $subsystem/uart2sem_0/monitor_rxempty]
connect_bd_net -net ${subsystem}_monitor_txdata [get_bd_pins $subsystem/sem_ultra_0/monitor_txdata] \
        [get_bd_pins $subsystem/uart2sem_0/monitor_txdata]
connect_bd_net -net ${subsystem}_monitor_txwrite [get_bd_pins $subsystem/sem_ultra_0/monitor_txwrite] \
        [get_bd_pins $subsystem/uart2sem_0/monitor_txwrite]
connect_bd_net -net ${subsystem}_monitor_rxread [get_bd_pins $subsystem/sem_ultra_0/monitor_rxread] \
        [get_bd_pins $subsystem/uart2sem_0/monitor_rxread]

# Connect UART to external ports
connect_bd_net -net ${subsystem}_monitor_rx [get_bd_pins $subsystem/uart_rx] \
        [get_bd_pins $subsystem/uart2sem_0/uart_rx]
connect_bd_net -net ${subsystem}_monitor_tx [get_bd_pins $subsystem/uart_tx] \
        [get_bd_pins $subsystem/uart2sem_0/uart_tx]

# Add auxiliary UART
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 $subsystem/axi_uartlite_0
set_property -dict [list CONFIG.C_BAUDRATE {115200}] [get_bd_cells $subsystem/axi_uartlite_0]

# Connect monitoring probe
connect_bd_net [get_bd_pins $subsystem/uart2sem_0/uart_tx] \
        [get_bd_pins $subsystem/axi_uartlite_0/rx]

# Connect interrupts
connect_bd_net -net ${subsystem}_uart_interrupt [get_bd_pins $subsystem/uart_interrupt] \
        [get_bd_pins $subsystem/axi_uartlite_0/interrupt]
connect_bd_net -net ${subsystem}_gpio_interrupt [get_bd_pins $subsystem/gpio_interrupt] \
        [get_bd_pins $subsystem/sem_xgpio/ip2intc_irpt]

# Connect to AXI4 interface
connect_bd_intf_net -intf_net ${subsystem}_s_axi_uart [get_bd_intf_pins $subsystem/axi_uartlite_0/S_AXI] [get_bd_intf_pins $subsystem/axi_sem/M01_AXI]
connect_bd_intf_net -intf_net ${subsystem}_s_axi_gpio [get_bd_intf_pins $subsystem/sem_xgpio/S_AXI] [get_bd_intf_pins $subsystem/axi_sem/M02_AXI]

# Connect to main clock
connect_bd_net [get_bd_pins $subsystem/s_axi_aclk] \
        [get_bd_pins $subsystem/sem_xgpio/s_axi_aclk]

# Connect to main reset
connect_bd_net [get_bd_pins $subsystem/s_axi_aresetn] \
        [get_bd_pins $subsystem/sem_xgpio/s_axi_aresetn]

# Connect to secondary clock
connect_bd_net [get_bd_pins $subsystem/clkbuff_0/BUFGCE_O] \
        [get_bd_pins $subsystem/uart2sem_0/icap_clk] \
        [get_bd_pins $subsystem/axi_uartlite_0/s_axi_aclk]

# Connect to secondary reset
connect_bd_net [get_bd_pins $subsystem/reset_0/peripheral_aresetn] \
        [get_bd_pins $subsystem/axi_uartlite_0/s_axi_aresetn]

# Create bit isolators
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 $subsystem/xlslice_bit11
set_property -dict [list CONFIG.DIN_FROM {11} CONFIG.DIN_TO {11} CONFIG.DIN_WIDTH {14}] [get_bd_cells $subsystem/xlslice_bit11]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 $subsystem/xlslice_bit12
set_property -dict [list CONFIG.DIN_FROM {12} CONFIG.DIN_TO {12} CONFIG.DIN_WIDTH {14}] [get_bd_cells $subsystem/xlslice_bit12]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 $subsystem/xlslice_bit13
set_property -dict [list CONFIG.DIN_FROM {13} CONFIG.DIN_TO {13} CONFIG.DIN_WIDTH {14}] [get_bd_cells $subsystem/xlslice_bit13]

# Connect GPIO input
connect_bd_net -net ${subsystem}_gpio_i [get_bd_pins $subsystem/sem_xgpio/gpio_io_o] \
        [get_bd_pins $subsystem/xlslice_bit11/Din] \
        [get_bd_pins $subsystem/xlslice_bit12/Din] \
        [get_bd_pins $subsystem/xlslice_bit13/Din]

# Connect bit isolators
connect_bd_net -net ${subsystem}_cap_gnt [get_bd_pins $subsystem/xlslice_bit11/Dout] \
        [get_bd_pins $subsystem/sem_ultra_0/cap_gnt]
connect_bd_net -net ${subsystem}_cap_rel [get_bd_pins $subsystem/xlslice_bit12/Dout] \
        [get_bd_pins $subsystem/sem_ultra_0/cap_rel]
connect_bd_net -net ${subsystem}_clk_en [get_bd_pins $subsystem/xlslice_bit13/Dout] \
        [get_bd_pins $subsystem/clkbuff_0/BUFGCE_CE]

# Create concatenator
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 $subsystem/xlconcat_1
set_property -dict [list CONFIG.NUM_PORTS {14}] [get_bd_cells $subsystem/xlconcat_1]

# Connect concatenator output
connect_bd_net -net ${subsystem}_gpio_o [get_bd_pins $subsystem/xlconcat_1/dout] \
        [get_bd_pins $subsystem/sem_xgpio/gpio_io_i]

# Connect concatenator inputs
connect_bd_net -net ${subsystem}_cap_reg [get_bd_pins $subsystem/xlconcat_1/In0] \
        [get_bd_pins $subsystem/sem_ultra_0/cap_req]
connect_bd_net [get_bd_pins $subsystem/xlconcat_1/In1] \
        [get_bd_pins $subsystem/sem_ultra_0/status_classification]
connect_bd_net [get_bd_pins $subsystem/xlconcat_1/In2] \
        [get_bd_pins $subsystem/sem_ultra_0/status_correction]
connect_bd_net [get_bd_pins $subsystem/xlconcat_1/In3] \
        [get_bd_pins $subsystem/sem_ultra_0/status_detect_only]
connect_bd_net -net ${subsystem}_status_diagnostic_scan [get_bd_pins $subsystem/xlconcat_1/In4] \
        [get_bd_pins $subsystem/sem_ultra_0/status_diagnostic_scan]
connect_bd_net [get_bd_pins $subsystem/xlconcat_1/In5] \
        [get_bd_pins $subsystem/sem_ultra_0/status_essential]
connect_bd_net [get_bd_pins $subsystem/xlconcat_1/In6] \
        [get_bd_pins $subsystem/sem_ultra_0/status_initialization]
connect_bd_net [get_bd_pins $subsystem/xlconcat_1/In7] \
        [get_bd_pins $subsystem/sem_ultra_0/status_observation]
connect_bd_net [get_bd_pins $subsystem/xlconcat_1/In8] \
        [get_bd_pins $subsystem/sem_ultra_0/status_uncorrectable]
connect_bd_net -net ${subsystem}_status_fatal_error [get_bd_pins $subsystem/xlconcat_1/In9] \
        [get_bd_pins $subsystem/and_8/Res]
connect_bd_net -net ${subsystem}_status_idle [get_bd_pins $subsystem/xlconcat_1/In10] \
        [get_bd_pins $subsystem/not_1/Res]
connect_bd_net [get_bd_pins $subsystem/xlconcat_1/In11] \
        [get_bd_pins $subsystem/xlslice_bit11/Dout]
connect_bd_net [get_bd_pins $subsystem/xlconcat_1/In12] \
        [get_bd_pins $subsystem/xlslice_bit12/Dout]
connect_bd_net [get_bd_pins $subsystem/xlconcat_1/In13] \
        [get_bd_pins $subsystem/xlslice_bit13/Dout]

# Connect injection
connect_bd_net -net ${subsystem}_status_injection [get_bd_pins $subsystem/sem_xgpio/gpio2_io_i] \
        [get_bd_pins $subsystem/sem_ultra_0/status_injection]
