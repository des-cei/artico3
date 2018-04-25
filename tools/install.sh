#!/bin/bash

#
# ARTICo3 Linux setup script
#
# Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
# Date        : August 2017
# Description : This shell script downloads, compiles, and sets up a
#               full embedded Linux environment to start working with
#               the ARTICo3 framework.
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
#     -Board  : Pynq (Zynq-7000 xc7z020clg400-1)
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
GITTAG_UBOOT="digilent-v2016.07"
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
pre_check "NFS" "nfsstat" ALLCHECK "nfs-kernel-server"
pre_check "Make" "make" ALLCHECK "build-essential"
pre_check_lib "lib32z1" "/usr/lib32/libz.so.1" ALLCHECK "lib32z1"
pre_check_lib "libssl" "libssl.so$" ALLCHECK "libssl-dev"

# Device Tree Compiler (dtc) dependencies
pre_check "Flex" "flex" ALLCHECK "flex"
pre_check "Bison" "bison" ALLCHECK "bison"

# Dropbear dependencies (required for building)
pre_check "Autoconf" "autoconf" ALLCHECK "autoconf"

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
export ARCH="arm"
#~ export CROSS_COMPILE="$XILINX_ROOT/Xilinx/SDK/$XILINX_VERSION/gnu/arm/lin/bin/arm-xilinx-linux-gnueabi-"
export CROSS_COMPILE="$XILINX_ROOT/Xilinx/SDK/$XILINX_VERSION/gnu/aarch32/lin/gcc-arm-linux-gnueabi/bin/arm-linux-gnueabihf-"
export KDIR="$WD/linux-xlnx"
export PATH="$WD/devicetree/dtc:$PATH"
export PATH="$WD/u-boot-digilent/tools:$PATH"

# Source Xilinx tools script (add Xilinx tools to the path)
source "$XILINX_ROOT/Xilinx/Vivado/$XILINX_VERSION/settings64.sh"

# Set GCC toolchain sysroot (required to enable dynamic application linking
# in the target system).
#
# NOTE: certain applications (specially network-based ones such as dropbear
#       or udhcpc) will not work properly when statically linked using a
#       glibc-based toolchain (https://lists.debian.org/debian-boot/2014/09/msg00700.html).
#       Can be solved using a custom toolchain featuring uclibc-ng instead.
#
GCC_SYSROOT="$XILINX_ROOT/Xilinx/SDK/$XILINX_VERSION/gnu/arm/lin/arm-xilinx-linux-gnueabi/libc"


#
# [3] Select rootfs mode
#

cat << EOF
This script supports three ways for setting up the root filesystem required by
the Linux kernel:
1. NFS share: The root filesystem is stored in a folder on the host PC, which
   is exported via NFS. This method is the best option to quickly share files
   between Pynq board and Host PC, which increases comfort during development.
   Network connectivity via Ethernet is required.
2. initrd image: Here the root filesystem is stored in a ramdisk image
   placed on the SD card. The Pynq board can work independently of a host PC
   but making changes to the filesystem and moving data to the Pynq board is
   more difficult.
3. initramfs image: same as 2, but using initramfs image instead of initrd.
EOF

printf "Type '1' for root filesystem as NFS share, '2' for initrd image, '3' for initramfs image.\n"
while true; do
    read -e -p "> " -i "1" ROOTFS
    if [[ $ROOTFS = "" ]]; then
        continue
    fi
    if [[ $ROOTFS =~ ^[1-3]$ ]]; then
        break
    else
        printf "Not valid. Choose {1,2,3}.\n"
    fi
done

