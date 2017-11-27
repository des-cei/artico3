"""
------------------------------------------------------------------------

ARTICo\u00b3 Development Kit

Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
Date        : November 2017
Description : Command - builds ARTICo3 Linux kernel driver.

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
    return "gen_driver"

def get_call(prj):
    return gen_driver_cmd

def get_parser(prj):
    parser = argparse.ArgumentParser("gen_driver", description="""
        Builds ARTICo3 Linux kernel driver.
        """)
    parser.add_argument("-l", "--link", help="link sources instead of copying", default=False, action="store_true")
    parser.add_argument("-c", "--cross", help="use external cross compiler instead of Xilinx's", default="")
    parser.add_argument("kdir", help="Linux kernel source path", nargs="?")
    parser.add_argument("outdir", help="alternative export directory", nargs="?")
    return parser

def gen_driver_cmd(args):
    gen_driver(args, args.kdir, args.outdir, args.link, args.cross)

def gen_driver(args, kdir, outdir, link, cross):
    prj = args.prj
    if kdir is None:
        log.error("Linux kernel source path must be specified")
        return
    outdir = outdir if outdir is not None else prj.basedir + ".os"
    shutil2.mkdir(outdir)
    outdir = outdir + "/driver"

    log.info("Generate Linux driver in project directory '" + prj.dir + "'")

    dictionary = {}

    log.info("Exporting Linux driver...")
    prj.apply_template("artico3_driver_linux", dictionary, outdir, link)

    log.info("Building Linux driver...")

    if cross == "":
        if "xczu" in prj.impl.part:
            cc = "/opt/Xilinx/SDK/{0}/gnu/aarch64/lin/aarch64-linux/bin/aarch64-linux-gnu-".format(prj.impl.xil[1])
        else:
            cc = "/opt/Xilinx/SDK/{0}/gnu/arm/lin/bin/arm-xilinx-linux-gnueabi-".format(prj.impl.xil[1])
    else:
        cc = cross

    if "xczu" in prj.impl.part:
        arch = "arm64"
    else:
        arch = "arm"

    shutil2.chdir(outdir)

    subprocess.run("""
        bash -c "export CROSS_COMPILE={0} &&
        export ARCH={1} &&
        export KDIR={2} &&
        make"
        """.format(cc, arch, kdir), shell=True, check=True)

    print()
    shutil2.chdir(prj.dir)
