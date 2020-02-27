#
# ARTICo3 IP library script for Vivado
#
# Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
# Date        : May 2018
#
# Description : Generates FPGA bitstream from Vivado project.
#

<a3<artico3_preproc>a3>

proc get_cpu_core_count {} {
    global tcl_platform env
    switch ${tcl_platform(platform)} {
        "windows" {
            return $env(NUMBER_OF_PROCESSORS)
        }

        "unix" {
            if {![catch {open "/proc/cpuinfo"} f]} {
            set cores [regexp -all -line {^processor\s} [read $f]]
            close $f
            if {$cores > 0} {
                return $cores
            }
            }
        }

        "Darwin" {
            if {![catch {exec $sysctl -n "hw.ncpu"} cores]} {
            return $cores
            }
        }

        default {
            puts "Unknown System"
            return 1
        }
    }
}

proc artico3_build_bitstream {} {

    #~ open_project myARTICo3.xpr
    #~ launch_runs impl_1 -to_step write_bitstream -jobs [ expr [get_cpu_core_count] / 2 + 1]
    #~ wait_on_run impl_1
    #~ close_project

    # Open Vivado project
    open_project myARTICo3.xpr

    #
    # Main system synthesis
    #

    puts "\[A3DK\] generating static system"

    # Synthesize main system
    launch_runs synth_1 -jobs [ expr [get_cpu_core_count] / 2 + 1]
    wait_on_run synth_1

<a3<generate for KERNELS(KernCoreName!="a3_dummy")>a3>
    #
    # Kernel synthesis : <a3<KernCoreName>a3>
    #

    puts "\[A3DK\] generating kernel <a3<KernCoreName>a3>"

    # Generate output products
    generate_target all [get_files *<a3<KernCoreName>a3>.bd]
    # Export IP user files
    export_ip_user_files -of_objects [get_files *<a3<KernCoreName>a3>.bd] -no_script -sync -force -quiet
    # Create specific IP run
    create_ip_run [get_files -of_objects [get_fileset sources_1] *<a3<KernCoreName>a3>.bd]
    # Launch module run
    launch_runs -jobs [ expr [get_cpu_core_count] / 2 + 1] <a3<KernCoreName>a3>_slot_0_synth_1
    # Wait for module run to finish
    wait_on_run <a3<KernCoreName>a3>_slot_0_synth_1
<a3<end generate>a3>
    #
    # Main system implementation
    #

    puts "\[A3DK\] implementing static system"

    # Run implementation
    launch_runs impl_1 -to_step route_design -jobs [ expr [get_cpu_core_count] / 2 + 1]
    wait_on_run impl_1

    # Open implemented design
    open_run impl_1

    # HOLD FIX
    phys_opt_design -directive ExploreWithHoldFix

    # Save checkpoint
    file mkdir [pwd]/checkpoints
    write_checkpoint -force checkpoints/system.dcp

    # Generate static system bitstream
    file mkdir [pwd]/bitstreams
    write_bitstream -force -no_partial_bitfile bitstreams/system.bit
    file mkdir [pwd]/bin
    file mkdir [pwd]/bin/pbs
    write_cfgmem -force -disablebitswap -interface SMAPx32 -format BIN -loadbit "up 0x0 bitstreams/system.bit" bin/system.bin

    # Replace slot contents by black boxes
<a3<generate for SLOTS>a3>
    update_design -cells [get_cells -hierarchical a3_slot_<a3<id>a3>] -black_box
<a3<end generate>a3>

    # Lock static routing
    lock_design -level routing

    # Save checkpoint
    write_checkpoint -force checkpoints/static.dcp

<a3<generate for KERNELS(KernCoreName!="a3_dummy")>a3>
    #
    # Kernel implementation : <a3<KernCoreName>a3>
    #

    puts "\[A3DK\] implementing kernel <a3<KernCoreName>a3>"

    # Open checkpoint
    open_checkpoint checkpoints/static.dcp

    # Replace black boxes by kernel logic
<a3<=generate for SLOTS=>a3>
    read_checkpoint -cell [get_cells -hierarchical a3_slot_<a3<id>a3>] myARTICo3.runs/<a3<KernCoreName>a3>_slot_0_synth_1/<a3<KernCoreName>a3>_slot_0.dcp
<a3<=end generate=>a3>

    # Run implementation
    opt_design
    place_design
    route_design

    # HOLD FIX
    phys_opt_design -directive ExploreWithHoldFix

    # Save checkpoint
    write_checkpoint -force checkpoints/<a3<KernCoreName>a3>.dcp

    # Verify checkpoint compatibility
    pr_verify checkpoints/system.dcp checkpoints/<a3<KernCoreName>a3>.dcp

    # Generate bitstreams
    write_bitstream -force bitstreams/<a3<KernCoreName>a3>.bit
<a3<=generate for SLOTS=>a3>
    write_cfgmem -force -disablebitswap -interface SMAPx32 -format BIN -loadbit "up 0x0 bitstreams/<a3<KernCoreName>a3>_a3_slot_<a3<id>a3>_partial.bit" bin/pbs/<a3<KernCoreName>a3>_a3_slot_<a3<id>a3>_partial.bin
<a3<=end generate=>a3>
<a3<end generate>a3>
    # Close Vivado project
    close_project

    # Clean write_cfgmem report files
    file delete -force {*}[glob bin/*.prm]
    file delete -force {*}[glob bin/pbs/*.prm]

}

#
# Main script starts here
#

artico3_build_bitstream
exit
