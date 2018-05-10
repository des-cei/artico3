# I/O Standard and Package pin constraints
# UART RX
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]
set_property PACKAGE_PIN E13 [get_ports uart_rx]

# UART TX
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]
set_property PACKAGE_PIN F13 [get_ports uart_tx]


# Placement constraints
create_pblock semip
add_cells_to_pblock [get_pblocks semip] [get_cells -quiet -hierarchical SEM_subsystem]
resize_pblock [get_pblocks semip] -add {SLICE_X56Y0:SLICE_X96Y119}
resize_pblock [get_pblocks semip] -add {DSP48E2_X12Y0:DSP48E2_X17Y47}
resize_pblock [get_pblocks semip] -add {IOB_X0Y0:IOB_X0Y37}
resize_pblock [get_pblocks semip] -add {RAMB18_X7Y0:RAMB18_X12Y47}
resize_pblock [get_pblocks semip] -add {RAMB36_X7Y0:RAMB36_X12Y23}
