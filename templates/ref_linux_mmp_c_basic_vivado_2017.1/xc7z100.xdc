# TODO: find a workaround to this issue
#
# [Place 30-469] Unroutable Placement! A PS7 / BUFG component pair is not placed in a routable site pair. The PS7 component can use the dedicated path between the PS7 and the clock buffer if both are placed in the same half (TOP/BOTTOM) side of the device. If this sub optimal condition is acceptable for this design, you may use the CLOCK_DEDICATED_ROUTE constraint in the .xdc file to demote this message to a WARNING. However, the use of this override is highly discouraged. These examples can be used directly in the .xdc file to override this clock rule.
#     < set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets system_i/processing_system7_0/inst/FCLK_CLK_unbuffered[0]] >
#
#     system_i/processing_system7_0/inst/PS7_i (PS7.FCLKCLK[0]) is locked to PS7_X0Y0
#      and system_i/processing_system7_0/inst/buffer_fclk_clk_0.FCLK_CLK_0_BUFG (BUFG.I) is provisionally placed by clockplacer on BUFGCTRL_X0Y15
#
#set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets system_i/processing_system7_0/inst/FCLK_CLK_unbuffered[0]]

# Configure pipeline logic
#create_pblock a3_pipe
#add_cells_to_pblock [get_pblocks a3_pipe] [get_cells -quiet -hierarchical pipe_logic*]
#resize_pblock [get_pblocks a3_pipe] -add {SLICE_X100Y0:SLICE_X109Y349}

# Set IP cores as reconfigurable partitions
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_0]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_1]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_2]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_3]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_4]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_5]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_6]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_7]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_8]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_9]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_10]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_11]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_12]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_13]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_14]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_15]

# Configure slot #0
create_pblock a3_slot_0
add_cells_to_pblock [get_pblocks a3_slot_0] [get_cells -quiet -hierarchical a3_slot_0]
resize_pblock [get_pblocks a3_slot_0] -add {SLICE_X116Y300:SLICE_X193Y349}
resize_pblock [get_pblocks a3_slot_0] -add {DSP48_X8Y120:DSP48_X13Y139}
resize_pblock [get_pblocks a3_slot_0] -add {RAMB18_X6Y120:RAMB18_X9Y139}
resize_pblock [get_pblocks a3_slot_0] -add {RAMB36_X6Y60:RAMB36_X9Y69}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_0]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_0]

# Configure slot #1
create_pblock a3_slot_1
add_cells_to_pblock [get_pblocks a3_slot_1] [get_cells -quiet -hierarchical a3_slot_1]
resize_pblock [get_pblocks a3_slot_1] -add {SLICE_X116Y250:SLICE_X193Y299}
resize_pblock [get_pblocks a3_slot_1] -add {DSP48_X8Y100:DSP48_X13Y119}
resize_pblock [get_pblocks a3_slot_1] -add {RAMB18_X6Y100:RAMB18_X9Y119}
resize_pblock [get_pblocks a3_slot_1] -add {RAMB36_X6Y50:RAMB36_X9Y59}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_1]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_1]

# Configure slot #2
create_pblock a3_slot_2
add_cells_to_pblock [get_pblocks a3_slot_2] [get_cells -quiet -hierarchical a3_slot_2]
resize_pblock [get_pblocks a3_slot_2] -add {SLICE_X116Y200:SLICE_X193Y249}
resize_pblock [get_pblocks a3_slot_2] -add {DSP48_X8Y80:DSP48_X13Y99}
resize_pblock [get_pblocks a3_slot_2] -add {RAMB18_X6Y80:RAMB18_X9Y99}
resize_pblock [get_pblocks a3_slot_2] -add {RAMB36_X6Y40:RAMB36_X9Y49}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_2]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_2]

# Configure slot #3
create_pblock a3_slot_3
add_cells_to_pblock [get_pblocks a3_slot_3] [get_cells -quiet -hierarchical a3_slot_3]
resize_pblock [get_pblocks a3_slot_3] -add {SLICE_X116Y150:SLICE_X191Y199}
resize_pblock [get_pblocks a3_slot_3] -add {DSP48_X8Y60:DSP48_X13Y79}
resize_pblock [get_pblocks a3_slot_3] -add {RAMB18_X6Y60:RAMB18_X9Y79}
resize_pblock [get_pblocks a3_slot_3] -add {RAMB36_X6Y30:RAMB36_X9Y39}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_3]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_3]

