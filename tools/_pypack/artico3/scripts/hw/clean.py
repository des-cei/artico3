"""
------------------------------------------------------------------------

ARTICo\u00b3 Development Kit

Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
Date        : August 2017
Description : Command - cleans Vivado design.

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
    return "clean_hw"

def get_call(prj):
    return clean_cmd

def get_parser(prj):
    parser = argparse.ArgumentParser("clean_hw", description="""
        Cleans the hardware project.
        """)
    parser.add_argument("-r", "--remove", help="remove entire hardware directory", action="store_true")
    return parser

def clean_cmd(args):
    clean(args)

def clean(args):
    if args.prj.impl.xil[0] == "vivado":
        _clean(args)
    else:
        log.error("Tool not supported")

def _clean(args):
    prj = args.prj
    hwdir = prj.basedir + ".hw"

    if args.remove:
        shutil2.rmtree(hwdir)
    else:
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
            vivado -mode batch -notrace -nojournal -nolog -source clean.tcl"
            """.format(prj.impl.xil[1]), shell=True, check=True)

        print()
        shutil2.chdir(prj.dir)
