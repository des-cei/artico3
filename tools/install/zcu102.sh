#!/bin/bash

#
# ARTICo3 Linux setup script
#
# Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
# Date        : May 2018
# Description : This shell script downloads, compiles, and sets up a
#               full embedded Linux environment to start working with
#               the ARTICo3 framework. This setup script relies on
#               Linaro Debian 18.04.
#
#
# The following code is a derivative work of the code from the ReconOS
# project, which is licensed GPLv2. This code therefore is also licensed
# under the terms of the GNU Public License, version 2.
#
# Author      : Georg Thombansen, Paderborn University
#


cat << EOF
#
# Welcome to the ARTICo3 Linux setup script.
#
# This script will help you create a fully functional embedded Linux
# system that can be used as the basic working environment for ARTICo3
# applications.
#
# System requirements:
#     -Board  : ZCU102 (Zynq UltraScale+ xczu9eg-ffvb1156-2-i)
#     -OS     : Ubuntu 16.04
#     -Xilinx : Vivado 2017.1
#     -Size   : ~3.0GB (free space)
#
# NOTE: while this script will only work for the Pynq development board,
#       the OS and Xilinx toolchain versions might still work if changed.
#       However, this script has only been tested in that scenario and
#       therefore, errors might occur if the settings are changed.
#
EOF


# Git tags to get known stable versions
#
# NOTE: users can decide to comment the respective lines in the code to
#       get the latest versions, but these are provided as failsafe
#       alternatives.
GITTAG_LINUX="xilinx-v2017.2"
GITTAG_DTC="v1.4.4"

# Xilinx tools installation directory
XILINX_ROOT="/opt"


# Functions to check availability of required applications and libraries
function pre_check {
    var=$3
    if command -v "$2" > /dev/null 2>&1; then
        printf "[OK]    $1\n"
    else
        printf "[ERROR] $1 (ubuntu pkg: $4)\n"
        eval $var=false
    fi
}

function pre_check_lib {
    var=$3
    ldconfig -p | grep "$2" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        printf "[OK]    $1\n"
    else
        printf "[ERROR] $1 (ubuntu pkg: $4)\n"
        eval $var=false
    fi
}


#
# [0] Parse command line arguments
#

if [ "$#" -ne 0 ]; then
    printf "Illegal number of arguments\n"
    printf "Usage: $0\n"
    exit 1
fi


#
# [1] Check dependencies
#

printf "Checking dependencies...\n"

# ARTICo3 toolchain (a3dk) relies on Python >= 3.5 (subprocess.run())
PYVERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[1:2])))')
PYVERSION=$(($PYVERSION + 0))
if command -v python3 > /dev/null 2>&1 && [[ $PYVERSION -ge 5 ]]; then
    printf "[OK]    Python\n"
else
    printf "[ERROR] Python\n"
    ALLCHECK=false
fi

# General dependencies
pre_check "Git" "git" ALLCHECK "git"
pre_check "Sed" "sed" ALLCHECK ""
#~ pre_check "NFS" "nfsstat" ALLCHECK "nfs-kernel-server"
pre_check "Make" "make" ALLCHECK "build-essential"
#~ pre_check_lib "lib32z1" "/usr/lib32/libz.so.1" ALLCHECK "lib32z1"
#~ pre_check_lib "libssl" "libssl.so$" ALLCHECK "libssl-dev"

# Device Tree Compiler (dtc) dependencies
pre_check "Flex" "flex" ALLCHECK "flex"
pre_check "Bison" "bison" ALLCHECK "bison"

# Dropbear dependencies (required for building)
#~ pre_check "Autoconf" "autoconf" ALLCHECK "autoconf"

if [ "$ALLCHECK" = false ]; then
    printf "Dependencies not met. Install missing packages and run script again.\n"
    exit 1
fi

# Exit if [ $? -ne 0 ] from now on (i.e. if any error occurs while
# executing one of the commands in the script.
set -e


#
# [2] Setup environment variables and working directory
#

