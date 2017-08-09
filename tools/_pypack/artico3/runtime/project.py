"""
ARTICo\u00b3 Development Kit

Author      : Alfonso Rodriguez <alfonso.rodriguezm@upm.es>
Date        : August 2017
Description : Current project info utilities.

"""

import re
import configparser
import logging

log = logging.getLogger(__name__)

class Shuffler:
    """Class to store information of the ARTICo\u00b3 infrastructure."""

    def __init__(self):
        pass

    def __repr__(self):
        pass

    def __str__(self):
        pass

class Slot:
    """Class to store information of an ARTICo\u00b3 slot."""

    _id = 0

    def __init__(self):
        pass

    def __repr__(self):
        return "slot"

    def __str__(self):
        pass

class Accelerator:
    """ Class to store information of an ARTICo\u00b3 hardware accelerator."""

    _id = 0

    def __init__(self):
        pass

    def __repr__(self):
        return "accelerator"

    def __str__(self):
        pass

class Project:
    """ Main class of an ARTICo\u00b3-based project. Contains all the
    required information regarding system configuration."""

    def __init__(self):
        pass

    def __repr__(self):
        return "project"

    def __str__(self):
        pass

    def load(self, filepath):
        """ Loads project info from configuration (.cfg) file. """

        cfg = configparser.RawConfigParser()
        cfg.optionxform = str
        ret = cfg.read(filepath)
        if not ret:
            log.error("Config file '" + filepath + "' not found")
            return

        self._parse_project(cfg)

    def _parse_project(self, cfg):
        """ Parses project configuration. """
        print(cfg.get("General", "Name"))
