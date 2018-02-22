from os.path import dirname, basename, isfile, splitext, sep as pathsep
from glob import glob
import sys

# Get just the filename of all *.py files under the current folder
file_mask = pathsep.join([dirname(__file__), "*.py"])
modules = [basename(f) for f in glob(file_mask) if isfile(f)]

# Remove the extension and filter out this file
__all__ = [splitext(f)[0] for f in modules if f != "__init__.py"]

# Import everything in __all__ automatically
from . import *
