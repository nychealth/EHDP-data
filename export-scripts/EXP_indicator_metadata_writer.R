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

suppressWarnings(suppressMessages(library(tidyverse)))
suppressWarnings(suppressMessages(library(DBI)))
suppressWarnings(suppressMessages(library(dbplyr)))
suppressWarnings(suppressMessages(library(odbc)))
suppressWarnings(suppressMessages(library(lubridate)))
suppressWarnings(suppressMessages(library(fs)))
suppressWarnings(suppressMessages(library(jsonlite))) # needs to be version 1.8.4
suppressWarnings(suppressMessages(library(rlang)))
suppressWarnings(suppressMessages(library(svDialogs)))
suppressWarnings(suppressMessages(library(scales)))

#-----------------------------------------------------------------------------------------#
# get base_dir for absolute path
#-----------------------------------------------------------------------------------------#

# get envionment var

base_dir <- Sys.getenv("base_dir")

if (base_dir == "") {
    
    # get the current folder
    
    this_dir <- last(unlist(path_split(path_abs("."))))
    
    # if the current folder is "EHDP-data", use the absolute path to it
    
    if (this_dir == "EHDP-data") {
        
        base_dir <- path_abs(".")
        
    } else {
        
        # if the current folder is below "EHDP-data", switch it
        
        base_dir <- path(str_replace(path_abs("."), "(.*/EHDP-data)(.*)", "\\1"))
        
    }
    
    # set environment var
    
    Sys.setenv(base_dir = base_dir)

} 


#-----------------------------------------------------------------------------------------#
# get or set server to use
#-----------------------------------------------------------------------------------------#

# get envionment var

server <- Sys.getenv("server")

if (server == "") {

    computername <- Sys.getenv("COMPUTERNAME")

    if (computername != "DESKTOP-PU7DGC1") {
        
        # default to network server
        
        server <- "SQLIT04A"
        
        Sys.setenv(server = server)

    } else {

        server <- "DESKTOP-PU7DGC1"
        
        Sys.setenv(server = server)

    }
}


#-----------------------------------------------------------------------------------------#
# get or set database to use
#-----------------------------------------------------------------------------------------#

# get envionment var

data_env <- Sys.getenv("data_env")

if (data_env == "") {
    
    # ask and set
    
    data_env <-
        dlgInput(
            message = "staging [s] or production [p]?",
            rstudio = FALSE
        )$res
    
    Sys.setenv(data_env = data_env)

} 

# set DB name

if (str_to_lower(data_env) == "s") {
    
    # staging
    
    db_name <- "BESP_IndicatorAnalysis"
    
} else if (str_to_lower(data_env) == "p") {
    
    # production
    
    db_name <- "BESP_Indicator"
    
}


#-----------------------------------------------------------------------------------------#
# Connecting to database
#-----------------------------------------------------------------------------------------#

# determining driver to use (so script works across machines)

odbc_driver <- 
    odbcListDrivers() %>% 
    pull(name) %>% 
    unique() %>% 
    str_subset("ODBC Driver") %>% 
    sort(decreasing = TRUE) %>% 
    head(1)

# if no "ODBC Driver", use Windows built-in driver

if (length(odbc_driver) == 0) odbc_driver <- "SQL Server"

# using Windows auth with no DSN

EHDP_odbc <-
    dbConnect(
        drv = odbc::odbc(),
        driver = paste0("{", odbc_driver, "}"),
        server = server,
        database = db_name,
        trusted_connection = "yes",
        encoding = "utf8",
        trustservercertificate = "yes"
    )


#=========================================================================================#
# Pulling & writing data ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# all metadata
#-----------------------------------------------------------------------------------------#

EXP_metadata_export <- 
    EHDP_odbc %>% 
    tbl("EXP_metadata_export") %>% 
    collect() %>% 
    arrange(
        IndicatorID,
        MeasureID,
        end_period
    ) %>% 
    mutate(
        across(
            where(is.character),
            ~ as_utf8_character(enc2native(.x))
        )
    )

#-----------------------------------------------------------------------------------------#
# general datasets for joining
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# distinct measures
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

distinct_measures <-
    EXP_metadata_export %>%
    select(
        IndicatorID,
        MeasureID
    ) %>%
    distinct()


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# indicator and measure text fields
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

indicator_measure_text <-
    EXP_metadata_export %>%
    select(
        IndicatorID,
        IndicatorName,
        IndicatorLabel,
        IndicatorDescription,
        MeasureID,
        MeasureName,
        MeasurementType,
        how_calculated,
        Sources,
        DisplayType
    ) %>%
    distinct()


#-----------------------------------------------------------------------------------------#
# nesting vis options
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# map options
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# On: 0/1
# RankReverse: 0/1

measure_mapping <- 
    EXP_metadata_export %>% 
    select(
        IndicatorID,
        MeasureID,
        On = Map,
        RankReverse
    ) %>% 
    distinct() %>% 
    group_by(IndicatorID, MeasureID) %>% 
    group_nest(.key = "Map", keep = FALSE) %>% 
    ungroup()


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# trend options
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# On: 0/1
# Disparities: 0/1

