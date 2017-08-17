#
# ARTICo3 IP library script for Vivado
#
# Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
# Date        : August 2017
#
# Description : This script generates the required IP library to be used
#               in Vivado IP integrator (packages all required IPs) as
#               part of the process carried out in the export.tcl script.
#

<a3<artico3_preproc>a3>

proc create_artico3_interfaces {repo_path} {

    #
    # ARTICo3 custom interface definition
    #
    # s_artico3_aclk    : in  std_logic;
    # s_artico3_aresetn : in  std_logic;
    # s_artico3_start   : in  std_logic;
    # s_artico3_ready   : out std_logic;
    # s_artico3_en      : in  std_logic;
    # s_artico3_we      : in  std_logic;
    # s_artico3_mode    : in  std_logic;
    # s_artico3_addr    : in  std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
    # s_artico3_wdata   : in  std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0);
    # s_artico3_rdata   : out std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0):
    #

    # ARTICo3 custom interface
    ipx::create_abstraction_definition cei.upm.es artico3 artico3_rtl 1.0
    ipx::create_bus_definition cei.upm.es artico3 artico3 1.0
    set_property xml_file_name $repo_path/artico3_rtl.xml [ipx::current_busabs]
    set_property xml_file_name $repo_path/artico3.xml [ipx::current_busdef]
    set_property bus_type_vlnv cei.upm.es:artico3:artico3:1.0 [ipx::current_busabs]
    set_property description {ARTICo3 custom interface (Shuffler and Accelerators)} [ipx::current_busdef]

    # ARTICo3 clock port
    ipx::add_bus_abstraction_port artico3_aclk [ipx::current_busabs]
    set_property default_value 0 [ipx::get_bus_abstraction_ports artico3_aclk -of_objects [ipx::current_busabs]]
    set_property master_presence required [ipx::get_bus_abstraction_ports artico3_aclk -of_objects [ipx::current_busabs]]
    set_property master_width 1 [ipx::get_bus_abstraction_ports artico3_aclk -of_objects [ipx::current_busabs]]
    set_property slave_presence required [ipx::get_bus_abstraction_ports artico3_aclk -of_objects [ipx::current_busabs]]
    set_property slave_direction in [ipx::get_bus_abstraction_ports artico3_aclk -of_objects [ipx::current_busabs]]
    set_property slave_width 1 [ipx::get_bus_abstraction_ports artico3_aclk -of_objects [ipx::current_busabs]]
    set_property description {ARTICo3 clock signal} [ipx::get_bus_abstraction_ports artico3_aclk -of_objects [ipx::current_busabs]]

    # ARTICo3 reset port
    ipx::add_bus_abstraction_port artico3_aresetn [ipx::current_busabs]
    set_property default_value 0 [ipx::get_bus_abstraction_ports artico3_aresetn -of_objects [ipx::current_busabs]]
    set_property master_presence required [ipx::get_bus_abstraction_ports artico3_aresetn -of_objects [ipx::current_busabs]]
    set_property master_width 1 [ipx::get_bus_abstraction_ports artico3_aresetn -of_objects [ipx::current_busabs]]
    set_property slave_presence required [ipx::get_bus_abstraction_ports artico3_aresetn -of_objects [ipx::current_busabs]]
    set_property slave_direction in [ipx::get_bus_abstraction_ports artico3_aresetn -of_objects [ipx::current_busabs]]
    set_property slave_width 1 [ipx::get_bus_abstraction_ports artico3_aresetn -of_objects [ipx::current_busabs]]
    set_property description {ARTICo3 reset signal (active low)} [ipx::get_bus_abstraction_ports artico3_aresetn -of_objects [ipx::current_busabs]]

    # ARTICo3 start port
    ipx::add_bus_abstraction_port artico3_start [ipx::current_busabs]
    set_property default_value 0 [ipx::get_bus_abstraction_ports artico3_start -of_objects [ipx::current_busabs]]
    set_property master_presence required [ipx::get_bus_abstraction_ports artico3_start -of_objects [ipx::current_busabs]]
    set_property master_width 1 [ipx::get_bus_abstraction_ports artico3_start -of_objects [ipx::current_busabs]]
    set_property slave_presence required [ipx::get_bus_abstraction_ports artico3_start -of_objects [ipx::current_busabs]]
    set_property slave_direction in [ipx::get_bus_abstraction_ports artico3_start -of_objects [ipx::current_busabs]]
    set_property slave_width 1 [ipx::get_bus_abstraction_ports artico3_start -of_objects [ipx::current_busabs]]
    set_property description {ARTICo3 start signal (rising-edge sensitive)} [ipx::get_bus_abstraction_ports artico3_start -of_objects [ipx::current_busabs]]

    # ARTICo3 ready port
    ipx::add_bus_abstraction_port artico3_ready [ipx::current_busabs]
    set_property default_value 0 [ipx::get_bus_abstraction_ports artico3_ready -of_objects [ipx::current_busabs]]
    set_property master_presence required [ipx::get_bus_abstraction_ports artico3_ready -of_objects [ipx::current_busabs]]
    set_property master_direction in [ipx::get_bus_abstraction_ports artico3_ready -of_objects [ipx::current_busabs]]
    set_property master_width 1 [ipx::get_bus_abstraction_ports artico3_ready -of_objects [ipx::current_busabs]]
    set_property slave_presence required [ipx::get_bus_abstraction_ports artico3_ready -of_objects [ipx::current_busabs]]
    set_property slave_width 1 [ipx::get_bus_abstraction_ports artico3_ready -of_objects [ipx::current_busabs]]
    set_property description {ARTICo3 ready signal (level-high sensitive)} [ipx::get_bus_abstraction_ports artico3_ready -of_objects [ipx::current_busabs]]

    # ARTICo3 enable port
    ipx::add_bus_abstraction_port artico3_en [ipx::current_busabs]
    set_property default_value 0 [ipx::get_bus_abstraction_ports artico3_en -of_objects [ipx::current_busabs]]
    set_property master_presence required [ipx::get_bus_abstraction_ports artico3_en -of_objects [ipx::current_busabs]]
    set_property master_width 1 [ipx::get_bus_abstraction_ports artico3_en -of_objects [ipx::current_busabs]]
    set_property slave_presence required [ipx::get_bus_abstraction_ports artico3_en -of_objects [ipx::current_busabs]]
    set_property slave_direction in [ipx::get_bus_abstraction_ports artico3_en -of_objects [ipx::current_busabs]]
    set_property slave_width 1 [ipx::get_bus_abstraction_ports artico3_en -of_objects [ipx::current_busabs]]
    set_property description {ARTICo3 accelerator enable signal} [ipx::get_bus_abstraction_ports artico3_en -of_objects [ipx::current_busabs]]

    # ARTICo3 write enable port
    ipx::add_bus_abstraction_port artico3_we [ipx::current_busabs]
    set_property default_value 0 [ipx::get_bus_abstraction_ports artico3_we -of_objects [ipx::current_busabs]]
    set_property master_presence required [ipx::get_bus_abstraction_ports artico3_we -of_objects [ipx::current_busabs]]
    set_property master_width 1 [ipx::get_bus_abstraction_ports artico3_we -of_objects [ipx::current_busabs]]
    set_property slave_presence required [ipx::get_bus_abstraction_ports artico3_we -of_objects [ipx::current_busabs]]
    set_property slave_direction in [ipx::get_bus_abstraction_ports artico3_we -of_objects [ipx::current_busabs]]
    set_property slave_width 1 [ipx::get_bus_abstraction_ports artico3_we -of_objects [ipx::current_busabs]]
    set_property description {ARTICo3 accelerator write enable signal} [ipx::get_bus_abstraction_ports artico3_we -of_objects [ipx::current_busabs]]

    # ARTICo3 access mode port
    ipx::add_bus_abstraction_port artico3_mode [ipx::current_busabs]
    set_property default_value 0 [ipx::get_bus_abstraction_ports artico3_mode -of_objects [ipx::current_busabs]]
    set_property master_presence required [ipx::get_bus_abstraction_ports artico3_mode -of_objects [ipx::current_busabs]]
    set_property master_width 1 [ipx::get_bus_abstraction_ports artico3_mode -of_objects [ipx::current_busabs]]
    set_property slave_presence required [ipx::get_bus_abstraction_ports artico3_mode -of_objects [ipx::current_busabs]]
    set_property slave_direction in [ipx::get_bus_abstraction_ports artico3_mode -of_objects [ipx::current_busabs]]
    set_property slave_width 1 [ipx::get_bus_abstraction_ports artico3_mode -of_objects [ipx::current_busabs]]
    set_property description {ARTICo3 access mode signal (0 - registers, 1 - memory)} [ipx::get_bus_abstraction_ports artico3_mode -of_objects [ipx::current_busabs]]

    # TODO: make bus width configurable in the following three elements (now fixed to 32 bits)

    # ARTICo3 address port
    ipx::add_bus_abstraction_port artico3_addr [ipx::current_busabs]
    set_property default_value 0 [ipx::get_bus_abstraction_ports artico3_addr -of_objects [ipx::current_busabs]]
    set_property master_presence required [ipx::get_bus_abstraction_ports artico3_addr -of_objects [ipx::current_busabs]]
    set_property master_width 32 [ipx::get_bus_abstraction_ports artico3_addr -of_objects [ipx::current_busabs]]
    set_property slave_presence required [ipx::get_bus_abstraction_ports artico3_addr -of_objects [ipx::current_busabs]]
    set_property slave_direction in [ipx::get_bus_abstraction_ports artico3_addr -of_objects [ipx::current_busabs]]
    set_property slave_width 32 [ipx::get_bus_abstraction_ports artico3_addr -of_objects [ipx::current_busabs]]
    set_property description {ARTICo3 address signal (multiplexed for read and write operations)} [ipx::get_bus_abstraction_ports artico3_addr -of_objects [ipx::current_busabs]]

    # ARTICo3 write data port
    ipx::add_bus_abstraction_port artico3_wdata [ipx::current_busabs]
    set_property default_value 0 [ipx::get_bus_abstraction_ports artico3_wdata -of_objects [ipx::current_busabs]]
    set_property master_presence required [ipx::get_bus_abstraction_ports artico3_wdata -of_objects [ipx::current_busabs]]
    set_property master_width 32 [ipx::get_bus_abstraction_ports artico3_wdata -of_objects [ipx::current_busabs]]
    set_property slave_presence required [ipx::get_bus_abstraction_ports artico3_wdata -of_objects [ipx::current_busabs]]
    set_property slave_direction in [ipx::get_bus_abstraction_ports artico3_wdata -of_objects [ipx::current_busabs]]
    set_property slave_width 32 [ipx::get_bus_abstraction_ports artico3_wdata -of_objects [ipx::current_busabs]]
    set_property description {ARTICo3 write data channel} [ipx::get_bus_abstraction_ports artico3_wdata -of_objects [ipx::current_busabs]]

    # ARTICo3 data out port
    ipx::add_bus_abstraction_port artico3_rdata [ipx::current_busabs]
    set_property default_value 0 [ipx::get_bus_abstraction_ports artico3_rdata -of_objects [ipx::current_busabs]]
    set_property master_presence required [ipx::get_bus_abstraction_ports artico3_rdata -of_objects [ipx::current_busabs]]
    set_property master_direction in [ipx::get_bus_abstraction_ports artico3_rdata -of_objects [ipx::current_busabs]]
    set_property master_width 32 [ipx::get_bus_abstraction_ports artico3_rdata -of_objects [ipx::current_busabs]]
    set_property slave_presence required [ipx::get_bus_abstraction_ports artico3_rdata -of_objects [ipx::current_busabs]]
    set_property slave_width 32 [ipx::get_bus_abstraction_ports artico3_rdata -of_objects [ipx::current_busabs]]
    set_property description {ARTICo3 read data channel} [ipx::get_bus_abstraction_ports artico3_rdata -of_objects [ipx::current_busabs]]

    # Save and finish
    ipx::save_abstraction_definition [ipx::current_busabs]
    ipx::save_bus_definition [ipx::current_busdef]

}

