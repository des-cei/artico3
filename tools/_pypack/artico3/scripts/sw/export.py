"""
------------------------------------------------------------------------

ARTICo\u00b3 Development Kit

Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
Date        : August 2017
Description : Command - exports and parses software application.

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
    return "export_sw"

def get_call(prj):
    return export_sw_cmd

def get_parser(prj):
    parser = argparse.ArgumentParser("export_hw", description="""
        Exports the software project and generates all necessary files.
        """)
    parser.add_argument("-l", "--link", help="link sources instead of copying", default=False, action="store_true")
    parser.add_argument("-d", "--debug", help="compile runtime with debug capability", default=False, action="store_true")
    parser.add_argument("swdir", help="alternative export directory", nargs="?")
    return parser

def export_sw_cmd(args):
    export_sw(args, args.swdir, args.link)

def export_sw(args, swdir, link):
    prj = args.prj
    swdir = swdir if swdir is not None else prj.basedir + ".sw"

    log.info("Export software to project directory '" + prj.dir + "'")

    dictionary = {}
    dictionary["NAME"] = prj.name.lower()
    if args.debug:
        dictionary["CFLAGS"] = prj.impl.cflags + " -DA3_DEBUG"
    else:
        dictionary["CFLAGS"] = prj.impl.cflags
    dictionary["LDFLAGS"] = prj.impl.ldflags

    dictionary["NUM_SLOTS"] = prj.shuffler.slots
    dictionary["DEVICE"] = "zynqmp" if "xczu" in prj.impl.part else "zynq"

    srcs = shutil2.join(prj.dir, "src", "application")
    dictionary["SOURCES"] = [srcs]

    log.info("Generating export files ...")
    templ = "artico3_app_" + prj.impl.os
    prj.apply_template(templ, dictionary, swdir, link)

    dictionary = {}
    dictionary["REPO_REL"] = shutil2.relpath(prj.impl.repo, swdir)
    dictionary["OBJS"] = [{"Source": shutil2.trimext(_) + ".o"}
                           for _ in shutil2.listfiles(swdir, True, "c[p]*$")]

    template.preproc(shutil2.join(swdir, "Makefile"), dictionary, "overwrite", force=True)
