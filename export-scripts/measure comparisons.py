###########################################################################################
###########################################################################################
##
## Building indicators.json and comparisons.json using nested DataFrames
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


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# get or set database to use
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# get envionment var

data_env = os.environ.get("data_env", "")

if (data_env == ""):
    
    # ask and set
    
    data_env = easygui.enterbox("staging [s] or production [p]?")
    
    os.environ["data_env"] = data_env

# set DB name

if (data_env.lower() == "s"):
    
    # staging
    
    db_name = "BESP_IndicatorAnalysis"

elif (data_env.lower() == "p"):
    
    # production
    
    db_name = "BESP_Indicator"


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# determining which driver to use
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

drivers_list = pyodbc.drivers()

# odbc

odbc_driver_list = list(filter(lambda dl: "ODBC Driver" in dl, drivers_list))
odbc_driver_list.sort(reverse = True)

# native

native_driver_list = list(filter(lambda dl: "SQL Server Native Client" in dl, drivers_list))
native_driver_list.sort()

# deciding & setting

if len(odbc_driver_list) > 0:
    
    driver = odbc_driver_list[0]
    
elif len(native_driver_list) > 0:
    
    driver = native_driver_list[0]
    
else:
    
    driver = "SQL Server"

#-----------------------------------------------------------------------------------------#
# Connecting to database
#-----------------------------------------------------------------------------------------#

EHDP_odbc = pyodbc.connect("DRIVER={" + driver + "};SERVER=SQLIT04A;DATABASE=" + db_name + ";Trusted_Connection=yes;")


#=========================================================================================#
# Pulling & writing data
#=========================================================================================#

EXP_metadata_export = (
    pd.read_sql("SELECT * FROM EXP_metadata_export", EHDP_odbc)
    .sort_values(by = ["IndicatorID", "MeasureID", "end_period"])
)

#-----------------------------------------------------------------------------------------#
# nesting vis options
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# map options
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# On: 0/1
# RankReverse: 0/1

measure_mapping = (
    EXP_metadata_export
    .loc[:, 
        [
            "IndicatorID",
            "MeasureID",
            "Map",
            "RankReverse"
        ]
    ]    
    .drop_duplicates()
    .rename(columns = {"Map": "On"})
    .groupby(["IndicatorID", "MeasureID"], dropna = False)
    .apply(lambda x: x[["On", "RankReverse"]].to_dict("records"))
    .reset_index()
    .rename(columns = {0: "Map"})
)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# trend options
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# On: 0/1
# Disparities: 0/1

measure_trend = (
    EXP_metadata_export
    .loc[:, 
        [
            "IndicatorID",
            "MeasureID",
            "Trend",
            "Disparities"
        ]
    ]
    .drop_duplicates()
    .rename(columns = {"Trend": "On"})
    .groupby(["IndicatorID", "MeasureID"], dropna = False)
    .apply(lambda x: x[["On", "Disparities"]].to_dict("records"))
    .reset_index()
    .rename(columns = {0: "Trend"})
)

# ==== measure (non-boro) comparisons ==== #

# ---- measure (non-boro) comparisons ---- #

EXP_measure_comparisons = (
    pd.read_sql("SELECT * FROM EXP_measure_comparisons", EHDP_odbc)
    .sort_values(by = ["IndicatorID", "ComparisonID", "MeasureID"])
)

# ---- measure (non-boro) comparisons ---- #

indicator_comparisons = (
    EXP_measure_comparisons
    .loc[:, ["IndicatorID", "ComparisonID"]]
    .drop_duplicates()
)
