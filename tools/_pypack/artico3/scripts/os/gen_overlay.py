"""
------------------------------------------------------------------------

ARTICo\u00b3 Development Kit

Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
Date        : November 2017
Description : Command - parses and compiles device tree overlay.

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
    return "gen_overlay"

def get_call(prj):
    return gen_overlay_cmd

def get_parser(prj):
    parser = argparse.ArgumentParser("gen_overlay", description="""
        Parses and compiles the ARTICo3 device tree overlay.
        """)
    parser.add_argument("-l", "--link", help="link sources instead of copying", default=False, action="store_true")
    parser.add_argument("dtcdir", help="Device Tree Compiler path", nargs="?")
    parser.add_argument("outdir", help="alternative export directory", nargs="?")
    return parser

def gen_overlay_cmd(args):
    gen_overlay(args, args.dtcdir, args.outdir, args.link)

def gen_overlay(args, dtcdir, outdir, link):
    prj = args.prj
    if dtcdir is None:
        log.error("Device Tree Compiler must be specified")
        return
    outdir = outdir if outdir is not None else prj.basedir + ".os"
    shutil2.mkdir(outdir)
    outdir = outdir + "/overlay"

    log.info("Generate device tree overlay in project directory '" + prj.dir + "'")

    dictionary = {}
    dictionary["DEVICE"] = "zynqmp" if "xczu" in prj.impl.part else "zynq"

    log.info("Exporting device tree overlay...")
    prj.apply_template("artico3_devicetree_overlay", dictionary, outdir, link)

    log.info("Building device tree overlay...")
    shutil2.chdir(outdir)
    subprocess.run("""
        bash -c "{0}/dtc -I dts -O dtb -@ -o artico3.dtbo artico3.dts"
        """.format(dtcdir), shell=True, check=True)

    print()
    shutil2.chdir(prj.dir)
