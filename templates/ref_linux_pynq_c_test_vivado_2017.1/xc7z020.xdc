# Configure pipeline logic
create_pblock a3_pipe
add_cells_to_pblock [get_pblocks a3_pipe] [get_cells -quiet -hierarchical pipe_logic*]
resize_pblock [get_pblocks a3_pipe] -add {SLICE_X44Y0:SLICE_X53Y149}
resize_pblock [get_pblocks a3_pipe] -add {RAMB18_X3Y0:RAMB18_X3Y59}
resize_pblock [get_pblocks a3_pipe] -add {RAMB36_X3Y0:RAMB36_X3Y29}

# Set IP cores as reconfigurable partitions
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_0]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_1]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_2]
set_property HD.RECONFIGURABLE true [get_cells -quiet -hierarchical a3_slot_3]

# Configure slot #0
create_pblock a3_slot_0
add_cells_to_pblock [get_pblocks a3_slot_0] [get_cells -quiet -hierarchical a3_slot_0]
resize_pblock [get_pblocks a3_slot_0] -add {SLICE_X80Y100:SLICE_X113Y149}
resize_pblock [get_pblocks a3_slot_0] -add {DSP48_X3Y40:DSP48_X4Y59}
resize_pblock [get_pblocks a3_slot_0] -add {RAMB18_X4Y40:RAMB18_X5Y59}
resize_pblock [get_pblocks a3_slot_0] -add {RAMB36_X4Y20:RAMB36_X5Y29}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_0]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_0]

# Configure slot #1
create_pblock a3_slot_1
add_cells_to_pblock [get_pblocks a3_slot_1] [get_cells -quiet -hierarchical a3_slot_1]
resize_pblock [get_pblocks a3_slot_1] -add {SLICE_X80Y50:SLICE_X113Y99}
resize_pblock [get_pblocks a3_slot_1] -add {DSP48_X3Y20:DSP48_X4Y39}
resize_pblock [get_pblocks a3_slot_1] -add {RAMB18_X4Y20:RAMB18_X5Y39}
resize_pblock [get_pblocks a3_slot_1] -add {RAMB36_X4Y10:RAMB36_X5Y19}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_1]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_1]

# Configure slot #2
create_pblock a3_slot_2
add_cells_to_pblock [get_pblocks a3_slot_2] [get_cells -quiet -hierarchical a3_slot_2]
resize_pblock [get_pblocks a3_slot_2] -add {SLICE_X80Y0:SLICE_X113Y49}
resize_pblock [get_pblocks a3_slot_2] -add {DSP48_X3Y0:DSP48_X4Y19}
resize_pblock [get_pblocks a3_slot_2] -add {RAMB18_X4Y0:RAMB18_X5Y19}
resize_pblock [get_pblocks a3_slot_2] -add {RAMB36_X4Y0:RAMB36_X5Y9}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_2]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_2]

# Configure slot #3
create_pblock a3_slot_3
add_cells_to_pblock [get_pblocks a3_slot_3] [get_cells -quiet -hierarchical a3_slot_3]
resize_pblock [get_pblocks a3_slot_3] -add {SLICE_X0Y0:SLICE_X31Y49}
resize_pblock [get_pblocks a3_slot_3] -add {DSP48_X0Y0:DSP48_X1Y19}
resize_pblock [get_pblocks a3_slot_3] -add {RAMB18_X0Y0:RAMB18_X1Y19}
resize_pblock [get_pblocks a3_slot_3] -add {RAMB36_X0Y0:RAMB36_X1Y9}
set_property RESET_AFTER_RECONFIG true [get_pblocks a3_slot_3]
set_property SNAPPING_MODE ON [get_pblocks a3_slot_3]
