"""
------------------------------------------------------------------------

ARTICo\u00b3 Development Kit

Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
Date        : August 2017
Description : Command - shows project info.

------------------------------------------------------------------------

The following code is a derivative work of the code from the ReconOS
project, which is licensed GPLv2. This code therefore is also licensed
under the terms of the GNU Public License, version 2.

------------------------------------------------------------------------
"""

import argparse
import logging

log = logging.getLogger(__name__)

def get_cmd(prj):
    return "info"

def get_call(prj):
    return info_cmd

def get_parser(prj):
    parser = argparse.ArgumentParser("info", description="""
        Prints information regarding the active project.
        """)
    return parser

def info_cmd(args):
    info(args)

def info(args):
    prj = args.prj
    print("-" * 40)
    print("ARTICo\u00b3 Project '" + prj.name + "'")
    print("  Board".ljust(20) + str(",".join(prj.impl.board)))
    print("  Reference Design".ljust(20) + prj.impl.design)
    print("  Part".ljust(20) + prj.impl.part)
    print("  Operating System".ljust(20) + prj.impl.os)
    print("  Xilinx Tools".ljust(20) + ",".join(prj.impl.xil))
    print("  CFlags".ljust(20) + prj.impl.cflags)
    print("  LdFlags".ljust(20) + prj.impl.ldflags)
    print("-" * 40)
    print("Shuffler:")
    print("  Slots".ljust(20) + str(prj.shuffler.slots))
    print("  Pipeline Stages".ljust(20) + str(prj.shuffler.stages))
    print("  Clock Buffers".ljust(20) + prj.shuffler.clkbuf)
    print("  Reset Buffers".ljust(20) + prj.shuffler.rstbuf)
    print("-" * 40)
    print("Kernels:")
    for kernel in prj.kerns:
        print(kernel)
    print("-" * 40)
    print("Slots:")
    for slot in prj.slots:
        print(slot)
    print("-" * 40)
