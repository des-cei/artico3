"""
ARTICo\u00b3 Development Kit

Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
Date        : August 2017
Description : Main application loop.

"""

import sys
import pkgutil
import importlib
import readline
import argparse
import logging
import artico3
import artico3.scripts

import artico3.runtime.project as project

logging.basicConfig(format="[artico3-toolchain] <%(name)s> %(levelname)s: %(message)s")
log = logging.getLogger(__name__)

def main():

    # TODO: load project configuration
    prj = project.Project()
    prj.load("build.cfg")

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
        "warning", "error"], default="warning")
    subparsers = parser.add_subparsers(title="commands", dest="cmd")
    for cmd,attr in cmds.items():
        c = subparsers.add_parser(cmd, add_help=False, parents=[attr[1]])
        c.set_defaults(func=attr[0])

    args = parser.parse_args()

    if args.log == "debug":
        logging.getLogger().setLevel(level=logging.DEBUG)
    elif args.log == "warning":
        logging.getLogger().setLevel(level=logging.WARNING)
    else:
        logging.getLogger().setLevel(level=logging.ERROR)

    if args.cmd == None:
        def _complete(text, state):
            if " " in readline.get_line_buffer():
                return None
            comp = [_ + " " for _ in cmds.keys() if _.startswith(text)]
            return comp[state] if state < len(comp) else None
            
        readline.parse_and_bind("tab: complete")
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
                except Exception:
                    log.error("Executing command '" + usr + "' failed")
            else:
                print("Command not found")

    else:
        args.func(args)