proc load_artico3_interfaces {repo_path} {

    ipx::open_ipxact_file $repo_path/artico3.xml

}

proc add_artico3_interface {path_to_ip bus_name aclk_signal_name aresetn_signal_name start_signal_name ready_signal_name en_signal_name we_signal_name mode_signal_name addr_signal_name wdata_signal_name rdata_signal_name mode} {

    ipx::current_core $path_to_ip/component.xml

    #
    # Set specific interface (master for Shuffler, slave for accelerators)
    #
    ipx::add_bus_interface $bus_name [ipx::current_core]
    set_property abstraction_type_vlnv cei.upm.es:artico3:artico3_rtl:1.0 [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]
    set_property bus_type_vlnv cei.upm.es:artico3:artico3:1.0 [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]
    if { [string equal "master" $mode] == 1 } {
        set_property interface_mode master [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]
    }

    # ARTICo3 clock port
    ipx::add_port_map artico3_aclk [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]
    set_property physical_name $aclk_signal_name [ipx::get_port_maps artico3_aclk -of_objects [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]]

    # ARTICo3 reset port
    ipx::add_port_map artico3_aresetn [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]
    set_property physical_name $aresetn_signal_name [ipx::get_port_maps artico3_aresetn -of_objects [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]]

    # ARTICo3 start port
    ipx::add_port_map artico3_start [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]
    set_property physical_name $start_signal_name [ipx::get_port_maps artico3_start -of_objects [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]]

    # ARTICo3 ready port
    ipx::add_port_map artico3_ready [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]
    set_property physical_name $ready_signal_name [ipx::get_port_maps artico3_ready -of_objects [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]]

    # ARTICo3 enable port
    ipx::add_port_map artico3_en [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]
    set_property physical_name $en_signal_name [ipx::get_port_maps artico3_en -of_objects [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]]

    # ARTICo3 write enable port
    ipx::add_port_map artico3_we [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]
    set_property physical_name $we_signal_name [ipx::get_port_maps artico3_we -of_objects [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]]

    # ARTICo3 access mode port
    ipx::add_port_map artico3_mode [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]
    set_property physical_name $mode_signal_name [ipx::get_port_maps artico3_mode -of_objects [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]]

    # ARTICo3 address port
    ipx::add_port_map artico3_addr [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]
    set_property physical_name $addr_signal_name [ipx::get_port_maps artico3_addr -of_objects [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]]

    # ARTICo3 write data port
    ipx::add_port_map artico3_wdata [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]
    set_property physical_name $wdata_signal_name [ipx::get_port_maps artico3_wdata -of_objects [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]]

    # ARTICo3 data out port
    ipx::add_port_map artico3_rdata [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]
    set_property physical_name $rdata_signal_name [ipx::get_port_maps artico3_rdata -of_objects [ipx::get_bus_interfaces $bus_name -of_objects [ipx::current_core]]]

    #
    # Save everything
    #
    ipx::create_xgui_files [ipx::current_core]
    ipx::update_checksums [ipx::current_core]
    ipx::save_core [ipx::current_core]

}

