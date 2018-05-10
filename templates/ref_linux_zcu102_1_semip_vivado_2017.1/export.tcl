#
# ARTICo3 IP library script for Vivado
#
# Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
# Date        : May 2018
#
# Description : This script generates a full system in Vivado using the
#               IP library created by create_ip_library.tcl by instantiating
#               the required modules and making the necessary connections.
#

<a3<artico3_preproc>a3>

variable script_file
set script_file "export.tcl"

# Help information for this script
proc help {} {

    variable script_file
    puts "\nDescription:"
    puts "This TCL script sets up all modules and connections in an IP integrator"
    puts "block design needed to create a fully functional ARTICo3 design.\n"
    puts "Syntax when called in batch mode:"
    puts "vivado -mode tcl -source $script_file -tclargs \[-proj_name <Name> -proj_path <Path>\]"
    puts "$script_file -tclargs \[--help\]\n"
    puts "Usage:"
    puts "Name                   Description"
    puts "-------------------------------------------------------------------------"
    puts "-proj_name <Name>        Optional: When given, a new project will be"
    puts "                         created with the given name"
    puts "-proj_path <path>        Path to the newly created project"
    puts "\[--help\]               Print help information for this script"
    puts "-------------------------------------------------------------------------\n"
    exit 0

}

set artico3_ip_dir [pwd]/pcores
set proj_name ""
set proj_path ""

# Parse command line arguments
if { $::argc > 0 } {
    for {set i 0} {$i < [llength $::argc]} {incr i} {
        set option [string trim [lindex $::argv $i]]
        switch -regexp -- $option {
            "-proj_name" { incr i; set proj_name  [lindex $::argv $i] }
            "-proj_path" { incr i; set proj_path  [lindex $::argv $i] }
            "-help"      { help }
            default {
                if { [regexp {^-} $option] } {
                    puts "ERROR: Unknown option '$option' specified, please type '$script_file -tclargs --help' for usage info.\n"
                    return 1
                }
            }
        }
    }
}

proc artico3_hw_setup {new_project_path new_project_name artico3_ip_dir} {

    # Create new project if "new_project_name" is given.
    # Otherwise current project will be reused.
    if { [llength $new_project_name] > 0} {
        create_project -force $new_project_name $new_project_path -part xczu9eg-ffvb1156-2-i
    }

    # Save directory and project names to variables for easy reuse
    set proj_name [current_project]
    set proj_dir [get_property directory [current_project]]

    # Set project properties

    set_property "default_lib" "xil_defaultlib" $proj_name
    set_property "sim.ip.auto_export_scripts" "1" $proj_name
    set_property "simulator_language" "Mixed" $proj_name
    set_property "target_language" "VHDL" $proj_name

    # Create 'sources_1' fileset (if not found)
    if {[string equal [get_filesets -quiet sources_1] ""]} {
        create_fileset -srcset sources_1
    }

    # Create 'constrs_1' fileset (if not found)
    if {[string equal [get_filesets -quiet constrs_1] ""]} {
        create_fileset -constrset constrs_1
    }

    # Create 'sim_1' fileset (if not found)
    if {[string equal [get_filesets -quiet sim_1] ""]} {
        create_fileset -simset sim_1
    }

    # Set 'sim_1' fileset properties
    set obj [get_filesets sim_1]
    set_property "transport_int_delay" "0" $obj
    set_property "transport_path_delay" "0" $obj
    set_property "xelab.nosort" "1" $obj
    set_property "xelab.unifast" "" $obj

# VIVADO CONFIGURATION
    # Create 'synth_1' run (if not found)
    if {[string equal [get_runs -quiet synth_1] ""]} {
        create_run -name synth_1 -part xczu9eg-ffvb1156-2-i -flow {Vivado Synthesis 2017} -strategy "Vivado Synthesis Defaults" -constrset constrs_1
    } else {
        set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
        set_property flow "Vivado Synthesis 2017" [get_runs synth_1]
    }
# END

    # Apply custom configuration for Synthesis
    set obj [get_runs synth_1]
    set_property "steps.synth_design.args.flatten_hierarchy" "rebuilt" $obj

    # set the current synth run
    current_run -synthesis [get_runs synth_1]

# VIVADO CONFIGURATION
    # Create 'impl_1' run (if not found)
    if {[string equal [get_runs -quiet impl_1] ""]} {
        create_run -name impl_1 -part xczu9eg-ffvb1156-2-i -flow {Vivado Implementation 2017} -strategy "Vivado Implementation Defaults" -constrset constrs_1 -parent_run synth_1
    } else {
        set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]
        set_property flow "Vivado Implementation 2017" [get_runs impl_1]
    }
