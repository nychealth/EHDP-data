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
# Connecting to database
#-----------------------------------------------------------------------------------------#

EHDP_odbc = pyodbc.connect("DRIVER={ODBC Driver 17 for SQL Server};SERVER=SQLIT04A;DATABASE=BESP_Indicator;Trusted_Connection=yes;")


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
    .dropna()
)

(
    EXP_measure_comparisons
    .loc[:, 
        [
            "IndicatorID",
            "MeasureID"
        ]
    ]
    .groupby(["IndicatorID"], dropna = False)
    .apply(lambda x: x[["MeasureID"]].to_dict("list"))
    .reset_index()
    .rename(columns = {0: "Measures"})
)

# ---- measure (non-boro) comparisons ---- #

indicator_comparisons = (
    EXP_measure_comparisons
    .loc[:, ["IndicatorID", "ComparisonID"]]
    .drop_duplicates()
    .dropna()
)


measure_mapping = (
    EXP_metadata_export
    .drop_duplicates()
    .groupby(["IndicatorID", "MeasureID"], dropna = False)
    .apply(lambda x: x[["On", "RankReverse"]].to_dict("records"))
    .reset_index()
    .rename(columns = {0: "Map"})
)

