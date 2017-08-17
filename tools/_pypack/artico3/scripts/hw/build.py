"""
------------------------------------------------------------------------

ARTICo\u00b3 Development Kit

Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
Date        : August 2017
Description : Command - builds FPGA bitstream from Vivado design.

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

log = logging.getLogger(__name__)

def get_cmd(prj):
    return "build_hw"

def get_call(prj):
    return build_cmd

def get_parser(prj):
    parser = argparse.ArgumentParser("build_hw", description="""
        Builds the hardware project and generates a bitstream to
        be downloaded to the FPGA.
        """)
    parser.add_argument("hwdir", help="alternative export directory", nargs="?")
    return parser

def build_cmd(args):
    build(args.prj, args.hwdir)

def build(prj, hwdir):
    if prj.impl.xil[0] == "vivado":
        _build(prj, hwdir)
    else:
        log.error("Tool not supported")

def _build(prj, hwdir):
    hwdir = hwdir if hwdir is not None else prj.basedir + ".hw"
    try:
        shutil2.chdir(hwdir)
    except:
        log.error("hardware directory '" + hwdir + "' not found")
        return

    # NOTE: for some reason, using the subprocess module as in the
    #       original RDK does not work (does not recognize source and,
    #       therefore, Vivado is not started).
    subprocess.run("""
        bash -c "source /opt/Xilinx/Vivado/{0}/settings64.sh &&
        vivado -mode batch -notrace -nojournal -nolog -source build.tcl"
        """.format(prj.impl.xil[1]), shell=True, check=True)

    print()
    shutil2.chdir(prj.dir)
