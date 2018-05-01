# Configure pipeline logic
create_pblock a3_pipe
add_cells_to_pblock [get_pblocks a3_pipe] [get_cells -quiet -hierarchical pipe_logic*]
resize_pblock [get_pblocks a3_pipe] -add {SLICE_X32Y50:SLICE_X41Y149}
resize_pblock [get_pblocks a3_pipe] -add {DSP48_X2Y20:DSP48_X2Y59}
resize_pblock [get_pblocks a3_pipe] -add {RAMB18_X2Y20:RAMB18_X2Y59}
resize_pblock [get_pblocks a3_pipe] -add {RAMB36_X2Y10:RAMB36_X2Y29}

# Set IP cores as reconfigurable partitions
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_0]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_1]

# Configure slot #0
create_pblock a3_slot_0
add_cells_to_pblock [get_pblocks a3_slot_0] [get_cells -quiet [list system_i/a3_slot_0]]
resize_pblock [get_pblocks a3_slot_0] -add {SLICE_X50Y50:SLICE_X111Y149}
resize_pblock [get_pblocks a3_slot_0] -add {DSP48_X3Y20:DSP48_X4Y59}
resize_pblock [get_pblocks a3_slot_0] -add {RAMB18_X3Y20:RAMB18_X5Y59}
resize_pblock [get_pblocks a3_slot_0] -add {RAMB36_X3Y10:RAMB36_X5Y29}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_0]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_0]

# Configure slot #1
create_pblock a3_slot_1
add_cells_to_pblock [get_pblocks a3_slot_1] [get_cells -quiet [list system_i/a3_slot_1]]
resize_pblock [get_pblocks a3_slot_1] -add {SLICE_X0Y0:SLICE_X111Y49}
resize_pblock [get_pblocks a3_slot_1] -add {DSP48_X0Y0:DSP48_X4Y19}
resize_pblock [get_pblocks a3_slot_1] -add {RAMB18_X0Y0:RAMB18_X5Y19}
resize_pblock [get_pblocks a3_slot_1] -add {RAMB36_X0Y0:RAMB36_X5Y9}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_1]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_1]