proc import_pcore { repo_path ip_name {libs ""} } {

    set artico3_pcore $ip_name  ;#[file tail $argv]
    set artico3_pcore_name [string range $artico3_pcore 0 [expr [string length $artico3_pcore]-9] ] ;# cuts of version string
    set artico3_pcore_dir $repo_path ;#[file dirname $argv]
    set temp_dir "/tmp/artico3_tmp/"

    puts "\[A3DK\] $artico3_pcore $artico3_pcore_name $artico3_pcore_dir $temp_dir"

    if { $artico3_pcore_name == "artico3" } {
        ipx::infer_core -set_current true -as_library true -vendor cei.upm.es -taxonomy /ARTICo3  $artico3_pcore_dir/$artico3_pcore
        set_property display_name artico3lib [ipx::current_core]
    } else {
        ipx::infer_core -set_current true -as_library false -vendor cei.upm.es -taxonomy /ARTICo3  $artico3_pcore_dir/$artico3_pcore
    }

    puts "\[A3DK\] After infer_core"
    set_property vendor                 cei.upm.es              [ipx::current_core]
    set_property library                artico3                 [ipx::current_core]
    set_property name                   $artico3_pcore_name     [ipx::current_core]
    set_property company_url            http://www.cei.upm.es/  [ipx::current_core]
    set_property display_name           $artico3_pcore_name     [ipx::current_core]
    set_property vendor_display_name    {Centro de Electronica Industrial (CEI-UPM)} [ipx::current_core]
    set_property description            {ARTICo3 Library}       [ipx::current_core]

    # Set libraries
    foreach {lib} $libs {
        puts "\[A3DK\] adding subcore $lib"
        ipx::add_subcore $lib [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
    }

    # Modify memory map type (default is AXI4-Lite + registers, use more general AXI4-Full + memory)
    if { [join [ipx::get_memory_maps -of_objects [ipx::current_core]] ""] != "" } {
        puts "\[A3DK\] changing behavior of memory map"
        set_property usage memory [ipx::get_address_blocks -of_objects [ipx::get_memory_maps -of_objects [ipx::current_core]]]
    }

    # ARTICo3 infrastructure
    if { $artico3_pcore_name == "artico3_shuffler" } {
        puts "\[A3DK\] applying ARTICo3 infrastructure specific configuration"
        # Associate AXI interfaces to clock. Given the particular structure
        # (one clock/reset pair for two AXI4 interfaces), this is not done
        # automatically by Vivado and requires user intervention.
        ipx::associate_bus_interfaces -busif s00_axi -clock s_axi_aclk [ipx::current_core]
        ipx::associate_bus_interfaces -busif s01_axi -clock s_axi_aclk [ipx::current_core]
        # TODO: associate ARTICo3 interfaces to clock (not done automatically) [NOT NECESSARY, WOULD REQUIRE PARSING ALSO]
        #~ ipx::associate_bus_interfaces -busif m00_artico3 -clock m00_artico3_aclk [ipx::current_core]
    }

    set_property core_revision 1 [ipx::current_core]
    ipx::create_xgui_files [ipx::current_core]

    ipx::update_checksums [ipx::current_core]
    ipx::save_core [ipx::current_core]
    puts "\[A3DK\] After save_core"

}

#
# Main script starts here
#

set ip_repo "pcores"
set temp_dir "/tmp/artico3_tmp/"

create_project -force managed_ip_project $temp_dir/managed_ip_project -part xc7z020clg400-1 -ip
set_property  ip_repo_paths  $ip_repo [current_project]

create_artico3_interfaces $ip_repo
load_artico3_interfaces $ip_repo

import_pcore $ip_repo artico3_shuffler_v1_00_a ""

# Import all required ARTICo3 kernels
<a3<generate for SLOTS>a3>
lappend kerns_list <a3<KernCoreName>a3>_v[string map {. _} "<a3<KernCoreVersion>a3>"]
<a3<end generate>a3>

# Make the elements of the list unique, i.e. remove duplicates
set kerns_list [lsort -unique $kerns_list]

# Import all hardware kernels exactly once
foreach kernel $kerns_list {
    import_pcore $ip_repo $kernel ""
}

# Create as many ARTICo3 master interfaces as required in Shuffler
set ip_name "artico3_shuffler_v1_00_a"
<a3<generate for SLOTS>a3>
add_artico3_interface $ip_repo/$ip_name "m<a3<id>a3>_artico3" "m<a3<id>a3>_artico3_aclk" "m<a3<id>a3>_artico3_aresetn" "m<a3<id>a3>_artico3_start" "m<a3<id>a3>_artico3_ready" "m<a3<id>a3>_artico3_en" "m<a3<id>a3>_artico3_we" "m<a3<id>a3>_artico3_mode" "m<a3<id>a3>_artico3_addr" "m<a3<id>a3>_artico3_wdata" "m<a3<id>a3>_artico3_rdata" "master"
<a3<end generate>a3>

# Create one ARTICo3 slave interface in each kernel
foreach kernel $kerns_list {
    set ip_name $kernel
    add_artico3_interface $ip_repo/$ip_name "s_artico3" "s_artico3_aclk" "s_artico3_aresetn" "s_artico3_start" "s_artico3_ready" "s_artico3_en" "s_artico3_we" "s_artico3_mode" "s_artico3_addr" "s_artico3_wdata" "s_artico3_rdata" "slave"
}

close_project
file delete -force $temp_dir
