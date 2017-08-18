"""
------------------------------------------------------------------------

ARTICo\u00b3 Development Kit

Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
Date        : August 2017
Description : Current project info utilities.

------------------------------------------------------------------------

The following code is a derivative work of the code from the ReconOS
project, which is licensed GPLv2. This code therefore is also licensed
under the terms of the GNU Public License, version 2.

Author      : Christoph Rüthing, University of Paderborn

------------------------------------------------------------------------
"""

import math
import sys
import re
import configparser
import logging

import artico3.utils.shutil2 as shutil2
import artico3.utils.template as template

log = logging.getLogger(__name__)

class Shuffler:
    """Class to store information of the ARTICo\u00b3 infrastructure."""

    def __init__(self):
        self.slots = 0
        self.stages = 0
        self.clkbuf = "none"
        self.rstbuf = "none"

    def __repr__(self):
        msg = ("<ARTICo\u00b3 Shuffler> "
               "slots={},pipeline_stages={},clock_buffers={},"
               "reset_buffers={}")
        return msg.format(self.slots, self.stages, self.clkbuf,
            self.rstbuf)

class Slot:
    """Class to store information of an ARTICo\u00b3 slot."""

    _id = 0

    def __init__(self):
        self.kerns = []
        self.id = Slot._id
        Slot._id += 1
        pass

    def __repr__(self):
        msg = ("<ARTICo\u00b3 Slot> id={},kernels={}")
        return msg.format(self.id, self.kerns)

class Kernel:
    """Class to store information of an ARTICo\u00b3 kernel."""

    def __init__(self, name, hwsrc, membytes, membanks, regrw, regro, rstpol):
        self.name, self.hwsrc = name, hwsrc
        self.membytes, self.membanks = membytes, membanks
        self.regrw, self.regro = regrw, regro
        self.rstpol = rstpol
        pass

    def __repr__(self):
        msg = ("<ARTICo\u00b3 Kernel> "
               "name={},hwsrc={},mem=({},{}),reg=({},{})")
        return msg.format(self.name, self.hwsrc, self.membytes,
            self.membanks, self.regrw, self.regro)

    def get_corename(self):
        return "a3_" + self.name.lower()

    def get_coreversion(self):
        return "1.00.a"

class Implementation:
    """Class to store implementation-specific details of the system."""

    def __init__(self):
        self.repo = ""

        self.board = ""
        self.part = ""
        self.design = ""
        self.xil = ""

        self.os = ""
        self.cflags = ""
        self.ldflags = ""

    def __repr__(self):
        msg = ("<ARTICo\u00b3 Impl.> "
               "repo={},board={},part={},template={},tool={},os={},"
               "cflags={},ldflags={}")
        return msg.format(self.repo, self.board, self.part, self.design,
            self.xil, self.os, self.cflags, self.ldflags)

