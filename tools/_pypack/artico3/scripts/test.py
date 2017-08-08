import logging
import argparse
import subprocess

log = logging.getLogger(__name__)

def get_cmd(prj):
    return "test"

def get_call(prj):
    return test_cmd

def get_parser(prj):
    parser = argparse.ArgumentParser(prog="test", description="""
        Test application functionality""")
    parser.add_argument("-t", "--tag", help="prints the tag")
    return parser

def test_cmd(args):
        
    log.debug("test_cmd() [ ]")

    print(type(args), args)
    if args.tag: print("TAG:", args.tag)

    # NOTE: for some reason, using the subprocess module as in the
    #       original RDK does not work (does not recognize source and,
    #       therefore, Vivado is not started).
    subprocess.run("""
        bash -c "source /opt/Xilinx/Vivado/2017.1/settings64.sh && 
        cd /home/alfonso/workspace &&
        vivado -mode tcl -notrace -nojournal -nolog"
        """, shell=True, check=True)
               
    log.debug("test_cmd() [+]")
    
