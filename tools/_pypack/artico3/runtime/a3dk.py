"""
------------------------------------------------------------------------

ARTICo\u00b3 Development Kit

Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
Date        : August 2017
Description : Main application loop.

------------------------------------------------------------------------

The following code is a derivative work of the code from the ReconOS
project, which is licensed GPLv2. This code therefore is also licensed
under the terms of the GNU Public License, version 2.

Author      : Christoph Rüthing, University of Paderborn

------------------------------------------------------------------------
"""

import sys
import pkgutil
import importlib
import readline
import os
import glob
import argparse
import logging

import artico3
import artico3.scripts
import artico3.runtime.project as project
import artico3.utils.shutil2 as shutil2

logging.basicConfig(format="[artico3-toolchain] <%(name)s> %(levelname)s: %(message)s")
log = logging.getLogger(__name__)

def main():

    prj = project.Project()
    pkgs = pkgutil.walk_packages(artico3.scripts.__path__, artico3.scripts.__name__ + ".")
    cmds = {}
    for m in [importlib.import_module(m) for f,m,p in pkgs if not p]:
        try:
            if getattr(m, "get_cmd")(None) is not None:
                cmd = getattr(m, "get_cmd")(prj)
                call = getattr(m, "get_call")(prj)
                parser = getattr(m, "get_parser")(prj)
                parser.set_defaults(prj=prj)
                cmds[cmd] = (call, parser)
        except AttributeError:
            log.warning("Could not import Module " + str(m))

    parser = argparse.ArgumentParser(prog="a3dk", description="""
        ARTICo3 Development Kit - Script-based toolchain to implement
        dynamically and partially reconfigurable systems with explicit
        task- and data-level parallelism.""")
    parser.add_argument("-l", "--log", help="log level", choices=["debug",
        "info", "warning", "error"], default="warning")
    subparsers = parser.add_subparsers(title="commands", dest="cmd")
    for cmd,attr in cmds.items():
        c = subparsers.add_parser(cmd, add_help=False, parents=[attr[1]])
        c.set_defaults(func=attr[0])
    args = parser.parse_args()

    if args.log == "debug":
        logging.getLogger().setLevel(level=logging.DEBUG)
    elif args.log == "info":
        logging.getLogger().setLevel(level=logging.INFO)
    elif args.log == "warning":
        logging.getLogger().setLevel(level=logging.WARNING)
    else:
        logging.getLogger().setLevel(level=logging.ERROR)

    prjfiles = shutil2.listfiles(".", ext="cfg$", rel=True)
    if not prjfiles:
        log.error("Project file not found")
        sys.exit(1)
    elif len(prjfiles) > 1:
        print("Multiple project files found. Please select:")
        for i,f in enumerate(prjfiles):
            print("  [" + str(i) + "] " + f)
        try:
            prjfile = prjfiles[int(input("File? "))]
        except:
            print("Applying [0] as default configuration")
            prjfile = prjfiles[0]
        print("Selected '" + prjfile + "'")
    else:
        prjfile = prjfiles[0]
    prj.load(prjfile)

    if args.cmd == None:

        def _complete(text, state):
            if " " in readline.get_line_buffer():
                #~ return None
                return ([f + "/" if os.path.isdir(f) else f for f in glob.glob(text + "*")]  + [None])[state]
            comp = [_ + " " for _ in cmds.keys() if _.startswith(text)]
            return comp[state] if state < len(comp) else None

        readline.parse_and_bind("tab: complete")
        readline.set_completer_delims(' \t\n;')
        readline.set_completer(_complete)

        while True:
            try:
                usr = input("ARTICo\u00b3 Development Kit> ")
            except KeyboardInterrupt:
                print()
                continue
            except EOFError:
                print()
                sys.exit(0)

            if usr == "":
                continue

            if usr in ("exit",):
                sys.exit(0)

            cmd = usr.split()[0]
            if cmd in cmds.keys():
                cmd = cmds[cmd]
                try:
                    cmd[0](cmd[1].parse_args(usr.split()[1:]))
                except SystemExit:
                    pass
                except Exception as ex:
                    print(ex.args)
                    log.error("Executing command '" + usr + "' failed")
            else:
                print("Command not found")

    else:
        args.func(args)
