###########################################################################################
###########################################################################################
##
## Building metadata.json and comparisons.json using nested DataFrames
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
import numpy as np

warnings.simplefilter("ignore")

#-----------------------------------------------------------------------------------------#
# get and set env vars
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# base_dir for absolute path
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
# server
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# get envionment var

server = os.environ.get("server", "")

if (server == ""):
        
    computername = os.environ.get("COMPUTERNAME", "")

    if (computername != "DESKTOP-PU7DGC1"):
        
        # ask and set
        
        server = "SQLIT04A"
        
        os.environ["server"] = server

    else:
            
        server = "DESKTOP-PU7DGC1"
        
        os.environ["server"] = server


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# database
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
# Connect to database
#-----------------------------------------------------------------------------------------#

EHDP_odbc = pyodbc.connect("DRIVER={" + driver + "};SERVER=" + server + ";DATABASE=" + db_name + ";Trusted_Connection=yes;trustservercertificate=yes")

#-----------------------------------------------------------------------------------------#
# create folders if they don't exist
#-----------------------------------------------------------------------------------------#

os.makedirs(base_dir + "/indicators/metadata/", exist_ok = True)


#=========================================================================================#
# data ops
#=========================================================================================#

EXP_metadata = (
    pd.read_sql("SELECT * FROM EXP_metadata", EHDP_odbc)
    .sort_values(by = ["IndicatorID", "MeasureID", "end_period"])
)

#-----------------------------------------------------------------------------------------#
# nesting vis options
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# map options
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# map flag

measure_mapping_flag = (
    EXP_metadata
    .loc[:, 
        [
            "IndicatorID",
            "MeasureID",
            "Map"
        ]
    ]    
    .drop_duplicates()
    .rename(columns = {"Map": "Map_flag"})
)

# RankReverse: 0/1

measure_mapping_rr = (
    EXP_metadata
    .query("Map == '1'")
    .loc[:,
        [
            "IndicatorID",
            "MeasureID",
            "RankReverse"
        ]
    ]
    .drop_duplicates()
    .groupby(["IndicatorID", "MeasureID"], dropna = False)
    .apply(lambda x: x[["RankReverse"]].drop_duplicates().to_dict("records")[0])
    .reset_index()
    .rename(columns = {0: "Map_rr"})
)

# TimeDescription

measure_mapping_time = (
    EXP_metadata
    .query("Map == '1'")
    .loc[:, 
        [
            "IndicatorID",
            "MeasureID",
            "TimeDescription"
        ]
    ]    
    .drop_duplicates()
    .groupby(["IndicatorID", "MeasureID"], dropna = False)
    .apply(lambda x: x[["TimeDescription"]].drop_duplicates().to_dict("list"))
    .reset_index()
    .rename(columns = {0: "Map_time"})
)

# GeoType

measure_mapping_geo = (
    EXP_metadata
    .query("Map == '1'")
    .loc[:, 
        [
            "IndicatorID",
            "MeasureID",
            "GeoType"
        ]
    ]    
    .drop_duplicates()
    .groupby(["IndicatorID", "MeasureID"], dropna = False)
    .apply(lambda x: x[["GeoType"]].drop_duplicates().to_dict("list"))
    .reset_index()
    .rename(columns = {0: "Map_geo"})
)

# combining

measure_mapping = (
    pd.merge(
        measure_mapping_flag,
        measure_mapping_time,
        how = "left"
    )
    .merge(
        measure_mapping_geo,
        how = "left"
    )
    .merge(
        measure_mapping_rr,
        how = "left"
    )
    # .assign(Map = lambda x: pd.DataFrame([x["Map_time"], x["Map_geo"], x["Map_rr"]]).to_dict("list"))
    # .assign(Map = lambda x: np.where(x.Map_flag == 0, None, x.Map))
    # .loc[:, 
    #     [
    #         "IndicatorID",
    #         "MeasureID",
    #         "Map"
    #     ]
    # ]
)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# trend options
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# measure_trend = (
#     EXP_metadata
#     .loc[:, 
#         [
#             "IndicatorID",
#             "MeasureID",
#             "Trend",
#             "Disparities"
#         ]
#     ]
#     .drop_duplicates()
#     .rename(columns = {"Trend": "On"})
#     .groupby(["IndicatorID", "MeasureID"], dropna = False)
#     .apply(lambda x: x[["On", "Disparities"]].to_dict("records"))
#     .reset_index()
#     .rename(columns = {0: "Trend"})
# )