class Project:
    """Main class of an ARTICo\u00b3-based project. Contains all the
    required information regarding system configuration."""

    def __init__(self, repo = None):
        self.kerns = []
        self.slots = []
        self.shuffler = Shuffler()
        self.impl = Implementation()

        self.name = ""
        self.file = ""
        self.dir = ""
        self.basedir = ""

        if repo is not None and shutil2.isdir(repo):
            self.impl.repo = repo
        elif shutil2.environ("ARTICo3"):
            self.impl.repo = shutil2.environ("ARTICo3")
        else:
            log.error("ARTICo\u00b33 repository not found")

    def __repr__(self):
        return "<ARTICo\u00b3 Project> name={}".format(self.name)

    def get_template(self, name):
        """Get template name from filesystem (first local, then repo)."""

        if shutil2.exists(shutil2.join(self.dir, "templates", name)):
            return shutil2.join(self.dir, "templates", name)
        else:
            return shutil2.join(self.impl.repo, "templates", name)

    def apply_template(self, name, dictionary, output, link = False):
        """Copy template files and generate source files by parsing."""

        shutil2.mkdir(output)
        shutil2.copytree(self.get_template(name), output, followlinks=True)
        template.generate(output, dictionary, "overwrite", link)

    def load(self, filepath):
        """Loads project info from configuration (.cfg) file."""

        Slot._id = 0

        self.kerns = []
        self.slots = []

        self.file = shutil2.abspath(filepath)
        self.dir = shutil2.dirname(self.file)
        self.basedir = shutil2.trimext(self.file)

        cfg = configparser.RawConfigParser()
        cfg.optionxform = str
        ret = cfg.read(filepath)
        if not ret:
            log.error("Config file '" + filepath + "' not found")
            return

        self._parse_project(cfg)
        self._check_project()

    def _parse_project(self, cfg):
        """Parses project configuration."""

        self.name = cfg.get("General", "Name")

        self.impl.board = re.split(r"[, ]+", cfg.get("General", "TargetBoard"))
        self.impl.part = cfg.get("General", "TargetPart")
        self.impl.design = cfg.get("General", "ReferenceDesign")
        self.impl.xil = re.split(r"[, ]+", cfg.get("General", "TargetXil"))

        self.impl.os = cfg.get("General", "TargetOS")
        if cfg.has_option("General", "CFlags"):
            self.impl.cflags = cfg.get("General", "CFlags")
        else:
            self.impl.cflags = ""
        if cfg.has_option("General", "LdFlags"):
            self.impl.ldflags = cfg.get("General", "LdFlags")
        else:
            self.impl.ldflags = ""

        log.debug(str(self))
        log.debug(str(self.impl))

        self._parse_shuffler(cfg)
        self._parse_kernels(cfg)

    def _parse_shuffler(self, cfg):
        """Parses ARTICo\u00b3 Shuffler configuration."""

        if cfg.has_option("ARTICo3", "Slots"):
            self.shuffler.slots = int(cfg.get("ARTICo3", "Slots"))
        else:
            log.warning("Number of ARTICo\u00b3 slots not specified, using 3")
            self.shuffler.slots = 3
        if cfg.has_option("ARTICo3", "PipelineStages"):
            self.shuffler.stages = int(cfg.get("ARTICo3", "PipelineStages"))
        else:
            self.shuffler.stages = 0
        if cfg.has_option("ARTICo3", "ClockBuffers"):
            self.shuffler.clkbuf = cfg.get("ARTICo3", "ClockBuffers")
        else:
            self.shuffler.clkbuf = "none"
        if cfg.has_option("ARTICo3", "ResetBuffers"):
            self.shuffler.rstbuf = cfg.get("ARTICo3", "ResetBuffers")
        else:
            self.shuffler.rstbuf = "none"

        log.debug(str(self.shuffler))

    def _parse_kernels(self, cfg):
        """Parses ARTICo\u00b3 kernels."""

        for kernel in [_ for _ in cfg.sections() if _.startswith("A3Kernel")]:
            match = re.search(r"^.*@(?P<name>.+)", kernel)
            if match is None:
                log.error("ARTICo\u00b3 accelerators must have a name")

            name = match.group("name")

            if cfg.has_option(kernel, "Replicas"):
                replicas = int(cfg.get(kernel, "Replicas"))
            else:
                log.warning("Number of replicas not specified, assuming 1")
                replicas = 1

            if cfg.has_option(kernel, "HwSource"):
                hwsrc = cfg.get(kernel, "HwSource")
            else:
                hwsrc = None

            if cfg.has_option(kernel, "MemBytes"):
                membytes = int(cfg.get(kernel, "MemBytes"))
            else:
                log.warning("Local memory size for kernel not specified, assuming 16kB")
                membytes = 16 * (2 ** 10)

            if cfg.has_option(kernel, "MemBanks"):
                membanks = int(cfg.get(kernel, "MemBanks"))
            else:
                log.warning("Number of local memory banks not specified, assuming 2")
                membanks = 2

            # NOTE: the following points are enforced by this fix.
            #         1. An odd number of banks are supported
            #         2. Each bank will have an integer number of 32-bit words
            if membytes != int(math.ceil((membytes / membanks) / 4) * 4 * membanks):
                log.warning("Increasing kernel memory size to ensure integer number of 32-bit words per bank")
                membytes = int(math.ceil((membytes / membanks) / 4) * 4 * membanks)

            if cfg.has_option(kernel, "RegRW"):
                regrw = int(cfg.get(kernel, "RegRW"))
            else:
                log.warning("Number of local R/W registers not specified, assuming 4")
                regrw = 4

            if cfg.has_option(kernel, "RegRO"):
                regro = int(cfg.get(kernel, "RegRO"))
            else:
                log.warning("Number of local Read Only registers not specified, assuming 4")
                regro = 4

            if cfg.has_option(kernel, "RstPol"):
                rstpol = cfg.get(kernel, "RstPol")
            else:
                log.warning("Reset polarity for accelerator not found, setting active low for AXI compatibility")
                rstpol = "low"

            kernel = Kernel(name, hwsrc, membytes, membanks, regrw,
                regro, rstpol)
            self.kerns.append(kernel)
            for i in range(replicas):
                slot = Slot()
                slot.kerns.append(kernel)
                self.slots.append(slot)
                log.debug(str(slot))


    def _check_project(self):
        """Checks the integrity of the loaded ARTICo\u00b3 project."""

        if Slot._id > self.shuffler.slots:
            log.error("Configured more ARTICo\u00b3 accelerators than slots")
            sys.exit(1)
        elif Slot._id < self.shuffler.slots:
            kernel = Kernel("dummy", "vhdl", 4096, 2, 2, 2, "low")
            self.kerns.append(kernel)
            for i in range(Slot._id, self.shuffler.slots):
                slot = Slot()
                slot.kerns.append(kernel)
                self.slots.append(slot)
                log.debug(str(slot))

        for kernel in self.kerns:
            if kernel.hwsrc is None:
                log.error("ARTICo\u00b3 accelerators must have a source")
                sys.exit(1)
            if kernel.membytes > (64 * (2 ** 10)):
                log.error("ARTICo\u00b3 accelerators cannot have more than 64kB of local memory")
                sys.exit(1)
            if kernel.rstpol not in ("high", "low"):
                log.error("ARTICo\u00b3 accelerators must set reset polarity properly")
                sys.exit(1)
