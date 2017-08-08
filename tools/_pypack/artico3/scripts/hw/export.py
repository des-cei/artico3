import argparse
import logging

log = logging.getLogger(__name__)

def get_cmd(prj):
    return "export_hw"

def get_call(prj):
    return export_hw_cmd

def get_parser(prj):
    parser = argparse.ArgumentParser(prog="export_hw", description="""
        Exports the hardware project and generates all necessary files.
        """)
    parser.add_argument("-l", "--link", help="link sources instead of copying", action="store_true")
    parser.add_argument("-t", "--thread", help="export only single thread")
    parser.add_argument("hwdir", help="alternative export directory", nargs="?")
    return parser

def export_hw_cmd(args):
    log.info("export_hw_cmd({})".format(args))