# trend flag

measure_trend_flag = (
    EXP_metadata
    .loc[:, 
        [
            "IndicatorID",
            "MeasureID",
            "Trend"
        ]
    ]    
    .drop_duplicates()
    .rename(columns = {"Trend": "Trend_flag"})
)


# TimeDescription

measure_trend_time = (
    EXP_metadata
    .query("Trend == '1'")
    .loc[:, 
        [
            "IndicatorID",
            "MeasureID",
            "TimeDescription"
        ]
    ]    
    .drop_duplicates()
    .groupby(["IndicatorID", "MeasureID"], dropna = False)
    .apply(lambda x: x[["TimeDescription"]].drop_duplicates().to_dict("list"))
    .reset_index()
    .rename(columns = {0: "Trend_time"})
)

# GeoType

measure_trend_geo = (
    EXP_metadata
    .query("Trend == '1'")
    .loc[:, 
        [
            "IndicatorID",
            "MeasureID",
            "GeoType"
        ]
    ]    
    .drop_duplicates()
    .groupby(["IndicatorID", "MeasureID"], dropna = False)
    .apply(lambda x: x[["GeoType"]].drop_duplicates().to_dict("list"))
    .reset_index()
    .rename(columns = {0: "Trend_geo"})
)

# combining

measure_trend = (
    pd.merge(
        measure_trend_flag,
        measure_trend_time,
        how = "left"
    )
    .merge(
        measure_trend_geo,
        how = "left"
    )
    .merge(
        measure_trend_disp,
        how = "left"
    )
    .assign(Trend = lambda x: pd.DataFrame([x["Trend_time"], x["Trend_geo"], x["Trend_disp"]]).to_dict("list"))
    .assign(Trend = lambda x: np.where(x.Trend_flag == 0, None, x.Trend))
    .loc[:, 
        [
            "IndicatorID",
            "MeasureID",
            "Trend"
        ]
    ]  
)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# measure (non-boro) trend comparisons
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# ==== specific comparisons view ==== #

EXP_comparisons = (
    pd.read_sql("SELECT * FROM EXP_comparisons", EHDP_odbc)
    .sort_values(by = ["IndicatorID", "ComparisonID", "MeasureID"])
)


# ==== nesting ComparisonIDs ==== #

indicator_comparisons = (
    EXP_comparisons
    .loc[:, ["IndicatorID", "ComparisonID"]]
    .drop_duplicates()
    .dropna()
    .groupby(["IndicatorID"])
    .apply(lambda x: x["ComparisonID"].tolist()) # [] returns Series, not DataFrame
    .reset_index()
    .rename(columns = {0: "Comparisons"})
)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# linked measures
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# ==== specific link view ==== #

# because left-joining these 400 rows added 12k rows to the view

MeasureID_links = (
    pd.read_sql("SELECT * FROM EXP_links", EHDP_odbc)
    .loc[:, ["BaseMeasureID", "MeasureID", "SecondaryAxis"]]
    .sort_values(by = ["BaseMeasureID", "MeasureID"])
)

# ==== nesting links ==== #

measure_links = (
    MeasureID_links
    .drop_duplicates()
    .groupby(["BaseMeasureID"], dropna = False)
    .apply(lambda x: x[["MeasureID", "SecondaryAxis"]].to_dict("records"))
    .reset_index()
    .rename(columns = {0: "Links", "BaseMeasureID": "MeasureID"})
)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# disparities
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# Disparities: 0/1

measure_disp = (
    EXP_metadata
    .query("Trend == '1'")
    .loc[:, 
        [
            "IndicatorID",
            "MeasureID",
            "Disparities"
        ]
    ]    
    .drop_duplicates()
    .groupby(["IndicatorID", "MeasureID"], dropna = False)
    .apply(lambda x: x[["Disparities"]].drop_duplicates().to_dict("records")[0])
    .reset_index()
    .rename(columns = {0: "Trend_disp"})
)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# combining map, trend, and links, then nesting those under VisOptions
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