# Configure slot #4
create_pblock a3_slot_4
add_cells_to_pblock [get_pblocks a3_slot_4] [get_cells -quiet -hierarchical a3_slot_4]
resize_pblock [get_pblocks a3_slot_4] -add {SLICE_X116Y100:SLICE_X191Y149}
resize_pblock [get_pblocks a3_slot_4] -add {DSP48_X8Y40:DSP48_X13Y59}
resize_pblock [get_pblocks a3_slot_4] -add {RAMB18_X6Y40:RAMB18_X9Y59}
resize_pblock [get_pblocks a3_slot_4] -add {RAMB36_X6Y20:RAMB36_X9Y29}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_4]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_4]

# Configure slot #5
create_pblock a3_slot_5
add_cells_to_pblock [get_pblocks a3_slot_5] [get_cells -quiet -hierarchical a3_slot_5]
resize_pblock [get_pblocks a3_slot_5] -add {SLICE_X116Y50:SLICE_X193Y99}
resize_pblock [get_pblocks a3_slot_5] -add {DSP48_X8Y20:DSP48_X13Y39}
resize_pblock [get_pblocks a3_slot_5] -add {RAMB18_X6Y20:RAMB18_X9Y39}
resize_pblock [get_pblocks a3_slot_5] -add {RAMB36_X6Y10:RAMB36_X9Y19}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_5]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_5]

# Configure slot #6
create_pblock a3_slot_6
add_cells_to_pblock [get_pblocks a3_slot_6] [get_cells -quiet -hierarchical a3_slot_6]
resize_pblock [get_pblocks a3_slot_6] -add {SLICE_X116Y0:SLICE_X193Y49}
resize_pblock [get_pblocks a3_slot_6] -add {DSP48_X8Y0:DSP48_X13Y19}
resize_pblock [get_pblocks a3_slot_6] -add {RAMB18_X6Y0:RAMB18_X9Y19}
resize_pblock [get_pblocks a3_slot_6] -add {RAMB36_X6Y0:RAMB36_X9Y9}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_6]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_6]

# Configure slot #7
create_pblock a3_slot_7
add_cells_to_pblock [get_pblocks a3_slot_7] [get_cells -quiet -hierarchical a3_slot_7]
resize_pblock [get_pblocks a3_slot_7] -add {SLICE_X0Y200:SLICE_X45Y249}
resize_pblock [get_pblocks a3_slot_7] -add {DSP48_X0Y80:DSP48_X3Y99}
resize_pblock [get_pblocks a3_slot_7] -add {RAMB18_X0Y80:RAMB18_X2Y99}
resize_pblock [get_pblocks a3_slot_7] -add {RAMB36_X0Y40:RAMB36_X2Y49}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_7]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_7]

# Configure slot #8
create_pblock a3_slot_8
add_cells_to_pblock [get_pblocks a3_slot_8] [get_cells -quiet -hierarchical a3_slot_8]
resize_pblock [get_pblocks a3_slot_8] -add {SLICE_X50Y200:SLICE_X95Y249}
resize_pblock [get_pblocks a3_slot_8] -add {DSP48_X4Y80:DSP48_X7Y99}
resize_pblock [get_pblocks a3_slot_8] -add {RAMB18_X3Y80:RAMB18_X5Y99}
resize_pblock [get_pblocks a3_slot_8] -add {RAMB36_X3Y40:RAMB36_X5Y49}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_8]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_8]

# Configure slot #9
create_pblock a3_slot_9
add_cells_to_pblock [get_pblocks a3_slot_9] [get_cells -quiet -hierarchical a3_slot_9]
resize_pblock [get_pblocks a3_slot_9] -add {SLICE_X0Y150:SLICE_X45Y199}
resize_pblock [get_pblocks a3_slot_9] -add {DSP48_X0Y60:DSP48_X3Y79}
resize_pblock [get_pblocks a3_slot_9] -add {RAMB18_X0Y60:RAMB18_X2Y79}
resize_pblock [get_pblocks a3_slot_9] -add {RAMB36_X0Y30:RAMB36_X2Y39}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_9]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_9]

