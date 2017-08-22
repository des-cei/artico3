"""
------------------------------------------------------------------------

ARTICo\u00b3 Development Kit

Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
Date        : August 2017
Description : Device specific definitions (low-level constraints).


In order to add new devices, users have to create a new dictionary entry
with the following data:

  slots      : number of reconfigurable slots available in this device

  pipe_depth : number of pipeline stages in the ARTICo3 infrastructure
               (between Shuffler and accelerators, used to avoid timing
               issues).

  clk_buffer : type of hardware primitive to use as clock buffers
                   none       (disables clock gating features)
                   global     (use global FPGA buffers)
                   horizontal (use local buffers per clock region)

  rst_buffer : type of hardware primitive to use as reset buffers
                   none
                   global     (use global FPGA buffers)
                   horizontal (use local buffers per clock region)

In addition, users need to provide an XDC file with all low-level
constraints required to build the system. This file has to be placed in
templates/a3_devices, and has to be named <part>.xdc being <part> the
dictionary entry name (fpgas["<part>"] = dev).

------------------------------------------------------------------------
"""

# Global dictionary with device info/data
fpgas = {}


# xc7z020 (Pynq, ZedBoard, MicroZed)
dev = {}
dev["slots"] = 4
dev["pipe_depth"] = 3
dev["clk_buffer"] = "horizontal"
dev["rst_buffer"] = "global"
fpgas["xc7z020"] = dev

""" ADD ADDITIONAL DEVICES HERE """