# END

    # Apply custom configuration for Implementation
    set obj [get_runs impl_1]
    set_property "steps.write_bitstream.args.mask_file" false $obj
    set_property "steps.write_bitstream.args.bin_file" false $obj
    set_property "steps.write_bitstream.args.readback_file" false $obj
    set_property "steps.write_bitstream.args.verbose" false $obj

    # set the current impl run
    current_run -implementation [get_runs impl_1]

    #
    # Start block design
    #

    create_bd_design "system"
    update_compile_order -fileset sources_1

    # Add artico3 repository
    set_property  ip_repo_paths $artico3_ip_dir [current_project]
    update_ip_catalog

    # Set board template
    set_property board_part xilinx.com:zcu102:part0:3.0 [current_project]

    # Add system reset module
    create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 reset_0

    # Add processing system for Zynq US+ Board
    create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.0 zynq_ultra_ps_e_0
    apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1"}  [get_bd_cells zynq_ultra_ps_e_0]

    # Make sure required AXI ports are active
    set_property -dict [list CONFIG.PSU__USE__M_AXI_GP0 {1}  \
                             CONFIG.PSU__USE__M_AXI_GP1 {1}  \
                             CONFIG.PSU__USE__M_AXI_GP2 {1}] \
                             [get_bd_cells zynq_ultra_ps_e_0]

    # Add interrupt port
    set_property -dict [list CONFIG.PSU__USE__IRQ0 {1}] [get_bd_cells zynq_ultra_ps_e_0]

    # Set Frequencies
    set_property -dict [list CONFIG.PSU__FPGA_PL0_ENABLE {1} CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100}] [get_bd_cells zynq_ultra_ps_e_0]

    # Add GPIO ports through EMIO
    set_property -dict [list CONFIG.PSU__GPIO_EMIO__PERIPHERAL__ENABLE {1} CONFIG.PSU__GPIO_EMIO__PERIPHERAL__IO {16}] [get_bd_cells zynq_ultra_ps_e_0]

# APPLICATION CONFIGURATION

    # Create instance of ARTICo3 infrastructure
    create_bd_cell -type ip -vlnv cei.upm.es:artico3:artico3_shuffler:1.0 artico3_shuffler_0

    # Create instances of hardware kernels
<a3<generate for SLOTS>a3>
    create_bd_cell -type ip -vlnv cei.upm.es:artico3:<a3<SlotCoreName>a3>:[string range <a3<SlotCoreVersion>a3> 0 2] "a3_slot_<a3<id>a3>"