# Create working directory
printf "Type path for ARTICo3 working directory:\n"
while true; do
    read -e -p "> " WD
    if [[ $WD = "" ]]; then
        continue
    fi
    WD=${WD/#\~/$HOME} # make tilde work
    if [ -d "$WD" ]; then # true if dir exists
        if find "$WD" -mindepth 1 -print -quit | grep -q .; then # true if dir not empty
            printf "The directory $(pwd)/$WD is not empty, please choose different name:\n"
        else # true if dir exists and emtpy
            break
        fi;
    else # true if dir does not exist
        mkdir -p $WD
        break
    fi
done
WD=$( cd $WD ; pwd -P ) # change to absolute path
cd $WD

# Get cross-compiler toolchain
printf "Type in your Xilinx Vivado tool version.\n"
printf "e.g. 2017.1\n"
while true; do
    read -e -p "> " -i "2017.1" XILINX_VERSION
    if [[ $XILINX_VERSION = "" ]]; then
        continue
    fi
    XILINX_VERSION=${XILINX_VERSION/#\~/$HOME} # make tilde work
    if [[ ! -e "$XILINX_ROOT/Xilinx/Vivado/$XILINX_VERSION" ]]; then
        printf "$XILINX_ROOT/Xilinx/Vivado/$XILINX_VERSION was not found. Change XILINX_ROOT value to match your installation directory and run script again.\n"
        exit 1
    else
        break
    fi
done

# Export environment variables
export ARCH="arm64"
export CROSS_COMPILE="$XILINX_ROOT/Xilinx/SDK/$XILINX_VERSION/gnu/aarch64/lin/aarch64-linux/bin/aarch64-linux-gnu-"
export KDIR="$WD/linux-xlnx"
export PATH="$WD/devicetree/dtc:$PATH"
export PATH="$WD/u-boot-digilent/tools:$PATH"

# Source Xilinx tools script (add Xilinx tools to the path)
source "$XILINX_ROOT/Xilinx/Vivado/$XILINX_VERSION/settings64.sh"


#
# [3] Download sources from Git repositories
#

git clone https://github.com/Xilinx/u-boot-xlnx.git
git clone https://github.com/xilinx/linux-xlnx


#
# [4] Build Device Tree
#

# Create working directory for device tree development
mkdir $WD/devicetree

# Download latest Device Tree Compiler (dtc), required to work with
# device tree overlays, and build it.
cd $WD/devicetree
git clone https://git.kernel.org/pub/scm/utils/dtc/dtc.git
cd $WD/devicetree/dtc
git checkout -b wb "$GITTAG_DTC"
make -j"$(nproc)"

# Download Xilinx device tree repository
#
# NOTE: repo version xilinx-v2017.4 is used to enable patching the Device
#       Tree files for the ZCU102 v1.0 revision.
#
cd $WD/devicetree
git clone https://github.com/Xilinx/device-tree-xlnx
cd $WD/devicetree/device-tree-xlnx
#~ git checkout -b wb "$GITTAG_LINUX"
git checkout -b wb "xilinx-v2017.4"

# Create directory to build device tree for Pynq board
mkdir $WD/devicetree/zcu102
cd $WD/devicetree/zcu102

# Create required files
cat > create_hdf.tcl << EOF
set cur_dir [pwd]

# Create Vivado project
create_project -force zcu102_dt \$cur_dir/zcu102_dt -part xczu9eg-ffvb1156-2-i
set proj_name [current_project]
set proj_dir [get_property directory [current_project]]
set_property "target_language" "VHDL" \$proj_name
set_property board_part xilinx.com:zcu102:part0:3.0 [current_project]

# Create block diagram
create_bd_design "design_1"
update_compile_order -fileset sources_1

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

# Connect clocks
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
               [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk] \
               [get_bd_pins zynq_ultra_ps_e_0/maxihpm1_fpd_aclk] \
               [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_lpd_aclk]

# Update layout of block design
regenerate_bd_layout

# Create wrapper file
make_wrapper -files [get_files \$proj_dir/\$proj_name.srcs/sources_1/bd/design_1/design_1.bd] -top
add_files -norecurse \$proj_dir/\$proj_name.srcs/sources_1/bd/design_1/hdl/design_1_wrapper.vhd
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
set_property top design_1_wrapper [current_fileset]
save_bd_design

# Generate output products
generate_target all [get_files  *.bd]

# Write hardware definition and close project
write_hwdef -force -file "\$cur_dir/zcu102.hdf"
close_project
EOF

cat > create_devicetree.tcl << EOF
open_hw_design zcu102.hdf
set_repo_path ../device-tree-xlnx
create_sw_design device-tree -os device_tree -proc psu_cortexa53_0
set_property CONFIG.periph_type_overrides "{BOARD zcu102-rev1.0}" [get_os]
generate_target -dir dts
EOF

# Generate device tree from a simple vivado project
vivado -mode batch -source create_hdf.tcl
hsi -mode batch -source create_devicetree.tcl

# Edit Device Tree
cd $WD/devicetree/zcu102/dts/

# Add interrupt controller to PL node
sed -i '/compatible = "simple-bus";/a \\t\tinterrupt-parent = <&gic>;' pl.dtsi

# Enable DMA usage via DMA Proxy
sed -i '/fpd_dma_chan1/a \\t\t\t#dma-cells = <1>;' zynqmp.dtsi

# Modify bootargs
BOOTARGS="bootargs = \"console=ttyPS0,115200 rootdelay=3 root=/dev/mmcblk0p2 rw earlyprintk uio_pdrv_genirq.of_id=generic-uio earlycon clk_ignore_unused\";"
sed -i "s|.*bootargs.*|\t\t$BOOTARGS|" system-top.dts

# Generate device tree blob (adding symbols, that is the reason for
# using the last version of dtc)
cd $WD/devicetree/zcu102/dts
dtc -I dts -O dtb -@ -o system.dtb system-top.dts


#
# [5] Build low-level firmware
#

mkdir -p $WD/firmware
cd $WD/firmware

#
# Build ARM Trusted Firmware
#
# NOTE: repo version xilinx-v2018.1 is used (it is compatible) because
#       it is the first release in which PL configuration from Linux is
#       done properly [1] (in previous releases, it was a non-blocking
#       process that led to runtime errors due to wrong PL programming and
#       race conditions).
#
# PL programming from Linux steps:
#
#     1. echo $flags > /sys/class/fpga_manager/fpga0/flags
#        echo $firmware > /sys/class/fpga_manager/fpga0/firmware
#
#        This procedure does not follow conventional FPGA Manager framework,
#        since it uses custom files named _flags_ and _firmware_ instead
#        of relying on Device Tree Overlays. See [2] for more info.
#
#     2. Linux (xilinx-v2017.2) @ ARM Cortex A53
#        | fpga_mgr_firmware_load()       drivers/fpga/fpga-mgr.c
#        | fpga_mgr_buf_load()            drivers/fpga/fpga-mgr.c
#        | zynqmp_fpga_ops_write()        drivers/fpga/zynqmp-fpga.c
#        | zynqmp_pm_fpga_load()          drivers/soc/xilinx/zynqmp/pm.c
#        | invoke_pm_fn()                 drivers/soc/xilinx/zynqmp/pm.c
#        | do_fw_call()                   drivers/soc/xilinx/zynqmp/pm.c
#        | do_fw_call_smc()               drivers/soc/xilinx/zynqmp/pm.c
#        | arm_smccc_smc()                arch/arm64/kernel/smccc-call.S
#
#     3. ARM Trusted Firmware (xilinx-v2018.1) @ ARM Cortex A53
#        | pm_smc_handler()               plat/xilinx/zynqmp/pm_service/pm_svc_main.c
#        | pm_fpga_load()                 plat/xilinx/zynqmp/pm_service/pm_api_sys.c
#        | pm_ipi_send_sync()             plat/xilinx/zynqmp/pm_service/pm_ipi.c
#        | pm_ipi_send_common()           plat/xilinx/zynqmp/pm_service/pm_ipi.c
#        | ipi_mb_notify()                plat/xilinx/zynqmp/pm_service/pm_ipi.c
#
#     4. Zynq MP PMU Firmware (xilinx-v2017.1) @ PMU MicroBlaze
#        | PmProcessApiCall ()            <embeddedsw>/lib/sw_apps/zynqmp_pmufw/src/pm_core.c
#        | PmFpgaLoad ()                  <embeddedsw>/lib/sw_apps/zynqmp_pmufw/src/pm_core.c
#        | XFpga_PL_BitSream_Load ()      <embeddedsw>/lib/sw_services/xilfpga/src/xilfpga_pcap.c
#
# [1] https://github.com/Xilinx/arm-trusted-firmware/commit/c055151bfd7641f9a748de2ecd50ff968ff07176#diff-84707f287ea5d2f11d613b22d81b5534
# [2] Documentation/devicetree/bindings/fpga/fpga-region.txt
#
git clone https://github.com/Xilinx/arm-trusted-firmware.git
cd $WD/firmware/arm-trusted-firmware
#~ git checkout -b wb "$GITTAG_LINUX"
git checkout -b wb "xilinx-v2018.1"
make -j $(nproc) PLAT=zynqmp RESET_TO_BL31=1

# Create ZynqMP FSBL + PMU Firmware projects
cd $WD/firmware
cp $WD/devicetree/zcu102/zcu102.hdf $WD/firmware
cat > create_firmware.tcl << EOF
set hwdsgn [open_hw_design zcu102.hdf]
generate_app -hw \$hwdsgn -os standalone -proc psu_cortexa53_0 -app zynqmp_fsbl -sw fsbl -dir fsbl
generate_app -hw \$hwdsgn -os standalone -proc psu_pmu_0 -app zynqmp_pmufw -sw pmufw -dir pmufw
EOF
hsi -mode batch -source create_firmware.tcl

# Modify BSPs to support DPR
#
# NOTE: these modifications have been made on top of xilfpga_v2_0, and
#       might not work with different versions (tested in Vivado 2017.1).
#
# TODO: check if the last one is the only important.
#
sed -i 's|Status = XFpga_PowerUpPl();|if (!(flags \& XFPGA_PARTIAL_EN)) Status = XFpga_PowerUpPl();|' $WD/firmware/pmufw/zynqmp_pmufw_bsp/psu_pmu_0/libsrc/xilfpga_*/src/xilfpga_pcap.c
sed -i 's|Status = XFpga_IsolationRestore();|if (!(flags \& XFPGA_PARTIAL_EN)) Status = XFpga_IsolationRestore();|' $WD/firmware/pmufw/zynqmp_pmufw_bsp/psu_pmu_0/libsrc/xilfpga_*/src/xilfpga_pcap.c
sed -i 's|XFpga_PsPlGpioReset(FPGA_NUM_FABRIC_RESETS);|if (!(flags \& XFPGA_PARTIAL_EN)) XFpga_PsPlGpioReset(FPGA_NUM_FABRIC_RESETS);|' $WD/firmware/pmufw/zynqmp_pmufw_bsp/psu_pmu_0/libsrc/xilfpga_*/src/xilfpga_pcap.c

# Build ZynqMP FSBL + PMU Firmware
cd $WD/firmware/fsbl
make
cd $WD/firmware/pmufw
make


#
# [6] Build U-Boot
#

cd $WD/u-boot-xlnx
git checkout -b wb "$GITTAG_LINUX"

make -j $(nproc) xilinx_zynqmp_zcu102_rev1.0_defconfig ;# xilinx_zynqmp_zcu102_rev1_0_defconfig for version >= xilinx-v2017.3

# Remove default bootargs (in some defconfigs, BOOTARGS is in the *_defconfig file)
sed -i '/.*bootargs=.*/d' $WD/u-boot-xlnx/include/configs/xilinx_zynqmp.h
sed -i 's|"sdboot=.*|"sdboot=mmc dev \$sdbootdev \&\& mmcinfo \&\& run uenvboot;" \\|' $WD/u-boot-xlnx/include/configs/xilinx_zynqmp.h

make -j $(nproc)


#
# [7] Generate boot image
#

mkdir -p $WD/boot
cd $WD/boot

# Copy files
cp $WD/firmware/fsbl/executable.elf fsbl.elf
cp $WD/firmware/pmufw/executable.elf pmufw.elf
cp $WD/firmware/arm-trusted-firmware/build/zynqmp/release/bl31/bl31.elf bl31.elf
cp $WD/u-boot-xlnx/u-boot.elf u-boot.elf

# Generate boot file
cat > boot.bif << EOF
image : {
    [bootloader, destination_cpu = a53-0]fsbl.elf
    [destination_cpu = pmu]pmufw.elf
    [destination_cpu = a53-0, exception_level = el-3, trustzone]bl31.elf
    [destination_cpu = a53-0, exception_level = el-2]u-boot.elf
}
EOF
bootgen -arch zynqmp -image boot.bif -o boot.bin


#
# [8] Build Linux kernel
#

cd $WD/linux-xlnx
git checkout -b wb "$GITTAG_LINUX"

make -j $(nproc) xilinx_zynqmp_defconfig

# Enable the following features:
#
#     1. Device Tree Overlays
#     2. Device Tree Overlays through configfs
#     3. UIO as built-in features, not modules
#
sed -i 's|.*CONFIG_OF_OVERLAY.*|CONFIG_OF_OVERLAY=y|' $WD/linux-xlnx/.config
sed -i '/.*CONFIG_OF_OVERLAY.*/a CONFIG_OF_CONFIGFS=y' $WD/linux-xlnx/.config
sed -i 's|CONFIG_UIO_PDRV_GENIRQ=m|CONFIG_UIO_PDRV_GENIRQ=y|' $WD/linux-xlnx/.config
sed -i 's|CONFIG_UIO_DMEM_GENIRQ=m|CONFIG_UIO_DMEM_GENIRQ=y|' $WD/linux-xlnx/.config

make -j $(nproc)


#
# [9] Prepare rootfs
#

mkdir $WD/rootfs
cd $WD/rootfs


#
# [10] Set up ARTICo3 system
#

# TODO: modify this to avoid private repository + move to step [4]
cd $WD
git clone https://alfonsorm@bitbucket.org/alfonsorm/artico3
cd $WD/artico3

# Build ARTICo3 Linux kernel modules
cd $WD/artico3/linux/drivers/dmaproxy
make -j $(nproc)

# Compile ARTICo3 device tree overlay
cat > $WD/rootfs/artico3.dts << EOF
/dts-v1/;
/plugin/;

/ {
    fragment@0 {
        target = <&amba_pl>;
        __overlay__ {
            artico3_shuffler_0: artico3_shuffler@a0000000 {
                compatible = "cei.upm,artico3-shuffler-1.0", "generic-uio";
                interrupt-parent = <&gic>;
                interrupts = <0 89 1>;
                reg = <0x0 0xa0000000 0x0 0x100000>;
            };
            artico3_slots_0: artico3_slots@b0000000 {
                compatible = "cei.upm,proxy-cdma-1.00.a";
                reg = <0x0 0xb0000000 0x0 0x100000>;
                dmas = <&fpd_dma_chan1 0>;
                dma-names = "ps-dma";
            };
        };
    };
};
EOF
dtc -I dts -O dtb -@ -o $WD/rootfs/artico3.dtbo $WD/rootfs/artico3.dts


#
# [11] Prepare SD card
#

cd $WD/rootfs

# Create SD image file
dd if=/dev/zero of=linarozcu102.img bs=1M count=4k status=progress

# Mount SD image file in loop device
sudo -H losetup -D
sudo -H losetup -P /dev/loop0 linarozcu102.img

#
# Create partitions
#
# to create the partitions programatically (rather than manually)
# we're going to simulate the manual input to fdisk
# The sed script strips off all the comments so that we can
# document what we're doing in-line with the actual commands
# Note that a blank line (commented as "default" will send a empty
# line terminated with a newline to take the fdisk default.
#
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | sudo -H fdisk /dev/loop0
  o # clear the in memory partition table
  n # new partition
  p # primary partition
  1 # partition number 1
    # default - start at beginning of disk
  +100M # 100 MB boot parttion
  n # new partition
  p # primary partition
  2 # partion number 2
    # default, start immediately after preceding partition
    # default, extend partition to end of disk
  a # make a partition bootable
  1 # bootable partition is partition 1 -- /dev/sda1
  t # change a partition type
  1 # target partition is partition 1
  c # partition type is W95 FAT32 (LBA)
  p # print the in-memory partition table
  w # write the partition table
  q # and we're done
EOF

# Format partitions
sudo -H mkfs.vfat /dev/loop0p1
sudo -H mkfs.ext4 /dev/loop0p2

# Mount partitions
mkdir $WD/rootfs/boot
mkdir $WD/rootfs/root
sudo -H mount -o defaults,uid=1000,gid=1000 /dev/loop0p1 $WD/rootfs/boot
sudo -H mount -t ext4 /dev/loop0p2 $WD/rootfs/root
#~ sudo -H chown "$USER":"$USER" $WD/rootfs/root

# Set up boot partition
cp $WD/boot/boot.bin $WD/rootfs/boot
cp $WD/linux-xlnx/arch/arm64/boot/Image $WD/rootfs/boot
cp $WD/devicetree/zcu102/dts/system.dtb $WD/rootfs/boot
sync

# Download Linaro (Debian) and extract rootfs
wget http://releases.linaro.org/debian/images/developer-arm64/18.04/linaro-stretch-developer-20180416-89.tar.gz
sudo -H tar --strip-components=1 -xzvphf linaro-stretch-developer-20180416-89.tar.gz -C root
sync

# Create script to initialize ARTICo3
cat > $WD/rootfs/setup.sh << EOF
# Load ARTICo3 device tree overlay
echo "Loading ARTICo3 device tree overlay..."
mkdir /sys/kernel/config/device-tree/overlays/artico3
echo overlays/artico3.dtbo > /sys/kernel/config/device-tree/overlays/artico3/path

# Load DMA proxy driver
echo "Loading DMA proxy driver..."
modprobe mdmaproxy

# Remove kernel messages from serial port
echo 1 > /proc/sys/kernel/printk
EOF
chmod +x $WD/rootfs/setup.sh

# Create script to move kernel modules to /lib/modules/...
cat > $WD/rootfs/artico3_init.sh << EOF
mkdir -p /lib/modules/\$(uname -r)
mv /root/mdmaproxy.ko /lib/modules/\$(uname -r)
touch /lib/modules/\$(uname -r)/modules.order
touch /lib/modules/\$(uname -r)/modules.builtin
depmod
rm -f /root/artico3_init.sh
EOF
chmod +x $WD/rootfs/artico3_init.sh

# Copy additional files
sudo -H mkdir -p $WD/rootfs/root/lib/firmware/overlays
sudo -H mv $WD/rootfs/artico3.dts $WD/rootfs/root/lib/firmware/overlays
sudo -H mv $WD/rootfs/artico3.dtbo $WD/rootfs/root/lib/firmware/overlays
sudo -H cp $WD/artico3/linux/drivers/dmaproxy/mdmaproxy.ko $WD/rootfs/root/root
sudo -H mv $WD/rootfs/setup.sh $WD/rootfs/root/root
sudo -H mv $WD/rootfs/artico3_init.sh $WD/rootfs/root/root
sync

# Unmount partitions
sudo -H umount /dev/loop0p1
sudo -H umount /dev/loop0p2
rm -rf $WD/rootfs/boot
rm -rf $WD/rootfs/root

# Remove SD image file from loop device
sudo -H losetup -D


#
# [12] Final steps
#

printf "ARTICo3 has been installed successfully.\n\n"
printf "Please execute the following post-installation steps:\n"
printf "* SD card image : $WD/rootfs/linarozcu102.img\n"
printf "  > sudo -H dd if=$WD/rootfs/linarozcu102.img of=/dev/sdX bs=4M status=progress\n"
printf "* Set boot mode to SD.\n"
printf "* Turn on the board, connect with UART.\n"
printf "* If 'ZynqMP> ' prompt appears type 'boot' followed by 'Enter'.\n\n"
printf "The Linux prompt '#/ ' will appear.\n"
printf "* Execute ./artico3_init.sh to set environment for the first time.\n"
