"""
------------------------------------------------------------------------

ARTICo\u00b3 Development Kit

Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
Date        : November 2017
Description : Command - cleans OS files (driver and device tree overlay).

------------------------------------------------------------------------

The following code is a derivative work of the code from the ReconOS
project, which is licensed GPLv2. This code therefore is also licensed
under the terms of the GNU Public License, version 2.

------------------------------------------------------------------------
"""

import argparse
import logging

import artico3.utils.shutil2 as shutil2
import artico3.utils.template as template

log = logging.getLogger(__name__)

def get_cmd(prj):
    return "clean_os"

def get_call(prj):
    return clean_os_cmd

def get_parser(prj):
    parser = argparse.ArgumentParser("clean_os", description="""
        cleans OS files (driver and device tree overlay).
        """)
    return parser

def clean_os_cmd(args):
    clean_os(args)

def clean_os(args):
    prj = args.prj
    outdir = prj.basedir + ".os"
    shutil2.rmtree(outdir)