# Configure slot #10
create_pblock a3_slot_10
add_cells_to_pblock [get_pblocks a3_slot_10] [get_cells -quiet -hierarchical a3_slot_10]
resize_pblock [get_pblocks a3_slot_10] -add {SLICE_X50Y150:SLICE_X95Y199}
resize_pblock [get_pblocks a3_slot_10] -add {DSP48_X4Y60:DSP48_X7Y79}
resize_pblock [get_pblocks a3_slot_10] -add {RAMB18_X3Y60:RAMB18_X5Y79}
resize_pblock [get_pblocks a3_slot_10] -add {RAMB36_X3Y30:RAMB36_X5Y39}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_10]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_10]

# Configure slot #11
create_pblock a3_slot_11
add_cells_to_pblock [get_pblocks a3_slot_11] [get_cells -quiet -hierarchical a3_slot_11]
resize_pblock [get_pblocks a3_slot_11] -add {SLICE_X0Y100:SLICE_X45Y149}
resize_pblock [get_pblocks a3_slot_11] -add {DSP48_X0Y40:DSP48_X3Y59}
resize_pblock [get_pblocks a3_slot_11] -add {RAMB18_X0Y40:RAMB18_X2Y59}
resize_pblock [get_pblocks a3_slot_11] -add {RAMB36_X0Y20:RAMB36_X2Y29}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_11]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_11]

# Configure slot #12
create_pblock a3_slot_12
add_cells_to_pblock [get_pblocks a3_slot_12] [get_cells -quiet -hierarchical a3_slot_12]
resize_pblock [get_pblocks a3_slot_12] -add {SLICE_X50Y100:SLICE_X95Y149}
resize_pblock [get_pblocks a3_slot_12] -add {DSP48_X4Y40:DSP48_X7Y59}
resize_pblock [get_pblocks a3_slot_12] -add {RAMB18_X3Y40:RAMB18_X5Y59}
resize_pblock [get_pblocks a3_slot_12] -add {RAMB36_X3Y20:RAMB36_X5Y29}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_12]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_12]

# Configure slot #13
create_pblock a3_slot_13
add_cells_to_pblock [get_pblocks a3_slot_13] [get_cells -quiet -hierarchical a3_slot_13]
resize_pblock [get_pblocks a3_slot_13] -add {SLICE_X0Y50:SLICE_X45Y99}
resize_pblock [get_pblocks a3_slot_13] -add {DSP48_X0Y20:DSP48_X3Y39}
resize_pblock [get_pblocks a3_slot_13] -add {RAMB18_X0Y20:RAMB18_X2Y39}
resize_pblock [get_pblocks a3_slot_13] -add {RAMB36_X0Y10:RAMB36_X2Y19}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_13]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_13]

# Configure slot #14
create_pblock a3_slot_14
add_cells_to_pblock [get_pblocks a3_slot_14] [get_cells -quiet -hierarchical a3_slot_14]
resize_pblock [get_pblocks a3_slot_14] -add {SLICE_X50Y50:SLICE_X95Y99}
resize_pblock [get_pblocks a3_slot_14] -add {DSP48_X4Y20:DSP48_X7Y39}
resize_pblock [get_pblocks a3_slot_14] -add {RAMB18_X3Y20:RAMB18_X5Y39}
resize_pblock [get_pblocks a3_slot_14] -add {RAMB36_X3Y10:RAMB36_X5Y19}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_14]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_14]

# Configure slot #15
create_pblock a3_slot_15
add_cells_to_pblock [get_pblocks a3_slot_15] [get_cells -quiet -hierarchical a3_slot_15]
resize_pblock [get_pblocks a3_slot_15] -add {SLICE_X0Y0:SLICE_X95Y49}
resize_pblock [get_pblocks a3_slot_15] -add {DSP48_X0Y0:DSP48_X7Y19}
resize_pblock [get_pblocks a3_slot_15] -add {RAMB18_X0Y0:RAMB18_X5Y19}
resize_pblock [get_pblocks a3_slot_15] -add {RAMB36_X0Y0:RAMB36_X5Y9}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_15]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_15]