if [[ $ROOTFS = 1 ]]; then
    printf "Type board IP.\n"
    while true; do
        read -e -p "> " -i "192.168.0.1" BOARDIP
        if [[ $BOARDIP = "" ]]; then
            continue
        fi
        if [[ $BOARDIP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        else
            printf "Not a valid IP, try again.\n"
        fi
    done

    # boardip = hostip + 1
    IFS='.' read -ra NBR <<< "$BOARDIP"
    INC=$((${NBR[3]} + 1))
    HOSTIPINC="${NBR[0]}.${NBR[1]}.${NBR[2]}.$INC"

    printf "Type host IP.\n"
    while true; do
        read -e -p "> " -i "$HOSTIPINC" HOSTIP
        if [[ $HOSTIP = "" ]]; then
            continue
        fi
        if [[ $HOSTIP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        else
            printf "Not a valid IP, try again.\n"
        fi
    done
fi


#
# [4] Download sources from Git repositories
#

git clone https://github.com/Digilent/u-boot-digilent
git clone https://github.com/xilinx/linux-xlnx
git clone git://git.busybox.net/busybox
git clone https://github.com/mkj/dropbear


#
# [5] Build Device Tree
#

# Create working directory for device tree development
mkdir $WD/devicetree
cd $WD/devicetree

# Download latest Device Tree Compiler (dtc), required to work with
# device tree overlays, and build it.
git clone https://git.kernel.org/pub/scm/utils/dtc/dtc.git
cd dtc
git checkout -b wb "$GITTAG_DTC"
make -j"$(nproc)"

# Create directory to build device tree for Pynq board
mkdir $WD/devicetree/pynq
cd $WD/devicetree/pynq

# Create required files
cat >> pynq_c_pl.xdc << EOF
## This file is a general .xdc for the PYNQ-Z1 board Rev. C
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project

## Clock signal 125 MHz

#set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { sysclk }]; #IO_L13P_T2_MRCC_35 Sch=sysclk
#create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { sysclk }];

##Switches

#set_property -dict { PACKAGE_PIN M20   IOSTANDARD LVCMOS33 } [get_ports { sw[0] }]; #IO_L7N_T1_AD2N_35 Sch=sw[0]
#set_property -dict { PACKAGE_PIN M19   IOSTANDARD LVCMOS33 } [get_ports { sw[1] }]; #IO_L7P_T1_AD2P_35 Sch=sw[1]

##RGB LEDs

#set_property -dict { PACKAGE_PIN L15   IOSTANDARD LVCMOS33 } [get_ports { led4_b }]; #IO_L22N_T3_AD7N_35 Sch=led4_b
#set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { led4_g }]; #IO_L16P_T2_35 Sch=led4_g
#set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports { led4_r }]; #IO_L21P_T3_DQS_AD14P_35 Sch=led4_r
#set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { led5_b }]; #IO_0_35 Sch=led5_b
#set_property -dict { PACKAGE_PIN L14   IOSTANDARD LVCMOS33 } [get_ports { led5_g }]; #IO_L22P_T3_AD7P_35 Sch=led5_g
#set_property -dict { PACKAGE_PIN M15   IOSTANDARD LVCMOS33 } [get_ports { led5_r }]; #IO_L23N_T3_35 Sch=led5_r

##LEDs

#set_property -dict { PACKAGE_PIN R14   IOSTANDARD LVCMOS33 } [get_ports { led[0] }]; #IO_L6N_T0_VREF_34 Sch=led[0]
#set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { led[1] }]; #IO_L6P_T0_34 Sch=led[1]
#set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports { led[2] }]; #IO_L21N_T3_DQS_AD14N_35 Sch=led[2]
#set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { led[3] }]; #IO_L23P_T3_35 Sch=led[3]

##Buttons

#set_property -dict { PACKAGE_PIN D19   IOSTANDARD LVCMOS33 } [get_ports { btn[0] }]; #IO_L4P_T0_35 Sch=btn[0]
#set_property -dict { PACKAGE_PIN D20   IOSTANDARD LVCMOS33 } [get_ports { btn[1] }]; #IO_L4N_T0_35 Sch=btn[1]
#set_property -dict { PACKAGE_PIN L20   IOSTANDARD LVCMOS33 } [get_ports { btn[2] }]; #IO_L9N_T1_DQS_AD3N_35 Sch=btn[2]
#set_property -dict { PACKAGE_PIN L19   IOSTANDARD LVCMOS33 } [get_ports { btn[3] }]; #IO_L9P_T1_DQS_AD3P_35 Sch=btn[3]

##Pmod Header JA

#set_property -dict { PACKAGE_PIN Y18   IOSTANDARD LVCMOS33 } [get_ports { ja[0] }]; #IO_L17P_T2_34 Sch=ja_p[1]
#set_property -dict { PACKAGE_PIN Y19   IOSTANDARD LVCMOS33 } [get_ports { ja[1] }]; #IO_L17N_T2_34 Sch=ja_n[1]
#set_property -dict { PACKAGE_PIN Y16   IOSTANDARD LVCMOS33 } [get_ports { ja[2] }]; #IO_L7P_T1_34 Sch=ja_p[2]
#set_property -dict { PACKAGE_PIN Y17   IOSTANDARD LVCMOS33 } [get_ports { ja[3] }]; #IO_L7N_T1_34 Sch=ja_n[2]
#set_property -dict { PACKAGE_PIN U18   IOSTANDARD LVCMOS33 } [get_ports { ja[4] }]; #IO_L12P_T1_MRCC_34 Sch=ja_p[3]
#set_property -dict { PACKAGE_PIN U19   IOSTANDARD LVCMOS33 } [get_ports { ja[5] }]; #IO_L12N_T1_MRCC_34 Sch=ja_n[3]
#set_property -dict { PACKAGE_PIN W18   IOSTANDARD LVCMOS33 } [get_ports { ja[6] }]; #IO_L22P_T3_34 Sch=ja_p[4]
#set_property -dict { PACKAGE_PIN W19   IOSTANDARD LVCMOS33 } [get_ports { ja[7] }]; #IO_L22N_T3_34 Sch=ja_n[4]

##Pmod Header JB

#set_property -dict { PACKAGE_PIN W14   IOSTANDARD LVCMOS33 } [get_ports { jb[0] }]; #IO_L8P_T1_34 Sch=jb_p[1]
#set_property -dict { PACKAGE_PIN Y14   IOSTANDARD LVCMOS33 } [get_ports { jb[1] }]; #IO_L8N_T1_34 Sch=jb_n[1]
#set_property -dict { PACKAGE_PIN T11   IOSTANDARD LVCMOS33 } [get_ports { jb[2] }]; #IO_L1P_T0_34 Sch=jb_p[2]
#set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports { jb[3] }]; #IO_L1N_T0_34 Sch=jb_n[2]
#set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports { jb[4] }]; #IO_L18P_T2_34 Sch=jb_p[3]
#set_property -dict { PACKAGE_PIN W16   IOSTANDARD LVCMOS33 } [get_ports { jb[5] }]; #IO_L18N_T2_34 Sch=jb_n[3]
#set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 } [get_ports { jb[6] }]; #IO_L4P_T0_34 Sch=jb_p[4]
#set_property -dict { PACKAGE_PIN W13   IOSTANDARD LVCMOS33 } [get_ports { jb[7] }]; #IO_L4N_T0_34 Sch=jb_n[4]

##Audio Out

#set_property -dict { PACKAGE_PIN R18   IOSTANDARD LVCMOS33 } [get_ports { aud_pwm }]; #IO_L20N_T3_34 Sch=aud_pwm
#set_property -dict { PACKAGE_PIN T17   IOSTANDARD LVCMOS33 } [get_ports { aud_sd }]; #IO_L20P_T3_34 Sch=aud_sd

##Mic input

#set_property -dict { PACKAGE_PIN F17   IOSTANDARD LVCMOS33 } [get_ports { m_clk }]; #IO_L6N_T0_VREF_35 Sch=m_clk
#set_property -dict { PACKAGE_PIN G18   IOSTANDARD LVCMOS33 } [get_ports { m_data }]; #IO_L16N_T2_35 Sch=m_data

##ChipKit Single Ended Analog Inputs
##NOTE: The ck_an_p pins can be used as single ended analog inputs with voltages from 0-3.3V (Chipkit Analog pins A0-A5).
##      These signals should only be connected to the XADC core. When using these pins as digital I/O, use pins ck_io[14-19].

#set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[0] }]; #IO_L3N_T0_DQS_AD1N_35 Sch=ck_an_n[0]
#set_property -dict { PACKAGE_PIN E17   IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[0] }]; #IO_L3P_T0_DQS_AD1P_35 Sch=ck_an_p[0]
#set_property -dict { PACKAGE_PIN E19   IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[1] }]; #IO_L5N_T0_AD9N_35 Sch=ck_an_n[1]
#set_property -dict { PACKAGE_PIN E18   IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[1] }]; #IO_L5P_T0_AD9P_35 Sch=ck_an_p[1]
#set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[2] }]; #IO_L20N_T3_AD6N_35 Sch=ck_an_n[2]
#set_property -dict { PACKAGE_PIN K14   IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[2] }]; #IO_L20P_T3_AD6P_35 Sch=ck_an_p[2]
#set_property -dict { PACKAGE_PIN J16   IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[3] }]; #IO_L24N_T3_AD15N_35 Sch=ck_an_n[3]
#set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[3] }]; #IO_L24P_T3_AD15P_35 Sch=ck_an_p[3]
#set_property -dict { PACKAGE_PIN H20   IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[4] }]; #IO_L17N_T2_AD5N_35 Sch=ck_an_n[4]
#set_property -dict { PACKAGE_PIN J20   IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[4] }]; #IO_L17P_T2_AD5P_35 Sch=ck_an_p[4]
#set_property -dict { PACKAGE_PIN G20   IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[5] }]; #IO_L18N_T2_AD13N_35 Sch=ck_an_n[5]
#set_property -dict { PACKAGE_PIN G19   IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[5] }]; #IO_L18P_T2_AD13P_35 Sch=ck_an_p[5]

##ChipKit Digital I/O Low

#set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS33 } [get_ports { ck_io[0] }]; #IO_L5P_T0_34 Sch=ck_io[0]
#set_property -dict { PACKAGE_PIN U12   IOSTANDARD LVCMOS33 } [get_ports { ck_io[1] }]; #IO_L2N_T0_34 Sch=ck_io[1]
#set_property -dict { PACKAGE_PIN U13   IOSTANDARD LVCMOS33 } [get_ports { ck_io[2] }]; #IO_L3P_T0_DQS_PUDC_B_34 Sch=ck_io[2]
#set_property -dict { PACKAGE_PIN V13   IOSTANDARD LVCMOS33 } [get_ports { ck_io[3] }]; #IO_L3N_T0_DQS_34 Sch=ck_io[3]
#set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports { ck_io[4] }]; #IO_L10P_T1_34 Sch=ck_io[4]
#set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS33 } [get_ports { ck_io[5] }]; #IO_L5N_T0_34 Sch=ck_io[5]
#set_property -dict { PACKAGE_PIN R16   IOSTANDARD LVCMOS33 } [get_ports { ck_io[6] }]; #IO_L19P_T3_34 Sch=ck_io[6]
#set_property -dict { PACKAGE_PIN U17   IOSTANDARD LVCMOS33 } [get_ports { ck_io[7] }]; #IO_L9N_T1_DQS_34 Sch=ck_io[7]
#set_property -dict { PACKAGE_PIN V17   IOSTANDARD LVCMOS33 } [get_ports { ck_io[8] }]; #IO_L21P_T3_DQS_34 Sch=ck_io[8]
#set_property -dict { PACKAGE_PIN V18   IOSTANDARD LVCMOS33 } [get_ports { ck_io[9] }]; #IO_L21N_T3_DQS_34 Sch=ck_io[9]
#set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports { ck_io[10] }]; #IO_L9P_T1_DQS_34 Sch=ck_io[10]
#set_property -dict { PACKAGE_PIN R17   IOSTANDARD LVCMOS33 } [get_ports { ck_io[11] }]; #IO_L19N_T3_VREF_34 Sch=ck_io[11]
#set_property -dict { PACKAGE_PIN P18   IOSTANDARD LVCMOS33 } [get_ports { ck_io[12] }]; #IO_L23N_T3_34 Sch=ck_io[12]
#set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { ck_io[13] }]; #IO_L23P_T3_34 Sch=ck_io[13]

##ChipKit Digital I/O On Outer Analog Header
##NOTE: These pins should be used when using the analog header signals A0-A5 as digital I/O (Chipkit digital pins 14-19)

#set_property -dict { PACKAGE_PIN Y11   IOSTANDARD LVCMOS33 } [get_ports { ck_io[14] }]; #IO_L18N_T2_13 Sch=ck_a[0]
#set_property -dict { PACKAGE_PIN Y12   IOSTANDARD LVCMOS33 } [get_ports { ck_io[15] }]; #IO_L20P_T3_13 Sch=ck_a[1]
#set_property -dict { PACKAGE_PIN W11   IOSTANDARD LVCMOS33 } [get_ports { ck_io[16] }]; #IO_L18P_T2_13 Sch=ck_a[2]
#set_property -dict { PACKAGE_PIN V11   IOSTANDARD LVCMOS33 } [get_ports { ck_io[17] }]; #IO_L21P_T3_DQS_13 Sch=ck_a[3]
#set_property -dict { PACKAGE_PIN T5    IOSTANDARD LVCMOS33 } [get_ports { ck_io[18] }]; #IO_L19P_T3_13 Sch=ck_a[4]
#set_property -dict { PACKAGE_PIN U10   IOSTANDARD LVCMOS33 } [get_ports { ck_io[19] }]; #IO_L12N_T1_MRCC_13 Sch=ck_a[5]

##ChipKit Digital I/O On Inner Analog Header
##NOTE: These pins will need to be connected to the XADC core when used as differential analog inputs (Chipkit analog pins A6-A11)

#set_property -dict { PACKAGE_PIN B20   IOSTANDARD LVCMOS33 } [get_ports { ck_io[20] }]; #IO_L1N_T0_AD0N_35 Sch=ad_n[0]
#set_property -dict { PACKAGE_PIN C20   IOSTANDARD LVCMOS33 } [get_ports { ck_io[21] }]; #IO_L1P_T0_AD0P_35 Sch=ad_p[0]
#set_property -dict { PACKAGE_PIN F20   IOSTANDARD LVCMOS33 } [get_ports { ck_io[22] }]; #IO_L15N_T2_DQS_AD12N_35 Sch=ad_n[12]
#set_property -dict { PACKAGE_PIN F19   IOSTANDARD LVCMOS33 } [get_ports { ck_io[23] }]; #IO_L15P_T2_DQS_AD12P_35 Sch=ad_p[12]
#set_property -dict { PACKAGE_PIN A20   IOSTANDARD LVCMOS33 } [get_ports { ck_io[24] }]; #IO_L2N_T0_AD8N_35 Sch=ad_n[8]
#set_property -dict { PACKAGE_PIN B19   IOSTANDARD LVCMOS33 } [get_ports { ck_io[25] }]; #IO_L2P_T0_AD8P_35 Sch=ad_p[8]

##ChipKit Digital I/O High

#set_property -dict { PACKAGE_PIN U5    IOSTANDARD LVCMOS33 } [get_ports { ck_io[26] }]; #IO_L19N_T3_VREF_13 Sch=ck_io[26]
#set_property -dict { PACKAGE_PIN V5    IOSTANDARD LVCMOS33 } [get_ports { ck_io[27] }]; #IO_L6N_T0_VREF_13 Sch=ck_io[27]
#set_property -dict { PACKAGE_PIN V6    IOSTANDARD LVCMOS33 } [get_ports { ck_io[28] }]; #IO_L22P_T3_13 Sch=ck_io[28]
#set_property -dict { PACKAGE_PIN U7    IOSTANDARD LVCMOS33 } [get_ports { ck_io[29] }]; #IO_L11P_T1_SRCC_13 Sch=ck_io[29]
#set_property -dict { PACKAGE_PIN V7    IOSTANDARD LVCMOS33 } [get_ports { ck_io[30] }]; #IO_L11N_T1_SRCC_13 Sch=ck_io[30]
#set_property -dict { PACKAGE_PIN U8    IOSTANDARD LVCMOS33 } [get_ports { ck_io[31] }]; #IO_L17N_T2_13 Sch=ck_io[31]
#set_property -dict { PACKAGE_PIN V8    IOSTANDARD LVCMOS33 } [get_ports { ck_io[32] }]; #IO_L15P_T2_DQS_13 Sch=ck_io[32]
#set_property -dict { PACKAGE_PIN V10   IOSTANDARD LVCMOS33 } [get_ports { ck_io[33] }]; #IO_L21N_T3_DQS_13 Sch=ck_io[33]
#set_property -dict { PACKAGE_PIN W10   IOSTANDARD LVCMOS33 } [get_ports { ck_io[34] }]; #IO_L16P_T2_13 Sch=ck_io[34]
#set_property -dict { PACKAGE_PIN W6    IOSTANDARD LVCMOS33 } [get_ports { ck_io[35] }]; #IO_L22N_T3_13 Sch=ck_io[35]
#set_property -dict { PACKAGE_PIN Y6    IOSTANDARD LVCMOS33 } [get_ports { ck_io[36] }]; #IO_L13N_T2_MRCC_13 Sch=ck_io[36]
#set_property -dict { PACKAGE_PIN Y7    IOSTANDARD LVCMOS33 } [get_ports { ck_io[37] }]; #IO_L13P_T2_MRCC_13 Sch=ck_io[37]
#set_property -dict { PACKAGE_PIN W8    IOSTANDARD LVCMOS33 } [get_ports { ck_io[38] }]; #IO_L15N_T2_DQS_13 Sch=ck_io[38]
#set_property -dict { PACKAGE_PIN Y8    IOSTANDARD LVCMOS33 } [get_ports { ck_io[39] }]; #IO_L14N_T2_SRCC_13 Sch=ck_io[39]
#set_property -dict { PACKAGE_PIN W9    IOSTANDARD LVCMOS33 } [get_ports { ck_io[40] }]; #IO_L16N_T2_13 Sch=ck_io[40]
#set_property -dict { PACKAGE_PIN Y9    IOSTANDARD LVCMOS33 } [get_ports { ck_io[41] }]; #IO_L14P_T2_SRCC_13 Sch=ck_io[41]
#set_property -dict { PACKAGE_PIN Y13   IOSTANDARD LVCMOS33 } [get_ports { ck_io[42] }]; #IO_L20N_T3_13 Sch=ck_ioa

## ChipKit SPI

#set_property -dict { PACKAGE_PIN W15   IOSTANDARD LVCMOS33 } [get_ports { ck_miso }]; #IO_L10N_T1_34 Sch=ck_miso
#set_property -dict { PACKAGE_PIN T12   IOSTANDARD LVCMOS33 } [get_ports { ck_mosi }]; #IO_L2P_T0_34 Sch=ck_mosi
#set_property -dict { PACKAGE_PIN H15   IOSTANDARD LVCMOS33 } [get_ports { ck_sck }]; #IO_L19P_T3_35 Sch=ck_sck
#set_property -dict { PACKAGE_PIN F16   IOSTANDARD LVCMOS33 } [get_ports { ck_ss }]; #IO_L6P_T0_35 Sch=ck_ss

## ChipKit I2C

#set_property -dict { PACKAGE_PIN P16   IOSTANDARD LVCMOS33 } [get_ports { ck_scl }]; #IO_L24N_T3_34 Sch=ck_scl
#set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { ck_sda }]; #IO_L24P_T3_34 Sch=ck_sda

##HDMI Rx

#set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { hdmi_rx_cec }]; #IO_L13N_T2_MRCC_35 Sch=hdmi_rx_cec
#set_property -dict { PACKAGE_PIN P19   IOSTANDARD TMDS_33  } [get_ports { hdmi_rx_clk_n }]; #IO_L13N_T2_MRCC_34 Sch=hdmi_rx_clk_n
#set_property -dict { PACKAGE_PIN N18   IOSTANDARD TMDS_33  } [get_ports { hdmi_rx_clk_p }]; #IO_L13P_T2_MRCC_34 Sch=hdmi_rx_clk_p
#set_property -dict { PACKAGE_PIN W20   IOSTANDARD TMDS_33  } [get_ports { hdmi_rx_d_n[0] }]; #IO_L16N_T2_34 Sch=hdmi_rx_d_n[0]
#set_property -dict { PACKAGE_PIN V20   IOSTANDARD TMDS_33  } [get_ports { hdmi_rx_d_p[0] }]; #IO_L16P_T2_34 Sch=hdmi_rx_d_p[0]
#set_property -dict { PACKAGE_PIN U20   IOSTANDARD TMDS_33  } [get_ports { hdmi_rx_d_n[1] }]; #IO_L15N_T2_DQS_34 Sch=hdmi_rx_d_n[1]
#set_property -dict { PACKAGE_PIN T20   IOSTANDARD TMDS_33  } [get_ports { hdmi_rx_d_p[1] }]; #IO_L15P_T2_DQS_34 Sch=hdmi_rx_d_p[1]
#set_property -dict { PACKAGE_PIN P20   IOSTANDARD TMDS_33  } [get_ports { hdmi_rx_d_n[2] }]; #IO_L14N_T2_SRCC_34 Sch=hdmi_rx_d_n[2]
#set_property -dict { PACKAGE_PIN N20   IOSTANDARD TMDS_33  } [get_ports { hdmi_rx_d_p[2] }]; #IO_L14P_T2_SRCC_34 Sch=hdmi_rx_d_p[2]
#set_property -dict { PACKAGE_PIN T19   IOSTANDARD LVCMOS33 } [get_ports { hdmi_rx_hpd }]; #IO_25_34 Sch=hdmi_rx_hpd
#set_property -dict { PACKAGE_PIN U14   IOSTANDARD LVCMOS33 } [get_ports { hdmi_rx_scl }]; #IO_L11P_T1_SRCC_34 Sch=hdmi_rx_scl
#set_property -dict { PACKAGE_PIN U15   IOSTANDARD LVCMOS33 } [get_ports { hdmi_rx_sda }]; #IO_L11N_T1_SRCC_34 Sch=hdmi_rx_sda

##HDMI Tx

#set_property -dict { PACKAGE_PIN G15   IOSTANDARD LVCMOS33 } [get_ports { hdmi_tx_cec }]; #IO_L19N_T3_VREF_35 Sch=hdmi_tx_cec
#set_property -dict { PACKAGE_PIN L17   IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_clk_n }]; #IO_L11N_T1_SRCC_35 Sch=hdmi_tx_clk_n
#set_property -dict { PACKAGE_PIN L16   IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_clk_p }]; #IO_L11P_T1_SRCC_35 Sch=hdmi_tx_clk_p
#set_property -dict { PACKAGE_PIN K18   IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_d_n[0] }]; #IO_L12N_T1_MRCC_35 Sch=hdmi_tx_d_n[0]
#set_property -dict { PACKAGE_PIN K17   IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_d_p[0] }]; #IO_L12P_T1_MRCC_35 Sch=hdmi_tx_d_p[0]
#set_property -dict { PACKAGE_PIN J19   IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_d_n[1] }]; #IO_L10N_T1_AD11N_35 Sch=hdmi_tx_d_n[1]
#set_property -dict { PACKAGE_PIN K19   IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_d_p[1] }]; #IO_L10P_T1_AD11P_35 Sch=hdmi_tx_d_p[1]
#set_property -dict { PACKAGE_PIN H18   IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_d_n[2] }]; #IO_L14N_T2_AD4N_SRCC_35 Sch=hdmi_tx_d_n[2]
#set_property -dict { PACKAGE_PIN J18   IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_d_p[2] }]; #IO_L14P_T2_AD4P_SRCC_35 Sch=hdmi_tx_d_p[2]
#set_property -dict { PACKAGE_PIN R19   IOSTANDARD LVCMOS33 } [get_ports { hdmi_tx_hpdn }]; #IO_0_34 Sch=hdmi_tx_hpdn
#set_property -dict { PACKAGE_PIN M17   IOSTANDARD LVCMOS33 } [get_ports { hdmi_tx_scl }]; #IO_L8P_T1_AD10P_35 Sch=hdmi_tx_scl
#set_property -dict { PACKAGE_PIN M18   IOSTANDARD LVCMOS33 } [get_ports { hdmi_tx_sda }]; #IO_L8N_T1_AD10N_35 Sch=hdmi_tx_sda

##Crypto SDA

#set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { crypto_sda }]; #IO_25_35 Sch=crypto_sda
EOF

cat >> pynq_c_ps.tcl << EOF
proc getPresetInfo {} {
  return [dict create name {PYNQ} description {PYNQ}  vlnv xilinx.com:ip:processing_system7:5.5 display_name {PYNQ} ]
}

proc validate_preset {IPINST} { return true }


proc apply_preset {IPINST} {
return [dict create \
    CONFIG.PCW_DDR_RAM_BASEADDR {0x00100000}  \
    CONFIG.PCW_DDR_RAM_HIGHADDR {0x1FFFFFFF}  \
    CONFIG.PCW_UART0_BASEADDR {0xE0000000}  \
    CONFIG.PCW_UART0_HIGHADDR {0xE0000FFF}  \
    CONFIG.PCW_UART1_BASEADDR {0xE0001000}  \
    CONFIG.PCW_UART1_HIGHADDR {0xE0001FFF}  \
    CONFIG.PCW_I2C0_BASEADDR {0xE0004000}  \
    CONFIG.PCW_I2C0_HIGHADDR {0xE0004FFF}  \
    CONFIG.PCW_I2C1_BASEADDR {0xE0005000}  \
    CONFIG.PCW_I2C1_HIGHADDR {0xE0005FFF}  \
    CONFIG.PCW_SPI0_BASEADDR {0xE0006000}  \
    CONFIG.PCW_SPI0_HIGHADDR {0xE0006FFF}  \
    CONFIG.PCW_SPI1_BASEADDR {0xE0007000}  \
    CONFIG.PCW_SPI1_HIGHADDR {0xE0007FFF}  \
    CONFIG.PCW_CAN0_BASEADDR {0xE0008000}  \
    CONFIG.PCW_CAN0_HIGHADDR {0xE0008FFF}  \
    CONFIG.PCW_CAN1_BASEADDR {0xE0009000}  \
    CONFIG.PCW_CAN1_HIGHADDR {0xE0009FFF}  \
    CONFIG.PCW_GPIO_BASEADDR {0xE000A000}  \
    CONFIG.PCW_GPIO_HIGHADDR {0xE000AFFF}  \
    CONFIG.PCW_ENET0_BASEADDR {0xE000B000}  \
    CONFIG.PCW_ENET0_HIGHADDR {0xE000BFFF}  \
    CONFIG.PCW_ENET1_BASEADDR {0xE000C000}  \
    CONFIG.PCW_ENET1_HIGHADDR {0xE000CFFF}  \
    CONFIG.PCW_SDIO0_BASEADDR {0xE0100000}  \
    CONFIG.PCW_SDIO0_HIGHADDR {0xE0100FFF}  \
    CONFIG.PCW_SDIO1_BASEADDR {0xE0101000}  \
    CONFIG.PCW_SDIO1_HIGHADDR {0xE0101FFF}  \
    CONFIG.PCW_USB0_BASEADDR {0xE0102000}  \
    CONFIG.PCW_USB0_HIGHADDR {0xE0102fff}  \
    CONFIG.PCW_USB1_BASEADDR {0xE0103000}  \
    CONFIG.PCW_USB1_HIGHADDR {0xE0103fff}  \
    CONFIG.PCW_TTC0_BASEADDR {0xE0104000}  \
    CONFIG.PCW_TTC0_HIGHADDR {0xE0104fff}  \
    CONFIG.PCW_TTC1_BASEADDR {0xE0105000}  \
    CONFIG.PCW_TTC1_HIGHADDR {0xE0105fff}  \
    CONFIG.PCW_FCLK_CLK0_BUF {true}  \
    CONFIG.PCW_FCLK_CLK1_BUF {false}  \
    CONFIG.PCW_FCLK_CLK2_BUF {false}  \
    CONFIG.PCW_FCLK_CLK3_BUF {false}  \
    CONFIG.PCW_UIPARAM_DDR_FREQ_MHZ {525}  \
    CONFIG.PCW_UIPARAM_DDR_BANK_ADDR_COUNT {3}  \
    CONFIG.PCW_UIPARAM_DDR_ROW_ADDR_COUNT {15}  \
    CONFIG.PCW_UIPARAM_DDR_COL_ADDR_COUNT {10}  \
    CONFIG.PCW_UIPARAM_DDR_CL {7}  \
    CONFIG.PCW_UIPARAM_DDR_CWL {6}  \
    CONFIG.PCW_UIPARAM_DDR_T_RCD {7}  \
    CONFIG.PCW_UIPARAM_DDR_T_RP {7}  \
    CONFIG.PCW_UIPARAM_DDR_T_RC {48.91}  \
    CONFIG.PCW_UIPARAM_DDR_T_RAS_MIN {35.0}  \
    CONFIG.PCW_UIPARAM_DDR_T_FAW {40.0}  \
    CONFIG.PCW_UIPARAM_DDR_AL {0}  \
    CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_0 {0.040}  \
    CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_1 {0.058}  \
    CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_2 {-0.009}  \
    CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_3 {-0.033}  \
    CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY0 {0.223}  \
    CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY1 {0.212}  \
    CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY2 {0.085}  \
    CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY3 {0.092}  \
    CONFIG.PCW_UIPARAM_DDR_DQS_0_LENGTH_MM {15.6}  \
    CONFIG.PCW_UIPARAM_DDR_DQS_1_LENGTH_MM {18.8}  \
    CONFIG.PCW_UIPARAM_DDR_DQS_2_LENGTH_MM {0}  \
    CONFIG.PCW_UIPARAM_DDR_DQS_3_LENGTH_MM {0}  \
    CONFIG.PCW_UIPARAM_DDR_DQ_0_LENGTH_MM {16.5}  \
    CONFIG.PCW_UIPARAM_DDR_DQ_1_LENGTH_MM {18}  \
    CONFIG.PCW_UIPARAM_DDR_DQ_2_LENGTH_MM {0}  \
    CONFIG.PCW_UIPARAM_DDR_DQ_3_LENGTH_MM {0}  \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_0_LENGTH_MM {25.8}  \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_1_LENGTH_MM {25.8}  \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_2_LENGTH_MM {0}  \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_3_LENGTH_MM {0}  \
    CONFIG.PCW_UIPARAM_DDR_DQS_0_PACKAGE_LENGTH {105.056}  \
    CONFIG.PCW_UIPARAM_DDR_DQS_1_PACKAGE_LENGTH {66.904}  \
    CONFIG.PCW_UIPARAM_DDR_DQS_2_PACKAGE_LENGTH {89.1715}  \
    CONFIG.PCW_UIPARAM_DDR_DQS_3_PACKAGE_LENGTH {113.63}  \
    CONFIG.PCW_UIPARAM_DDR_DQ_0_PACKAGE_LENGTH {98.503}  \
    CONFIG.PCW_UIPARAM_DDR_DQ_1_PACKAGE_LENGTH {68.5855}  \
    CONFIG.PCW_UIPARAM_DDR_DQ_2_PACKAGE_LENGTH {90.295}  \
    CONFIG.PCW_UIPARAM_DDR_DQ_3_PACKAGE_LENGTH {103.977}  \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_0_PACKAGE_LENGTH {80.4535}  \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_1_PACKAGE_LENGTH {80.4535}  \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_2_PACKAGE_LENGTH {80.4535}  \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_3_PACKAGE_LENGTH {80.4535}  \
    CONFIG.PCW_UIPARAM_DDR_DQS_0_PROPOGATION_DELAY {160}  \
    CONFIG.PCW_UIPARAM_DDR_DQS_1_PROPOGATION_DELAY {160}  \
    CONFIG.PCW_UIPARAM_DDR_DQS_2_PROPOGATION_DELAY {160}  \
    CONFIG.PCW_UIPARAM_DDR_DQS_3_PROPOGATION_DELAY {160}  \
    CONFIG.PCW_UIPARAM_DDR_DQ_0_PROPOGATION_DELAY {160}  \
    CONFIG.PCW_UIPARAM_DDR_DQ_1_PROPOGATION_DELAY {160}  \
    CONFIG.PCW_UIPARAM_DDR_DQ_2_PROPOGATION_DELAY {160}  \
    CONFIG.PCW_UIPARAM_DDR_DQ_3_PROPOGATION_DELAY {160}  \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_0_PROPOGATION_DELAY {160}  \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_1_PROPOGATION_DELAY {160}  \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_2_PROPOGATION_DELAY {160}  \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_3_PROPOGATION_DELAY {160}  \
    CONFIG.PCW_PACKAGE_DDR_DQS_TO_CLK_DELAY_0 {0.040}  \
    CONFIG.PCW_PACKAGE_DDR_DQS_TO_CLK_DELAY_1 {0.058}  \
    CONFIG.PCW_PACKAGE_DDR_DQS_TO_CLK_DELAY_2 {-0.009}  \
    CONFIG.PCW_PACKAGE_DDR_DQS_TO_CLK_DELAY_3 {-0.033}  \
    CONFIG.PCW_PACKAGE_DDR_BOARD_DELAY0 {0.223}  \
    CONFIG.PCW_PACKAGE_DDR_BOARD_DELAY1 {0.212}  \
    CONFIG.PCW_PACKAGE_DDR_BOARD_DELAY2 {0.085}  \
    CONFIG.PCW_PACKAGE_DDR_BOARD_DELAY3 {0.092}  \
    CONFIG.PCW_CPU_CPU_6X4X_MAX_RANGE {667}  \
    CONFIG.PCW_CRYSTAL_PERIPHERAL_FREQMHZ {50}  \
    CONFIG.PCW_APU_PERIPHERAL_FREQMHZ {650}  \
    CONFIG.PCW_DCI_PERIPHERAL_FREQMHZ {10.159}  \
    CONFIG.PCW_QSPI_PERIPHERAL_FREQMHZ {200}  \
    CONFIG.PCW_SMC_PERIPHERAL_FREQMHZ {100}  \
    CONFIG.PCW_USB0_PERIPHERAL_FREQMHZ {60}  \
    CONFIG.PCW_USB1_PERIPHERAL_FREQMHZ {60}  \
    CONFIG.PCW_SDIO_PERIPHERAL_FREQMHZ {50}  \
    CONFIG.PCW_UART_PERIPHERAL_FREQMHZ {100}  \
    CONFIG.PCW_SPI_PERIPHERAL_FREQMHZ {166.666666}  \
    CONFIG.PCW_CAN_PERIPHERAL_FREQMHZ {100}  \
    CONFIG.PCW_CAN0_PERIPHERAL_FREQMHZ {-1}  \
    CONFIG.PCW_CAN1_PERIPHERAL_FREQMHZ {-1}  \
    CONFIG.PCW_I2C_PERIPHERAL_FREQMHZ {25}  \
    CONFIG.PCW_WDT_PERIPHERAL_FREQMHZ {133.333333}  \
    CONFIG.PCW_TTC_PERIPHERAL_FREQMHZ {50}  \
    CONFIG.PCW_TTC0_CLK0_PERIPHERAL_FREQMHZ {133.333333}  \
    CONFIG.PCW_TTC0_CLK1_PERIPHERAL_FREQMHZ {133.333333}  \
    CONFIG.PCW_TTC0_CLK2_PERIPHERAL_FREQMHZ {133.333333}  \
    CONFIG.PCW_TTC1_CLK0_PERIPHERAL_FREQMHZ {133.333333}  \
    CONFIG.PCW_TTC1_CLK1_PERIPHERAL_FREQMHZ {133.333333}  \
    CONFIG.PCW_TTC1_CLK2_PERIPHERAL_FREQMHZ {133.333333}  \
    CONFIG.PCW_PCAP_PERIPHERAL_FREQMHZ {200}  \
    CONFIG.PCW_TPIU_PERIPHERAL_FREQMHZ {200}  \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100}  \
    CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ {50}  \
    CONFIG.PCW_FPGA2_PERIPHERAL_FREQMHZ {50}  \
    CONFIG.PCW_FPGA3_PERIPHERAL_FREQMHZ {50}  \
    CONFIG.PCW_ACT_APU_PERIPHERAL_FREQMHZ {650.000000}  \
    CONFIG.PCW_UIPARAM_ACT_DDR_FREQ_MHZ {525.000000}  \
    CONFIG.PCW_ACT_DCI_PERIPHERAL_FREQMHZ {10.096154}  \
    CONFIG.PCW_ACT_QSPI_PERIPHERAL_FREQMHZ {200.000000}  \
    CONFIG.PCW_ACT_SMC_PERIPHERAL_FREQMHZ {10.000000}  \
    CONFIG.PCW_ACT_ENET0_PERIPHERAL_FREQMHZ {125.000000}  \
    CONFIG.PCW_ACT_ENET1_PERIPHERAL_FREQMHZ {10.000000}  \
    CONFIG.PCW_ACT_USB0_PERIPHERAL_FREQMHZ {60}  \
    CONFIG.PCW_ACT_USB1_PERIPHERAL_FREQMHZ {60}  \
    CONFIG.PCW_ACT_SDIO_PERIPHERAL_FREQMHZ {50.000000}  \
    CONFIG.PCW_ACT_UART_PERIPHERAL_FREQMHZ {100.000000}  \
    CONFIG.PCW_ACT_SPI_PERIPHERAL_FREQMHZ {10.000000}  \
    CONFIG.PCW_ACT_CAN_PERIPHERAL_FREQMHZ {10.000000}  \
    CONFIG.PCW_ACT_CAN0_PERIPHERAL_FREQMHZ {23.8095}  \
    CONFIG.PCW_ACT_CAN1_PERIPHERAL_FREQMHZ {23.8095}  \
    CONFIG.PCW_ACT_I2C_PERIPHERAL_FREQMHZ {50}  \
    CONFIG.PCW_ACT_WDT_PERIPHERAL_FREQMHZ {108.333336}  \
    CONFIG.PCW_ACT_TTC_PERIPHERAL_FREQMHZ {50}  \
    CONFIG.PCW_ACT_PCAP_PERIPHERAL_FREQMHZ {200.000000}  \
    CONFIG.PCW_ACT_TPIU_PERIPHERAL_FREQMHZ {200.000000}  \
    CONFIG.PCW_ACT_FPGA0_PERIPHERAL_FREQMHZ {100.000000}  \
    CONFIG.PCW_ACT_FPGA1_PERIPHERAL_FREQMHZ {50.000000}  \
    CONFIG.PCW_ACT_FPGA2_PERIPHERAL_FREQMHZ {50.000000}  \
    CONFIG.PCW_ACT_FPGA3_PERIPHERAL_FREQMHZ {50.000000}  \
    CONFIG.PCW_ACT_TTC0_CLK0_PERIPHERAL_FREQMHZ {108.333336}  \
    CONFIG.PCW_ACT_TTC0_CLK1_PERIPHERAL_FREQMHZ {108.333336}  \
    CONFIG.PCW_ACT_TTC0_CLK2_PERIPHERAL_FREQMHZ {108.333336}  \
    CONFIG.PCW_ACT_TTC1_CLK0_PERIPHERAL_FREQMHZ {108.333336}  \
    CONFIG.PCW_ACT_TTC1_CLK1_PERIPHERAL_FREQMHZ {108.333336}  \
    CONFIG.PCW_ACT_TTC1_CLK2_PERIPHERAL_FREQMHZ {108.333336}  \
    CONFIG.PCW_CLK0_FREQ {100000000}  \
    CONFIG.PCW_CLK1_FREQ {50000000}  \
    CONFIG.PCW_CLK2_FREQ {50000000}  \
    CONFIG.PCW_CLK3_FREQ {50000000}  \
    CONFIG.PCW_OVERRIDE_BASIC_CLOCK {0}  \
    CONFIG.PCW_CPU_PERIPHERAL_DIVISOR0 {2}  \
    CONFIG.PCW_DDR_PERIPHERAL_DIVISOR0 {2}  \
    CONFIG.PCW_SMC_PERIPHERAL_DIVISOR0 {1}  \
    CONFIG.PCW_QSPI_PERIPHERAL_DIVISOR0 {5}  \
    CONFIG.PCW_SDIO_PERIPHERAL_DIVISOR0 {20}  \
    CONFIG.PCW_UART_PERIPHERAL_DIVISOR0 {10}  \
    CONFIG.PCW_SPI_PERIPHERAL_DIVISOR0 {1}  \
    CONFIG.PCW_CAN_PERIPHERAL_DIVISOR0 {1}  \
    CONFIG.PCW_CAN_PERIPHERAL_DIVISOR1 {1}  \
    CONFIG.PCW_FCLK0_PERIPHERAL_DIVISOR0 {10}  \
    CONFIG.PCW_FCLK1_PERIPHERAL_DIVISOR0 {20}  \
    CONFIG.PCW_FCLK2_PERIPHERAL_DIVISOR0 {20}  \
    CONFIG.PCW_FCLK3_PERIPHERAL_DIVISOR0 {20}  \
    CONFIG.PCW_FCLK0_PERIPHERAL_DIVISOR1 {1}  \
    CONFIG.PCW_FCLK1_PERIPHERAL_DIVISOR1 {1}  \
    CONFIG.PCW_FCLK2_PERIPHERAL_DIVISOR1 {1}  \
    CONFIG.PCW_FCLK3_PERIPHERAL_DIVISOR1 {1}  \
    CONFIG.PCW_ENET0_PERIPHERAL_DIVISOR0 {8}  \
    CONFIG.PCW_ENET1_PERIPHERAL_DIVISOR0 {1}  \
    CONFIG.PCW_ENET0_PERIPHERAL_DIVISOR1 {1}  \
    CONFIG.PCW_ENET1_PERIPHERAL_DIVISOR1 {1}  \
    CONFIG.PCW_TPIU_PERIPHERAL_DIVISOR0 {1}  \
    CONFIG.PCW_DCI_PERIPHERAL_DIVISOR0 {52}  \
    CONFIG.PCW_DCI_PERIPHERAL_DIVISOR1 {2}  \
    CONFIG.PCW_PCAP_PERIPHERAL_DIVISOR0 {5}  \
    CONFIG.PCW_TTC0_CLK0_PERIPHERAL_DIVISOR0 {1}  \
    CONFIG.PCW_TTC0_CLK1_PERIPHERAL_DIVISOR0 {1}  \
    CONFIG.PCW_TTC0_CLK2_PERIPHERAL_DIVISOR0 {1}  \
    CONFIG.PCW_TTC1_CLK0_PERIPHERAL_DIVISOR0 {1}  \
    CONFIG.PCW_TTC1_CLK1_PERIPHERAL_DIVISOR0 {1}  \
    CONFIG.PCW_TTC1_CLK2_PERIPHERAL_DIVISOR0 {1}  \
    CONFIG.PCW_WDT_PERIPHERAL_DIVISOR0 {1}  \
    CONFIG.PCW_ARMPLL_CTRL_FBDIV {26}  \
    CONFIG.PCW_IOPLL_CTRL_FBDIV {20}  \
    CONFIG.PCW_DDRPLL_CTRL_FBDIV {21}  \
    CONFIG.PCW_CPU_CPU_PLL_FREQMHZ {1300.000}  \
    CONFIG.PCW_IO_IO_PLL_FREQMHZ {1000.000}  \
    CONFIG.PCW_DDR_DDR_PLL_FREQMHZ {1050.000}  \
    CONFIG.PCW_SMC_PERIPHERAL_VALID {0}  \
    CONFIG.PCW_SDIO_PERIPHERAL_VALID {1}  \
    CONFIG.PCW_SPI_PERIPHERAL_VALID {0}  \
    CONFIG.PCW_CAN_PERIPHERAL_VALID {0}  \
    CONFIG.PCW_UART_PERIPHERAL_VALID {1}  \
    CONFIG.PCW_EN_EMIO_CAN0 {0}  \
    CONFIG.PCW_EN_EMIO_CAN1 {0}  \
    CONFIG.PCW_EN_EMIO_ENET0 {0}  \
    CONFIG.PCW_EN_EMIO_ENET1 {0}  \
    CONFIG.PCW_EN_PTP_ENET0 {0}  \
    CONFIG.PCW_EN_PTP_ENET1 {0}  \
    CONFIG.PCW_EN_EMIO_GPIO {0}  \
    CONFIG.PCW_EN_EMIO_I2C0 {0}  \
    CONFIG.PCW_EN_EMIO_I2C1 {0}  \
    CONFIG.PCW_EN_EMIO_PJTAG {0}  \
    CONFIG.PCW_EN_EMIO_SDIO0 {0}  \
    CONFIG.PCW_EN_EMIO_CD_SDIO0 {0}  \
    CONFIG.PCW_EN_EMIO_WP_SDIO0 {0}  \
    CONFIG.PCW_EN_EMIO_SDIO1 {0}  \
    CONFIG.PCW_EN_EMIO_CD_SDIO1 {0}  \
    CONFIG.PCW_EN_EMIO_WP_SDIO1 {0}  \
    CONFIG.PCW_EN_EMIO_SPI0 {0}  \
    CONFIG.PCW_EN_EMIO_SPI1 {0}  \
    CONFIG.PCW_EN_EMIO_UART0 {0}  \
    CONFIG.PCW_EN_EMIO_UART1 {0}  \
    CONFIG.PCW_EN_EMIO_MODEM_UART0 {0}  \
    CONFIG.PCW_EN_EMIO_MODEM_UART1 {0}  \
    CONFIG.PCW_EN_EMIO_TTC0 {0}  \
    CONFIG.PCW_EN_EMIO_TTC1 {0}  \
    CONFIG.PCW_EN_EMIO_WDT {0}  \
    CONFIG.PCW_EN_EMIO_TRACE {0}  \
    CONFIG.PCW_USE_AXI_NONSECURE {0}  \
    CONFIG.PCW_USE_M_AXI_GP0 {0}  \
    CONFIG.PCW_USE_M_AXI_GP1 {0}  \
    CONFIG.PCW_USE_S_AXI_GP0 {0}  \
    CONFIG.PCW_USE_S_AXI_GP1 {0}  \
    CONFIG.PCW_USE_S_AXI_ACP {0}  \
    CONFIG.PCW_USE_S_AXI_HP0 {0}  \
    CONFIG.PCW_USE_S_AXI_HP1 {0}  \
    CONFIG.PCW_USE_S_AXI_HP2 {0}  \
    CONFIG.PCW_USE_S_AXI_HP3 {0}  \
    CONFIG.PCW_M_AXI_GP0_FREQMHZ {10}  \
    CONFIG.PCW_M_AXI_GP1_FREQMHZ {10}  \
    CONFIG.PCW_S_AXI_GP0_FREQMHZ {10}  \
    CONFIG.PCW_S_AXI_GP1_FREQMHZ {10}  \
    CONFIG.PCW_S_AXI_ACP_FREQMHZ {10}  \
    CONFIG.PCW_S_AXI_HP0_FREQMHZ {10}  \
    CONFIG.PCW_S_AXI_HP1_FREQMHZ {10}  \
    CONFIG.PCW_S_AXI_HP2_FREQMHZ {10}  \
    CONFIG.PCW_S_AXI_HP3_FREQMHZ {10}  \
    CONFIG.PCW_USE_DMA0 {0}  \
    CONFIG.PCW_USE_DMA1 {0}  \
    CONFIG.PCW_USE_DMA2 {0}  \
    CONFIG.PCW_USE_DMA3 {0}  \
    CONFIG.PCW_USE_TRACE {0}  \
    CONFIG.PCW_TRACE_PIPELINE_WIDTH {8}  \
    CONFIG.PCW_INCLUDE_TRACE_BUFFER {0}  \
    CONFIG.PCW_TRACE_BUFFER_FIFO_SIZE {128}  \
    CONFIG.PCW_USE_TRACE_DATA_EDGE_DETECTOR {0}  \
    CONFIG.PCW_TRACE_BUFFER_CLOCK_DELAY {12}  \
    CONFIG.PCW_USE_CROSS_TRIGGER {0}  \
    CONFIG.PCW_FTM_CTI_IN0 {<Select>}  \
    CONFIG.PCW_FTM_CTI_IN1 {<Select>}  \
    CONFIG.PCW_FTM_CTI_IN2 {<Select>}  \
    CONFIG.PCW_FTM_CTI_IN3 {<Select>}  \
    CONFIG.PCW_FTM_CTI_OUT0 {<Select>}  \
    CONFIG.PCW_FTM_CTI_OUT1 {<Select>}  \
    CONFIG.PCW_FTM_CTI_OUT2 {<Select>}  \
    CONFIG.PCW_FTM_CTI_OUT3 {<Select>}  \
    CONFIG.PCW_USE_DEBUG {0}  \
    CONFIG.PCW_USE_CR_FABRIC {1}  \
    CONFIG.PCW_USE_AXI_FABRIC_IDLE {0}  \
    CONFIG.PCW_USE_DDR_BYPASS {0}  \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {0}  \
    CONFIG.PCW_USE_PROC_EVENT_BUS {0}  \
    CONFIG.PCW_USE_EXPANDED_IOP {0}  \
    CONFIG.PCW_USE_HIGH_OCM {0}  \
    CONFIG.PCW_USE_PS_SLCR_REGISTERS {0}  \
    CONFIG.PCW_USE_EXPANDED_PS_SLCR_REGISTERS {0}  \
    CONFIG.PCW_USE_CORESIGHT {0}  \
    CONFIG.PCW_EN_EMIO_SRAM_INT {0}  \
    CONFIG.PCW_GPIO_EMIO_GPIO_WIDTH {64}  \
    CONFIG.PCW_UART0_BAUD_RATE {115200}  \
    CONFIG.PCW_UART1_BAUD_RATE {115200}  \
    CONFIG.PCW_EN_4K_TIMER {0}  \
    CONFIG.PCW_M_AXI_GP0_ID_WIDTH {12}  \
    CONFIG.PCW_M_AXI_GP0_ENABLE_STATIC_REMAP {0}  \
    CONFIG.PCW_M_AXI_GP0_SUPPORT_NARROW_BURST {0}  \
    CONFIG.PCW_M_AXI_GP0_THREAD_ID_WIDTH {12}  \
    CONFIG.PCW_M_AXI_GP1_ID_WIDTH {12}  \
    CONFIG.PCW_M_AXI_GP1_ENABLE_STATIC_REMAP {0}  \
    CONFIG.PCW_M_AXI_GP1_SUPPORT_NARROW_BURST {0}  \
    CONFIG.PCW_M_AXI_GP1_THREAD_ID_WIDTH {12}  \
    CONFIG.PCW_S_AXI_GP0_ID_WIDTH {6}  \
    CONFIG.PCW_S_AXI_GP1_ID_WIDTH {6}  \
    CONFIG.PCW_S_AXI_ACP_ID_WIDTH {3}  \
    CONFIG.PCW_INCLUDE_ACP_TRANS_CHECK {0}  \
    CONFIG.PCW_USE_DEFAULT_ACP_USER_VAL {0}  \
    CONFIG.PCW_S_AXI_ACP_ARUSER_VAL {31}  \
    CONFIG.PCW_S_AXI_ACP_AWUSER_VAL {31}  \
    CONFIG.PCW_S_AXI_HP0_ID_WIDTH {6}  \
    CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {64}  \
    CONFIG.PCW_S_AXI_HP1_ID_WIDTH {6}  \
    CONFIG.PCW_S_AXI_HP1_DATA_WIDTH {64}  \
    CONFIG.PCW_S_AXI_HP2_ID_WIDTH {6}  \
    CONFIG.PCW_S_AXI_HP2_DATA_WIDTH {64}  \
    CONFIG.PCW_S_AXI_HP3_ID_WIDTH {6}  \
    CONFIG.PCW_S_AXI_HP3_DATA_WIDTH {64}  \
    CONFIG.PCW_EN_DDR {1}  \
    CONFIG.PCW_EN_SMC {0}  \
    CONFIG.PCW_EN_QSPI {1}  \
    CONFIG.PCW_EN_CAN0 {0}  \
    CONFIG.PCW_EN_CAN1 {0}  \
    CONFIG.PCW_EN_ENET0 {1}  \
    CONFIG.PCW_EN_ENET1 {0}  \
    CONFIG.PCW_EN_GPIO {1}  \
    CONFIG.PCW_EN_I2C0 {0}  \
    CONFIG.PCW_EN_I2C1 {0}  \
    CONFIG.PCW_EN_PJTAG {0}  \
    CONFIG.PCW_EN_SDIO0 {1}  \
    CONFIG.PCW_EN_SDIO1 {0}  \
    CONFIG.PCW_EN_SPI0 {0}  \
    CONFIG.PCW_EN_SPI1 {0}  \
    CONFIG.PCW_EN_UART0 {1}  \
    CONFIG.PCW_EN_UART1 {0}  \
    CONFIG.PCW_EN_MODEM_UART0 {0}  \
    CONFIG.PCW_EN_MODEM_UART1 {0}  \
    CONFIG.PCW_EN_TTC0 {0}  \
    CONFIG.PCW_EN_TTC1 {0}  \
    CONFIG.PCW_EN_WDT {0}  \
    CONFIG.PCW_EN_TRACE {0}  \
    CONFIG.PCW_EN_USB0 {1}  \
    CONFIG.PCW_EN_USB1 {0}  \
    CONFIG.PCW_DQ_WIDTH {32}  \
    CONFIG.PCW_DQS_WIDTH {4}  \
    CONFIG.PCW_DM_WIDTH {4}  \
    CONFIG.PCW_MIO_PRIMITIVE {54}  \
    CONFIG.PCW_EN_CLK0_PORT {1}  \
    CONFIG.PCW_EN_CLK1_PORT {0}  \
    CONFIG.PCW_EN_CLK2_PORT {0}  \
    CONFIG.PCW_EN_CLK3_PORT {0}  \
    CONFIG.PCW_EN_RST0_PORT {1}  \
    CONFIG.PCW_EN_RST1_PORT {0}  \
    CONFIG.PCW_EN_RST2_PORT {0}  \
    CONFIG.PCW_EN_RST3_PORT {0}  \
    CONFIG.PCW_EN_CLKTRIG0_PORT {0}  \
    CONFIG.PCW_EN_CLKTRIG1_PORT {0}  \
    CONFIG.PCW_EN_CLKTRIG2_PORT {0}  \
    CONFIG.PCW_EN_CLKTRIG3_PORT {0}  \
    CONFIG.PCW_P2F_DMAC_ABORT_INTR {0}  \
    CONFIG.PCW_P2F_DMAC0_INTR {0}  \
    CONFIG.PCW_P2F_DMAC1_INTR {0}  \
    CONFIG.PCW_P2F_DMAC2_INTR {0}  \
    CONFIG.PCW_P2F_DMAC3_INTR {0}  \
    CONFIG.PCW_P2F_DMAC4_INTR {0}  \
    CONFIG.PCW_P2F_DMAC5_INTR {0}  \
    CONFIG.PCW_P2F_DMAC6_INTR {0}  \
    CONFIG.PCW_P2F_DMAC7_INTR {0}  \
    CONFIG.PCW_P2F_SMC_INTR {0}  \
    CONFIG.PCW_P2F_QSPI_INTR {0}  \
    CONFIG.PCW_P2F_CTI_INTR {0}  \
    CONFIG.PCW_P2F_GPIO_INTR {0}  \
    CONFIG.PCW_P2F_USB0_INTR {0}  \
    CONFIG.PCW_P2F_ENET0_INTR {0}  \
    CONFIG.PCW_P2F_SDIO0_INTR {0}  \
    CONFIG.PCW_P2F_I2C0_INTR {0}  \
    CONFIG.PCW_P2F_SPI0_INTR {0}  \
    CONFIG.PCW_P2F_UART0_INTR {0}  \
    CONFIG.PCW_P2F_CAN0_INTR {0}  \
    CONFIG.PCW_P2F_USB1_INTR {0}  \
    CONFIG.PCW_P2F_ENET1_INTR {0}  \
    CONFIG.PCW_P2F_SDIO1_INTR {0}  \
    CONFIG.PCW_P2F_I2C1_INTR {0}  \
    CONFIG.PCW_P2F_SPI1_INTR {0}  \
    CONFIG.PCW_P2F_UART1_INTR {0}  \
    CONFIG.PCW_P2F_CAN1_INTR {0}  \
    CONFIG.PCW_IRQ_F2P_INTR {0}  \
    CONFIG.PCW_IRQ_F2P_MODE {DIRECT}  \
    CONFIG.PCW_CORE0_FIQ_INTR {0}  \
    CONFIG.PCW_CORE0_IRQ_INTR {0}  \
    CONFIG.PCW_CORE1_FIQ_INTR {0}  \
    CONFIG.PCW_CORE1_IRQ_INTR {0}  \
    CONFIG.PCW_VALUE_SILVERSION {3}  \
    CONFIG.PCW_IMPORT_BOARD_PRESET {None}  \
    CONFIG.PCW_PERIPHERAL_BOARD_PRESET {None}  \
    CONFIG.PCW_PRESET_BANK0_VOLTAGE {LVCMOS 3.3V}  \
    CONFIG.PCW_PRESET_BANK1_VOLTAGE {LVCMOS 1.8V}  \
    CONFIG.PCW_UIPARAM_DDR_ENABLE {1}  \
    CONFIG.PCW_UIPARAM_DDR_ADV_ENABLE {0}  \
    CONFIG.PCW_UIPARAM_DDR_MEMORY_TYPE {DDR 3}  \
    CONFIG.PCW_UIPARAM_DDR_ECC {Disabled}  \
    CONFIG.PCW_UIPARAM_DDR_BUS_WIDTH {16 Bit}  \
    CONFIG.PCW_UIPARAM_DDR_BL {8}  \
    CONFIG.PCW_UIPARAM_DDR_HIGH_TEMP {Normal (0-85)}  \
    CONFIG.PCW_UIPARAM_DDR_PARTNO {MT41J256M16 RE-125}  \
    CONFIG.PCW_UIPARAM_DDR_DRAM_WIDTH {16 Bits}  \
    CONFIG.PCW_UIPARAM_DDR_DEVICE_CAPACITY {4096 MBits}  \
    CONFIG.PCW_UIPARAM_DDR_SPEED_BIN {DDR3_1066F}  \
    CONFIG.PCW_UIPARAM_DDR_TRAIN_WRITE_LEVEL {1}  \
    CONFIG.PCW_UIPARAM_DDR_TRAIN_READ_GATE {1}  \
    CONFIG.PCW_UIPARAM_DDR_TRAIN_DATA_EYE {1}  \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_STOP_EN {0}  \
    CONFIG.PCW_UIPARAM_DDR_USE_INTERNAL_VREF {0}  \
    CONFIG.PCW_DDR_PRIORITY_WRITEPORT_0 {<Select>}  \
    CONFIG.PCW_DDR_PRIORITY_WRITEPORT_1 {<Select>}  \
    CONFIG.PCW_DDR_PRIORITY_WRITEPORT_2 {<Select>}  \
    CONFIG.PCW_DDR_PRIORITY_WRITEPORT_3 {<Select>}  \
    CONFIG.PCW_DDR_PRIORITY_READPORT_0 {<Select>}  \
    CONFIG.PCW_DDR_PRIORITY_READPORT_1 {<Select>}  \
    CONFIG.PCW_DDR_PRIORITY_READPORT_2 {<Select>}  \
    CONFIG.PCW_DDR_PRIORITY_READPORT_3 {<Select>}  \
    CONFIG.PCW_DDR_PORT0_HPR_ENABLE {0}  \
    CONFIG.PCW_DDR_PORT1_HPR_ENABLE {0}  \
    CONFIG.PCW_DDR_PORT2_HPR_ENABLE {0}  \
    CONFIG.PCW_DDR_PORT3_HPR_ENABLE {0}  \
    CONFIG.PCW_DDR_HPRLPR_QUEUE_PARTITION {HPR(0)/LPR(32)}  \
    CONFIG.PCW_DDR_LPR_TO_CRITICAL_PRIORITY_LEVEL {2}  \
    CONFIG.PCW_DDR_HPR_TO_CRITICAL_PRIORITY_LEVEL {15}  \
    CONFIG.PCW_DDR_WRITE_TO_CRITICAL_PRIORITY_LEVEL {2}  \
    CONFIG.PCW_NAND_PERIPHERAL_ENABLE {0}  \
    CONFIG.PCW_NAND_NAND_IO {<Select>}  \
    CONFIG.PCW_NAND_GRP_D8_ENABLE {0}  \
    CONFIG.PCW_NAND_GRP_D8_IO {<Select>}  \
    CONFIG.PCW_NOR_PERIPHERAL_ENABLE {0}  \
    CONFIG.PCW_NOR_NOR_IO {<Select>}  \
    CONFIG.PCW_NOR_GRP_A25_ENABLE {0}  \
    CONFIG.PCW_NOR_GRP_A25_IO {<Select>}  \
    CONFIG.PCW_NOR_GRP_CS0_ENABLE {0}  \
    CONFIG.PCW_NOR_GRP_CS0_IO {<Select>}  \
    CONFIG.PCW_NOR_GRP_SRAM_CS0_ENABLE {0}  \
    CONFIG.PCW_NOR_GRP_SRAM_CS0_IO {<Select>}  \
    CONFIG.PCW_NOR_GRP_CS1_ENABLE {0}  \
    CONFIG.PCW_NOR_GRP_CS1_IO {<Select>}  \
    CONFIG.PCW_NOR_GRP_SRAM_CS1_ENABLE {0}  \
    CONFIG.PCW_NOR_GRP_SRAM_CS1_IO {<Select>}  \
    CONFIG.PCW_NOR_GRP_SRAM_INT_ENABLE {0}  \
    CONFIG.PCW_NOR_GRP_SRAM_INT_IO {<Select>}  \
    CONFIG.PCW_QSPI_PERIPHERAL_ENABLE {1}  \
    CONFIG.PCW_QSPI_QSPI_IO {MIO 1 .. 6}  \
    CONFIG.PCW_QSPI_GRP_SINGLE_SS_ENABLE {1}  \
    CONFIG.PCW_QSPI_GRP_SINGLE_SS_IO {MIO 1 .. 6}  \
    CONFIG.PCW_QSPI_GRP_SS1_ENABLE {0}  \
    CONFIG.PCW_QSPI_GRP_SS1_IO {<Select>}  \
    CONFIG.PCW_QSPI_GRP_IO1_ENABLE {0}  \
    CONFIG.PCW_QSPI_GRP_IO1_IO {<Select>}  \
    CONFIG.PCW_QSPI_GRP_FBCLK_ENABLE {1}  \
    CONFIG.PCW_QSPI_GRP_FBCLK_IO {MIO 8}  \
    CONFIG.PCW_QSPI_INTERNAL_HIGHADDRESS {0xFCFFFFFF}  \
    CONFIG.PCW_ENET0_PERIPHERAL_ENABLE {1}  \
    CONFIG.PCW_ENET0_ENET0_IO {MIO 16 .. 27}  \
    CONFIG.PCW_ENET0_GRP_MDIO_ENABLE {1}  \
    CONFIG.PCW_ENET0_GRP_MDIO_IO {MIO 52 .. 53}  \
    CONFIG.PCW_ENET_RESET_ENABLE {1}  \
    CONFIG.PCW_ENET_RESET_SELECT {Share reset pin}  \
    CONFIG.PCW_ENET0_RESET_ENABLE {1}  \
    CONFIG.PCW_ENET0_RESET_IO {MIO 9}  \
    CONFIG.PCW_ENET1_PERIPHERAL_ENABLE {0}  \
    CONFIG.PCW_ENET1_ENET1_IO {<Select>}  \
    CONFIG.PCW_ENET1_GRP_MDIO_ENABLE {0}  \
    CONFIG.PCW_ENET1_GRP_MDIO_IO {<Select>}  \
    CONFIG.PCW_ENET1_RESET_ENABLE {0}  \
    CONFIG.PCW_ENET1_RESET_IO {<Select>}  \
    CONFIG.PCW_SD0_PERIPHERAL_ENABLE {1}  \
    CONFIG.PCW_SD0_SD0_IO {MIO 40 .. 45}  \
    CONFIG.PCW_SD0_GRP_CD_ENABLE {1}  \
    CONFIG.PCW_SD0_GRP_CD_IO {MIO 47}  \
    CONFIG.PCW_SD0_GRP_WP_ENABLE {0}  \
    CONFIG.PCW_SD0_GRP_WP_IO {<Select>}  \
    CONFIG.PCW_SD0_GRP_POW_ENABLE {0}  \
    CONFIG.PCW_SD0_GRP_POW_IO {<Select>}  \
    CONFIG.PCW_SD1_PERIPHERAL_ENABLE {0}  \
    CONFIG.PCW_SD1_SD1_IO {<Select>}  \
    CONFIG.PCW_SD1_GRP_CD_ENABLE {0}  \
    CONFIG.PCW_SD1_GRP_CD_IO {<Select>}  \
    CONFIG.PCW_SD1_GRP_WP_ENABLE {0}  \
    CONFIG.PCW_SD1_GRP_WP_IO {<Select>}  \
    CONFIG.PCW_SD1_GRP_POW_ENABLE {0}  \
    CONFIG.PCW_SD1_GRP_POW_IO {<Select>}  \
    CONFIG.PCW_UART0_PERIPHERAL_ENABLE {1}  \
    CONFIG.PCW_UART0_UART0_IO {MIO 14 .. 15}  \
    CONFIG.PCW_UART0_GRP_FULL_ENABLE {0}  \
    CONFIG.PCW_UART0_GRP_FULL_IO {<Select>}  \
    CONFIG.PCW_UART1_PERIPHERAL_ENABLE {0}  \
    CONFIG.PCW_UART1_UART1_IO {<Select>}  \
    CONFIG.PCW_UART1_GRP_FULL_ENABLE {0}  \
    CONFIG.PCW_UART1_GRP_FULL_IO {<Select>}  \
    CONFIG.PCW_SPI0_PERIPHERAL_ENABLE {0}  \
    CONFIG.PCW_SPI0_SPI0_IO {<Select>}  \
    CONFIG.PCW_SPI0_GRP_SS0_ENABLE {0}  \
    CONFIG.PCW_SPI0_GRP_SS0_IO {<Select>}  \
    CONFIG.PCW_SPI0_GRP_SS1_ENABLE {0}  \
    CONFIG.PCW_SPI0_GRP_SS1_IO {<Select>}  \
    CONFIG.PCW_SPI0_GRP_SS2_ENABLE {0}  \
    CONFIG.PCW_SPI0_GRP_SS2_IO {<Select>}  \
    CONFIG.PCW_SPI1_PERIPHERAL_ENABLE {0}  \
    CONFIG.PCW_SPI1_SPI1_IO {<Select>}  \
    CONFIG.PCW_SPI1_GRP_SS0_ENABLE {0}  \
    CONFIG.PCW_SPI1_GRP_SS0_IO {<Select>}  \
    CONFIG.PCW_SPI1_GRP_SS1_ENABLE {0}  \
    CONFIG.PCW_SPI1_GRP_SS1_IO {<Select>}  \
    CONFIG.PCW_SPI1_GRP_SS2_ENABLE {0}  \
    CONFIG.PCW_SPI1_GRP_SS2_IO {<Select>}  \
    CONFIG.PCW_CAN0_PERIPHERAL_ENABLE {0}  \
    CONFIG.PCW_CAN0_CAN0_IO {<Select>}  \
    CONFIG.PCW_CAN0_GRP_CLK_ENABLE {0}  \
    CONFIG.PCW_CAN0_GRP_CLK_IO {<Select>}  \
    CONFIG.PCW_CAN1_PERIPHERAL_ENABLE {0}  \
    CONFIG.PCW_CAN1_CAN1_IO {<Select>}  \
    CONFIG.PCW_CAN1_GRP_CLK_ENABLE {0}  \
    CONFIG.PCW_CAN1_GRP_CLK_IO {<Select>}  \
    CONFIG.PCW_TRACE_PERIPHERAL_ENABLE {0}  \
    CONFIG.PCW_TRACE_TRACE_IO {<Select>}  \
    CONFIG.PCW_TRACE_GRP_2BIT_ENABLE {0}  \
    CONFIG.PCW_TRACE_GRP_2BIT_IO {<Select>}  \
    CONFIG.PCW_TRACE_GRP_4BIT_ENABLE {0}  \
    CONFIG.PCW_TRACE_GRP_4BIT_IO {<Select>}  \
    CONFIG.PCW_TRACE_GRP_8BIT_ENABLE {0}  \
    CONFIG.PCW_TRACE_GRP_8BIT_IO {<Select>}  \
    CONFIG.PCW_TRACE_GRP_16BIT_ENABLE {0}  \
    CONFIG.PCW_TRACE_GRP_16BIT_IO {<Select>}  \
    CONFIG.PCW_TRACE_GRP_32BIT_ENABLE {0}  \
    CONFIG.PCW_TRACE_GRP_32BIT_IO {<Select>}  \
    CONFIG.PCW_TRACE_INTERNAL_WIDTH {2}  \
    CONFIG.PCW_WDT_PERIPHERAL_ENABLE {0}  \
    CONFIG.PCW_WDT_WDT_IO {<Select>}  \
    CONFIG.PCW_TTC0_PERIPHERAL_ENABLE {0}  \
    CONFIG.PCW_TTC0_TTC0_IO {<Select>}  \
    CONFIG.PCW_TTC1_PERIPHERAL_ENABLE {0}  \
    CONFIG.PCW_TTC1_TTC1_IO {<Select>}  \
    CONFIG.PCW_PJTAG_PERIPHERAL_ENABLE {0}  \
    CONFIG.PCW_PJTAG_PJTAG_IO {<Select>}  \
    CONFIG.PCW_USB0_PERIPHERAL_ENABLE {1}  \
    CONFIG.PCW_USB0_USB0_IO {MIO 28 .. 39}  \
    CONFIG.PCW_USB_RESET_ENABLE {1}  \
    CONFIG.PCW_USB_RESET_SELECT {Share reset pin}  \
    CONFIG.PCW_USB0_RESET_ENABLE {1}  \
    CONFIG.PCW_USB0_RESET_IO {MIO 46}  \
    CONFIG.PCW_USB1_PERIPHERAL_ENABLE {0}  \
    CONFIG.PCW_USB1_USB1_IO {<Select>}  \
    CONFIG.PCW_USB1_RESET_ENABLE {0}  \
    CONFIG.PCW_USB1_RESET_IO {<Select>}  \
    CONFIG.PCW_I2C0_PERIPHERAL_ENABLE {0}  \
    CONFIG.PCW_I2C0_I2C0_IO {<Select>}  \
    CONFIG.PCW_I2C0_GRP_INT_ENABLE {0}  \
    CONFIG.PCW_I2C0_GRP_INT_IO {<Select>}  \
    CONFIG.PCW_I2C0_RESET_ENABLE {0}  \
    CONFIG.PCW_I2C0_RESET_IO {<Select>}  \
    CONFIG.PCW_I2C1_PERIPHERAL_ENABLE {0}  \
    CONFIG.PCW_I2C1_I2C1_IO {<Select>}  \
    CONFIG.PCW_I2C1_GRP_INT_ENABLE {0}  \
    CONFIG.PCW_I2C1_GRP_INT_IO {<Select>}  \
    CONFIG.PCW_I2C_RESET_ENABLE {1}  \
    CONFIG.PCW_I2C_RESET_SELECT {<Select>}  \
    CONFIG.PCW_I2C1_RESET_ENABLE {0}  \
    CONFIG.PCW_I2C1_RESET_IO {<Select>}  \
    CONFIG.PCW_GPIO_PERIPHERAL_ENABLE {0}  \
    CONFIG.PCW_GPIO_MIO_GPIO_ENABLE {1}  \
    CONFIG.PCW_GPIO_MIO_GPIO_IO {MIO}  \
    CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE {0}  \
    CONFIG.PCW_GPIO_EMIO_GPIO_IO {<Select>}  \
    CONFIG.PCW_APU_CLK_RATIO_ENABLE {6:2:1}  \
    CONFIG.PCW_ENET0_PERIPHERAL_FREQMHZ {1000 Mbps}  \
    CONFIG.PCW_ENET1_PERIPHERAL_FREQMHZ {1000 Mbps}  \
    CONFIG.PCW_CPU_PERIPHERAL_CLKSRC {ARM PLL}  \
    CONFIG.PCW_DDR_PERIPHERAL_CLKSRC {DDR PLL}  \
    CONFIG.PCW_SMC_PERIPHERAL_CLKSRC {IO PLL}  \
    CONFIG.PCW_QSPI_PERIPHERAL_CLKSRC {IO PLL}  \
    CONFIG.PCW_SDIO_PERIPHERAL_CLKSRC {IO PLL}  \
    CONFIG.PCW_UART_PERIPHERAL_CLKSRC {IO PLL}  \
    CONFIG.PCW_SPI_PERIPHERAL_CLKSRC {IO PLL}  \
    CONFIG.PCW_CAN_PERIPHERAL_CLKSRC {IO PLL}  \
    CONFIG.PCW_FCLK0_PERIPHERAL_CLKSRC {IO PLL}  \
    CONFIG.PCW_FCLK1_PERIPHERAL_CLKSRC {IO PLL}  \
    CONFIG.PCW_FCLK2_PERIPHERAL_CLKSRC {IO PLL}  \
    CONFIG.PCW_FCLK3_PERIPHERAL_CLKSRC {IO PLL}  \
    CONFIG.PCW_ENET0_PERIPHERAL_CLKSRC {IO PLL}  \
    CONFIG.PCW_ENET1_PERIPHERAL_CLKSRC {IO PLL}  \
    CONFIG.PCW_CAN0_PERIPHERAL_CLKSRC {External}  \
    CONFIG.PCW_CAN1_PERIPHERAL_CLKSRC {External}  \
    CONFIG.PCW_TPIU_PERIPHERAL_CLKSRC {External}  \
    CONFIG.PCW_TTC0_CLK0_PERIPHERAL_CLKSRC {CPU_1X}  \
    CONFIG.PCW_TTC0_CLK1_PERIPHERAL_CLKSRC {CPU_1X}  \
    CONFIG.PCW_TTC0_CLK2_PERIPHERAL_CLKSRC {CPU_1X}  \
    CONFIG.PCW_TTC1_CLK0_PERIPHERAL_CLKSRC {CPU_1X}  \
    CONFIG.PCW_TTC1_CLK1_PERIPHERAL_CLKSRC {CPU_1X}  \
    CONFIG.PCW_TTC1_CLK2_PERIPHERAL_CLKSRC {CPU_1X}  \
    CONFIG.PCW_WDT_PERIPHERAL_CLKSRC {CPU_1X}  \
    CONFIG.PCW_DCI_PERIPHERAL_CLKSRC {DDR PLL}  \
    CONFIG.PCW_PCAP_PERIPHERAL_CLKSRC {IO PLL}  \
    CONFIG.PCW_USB_RESET_POLARITY {Active Low}  \
    CONFIG.PCW_ENET_RESET_POLARITY {Active Low}  \
    CONFIG.PCW_I2C_RESET_POLARITY {Active Low}  \
    CONFIG.PCW_MIO_0_PULLUP {enabled}  \
    CONFIG.PCW_MIO_0_IOTYPE {LVCMOS 3.3V}  \
    CONFIG.PCW_MIO_0_DIRECTION {inout}  \
    CONFIG.PCW_MIO_0_SLEW {slow}  \
    CONFIG.PCW_MIO_1_PULLUP {enabled}  \
    CONFIG.PCW_MIO_1_IOTYPE {LVCMOS 3.3V}  \
    CONFIG.PCW_MIO_1_DIRECTION {out}  \
    CONFIG.PCW_MIO_1_SLEW {slow}  \
    CONFIG.PCW_MIO_2_PULLUP {disabled}  \
    CONFIG.PCW_MIO_2_IOTYPE {LVCMOS 3.3V}  \
    CONFIG.PCW_MIO_2_DIRECTION {inout}  \
    CONFIG.PCW_MIO_2_SLEW {slow}  \
    CONFIG.PCW_MIO_3_PULLUP {disabled}  \
    CONFIG.PCW_MIO_3_IOTYPE {LVCMOS 3.3V}  \
    CONFIG.PCW_MIO_3_DIRECTION {inout}  \
    CONFIG.PCW_MIO_3_SLEW {slow}  \
    CONFIG.PCW_MIO_4_PULLUP {disabled}  \
    CONFIG.PCW_MIO_4_IOTYPE {LVCMOS 3.3V}  \
    CONFIG.PCW_MIO_4_DIRECTION {inout}  \
    CONFIG.PCW_MIO_4_SLEW {slow}  \
    CONFIG.PCW_MIO_5_PULLUP {disabled}  \
    CONFIG.PCW_MIO_5_IOTYPE {LVCMOS 3.3V}  \
    CONFIG.PCW_MIO_5_DIRECTION {inout}  \
    CONFIG.PCW_MIO_5_SLEW {slow}  \
    CONFIG.PCW_MIO_6_PULLUP {disabled}  \
    CONFIG.PCW_MIO_6_IOTYPE {LVCMOS 3.3V}  \
    CONFIG.PCW_MIO_6_DIRECTION {out}  \
    CONFIG.PCW_MIO_6_SLEW {slow}  \
    CONFIG.PCW_MIO_7_PULLUP {disabled}  \
    CONFIG.PCW_MIO_7_IOTYPE {LVCMOS 3.3V}  \
    CONFIG.PCW_MIO_7_DIRECTION {out}  \
    CONFIG.PCW_MIO_7_SLEW {slow}  \
    CONFIG.PCW_MIO_8_PULLUP {disabled}  \
    CONFIG.PCW_MIO_8_IOTYPE {LVCMOS 3.3V}  \
    CONFIG.PCW_MIO_8_DIRECTION {out}  \
    CONFIG.PCW_MIO_8_SLEW {slow}  \
    CONFIG.PCW_MIO_9_PULLUP {enabled}  \
    CONFIG.PCW_MIO_9_IOTYPE {LVCMOS 3.3V}  \
    CONFIG.PCW_MIO_9_DIRECTION {out}  \
    CONFIG.PCW_MIO_9_SLEW {slow}  \
    CONFIG.PCW_MIO_10_PULLUP {enabled}  \
    CONFIG.PCW_MIO_10_IOTYPE {LVCMOS 3.3V}  \
    CONFIG.PCW_MIO_10_DIRECTION {inout}  \
    CONFIG.PCW_MIO_10_SLEW {slow}  \
    CONFIG.PCW_MIO_11_PULLUP {enabled}  \
    CONFIG.PCW_MIO_11_IOTYPE {LVCMOS 3.3V}  \
    CONFIG.PCW_MIO_11_DIRECTION {inout}  \
    CONFIG.PCW_MIO_11_SLEW {slow}  \
    CONFIG.PCW_MIO_12_PULLUP {enabled}  \
    CONFIG.PCW_MIO_12_IOTYPE {LVCMOS 3.3V}  \
    CONFIG.PCW_MIO_12_DIRECTION {inout}  \
    CONFIG.PCW_MIO_12_SLEW {slow}  \
    CONFIG.PCW_MIO_13_PULLUP {enabled}  \
    CONFIG.PCW_MIO_13_IOTYPE {LVCMOS 3.3V}  \
    CONFIG.PCW_MIO_13_DIRECTION {inout}  \
    CONFIG.PCW_MIO_13_SLEW {slow}  \
    CONFIG.PCW_MIO_14_PULLUP {enabled}  \
    CONFIG.PCW_MIO_14_IOTYPE {LVCMOS 3.3V}  \
    CONFIG.PCW_MIO_14_DIRECTION {in}  \
    CONFIG.PCW_MIO_14_SLEW {slow}  \
    CONFIG.PCW_MIO_15_PULLUP {enabled}  \
    CONFIG.PCW_MIO_15_IOTYPE {LVCMOS 3.3V}  \
    CONFIG.PCW_MIO_15_DIRECTION {out}  \
    CONFIG.PCW_MIO_15_SLEW {slow}  \
    CONFIG.PCW_MIO_16_PULLUP {enabled}  \
    CONFIG.PCW_MIO_16_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_16_DIRECTION {out}  \
    CONFIG.PCW_MIO_16_SLEW {slow}  \
    CONFIG.PCW_MIO_17_PULLUP {enabled}  \
    CONFIG.PCW_MIO_17_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_17_DIRECTION {out}  \
    CONFIG.PCW_MIO_17_SLEW {slow}  \
    CONFIG.PCW_MIO_18_PULLUP {enabled}  \
    CONFIG.PCW_MIO_18_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_18_DIRECTION {out}  \
    CONFIG.PCW_MIO_18_SLEW {slow}  \
    CONFIG.PCW_MIO_19_PULLUP {enabled}  \
    CONFIG.PCW_MIO_19_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_19_DIRECTION {out}  \
    CONFIG.PCW_MIO_19_SLEW {slow}  \
    CONFIG.PCW_MIO_20_PULLUP {enabled}  \
    CONFIG.PCW_MIO_20_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_20_DIRECTION {out}  \
    CONFIG.PCW_MIO_20_SLEW {slow}  \
    CONFIG.PCW_MIO_21_PULLUP {enabled}  \
    CONFIG.PCW_MIO_21_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_21_DIRECTION {out}  \
    CONFIG.PCW_MIO_21_SLEW {slow}  \
    CONFIG.PCW_MIO_22_PULLUP {enabled}  \
    CONFIG.PCW_MIO_22_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_22_DIRECTION {in}  \
    CONFIG.PCW_MIO_22_SLEW {slow}  \
    CONFIG.PCW_MIO_23_PULLUP {enabled}  \
    CONFIG.PCW_MIO_23_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_23_DIRECTION {in}  \
    CONFIG.PCW_MIO_23_SLEW {slow}  \
    CONFIG.PCW_MIO_24_PULLUP {enabled}  \
    CONFIG.PCW_MIO_24_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_24_DIRECTION {in}  \
    CONFIG.PCW_MIO_24_SLEW {slow}  \
    CONFIG.PCW_MIO_25_PULLUP {enabled}  \
    CONFIG.PCW_MIO_25_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_25_DIRECTION {in}  \
    CONFIG.PCW_MIO_25_SLEW {slow}  \
    CONFIG.PCW_MIO_26_PULLUP {enabled}  \
    CONFIG.PCW_MIO_26_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_26_DIRECTION {in}  \
    CONFIG.PCW_MIO_26_SLEW {slow}  \
    CONFIG.PCW_MIO_27_PULLUP {enabled}  \
    CONFIG.PCW_MIO_27_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_27_DIRECTION {in}  \
    CONFIG.PCW_MIO_27_SLEW {slow}  \
    CONFIG.PCW_MIO_28_PULLUP {enabled}  \
    CONFIG.PCW_MIO_28_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_28_DIRECTION {inout}  \
    CONFIG.PCW_MIO_28_SLEW {slow}  \
    CONFIG.PCW_MIO_29_PULLUP {enabled}  \
    CONFIG.PCW_MIO_29_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_29_DIRECTION {in}  \
    CONFIG.PCW_MIO_29_SLEW {slow}  \
    CONFIG.PCW_MIO_30_PULLUP {enabled}  \
    CONFIG.PCW_MIO_30_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_30_DIRECTION {out}  \
    CONFIG.PCW_MIO_30_SLEW {slow}  \
    CONFIG.PCW_MIO_31_PULLUP {enabled}  \
    CONFIG.PCW_MIO_31_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_31_DIRECTION {in}  \
    CONFIG.PCW_MIO_31_SLEW {slow}  \
    CONFIG.PCW_MIO_32_PULLUP {enabled}  \
    CONFIG.PCW_MIO_32_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_32_DIRECTION {inout}  \
    CONFIG.PCW_MIO_32_SLEW {slow}  \
    CONFIG.PCW_MIO_33_PULLUP {enabled}  \
    CONFIG.PCW_MIO_33_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_33_DIRECTION {inout}  \
    CONFIG.PCW_MIO_33_SLEW {slow}  \
    CONFIG.PCW_MIO_34_PULLUP {enabled}  \
    CONFIG.PCW_MIO_34_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_34_DIRECTION {inout}  \
    CONFIG.PCW_MIO_34_SLEW {slow}  \
    CONFIG.PCW_MIO_35_PULLUP {enabled}  \
    CONFIG.PCW_MIO_35_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_35_DIRECTION {inout}  \
    CONFIG.PCW_MIO_35_SLEW {slow}  \
    CONFIG.PCW_MIO_36_PULLUP {enabled}  \
    CONFIG.PCW_MIO_36_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_36_DIRECTION {in}  \
    CONFIG.PCW_MIO_36_SLEW {slow}  \
    CONFIG.PCW_MIO_37_PULLUP {enabled}  \
    CONFIG.PCW_MIO_37_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_37_DIRECTION {inout}  \
    CONFIG.PCW_MIO_37_SLEW {slow}  \
    CONFIG.PCW_MIO_38_PULLUP {enabled}  \
    CONFIG.PCW_MIO_38_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_38_DIRECTION {inout}  \
    CONFIG.PCW_MIO_38_SLEW {slow}  \
    CONFIG.PCW_MIO_39_PULLUP {enabled}  \
    CONFIG.PCW_MIO_39_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_39_DIRECTION {inout}  \
    CONFIG.PCW_MIO_39_SLEW {slow}  \
    CONFIG.PCW_MIO_40_PULLUP {enabled}  \
    CONFIG.PCW_MIO_40_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_40_DIRECTION {inout}  \
    CONFIG.PCW_MIO_40_SLEW {slow}  \
    CONFIG.PCW_MIO_41_PULLUP {enabled}  \
    CONFIG.PCW_MIO_41_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_41_DIRECTION {inout}  \
    CONFIG.PCW_MIO_41_SLEW {slow}  \
    CONFIG.PCW_MIO_42_PULLUP {enabled}  \
    CONFIG.PCW_MIO_42_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_42_DIRECTION {inout}  \
    CONFIG.PCW_MIO_42_SLEW {slow}  \
    CONFIG.PCW_MIO_43_PULLUP {enabled}  \
    CONFIG.PCW_MIO_43_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_43_DIRECTION {inout}  \
    CONFIG.PCW_MIO_43_SLEW {slow}  \
    CONFIG.PCW_MIO_44_PULLUP {enabled}  \
    CONFIG.PCW_MIO_44_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_44_DIRECTION {inout}  \
    CONFIG.PCW_MIO_44_SLEW {slow}  \
    CONFIG.PCW_MIO_45_PULLUP {enabled}  \
    CONFIG.PCW_MIO_45_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_45_DIRECTION {inout}  \
    CONFIG.PCW_MIO_45_SLEW {slow}  \
    CONFIG.PCW_MIO_46_PULLUP {enabled}  \
    CONFIG.PCW_MIO_46_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_46_DIRECTION {out}  \
    CONFIG.PCW_MIO_46_SLEW {slow}  \
    CONFIG.PCW_MIO_47_PULLUP {enabled}  \
    CONFIG.PCW_MIO_47_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_47_DIRECTION {in}  \
    CONFIG.PCW_MIO_47_SLEW {slow}  \
    CONFIG.PCW_MIO_48_PULLUP {enabled}  \
    CONFIG.PCW_MIO_48_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_48_DIRECTION {inout}  \
    CONFIG.PCW_MIO_48_SLEW {slow}  \
    CONFIG.PCW_MIO_49_PULLUP {enabled}  \
    CONFIG.PCW_MIO_49_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_49_DIRECTION {inout}  \
    CONFIG.PCW_MIO_49_SLEW {slow}  \
    CONFIG.PCW_MIO_50_PULLUP {enabled}  \
    CONFIG.PCW_MIO_50_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_50_DIRECTION {inout}  \
    CONFIG.PCW_MIO_50_SLEW {slow}  \
    CONFIG.PCW_MIO_51_PULLUP {enabled}  \
    CONFIG.PCW_MIO_51_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_51_DIRECTION {inout}  \
    CONFIG.PCW_MIO_51_SLEW {slow}  \
    CONFIG.PCW_MIO_52_PULLUP {enabled}  \
    CONFIG.PCW_MIO_52_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_52_DIRECTION {out}  \
    CONFIG.PCW_MIO_52_SLEW {slow}  \
    CONFIG.PCW_MIO_53_PULLUP {enabled}  \
    CONFIG.PCW_MIO_53_IOTYPE {LVCMOS 1.8V}  \
    CONFIG.PCW_MIO_53_DIRECTION {inout}  \
    CONFIG.PCW_MIO_53_SLEW {slow}  \
    CONFIG.PCW_UIPARAM_GENERATE_SUMMARY {NA}  \
    CONFIG.PCW_MIO_TREE_PERIPHERALS {GPIO#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#GPIO#Quad SPI Flash#ENET Reset#GPIO#GPIO#GPIO#GPIO#UART 0#UART 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0#USB Reset#SD 0#GPIO#GPIO#GPIO#GPIO#Enet 0#Enet 0}  \
    CONFIG.PCW_MIO_TREE_SIGNALS {gpio[0]#qspi0_ss_b#qspi0_io[0]#qspi0_io[1]#qspi0_io[2]#qspi0_io[3]#qspi0_sclk#gpio[7]#qspi_fbclk#reset#gpio[10]#gpio[11]#gpio[12]#gpio[13]#rx#tx#tx_clk#txd[0]#txd[1]#txd[2]#txd[3]#tx_ctl#rx_clk#rxd[0]#rxd[1]#rxd[2]#rxd[3]#rx_ctl#data[4]#dir#stp#nxt#data[0]#data[1]#data[2]#data[3]#clk#data[5]#data[6]#data[7]#clk#cmd#data[0]#data[1]#data[2]#data[3]#reset#cd#gpio[48]#gpio[49]#gpio[50]#gpio[51]#mdc#mdio}  \
    CONFIG.PCW_PS7_SI_REV {PRODUCTION}  \
    CONFIG.PCW_FPGA_FCLK0_ENABLE {1}  \
    CONFIG.PCW_FPGA_FCLK1_ENABLE {0}  \
    CONFIG.PCW_FPGA_FCLK2_ENABLE {0}  \
    CONFIG.PCW_FPGA_FCLK3_ENABLE {0}  \
    CONFIG.PCW_NOR_SRAM_CS0_T_TR {1}  \
    CONFIG.PCW_NOR_SRAM_CS0_T_PC {1}  \
    CONFIG.PCW_NOR_SRAM_CS0_T_WP {1}  \
    CONFIG.PCW_NOR_SRAM_CS0_T_CEOE {1}  \
    CONFIG.PCW_NOR_SRAM_CS0_T_WC {11}  \
    CONFIG.PCW_NOR_SRAM_CS0_T_RC {11}  \
    CONFIG.PCW_NOR_SRAM_CS0_WE_TIME {0}  \
    CONFIG.PCW_NOR_SRAM_CS1_T_TR {1}  \
    CONFIG.PCW_NOR_SRAM_CS1_T_PC {1}  \
    CONFIG.PCW_NOR_SRAM_CS1_T_WP {1}  \
    CONFIG.PCW_NOR_SRAM_CS1_T_CEOE {1}  \
    CONFIG.PCW_NOR_SRAM_CS1_T_WC {11}  \
    CONFIG.PCW_NOR_SRAM_CS1_T_RC {11}  \
    CONFIG.PCW_NOR_SRAM_CS1_WE_TIME {0}  \
    CONFIG.PCW_NOR_CS0_T_TR {1}  \
    CONFIG.PCW_NOR_CS0_T_PC {1}  \
    CONFIG.PCW_NOR_CS0_T_WP {1}  \
    CONFIG.PCW_NOR_CS0_T_CEOE {1}  \
    CONFIG.PCW_NOR_CS0_T_WC {11}  \
    CONFIG.PCW_NOR_CS0_T_RC {11}  \
    CONFIG.PCW_NOR_CS0_WE_TIME {0}  \
    CONFIG.PCW_NOR_CS1_T_TR {1}  \
    CONFIG.PCW_NOR_CS1_T_PC {1}  \
    CONFIG.PCW_NOR_CS1_T_WP {1}  \
    CONFIG.PCW_NOR_CS1_T_CEOE {1}  \
    CONFIG.PCW_NOR_CS1_T_WC {11}  \
    CONFIG.PCW_NOR_CS1_T_RC {11}  \
    CONFIG.PCW_NOR_CS1_WE_TIME {0}  \
    CONFIG.PCW_NAND_CYCLES_T_RR {1}  \
    CONFIG.PCW_NAND_CYCLES_T_AR {1}  \
    CONFIG.PCW_NAND_CYCLES_T_CLR {1}  \
    CONFIG.PCW_NAND_CYCLES_T_WP {1}  \
    CONFIG.PCW_NAND_CYCLES_T_REA {1}  \
    CONFIG.PCW_NAND_CYCLES_T_WC {11}  \
    CONFIG.PCW_NAND_CYCLES_T_RC {11}  \
    CONFIG.PCW_SMC_CYCLE_T0 {NA}  \
    CONFIG.PCW_SMC_CYCLE_T1 {NA}  \
    CONFIG.PCW_SMC_CYCLE_T2 {NA}  \
    CONFIG.PCW_SMC_CYCLE_T3 {NA}  \
    CONFIG.PCW_SMC_CYCLE_T4 {NA}  \
    CONFIG.PCW_SMC_CYCLE_T5 {NA}  \
    CONFIG.PCW_SMC_CYCLE_T6 {NA}  \
    CONFIG.PCW_PACKAGE_NAME {clg400}  \
    CONFIG.PCW_PLL_BYPASSMODE_ENABLE {0}  \
]
}
EOF

cat >> create_hdf.tcl << EOF
set cur_dir [pwd]

# Create Vivado project
create_project -force pynq_dt \$cur_dir/pynq_dt -part xc7z020clg400-1
set proj_name [current_project]
set proj_dir [get_property directory [current_project]]
set_property "target_language" "VHDL" \$proj_name

# Create block diagram
create_bd_design "design_1"
update_compile_order -fileset sources_1

# Add processing system for Zynq Board
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 DDR
create_bd_intf_port -mode Master -vlnv xilinx.com:display_processing_system7:fixedio_rtl:1.0 FIXED_IO
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0

# Connect DDR and fixed IO
connect_bd_intf_net -intf_net processing_system7_0_DDR [get_bd_intf_ports DDR] [get_bd_intf_pins processing_system7_0/DDR]
connect_bd_intf_net -intf_net processing_system7_0_FIXED_IO [get_bd_intf_ports FIXED_IO] [get_bd_intf_pins processing_system7_0/FIXED_IO]

# Apply board preset
source \$cur_dir/pynq_c_ps.tcl
set_property -dict [apply_preset processing_system7_0] [get_bd_cells processing_system7_0]

# Make sure required AXI ports are active
set_property -dict [list CONFIG.PCW_USE_M_AXI_GP0 {1} \
                         CONFIG.PCW_USE_M_AXI_GP1 {1} \
                         CONFIG.PCW_USE_S_AXI_HP0 {1} \
                         CONFIG.PCW_USE_S_AXI_ACP {1}]\
                         [get_bd_cells processing_system7_0]

# Add interrupt port
set_property -dict [list CONFIG.PCW_USE_FABRIC_INTERRUPT {1} CONFIG.PCW_IRQ_F2P_INTR {1}] [get_bd_cells processing_system7_0]

# Set Frequencies
set_property -dict [ list CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} ] [get_bd_cells processing_system7_0]

# Tie AxUSER signals on ACP port to '1' to enable cache coherancy
set_property -dict [list CONFIG.PCW_USE_DEFAULT_ACP_USER_VAL {1}] [get_bd_cells processing_system7_0]

# Connect clocks
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
               [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK] \
               [get_bd_pins processing_system7_0/M_AXI_GP1_ACLK] \
               [get_bd_pins processing_system7_0/S_AXI_HP0_ACLK] \
               [get_bd_pins processing_system7_0/S_AXI_ACP_ACLK]

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
write_hwdef -force -file "\$cur_dir/pynq.hdf"
close_project
EOF

cat >> create_devicetree.tcl << EOF
set cur_dir [pwd]

open_hw_design \$cur_dir/pynq.hdf
set_repo_path \$cur_dir/device-tree-xlnx
create_sw_design device-tree -os device_tree -proc ps7_cortexa9_0
generate_target -dir dts
EOF

# Download Xilinx device tree repository
git clone https://github.com/Xilinx/device-tree-xlnx
cd $WD/devicetree/pynq/device-tree-xlnx
git checkout -b wb "$GITTAG_LINUX"
cd $WD/devicetree/pynq

# Generate device tree from a simple vivado project
vivado -mode batch -source create_hdf.tcl
hsi -mode batch -source create_devicetree.tcl

# Modify device tree files (required to make Ethernet and USB work)
cd $WD/devicetree/pynq/dts/
sed -i '/\/ {/a \\tmodel = "Pynq Development Board";\n\tcompatible = "xlnx,zynq-pynq", "xlnx,zynq-7000";' system-top.dts
sed -i '/.*xlnx,ptp-enet-clock.*/a \\tphy-handle = <&ethernet_phy>;\n\tethernet_phy: ethernet-phy@0 {\n\t\treg = <0>;\n\t\tdevice_type = "ethernet-phy";\n\t};' pcw.dtsi
sed -i '/.*usb-reset.*/a \\tusb-phy = <&usb_phy0>;' pcw.dtsi
sed -i '/\/ {/a \\tusb_phy0: phy0@e0002000 {\n\t\tcompatible = "ulpi-phy";\n\t\t#phy-cells = <0>;\n\t\treg = <0xe0002000 0x1000>;\n\t\tview-port = <0x0170>;\n\t\tdrv-vbus;\n\t};' pcw.dtsi

# Modify bootargs (depends on the type of rootfs selected)
if [[ $ROOTFS = 1 ]]; then
    BOOTARGS="bootargs = \"console=ttyPS0,115200 root=/dev/nfs rw nfsroot=$HOSTIP:$WD/nfs,tcp,nfsvers=3 ip=$BOARDIP:::255.255.255.0:artico3:eth0:off earlyprintk uio_pdrv_genirq.of_id=generic-uio\";"
    sed -i "s|.*bootargs.*|\t\t$BOOTARGS|" system-top.dts
else
    BOOTARGS="bootargs = \"console=ttyPS0,115200 root=/dev/ram rw initrd=0x4000000 earlyprintk uio_pdrv_genirq.of_id=generic-uio\";"
    sed -i "s|.*bootargs.*|\t\t$BOOTARGS|" system-top.dts
fi

# Create "fake" PL include to enable overlays
cat > pl.dtsi << EOF
/ {
    amba_pl: amba_pl {
        #address-cells = <1>;
        #size-cells = <1>;
        compatible = "simple-bus";
        interrupt-parent = <&intc>;
        ranges ;
    };
};
EOF

# Add include to top file
sed -i '/.*pcw.dtsi*./i \/include/ "pl.dtsi"' system-top.dts

# Generate device tree blob (adding symbols, that is the reason for
# using the last version of dtc)
cd $WD/devicetree/pynq/dts
dtc -I dts -O dts -@ -o devicetree.dts system-top.dts
dtc -I dts -O dtb -@ -o devicetree.dtb system-top.dts


#
# [6] Build U-Boot
#

cd $WD/u-boot-digilent
git checkout -b wb "$GITTAG_UBOOT"

# Added to leave $WD/u-boot-digilent/include/configs/zynq-common.h as original from u-boot-xlnx
sed -i '/.*sdboot=.*/i \\t"kernel_image=uImage\\0"\t\\\n\t"kernel_load_address=0x2080000\\0"\t\\\n\t"ramdisk_image=uramdisk.image.gz\\0"\t\\\n\t"ramdisk_load_address=0x4000000\\0"\t\\\n\t"devicetree_image=devicetree.dtb\\0"\t\\\n\t"devicetree_load_address=0x2000000\\0"\t\\' $WD/u-boot-digilent/include/configs/zynq-common.h
sed -i 's|.*sdboot=.*|\t"sdboot=if mmcinfo; then "\t\\|' $WD/u-boot-digilent/include/configs/zynq-common.h
sed -i '/.*sdboot=if mmcinfo;.*/{n;N;d}' $WD/u-boot-digilent/include/configs/zynq-common.h
sed -i '/.*sdboot=.*/a \\t\t\t"run uenvboot; "\t\\\n\t\t\t"echo Copying Linux from SD to RAM... && "\t\\\n\t\t\t"load mmc 0 ${kernel_load_address} ${kernel_image} && "\t\\\n\t\t\t"load mmc 0 ${devicetree_load_address} ${devicetree_image} && "\t\\\n\t\t\t"load mmc 0 ${ramdisk_load_address} ${ramdisk_image} && "\t\\\n\t\t\t"bootm ${kernel_load_address} ${ramdisk_load_address} ${devicetree_load_address}; "\t\\\n\t\t"fi\\0"\t\\' $WD/u-boot-digilent/include/configs/zynq-common.h

if [[ $ROOTFS = 1 ]]; then
    sed -i '/.*sdboot=if mmcinfo;.*/{n;d}' $WD/u-boot-digilent/include/configs/zynq-common.h
    sed -i '/.*load mmc 0 ${ramdisk_load_address} ${ramdisk_image} &&.*/{n;d}' $WD/u-boot-digilent/include/configs/zynq-common.h
    sed -i 's|.*load mmc 0 ${ramdisk_load_address} ${ramdisk_image} &&.*|\t\t\t"bootm ${kernel_load_address} - ${devicetree_load_address}; "\t\\|' $WD/u-boot-digilent/include/configs/zynq-common.h
else
    sed -i '/.*sdboot=if mmcinfo;.*/{n;d}' $WD/u-boot-digilent/include/configs/zynq-common.h
fi

make -j"$(nproc)" zynq_artyz7_defconfig
make -j"$(nproc)"


#
# [7] Build Linux kernel
#

cd $WD/linux-xlnx
git checkout -b wb "$GITTAG_LINUX"

make -j"$(nproc)" xilinx_zynq_defconfig

#~ # Make sure PCAP reconfiguration is enabled (DEVCFG) (from version
#~ # xilinx-v2017.1 this has been disabled to support new reconfiguration
#~ # managers). This edit comes here to patch xilinx_zynq_defconfig.
#~ sed -i '/.*DEVCFG.*/d' $WD/linux-xlnx/.config
#~ echo "CONFIG_XILINX_DEVCFG=y" >> $WD/linux-xlnx/.config

# Modifications in some of the device drivers for the fpga_manager framework need to be done
# to make partial reconfiguration work in Zynq-7000 devices.
sed -i 's|info->flags|mgr->flags|' $WD/linux-xlnx/drivers/fpga/zynq-fpga.c

# Increase available memory for Linux CMA (default in Zynq-7000 is 16MB)
#
# This is required to be able to perform full reconfiguration in the
# Zynq MMP board (full bitstream size ~17MB).
#
sed -i 's|.*CONFIG_CMA_SIZE_MBYTES.*|CONFIG_CMA_SIZE_MBYTES=128|' $WD/linux-xlnx/.config

# Modifications in some of the low-level files are required to avoid problems with Ethernet and DMA.
# See https://groups.google.com/forum/#!topic/reconos/ko-u2LnWL-I
#     https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=7a3cc2a7b2c723aa552028f4e66841cec183756d
#
# Already fixed (not in the v2017.1 tag):
#     https://github.com/Xilinx/linux-xlnx/commit/7c415150cdd61191bad4f5aeba38c22d875500c1
#
sed -i 's|.*memblock_reserve.*|\t\tmemblock_reserve(__pa(PAGE_OFFSET), 0x80000);|' $WD/linux-xlnx/arch/arm/mach-zynq/common.c

make -j"$(nproc)" uImage LOADADDR=0x00008000


#
# [8] Build Busybox
#

cd $WD/busybox
make -j"$(nproc)" defconfig

make -j"$(nproc)"
make -j"$(nproc)" install


#
# [9] Build Dropbear
#

cd $WD/dropbear

# Use autoconf to set everything up
autoconf
autoheader

# Automate configuration
./configure --host=arm-xilinx-linux-gnueabi --disable-zlib --disable-shadow CC="$CROSS_COMPILE"gcc STRIP="$CROSS_COMPILE"strip

# Build dropbear
make -j"$(nproc)" PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" MULTI=1 strip


#
# [10] Prepare rootfs
#

mkdir $WD/nfs
cd $WD/nfs

# Create directory structure
mkdir bin sbin usr usr/bin usr/sbin dev etc etc/init.d lib mnt opt opt/artico3 proc root sys tmp

# Install busybox
cp -r $WD/busybox/_install/* $WD/nfs/

# Install dropbear
cp $WD/dropbear/dropbearmulti $WD/nfs/usr/sbin/dropbear
cd $WD/nfs/usr/bin/
ln -s ../sbin/dropbear dbclient
ln -s ../sbin/dropbear ssh
ln -s ../sbin/dropbear dropbearkey
ln -s ../sbin/dropbear dropbearconvert
ln -s ../sbin/dropbear scp

# Install dynamic application linking support
cd $WD/nfs
# Depending on the toolchain used (glibc, uclibc-ng, etc.), not all
# the following elements might be present. This prevents the script
# from finishing early due to unexpected errors.
set +e
# Copy shared libraries and bin utilities
cp -R "$GCC_SYSROOT"/lib/* $WD/nfs/lib
cp -R "$GCC_SYSROOT"/sbin/* $WD/nfs/sbin
cp -R "$GCC_SYSROOT"/usr/bin/* $WD/nfs/usr/bin
cp -R "$GCC_SYSROOT"/usr/sbin/* $WD/nfs/usr/sbin
# Strip files (remove debugging info)
"$CROSS_COMPILE"strip lib/*
"$CROSS_COMPILE"strip sbin/*
"$CROSS_COMPILE"strip usr/bin/*
"$CROSS_COMPILE"strip usr/sbin/*
# Modify scripts to work with busybox shell (not bash)
sed -i 's|/bin/bash|/bin/sh|' $(grep -rl '/bin/bash' $WD/nfs/sbin/*)
sed -i 's|/bin/bash|/bin/sh|' $(grep -rl '/bin/bash' $WD/nfs/usr/bin/*)
sed -i 's|/bin/bash|/bin/sh|' $(grep -rl '/bin/bash' $WD/nfs/usr/sbin/*)
# Revert error response behavior
set -e

# Setup dropbear
#
# NOTE : when connecting to dropbear, some environment variables are not
#        properly set (e.g. PATH does not include /sbin or /usr/sbin).
#        This has to be fixed to provide full access to all capabilities
#        installed in the target platform.
#        In addition, the following code assumes that the root directory
#        is /root. However, Busybox's init sets HOME=/, which might lead
#        to errors when trying to log in.
#        Both issues are solved by creating a /etc/profile with basic
#        configuration rules (see a few lines below).
#
mkdir etc/dropbear

# Setup DHCP client
mkdir -p usr/share/udhcpc
cp $WD/busybox/examples/udhcp/simple.script usr/share/udhcpc/default.script

# Create directory for device tree overlays
mkdir -p lib/firmware/overlays

# Create global shell profile
cat > etc/profile << EOF
export HOME=/root
export PATH=/sbin:/usr/sbin:/bin:/usr/bin
EOF

# Create password file (required by dropbear)
cat > etc/passwd << EOF
root::0:0:root:/root:/bin/sh
EOF

# Create hostname
echo 'artico3' > etc/hostname

# Create dummy mdev configuration file
cat > etc/mdev.conf << EOF
#
# mdev.conf - Busybox's mdev configuration file
#
# Contains rules to:
#     1. Populate /dev when devtmpfs is not used (mdev -s)
#     2. Manage uevents, i.e. changes in sysfs   (echo /sbin/mdev > /proc/sys/kernel/hotplug)
#
# RULE FORMAT:
#
# [-][ENV=regex;]<device regex>       <uid>:<gid> <permissions> [>|=path]|[!] [@|$|*<command>]
# [-][ENV=regex;]@<maj[,min1[-min2]]> <uid>:<gid> <permissions> [>|=path]|[!] [@|$|*<command>]
# [-][ENV=regex;]\$envvar=<regex>      <uid>:<gid> <permissions> [>|=path]|[!] [@|$|*<command>]
#
# REFERENCE:
#     [*]        Optional argument
#     -          Continue parsing rules after match in this line
#     =path      Rename/move device node
#     >path      Rename/move device node + create direct symlink /dev/*
#     !          Prevent creation of device node
#     @<command> Run after creating the device
#     $<command> Run before removing the device
#     *<command> Run both after creating and before removing the device
#
# NOTES:
#     * [ENV=regex;] can match more than one environment variable.
#       e.g. -ACTION=add;SUBSYSTEM=platform;.* 0:0 660
#     * [>|=path] requires a trailing / to move devices to a directory.
#     * [>path] doesn't work well if devtmpfs is enabled (generates
#       duplicated entries instead of symbolic links).
#     * <uid>:<gid> needs to be set according to the current embedded
#       system configuration (0:0 for root:root in most cases).
#

# Enable module loading for hotplugged devices
\$MODALIAS=.* 0:0 660 @modprobe "\$MODALIAS"
EOF

# Create inittab file
cat > etc/inittab << EOF
::sysinit:/etc/init.d/rcS

# Start an askfirst shell on the serial ports
ttyPS0::respawn:-/bin/sh

# What to do when restarting the init process
::restart:/sbin/init

# What to do before rebooting
::shutdown:/bin/umount -a -r
EOF

# Create rcS initialization script
cat > etc/init.d/rcS << EOF
#!/bin/sh

echo "Starting rcS..."

echo "++ Mounting filesystems..."
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t tmpfs tmpfs /tmp
mount -t configfs config /sys/kernel/config
EOF

if [[ $ROOTFS = 3 ]]; then
    cat >> etc/init.d/rcS <<'EOF'
mount -t devtmpfs dev /dev
EOF
fi

cat >> etc/init.d/rcS <<'EOF'
mkdir -p /dev/pts
mount -t devpts devpts /dev/pts

echo "++ Starting system log..."
echo "" >> /opt/artico3/syslog
syslogd -O /opt/artico3/syslog
klogd -c 8

echo "++ Starting mdev..."
echo /sbin/mdev > /proc/sys/kernel/hotplug

echo "++ Starting dropbear..."
hostname -F /etc/hostname
dropbear -B -R

#echo "++ Starting udhcpc..."
#udhcpc -b -S

echo "++ Loading DMA proxy driver..."
/opt/artico3/artico3_init.sh
modprobe mdmaproxy

echo "++ Loading ARTICo3 device tree overlay..."
mkdir /sys/kernel/config/device-tree/overlays/artico3
echo overlays/artico3.dtbo > /sys/kernel/config/device-tree/overlays/artico3/path

echo "rcS Complete"
EOF

chmod +x etc/init.d/rcS

# Create init entry in /
ln -s bin/busybox init

# Export NFS
if [[ $ROOTFS = 1 ]]; then
    printf "Please provide root access to export NFS share!\n"
    sudo -H bash -c "sed -i '/.*$BOARDIP.*/d' /etc/exports"
    sudo -H bash -c "cat >> /etc/exports << EOF
$WD/nfs/ $BOARDIP(rw,no_subtree_check,all_squash,anonuid=$(id -u),anongid=$(id -g))
EOF"
    sudo -H exportfs -ar
fi


#
# [11] Set up ARTICo3 system
#

# TODO: modify this to avoid private repository + move to step [4]
cd $WD
git clone https://alfonsorm@bitbucket.org/alfonsorm/artico3
cd $WD/artico3

# Build ARTICo3 Linux kernel modules
cd $WD/artico3/linux/drivers/dmaproxy
make -j"$(nproc)" PREFIX=$WD/nfs/opt/artico3 install

# Compile ARTICo3 device tree overlay
cat >> $WD/nfs/lib/firmware/overlays/artico3.dts << EOF
/dts-v1/;
/plugin/;

/ {
    fragment@0 {
        target = <&amba_pl>;
        __overlay__ {
            artico3_shuffler_0: artico3_shuffler@7aa00000 {
                compatible = "cei.upm,artico3-shuffler-1.0", "generic-uio";
                interrupt-parent = <&intc>;
                interrupts = <0 29 1>;
                reg = <0x7aa00000 0x100000>;
            };
            artico3_slots_0: artico3_slots@8aa00000 {
                compatible = "cei.upm,proxy-cdma-1.00.a";
                reg = <0x8aa00000 0x100000>;
                dmas = <&dmac_s 0>;
                dma-names = "ps-dma";
            };
        };
    };
};
EOF
dtc -I dts -O dtb -@ -o $WD/nfs/lib/firmware/overlays/artico3.dtbo $WD/nfs/lib/firmware/overlays/artico3.dts

# Create script to move kernel module to /lib/modules/...
cat >> $WD/nfs/opt/artico3/artico3_init.sh << EOF
mkdir -p /lib/modules/\$(uname -r)
mv /opt/artico3/mdmaproxy.ko /lib/modules/\$(uname -r)
modprobe mdmaproxy
modprobe -r mdmaproxy
sed -i '/.*artico3_init.sh.*/d' /etc/init.d/rcS
rm -f /opt/artico3/artico3_init.sh
EOF
chmod +x $WD/nfs/opt/artico3/artico3_init.sh


#
# [12] Prepare SD card
#

mkdir $WD/sdcard

cp $WD/u-boot-digilent/spl/boot.bin $WD/sdcard/
cp $WD/u-boot-digilent/u-boot.img $WD/sdcard/
cp $WD/linux-xlnx/arch/arm/boot/uImage $WD/sdcard/
cp $WD/devicetree/pynq/dts/devicetree.dtb $WD/sdcard/


#
# [13] Create rootfs image (initrd / initramfs)
#

if [[ $ROOTFS = 2 ]]; then
    mkdir $WD/ramdisk
    cd $WD/ramdisk
    dd if=/dev/zero of=ramdisk.image bs=1024 count=16384
    mke2fs -F ramdisk.image -L "ramdisk" -b 1024 -m 0
    tune2fs ramdisk.image -i 0
    chmod a+rwx ramdisk.image
    mkdir $WD/ramdisk/mnt/
    printf "Please provide root access to mount ramdisk image!\n"
    sudo -H mount -o loop ramdisk.image $WD/ramdisk/mnt/

    sudo -H cp -r $WD/nfs/* $WD/ramdisk/mnt/
    sudo -H umount $WD/ramdisk/mnt/
    gzip $WD/ramdisk/ramdisk.image
    mkimage -A arm -T ramdisk -C gzip -d $WD/ramdisk/ramdisk.image.gz $WD/ramdisk/uramdisk.image.gz
    cp $WD/ramdisk/uramdisk.image.gz $WD/sdcard/
fi

if [[ $ROOTFS = 3 ]]; then
    mkdir $WD/initramfs
    cd $WD/nfs
    find . | cpio -H newc -o > $WD/initramfs/initramfs.cpio
    cat $WD/initramfs/initramfs.cpio | gzip > $WD/initramfs/initramfs.cpio.gz
    mkimage -A arm -T ramdisk -C gzip -d $WD/initramfs/initramfs.cpio.gz $WD/initramfs/uramdisk.image.gz
    cp $WD/initramfs/uramdisk.image.gz $WD/sdcard/
fi


#
# [14] Final steps
#

printf "ARTICo3 has been installed successfully.\n\n"
printf "Please execute the following post-installation steps:\n"
printf "* Format a SD card as FAT32 with boot flag set.\n"
printf "* Copy content from $WD/sdcard/ to the SD card and insert in Pynq board.\n"
printf "* Set boot mode to SD using jumper JP4.\n"
if [[ $ROOTFS = 1 ]]; then
  printf "* Set the IP address of the host PC to $HOSTIP.\n"
fi
printf "* Turn on the board, connect with UART.\n"
printf "* If 'Zynq> ' prompt appears type 'boot' followed by 'Enter'.\n\n"
printf "The Linux prompt '#\ ' will appear.\n"
