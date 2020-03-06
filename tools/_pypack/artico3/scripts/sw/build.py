"""
------------------------------------------------------------------------

ARTICo\u00b3 Development Kit

Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
Date        : August 2017
Description : Command - builds software application.

------------------------------------------------------------------------

The following code is a derivative work of the code from the ReconOS
project, which is licensed GPLv2. This code therefore is also licensed
under the terms of the GNU Public License, version 2.

------------------------------------------------------------------------
"""

import argparse
import subprocess
import logging

import artico3.utils.shutil2 as shutil2
import artico3.utils.template as template

log = logging.getLogger(__name__)

def get_cmd(prj):
    return "build_sw"

def get_call(prj):
    return build_cmd

def get_parser(prj):
    parser = argparse.ArgumentParser("build_sw", description="""
        Builds the software project and generates an executable.
        """)
    parser.add_argument("-d", "--debug", help="compile runtime with debug capability", default=False, action="store_true")
    parser.add_argument("--dynamic", help="enable dynamic linking, default is static", default=False, action="store_true")
    parser.add_argument("-c", "--cross", help="use external cross compiler instead of Xilinx's", default="")
    parser.add_argument("--busy-wait", help="use busy-wait instead of interrupt-based management in runtime library", default=False, action="store_true", dest="busy")
    return parser

def build_cmd(args):
    build(args, args.cross, args.dynamic, args.debug, args.busy)

def build(args, cross, dynamic, debug, busy):
    prj = args.prj
    swdir = prj.basedir + ".sw"

    try:
        shutil2.chdir(swdir)
    except:
        log.error("software directory '" + swdir + "' not found")
        return

    if cross == "":
        if "xczu" in prj.impl.part:
            cc = "/opt/Xilinx/SDK/{0}/gnu/aarch64/lin/aarch64-linux/bin/aarch64-linux-gnu-".format(prj.impl.xil[1])
        else:
            #~ cc = "/opt/Xilinx/SDK/{0}/gnu/arm/lin/bin/arm-xilinx-linux-gnueabi-".format(prj.impl.xil[1])
            cc = "/opt/Xilinx/SDK/{0}/gnu/aarch32/lin/gcc-arm-linux-gnueabi/bin/arm-linux-gnueabihf-".format(prj.impl.xil[1])
    else:
        cc = cross

    if dynamic:
        target = "shared"
    else:
        target = "static"

    if debug:
        target = target + "_dbg"

    if busy:
        cflags = "-DA3_BUSY_WAIT"
    else:
        cflags = ""

    subprocess.run("""
        bash -c "export CROSS_COMPILE={0} &&
        export CFLAGS_A3={1} &&
        make {2}"
        """.format(cc, cflags, target), shell=True, check=True)

    print()
    shutil2.chdir(prj.dir)
