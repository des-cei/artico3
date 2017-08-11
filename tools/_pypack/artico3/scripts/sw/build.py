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
    return parser

def build_cmd(args):
    build(args)

def build(args):
    prj = args.prj
    swdir = prj.basedir + ".sw"

    try:
        shutil2.chdir(swdir)
    except:
        log.error("software directory '" + swdir + "' not found")
        return

    subprocess.run("""
        bash -c "export CROSS_COMPILE=/opt/Xilinx/SDK/{0}/gnu/arm/lin/bin/arm-xilinx-linux-gnueabi- &&
        make"
        """.format(prj.impl.xil[1]), shell=True, check=True)

    print()
    shutil2.chdir(prj.dir)
