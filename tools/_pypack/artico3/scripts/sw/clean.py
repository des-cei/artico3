"""
------------------------------------------------------------------------

ARTICo\u00b3 Development Kit

Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
Date        : August 2017
Description : Command - cleans software application.

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
    return "clean_sw"

def get_call(prj):
    return clean_cmd

def get_parser(prj):
    parser = argparse.ArgumentParser("clean_sw", description="""
        Cleans the software project.
        """)
    parser.add_argument("-r", "--remove", help="remove entire software directory", action="store_true")
    return parser

def clean_cmd(args):
    clean(args)

def clean(args):
    prj = args.prj
    swdir = prj.basedir + ".sw"

    if args.remove:
        shutil2.rmtree(swdir)
    else:
        try:
            shutil2.chdir(swdir)
        except:
            log.error("software directory '" + swdir + "' not found")
            return

        subprocess.run("""
            bash -c "export CROSS_COMPILE=/opt/Xilinx/SDK/{0}/gnu/arm/lin/bin/arm-xilinx-linux-gnueabi- &&
            make clean"
            """.format(prj.impl.xil[1]), shell=True, check=True)


        print()
        shutil2.chdir(prj.dir)