measure_trend <- 
    EXP_metadata_export %>% 
    select(
        IndicatorID,
        MeasureID,
        On = Trend,
        Disparities
    ) %>% 
    distinct() %>% 
    group_by(IndicatorID, MeasureID) %>% 
    group_nest(.key = "Trend", keep = FALSE) %>% 
    ungroup()


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# measure (non-boro) trend comparisons
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# ==== specific comparisons view ==== #

EXP_measure_comparisons <- 
    EHDP_odbc %>% 
    tbl("EXP_measure_comparisons") %>% 
    collect() %>% 
    arrange(
        IndicatorID,
        ComparisonID,
        MeasureID
    ) %>% 
    mutate(
        across(
            where(is.character),
            ~ as_utf8_character(enc2native(.x))
        )
    )

# ==== nesting ComparisonIDs ==== #

indicator_comparisons <- 
    EXP_measure_comparisons %>% 
    select(
        IndicatorID,
        Comparisons = ComparisonID
    ) %>% 
    distinct() %>% 
    drop_na() %>% 
    group_by(IndicatorID) %>% 
    summarise(Comparisons = list(unname(unlist(Comparisons))))


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# links and disparities
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# ==== specific link view ==== #

# because left-joining these 400 rows added 12k rows to the view

MeasureID_links <- 
    EHDP_odbc %>% 
    tbl("EXP_measure_links") %>% 
    select(BaseMeasureID, MeasureID, SecondaryAxis) %>% 
    collect() %>% 
    arrange(
        BaseMeasureID,
        MeasureID
    ) %>% 
    mutate(
        across(
            where(is.character),
            ~ as_utf8_character(enc2native(.x))
        )
    )


# ==== nesting links ==== #

measure_links <- 
    MeasureID_links %>% 
    distinct() %>% 
    group_by(BaseMeasureID) %>% 
    group_nest(.key = "Links", keep = FALSE) %>% 
    rename(MeasureID = BaseMeasureID)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# combining map, trend, and links, then nesting those under VisOptions
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

measure_vis_options <- 
    left_join(
        measure_mapping,
        measure_trend,
        by = c("IndicatorID", "MeasureID")
    ) %>% 
    left_join(
        measure_links,
        by = "MeasureID"
    ) %>% 
    group_by(IndicatorID, MeasureID) %>% 
    group_nest(.key = "VisOptions", keep = FALSE)


#-----------------------------------------------------------------------------------------#
# nesting geotypes
#-----------------------------------------------------------------------------------------#

measure_geotypes <- 
    EXP_metadata_export %>% 
    select(
        IndicatorID,
        MeasureID,
        GeoType,
        GeoTypeDescription
    ) %>% 
    distinct() %>% 
    group_by(
        IndicatorID,
        MeasureID
    ) %>% 
    group_nest(.key = "AvailableGeographyTypes", keep = FALSE)


#-----------------------------------------------------------------------------------------#
# nesting times
#-----------------------------------------------------------------------------------------#

measure_times <- 
    EXP_metadata_export %>% 
    select(
        IndicatorID,
        MeasureID,
        TimeDescription,
        start_period,
        end_period
    ) %>% 
    mutate(
        start_period = as.numeric(as_datetime(start_period)) * 1000,
        end_period = as.numeric(as_datetime(end_period)) * 1000
    ) %>% 
    distinct() %>% 
    group_by(
        IndicatorID,
        MeasureID
    ) %>% 
    group_nest(.key = "AvailableTimes", keep = FALSE)


#-----------------------------------------------------------------------------------------#
# combining geotype, times, and vis options, then nesting those under other measure-level info vars
#-----------------------------------------------------------------------------------------#

metadata <- 
    left_join(
        indicator_measure_text,
        measure_geotypes,
        by = c("IndicatorID", "MeasureID")
    ) %>% 
    left_join(
        measure_times,
        by = c("IndicatorID", "MeasureID")
    ) %>% 
    left_join(
        measure_vis_options,
        by = c("IndicatorID", "MeasureID")
    ) %>% 
    group_by(
        IndicatorID,
        IndicatorName,
        IndicatorLabel,
        IndicatorDescription
    ) %>% 
    group_nest(.key = "Measures", keep = FALSE) %>% 
    left_join(
        indicator_comparisons,
        by = "IndicatorID"
    ) %>% 
    relocate(
        IndicatorID,
        IndicatorName,
        IndicatorLabel,
        IndicatorDescription,
        Comparisons,
        Measures
    )


#-----------------------------------------------------------------------------------------#
# saving file ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# converting to JSON
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

metadata_json_pretty <- metadata %>% toJSON(pretty = TRUE, null = "null", na = "null")
metadata_json        <- metadata %>% toJSON(pretty = FALSE, null = "null", na = "null")

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# saving JSON
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

write_file(metadata_json_pretty, path(base_dir, "indicators/indicators_pretty.json"))
write_file(metadata_json,        path(base_dir, "indicators/indicators.json"))

#-----------------------------------------------------------------------------------------#
# closing database connection
#-----------------------------------------------------------------------------------------#

dbDisconnect(EHDP_odbc)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