<a3<end generate>a3>

    # Required to avoid problems with AXI Interconnect
    set_property -dict [list CONFIG.C_S_AXI_ID_WIDTH {12}] [get_bd_cells artico3_shuffler_0]

    # Create and configure new AXI Interconnects
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_a3ctrl
    set_property -dict [ list CONFIG.NUM_MI {1} CONFIG.NUM_SI {1}] [get_bd_cells axi_a3ctrl]
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_a3data
    set_property -dict [ list CONFIG.NUM_MI {1} CONFIG.NUM_SI {1}] [get_bd_cells axi_a3data]
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_sem
    set_property -dict [ list CONFIG.NUM_MI {1} CONFIG.NUM_SI {1}] [get_bd_cells axi_sem]

    # Create SEM IP Subsystem
    set subsystem "SEM_subsystem"
    source export_sem_subsys.tcl

    # Connect GPIO ports
    connect_bd_net -net gpio_i [get_bd_pins $subsystem/gpio_i] [get_bd_pins zynq_ultra_ps_e_0/emio_gpio_o]
    connect_bd_net -net gpio_o [get_bd_pins $subsystem/gpio_o] [get_bd_pins zynq_ultra_ps_e_0/emio_gpio_i]

    # Make UART ports external
    create_bd_port -dir I uart_rx
    connect_bd_net -net uart_rx [get_bd_pins $subsystem/uart_rx] [get_bd_port uart_rx]
    create_bd_port -dir O uart_tx
    connect_bd_net -net uart_tx [get_bd_pins $subsystem/uart_tx] [get_bd_port uart_tx]

    # Connect AXI interfaces
    connect_bd_intf_net -intf_net axi_a3ctrl_S00_AXI [get_bd_intf_pins axi_a3ctrl/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD]
    connect_bd_intf_net -intf_net axi_a3ctrl_M00_AXI [get_bd_intf_pins axi_a3ctrl/M00_AXI] [get_bd_intf_pins artico3_shuffler_0/s00_axi]

    connect_bd_intf_net -intf_net axi_a3data_S00_AXI [get_bd_intf_pins axi_a3data/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM1_FPD]
    connect_bd_intf_net -intf_net axi_a3data_M00_AXI [get_bd_intf_pins axi_a3data/M00_AXI] [get_bd_intf_pins artico3_shuffler_0/s01_axi]

    connect_bd_intf_net -intf_net axi_sem_S00_AXI [get_bd_intf_pins axi_sem/S00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_LPD]
    connect_bd_intf_net -intf_net axi_sem_M00_AXI [get_bd_intf_pins axi_sem/M00_AXI] [get_bd_intf_pins $subsystem/s_axi]

    # Connect clocks
    connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
                        [get_bd_pins reset_0/slowest_sync_clk] \
                        [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk] \
                        [get_bd_pins axi_a3ctrl/ACLK] \
                        [get_bd_pins axi_a3ctrl/M00_ACLK] \
                        [get_bd_pins axi_a3ctrl/S00_ACLK] \
                        [get_bd_pins zynq_ultra_ps_e_0/maxihpm1_fpd_aclk] \
                        [get_bd_pins axi_a3data/ACLK] \
                        [get_bd_pins axi_a3data/M00_ACLK] \
                        [get_bd_pins axi_a3data/S00_ACLK] \
                        [get_bd_pins artico3_shuffler_0/s_axi_aclk] \
                        [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_lpd_aclk] \
                        [get_bd_pins axi_sem/ACLK] \
                        [get_bd_pins axi_sem/M00_ACLK] \
                        [get_bd_pins axi_sem/S00_ACLK] \
                        [get_bd_pins $subsystem/s_axi_aclk]

    # Connect resets
    connect_bd_net [get_bd_pins reset_0/ext_reset_in] [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0]

    connect_bd_net [get_bd_pins reset_0/Interconnect_aresetn] \
                        [get_bd_pins axi_a3ctrl/ARESETN] \
                        [get_bd_pins axi_a3ctrl/M00_ARESETN] \
                        [get_bd_pins axi_a3ctrl/S00_ARESETN] \
                        [get_bd_pins axi_a3data/ARESETN] \
                        [get_bd_pins axi_a3data/M00_ARESETN] \
                        [get_bd_pins axi_a3data/S00_ARESETN] \
                        [get_bd_pins axi_sem/ARESETN] \
                        [get_bd_pins axi_sem/M00_ARESETN] \
                        [get_bd_pins axi_sem/S00_ARESETN]

    connect_bd_net [get_bd_pins reset_0/peripheral_aresetn] \
                        [get_bd_pins artico3_shuffler_0/s_axi_aresetn] \
                        [get_bd_pins $subsystem/s_axi_aresetn]

    # Connect interrupts
    create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0
    set_property -dict [list CONFIG.NUM_PORTS {2}] [get_bd_cells xlconcat_0]

    connect_bd_net [get_bd_pins artico3_shuffler_0/interrupt] [get_bd_pins xlconcat_0/In0]
    connect_bd_net [get_bd_pins $subsystem/uart_interrupt] [get_bd_pins xlconcat_0/In1]
    connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]

    # Connect ARTICo3 slots
