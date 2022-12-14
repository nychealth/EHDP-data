###########################################################################################
###########################################################################################
##
## Building indicators.json using nested DataFrames
##
###########################################################################################
###########################################################################################

#=========================================================================================#
# Setting up
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# Loading libraries
#-----------------------------------------------------------------------------------------#

import pyodbc
import pandas as pd
import easygui
import os
import warnings
import re

warnings.simplefilter("ignore")

#-----------------------------------------------------------------------------------------#
# Connecting to BESP_Indicator database
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# get base_dir for absolute path
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# get environemnt var

base_dir = os.environ.get("base_dir", "")

if (base_dir == ""):

    # get current folder

    this_dir = os.path.basename(os.path.abspath("."))

    # if the current folder is "EHDP-data", use the absolute path to it

    if (this_dir == "EHDP-data"):
        
        base_dir = os.path.abspath(".")

    else:

        # if the current folder is below "EHDP-data", switch it

        base_dir = re.sub(r"(.*EHDP-data)(.*)", r"\1", os.path.abspath("."))

    os.environ["base_dir"] = base_dir