vis_options = (
    pd.merge(
        measure_mapping,
        measure_trend,
        how = "left"
    )
    .merge(
        measure_links,
        how = "left"
    )
    .groupby(
        [
            "IndicatorID",
            "MeasureID"
        ],
        dropna = False
    )
    .apply(lambda x: x[[
        "Map", 
        "Trend", 
        "Links"
    ]].to_dict('records'))
    .reset_index()
    .rename(columns = {0: "VisOptions"})
)


#-----------------------------------------------------------------------------------------#
# nesting geotypes
#-----------------------------------------------------------------------------------------#

measure_geotypes = (
    EXP_metadata
    .loc[:, 
        [
            "IndicatorID",
            "IndicatorName",
            "IndicatorLabel",
            "IndicatorDescription",
            "MeasureID",
            "MeasureName",
            "MeasurementType",
            "how_calculated",
            "Sources",
            "DisplayType",
            "GeoType",
            "GeoTypeDescription"
        ]
    ]
    .drop_duplicates()
    .groupby(
        [
            "IndicatorID",
            "IndicatorName",
            "IndicatorLabel",
            "IndicatorDescription",
            "MeasureID",
            "MeasureName",
            "MeasurementType",
            "how_calculated",
            "Sources",
            "DisplayType"
        ],
        dropna = False
    )
    .apply(lambda x: x[["GeoType", "GeoTypeDescription"]].to_dict("records"))
    .reset_index()
    .rename(columns = {0: "AvailableGeoTypes"})
)


#-----------------------------------------------------------------------------------------#
# nesting times
#-----------------------------------------------------------------------------------------#

measure_times = (
    EXP_metadata
    .loc[:, 
        [
            "IndicatorID",
            "IndicatorName",
            "IndicatorLabel",
            "IndicatorDescription",
            "MeasureID",
            "MeasureName",
            "MeasurementType",
            "how_calculated",
            "Sources",
            "DisplayType",
            "TimeDescription",
            "start_period",
            "end_period"
        ]
    ]
    .drop_duplicates()
    .groupby(
        [
            "IndicatorID",
            "IndicatorName",
            "IndicatorLabel",
            "IndicatorDescription",
            "MeasureID",
            "MeasureName",
            "MeasurementType",
            "how_calculated",
            "Sources",
            "DisplayType"
        ],
        dropna = False
    )
    .apply(lambda x: x[["TimeDescription", "start_period", "end_period"]].to_dict("records"))
    .reset_index()
    .rename(columns = {0: "AvailableTimes"})
)


#-----------------------------------------------------------------------------------------#
# combining geotype, times, and vis options, then nesting those under other measure-level info vars
#-----------------------------------------------------------------------------------------#

metadata = (
    pd.merge(
        measure_geotypes,
        measure_times,
        how = "left"
    )
    .merge(
        vis_options,
        how = "left"
    )
    .groupby(
        [
            "IndicatorID",
            "IndicatorName",
            "IndicatorLabel",
            "IndicatorDescription"
        ],
        dropna = False
    )
    .apply(lambda x: x[[
        "MeasureID", 
        "MeasureName", 
        "MeasurementType", 
        "how_calculated",
        "Sources",
        "DisplayType",
        "AvailableGeoTypes",
        "AvailableTimes",
        "VisOptions"
    ]].to_dict('records'))
    .reset_index()
    .rename(columns = {0: "Measures"})
    .merge(
        indicator_comparisons,
        how = "left"
    )
    .loc[:, 
        [
            "IndicatorID",
            "IndicatorName",
            "IndicatorLabel",
            "IndicatorDescription",
            "Comparisons",
            "Measures"
        ]
    ]
    
)


#-----------------------------------------------------------------------------------------#
# saving files
#-----------------------------------------------------------------------------------------#

metadata.to_json(base_dir + "/indicators/metadata/metadata_pretty.json", orient = "records", indent = 2)
metadata.to_json(base_dir + "/indicators/metadata/metadata.json", orient = "records", indent = 0)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