<a3<generate for SLOTS>a3>
    connect_bd_intf_net -intf_net artico3_slot<a3<id>a3> [get_bd_intf_pins artico3_shuffler_0/m<a3<id>a3>_artico3] [get_bd_intf_pins a3_slot_<a3<id>a3>/s_artico3]
<a3<end generate>a3>

    # Generate memory-mapped segments for custom peripherals
    create_bd_addr_seg -range 1M -offset 0xa0000000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs artico3_shuffler_0/s00_axi/reg0] SEG0
    create_bd_addr_seg -range 1M -offset 0xb0000000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs artico3_shuffler_0/s01_axi/reg0] SEG1
    create_bd_addr_seg -range 4K -offset 0x80000000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs $subsystem/axi2sem_0/s00_axi/reg0] SEG2
    create_bd_addr_seg -range 4K -offset 0x80003000 [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs $subsystem/axi_uartlite_0/S_AXI/Reg] SEG3

# END

    # Update layout of block design
    regenerate_bd_layout

    #make wrapper file; vivado needs it to implement design
    make_wrapper -files [get_files $proj_dir/$proj_name.srcs/sources_1/bd/system/system.bd] -top
    add_files -norecurse $proj_dir/$proj_name.srcs/sources_1/bd/system/hdl/system_wrapper.vhd
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1
    set_property top system_wrapper [current_fileset]
    save_bd_design

# KERNEL LIBRARY (Xilinx Partial Reconfiguration Flow)

<a3<generate for KERNELS(KernCoreName!="a3_dummy")>a3>
    #
    # Kernel : <a3<KernCoreName>a3>
    #

    # Create submodule block design
    create_bd_design "<a3<KernCoreName>a3>"

    # Create dummy port
    create_bd_intf_port -mode Slave -vlnv cei.upm.es:artico3:artico3_rtl:1.0 s_artico3

    # Create module instance
    create_bd_cell -type ip -vlnv cei.upm.es:artico3:<a3<KernCoreName>a3>:[string range <a3<KernCoreVersion>a3> 0 2] "slot"

    # Connect ARTICo3 slot
    connect_bd_intf_net -intf_net artico3_slot [get_bd_intf_ports s_artico3] [get_bd_intf_pins slot/s_artico3]

    # Update layout of block design
    regenerate_bd_layout

    #make wrapper file; vivado needs it to implement design
    make_wrapper -files [get_files $proj_dir/$proj_name.srcs/sources_1/bd/<a3<KernCoreName>a3>/<a3<KernCoreName>a3>.bd] -top
    add_files -norecurse $proj_dir/$proj_name.srcs/sources_1/bd/<a3<KernCoreName>a3>/hdl/<a3<KernCoreName>a3>_wrapper.vhd
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1
    save_bd_design
<a3<end generate>a3>
# END

# LOW-LEVEL DEPENDENCIES

    # Add DPR constraints
    add_files -fileset constrs_1 -norecurse $proj_dir/xczu9eg.xdc

    # Add other constraints
    add_files -fileset constrs_1 -norecurse $proj_dir/semip.xdc

# END

}

#
# Main script starts here
#

artico3_hw_setup $proj_path $proj_name $artico3_ip_dir
puts "\[A3DK\] project creation finished"
