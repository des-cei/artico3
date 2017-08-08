#
# ARTICo3 IP library script for Vivado
#
# Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
# Date        : August 2017
#
# Description : Generates FPGA bitstream from Vivado project.
#

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
    
    open_project test/test.xpr
    launch_runs impl_1 -to_step write_bitstream -jobs [ expr [get_cpu_core_count] / 2 + 1]
    wait_on_run impl_1
    close_project
    
}

#
# Main script starts here
#

artico3_build_bitstream
exit
