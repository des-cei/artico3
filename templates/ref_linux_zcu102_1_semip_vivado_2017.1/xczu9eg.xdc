# Configure pipeline logic
create_pblock a3_pipe
add_cells_to_pblock [get_pblocks a3_pipe] [get_cells -quiet -hierarchical pipe_logic*]
resize_pblock [get_pblocks a3_pipe] -add {SLICE_X47Y180:SLICE_X49Y419}

# Set IP cores as reconfigurable partitions
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_0]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_1]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_2]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_3]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_4]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_5]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_6]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_7]

# Configure slot #0
create_pblock a3_slot_0
add_cells_to_pblock [get_pblocks a3_slot_0] [get_cells -quiet -hierarchical a3_slot_0]
resize_pblock [get_pblocks a3_slot_0] -add {SLICE_X50Y360:SLICE_X96Y419}
resize_pblock [get_pblocks a3_slot_0] -add {DSP48E2_X10Y144:DSP48E2_X17Y167}
resize_pblock [get_pblocks a3_slot_0] -add {RAMB18_X7Y144:RAMB18_X12Y167}
resize_pblock [get_pblocks a3_slot_0] -add {RAMB36_X7Y72:RAMB36_X12Y83}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_0]
#set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_0]

# Configure slot #1
create_pblock a3_slot_1
add_cells_to_pblock [get_pblocks a3_slot_1] [get_cells -quiet -hierarchical a3_slot_1]
resize_pblock [get_pblocks a3_slot_1] -add {SLICE_X50Y300:SLICE_X96Y359}
resize_pblock [get_pblocks a3_slot_1] -add {DSP48E2_X10Y120:DSP48E2_X17Y143}
resize_pblock [get_pblocks a3_slot_1] -add {RAMB18_X7Y120:RAMB18_X12Y143}
resize_pblock [get_pblocks a3_slot_1] -add {RAMB36_X7Y60:RAMB36_X12Y71}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_1]
#set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_1]

# Configure slot #2
create_pblock a3_slot_2
add_cells_to_pblock [get_pblocks a3_slot_2] [get_cells -quiet -hierarchical a3_slot_2]
resize_pblock [get_pblocks a3_slot_2] -add {SLICE_X50Y240:SLICE_X96Y299}
resize_pblock [get_pblocks a3_slot_2] -add {DSP48E2_X10Y96:DSP48E2_X17Y119}
resize_pblock [get_pblocks a3_slot_2] -add {RAMB18_X7Y96:RAMB18_X12Y119}
resize_pblock [get_pblocks a3_slot_2] -add {RAMB36_X7Y48:RAMB36_X12Y59}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_2]
#set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_2]

# Configure slot #3
create_pblock a3_slot_3
add_cells_to_pblock [get_pblocks a3_slot_3] [get_cells -quiet -hierarchical a3_slot_3]
resize_pblock [get_pblocks a3_slot_3] -add {SLICE_X50Y180:SLICE_X96Y239}
resize_pblock [get_pblocks a3_slot_3] -add {DSP48E2_X10Y72:DSP48E2_X17Y95}
resize_pblock [get_pblocks a3_slot_3] -add {RAMB18_X7Y72:RAMB18_X12Y95}
resize_pblock [get_pblocks a3_slot_3] -add {RAMB36_X7Y36:RAMB36_X12Y47}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_3]
#set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_3]

# Configure slot #4
create_pblock a3_slot_4
add_cells_to_pblock [get_pblocks a3_slot_4] [get_cells -quiet -hierarchical a3_slot_4]
resize_pblock [get_pblocks a3_slot_4] -add {SLICE_X0Y360:SLICE_X45Y419}
resize_pblock [get_pblocks a3_slot_4] -add {DSP48E2_X0Y144:DSP48E2_X8Y167}
resize_pblock [get_pblocks a3_slot_4] -add {RAMB18_X0Y144:RAMB18_X5Y167}
resize_pblock [get_pblocks a3_slot_4] -add {RAMB36_X0Y72:RAMB36_X5Y83}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_4]
#set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_4]

# Configure slot #5
create_pblock a3_slot_5
add_cells_to_pblock [get_pblocks a3_slot_5] [get_cells -quiet -hierarchical a3_slot_5]
resize_pblock [get_pblocks a3_slot_5] -add {SLICE_X0Y300:SLICE_X45Y359}
resize_pblock [get_pblocks a3_slot_5] -add {DSP48E2_X0Y120:DSP48E2_X8Y143}
resize_pblock [get_pblocks a3_slot_5] -add {RAMB18_X0Y120:RAMB18_X5Y143}
resize_pblock [get_pblocks a3_slot_5] -add {RAMB36_X0Y60:RAMB36_X5Y71}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_5]
#set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_5]

# Configure slot #6
create_pblock a3_slot_6
add_cells_to_pblock [get_pblocks a3_slot_6] [get_cells -quiet -hierarchical a3_slot_6]
resize_pblock [get_pblocks a3_slot_6] -add {SLICE_X0Y240:SLICE_X45Y299}
resize_pblock [get_pblocks a3_slot_6] -add {DSP48E2_X0Y96:DSP48E2_X8Y119}
resize_pblock [get_pblocks a3_slot_6] -add {RAMB18_X0Y96:RAMB18_X5Y119}
resize_pblock [get_pblocks a3_slot_6] -add {RAMB36_X0Y48:RAMB36_X5Y59}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_6]
#set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_6]

# Configure slot #7
create_pblock a3_slot_7
add_cells_to_pblock [get_pblocks a3_slot_7] [get_cells -quiet -hierarchical a3_slot_7]
resize_pblock [get_pblocks a3_slot_7] -add {SLICE_X0Y180:SLICE_X45Y239}
resize_pblock [get_pblocks a3_slot_7] -add {DSP48E2_X0Y72:DSP48E2_X8Y95}
resize_pblock [get_pblocks a3_slot_7] -add {RAMB18_X0Y72:RAMB18_X5Y95}
resize_pblock [get_pblocks a3_slot_7] -add {RAMB36_X0Y36:RAMB36_X5Y47}
set_property SNAPPING_MODE ON [get_pblocks a3_slot_7]
#set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_7]
