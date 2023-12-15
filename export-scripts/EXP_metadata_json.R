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
# set summarise options
#-----------------------------------------------------------------------------------------#

options(dplyr.summarise.inform = FALSE)

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

EXP_metadata <- 
    EHDP_odbc %>% 
    tbl("EXP_metadata") %>% 
    collect() %>% 
    arrange(
        IndicatorID,
        MeasureID,
        TimePeriodID
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
    EXP_metadata %>%
    select(
        IndicatorID,
        MeasureID
    ) %>%
    distinct()


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# indicator and measure text fields
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

indicator_measure_text <-
    EXP_metadata %>%
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
# table options
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# TimePeriodID

measure_table_time <- 
    EXP_metadata %>% 
    filter(Table == 1) %>%
    select(
        IndicatorID,
        MeasureID,
        GeoType,
        TimePeriodID
    ) %>% 
    distinct() %>% 
    left_join(
        distinct_measures,
        .,
        by = c("IndicatorID", "MeasureID")
    ) %>% 
    group_by(IndicatorID, MeasureID, GeoType) %>% 
    summarise(TimePeriodID = list(unname(unlist(TimePeriodID)))) %>% 
    ungroup()

# GeoType

# measure_table_geo <- 
#     EXP_metadata %>% 
#     filter(Table == 1) %>% 
#     select(
#         IndicatorID,
#         MeasureID,
#         GeoType
#     ) %>% 
#     distinct() %>% 
#     left_join(
#         distinct_measures,
#         .,
#         by = c("IndicatorID", "MeasureID")
#     ) %>% 
#     group_by(IndicatorID, MeasureID) %>% 
#     summarise(GeoType = list(unname(unlist(GeoType)))) %>% 
#     ungroup()

# combining

measure_table <- 
    left_join(
        distinct_measures,
        measure_table_time,
        by = c("IndicatorID", "MeasureID")
    ) %>% 
    # left_join(
    #     measure_table_geo,
    #     by = c("IndicatorID", "MeasureID", "GeoType")
    # ) %>% 
    group_by(IndicatorID, MeasureID) %>% 
    group_nest(.key = "Table", keep = FALSE)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# map options
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# RankReverse: 0/1

measure_mapping_rr <- 
    EXP_metadata %>% 
    filter(Map == 1) %>% 
    select(
        IndicatorID,
        MeasureID,
        RankReverse
    ) %>% 
    left_join(
        distinct_measures,
        .,
        by = c("IndicatorID", "MeasureID")
    ) %>% 
    group_by(MeasureID) %>% 
    summarise(RankReverse = max(RankReverse))

# TimePeriodID

measure_mapping_time <- 
    EXP_metadata %>% 
    filter(Map == 1) %>% 
    select(
        IndicatorID,
        MeasureID,
        GeoType,
        TimePeriodID
    ) %>% 
    distinct() %>% 
    left_join(
        distinct_measures,
        .,
        by = c("IndicatorID", "MeasureID")
    ) %>%     
    group_by(IndicatorID, MeasureID, GeoType) %>% 
    summarise(TimePeriodID = list(unname(unlist(TimePeriodID))),) %>% 
    ungroup()

# GeoType

# measure_mapping_geo <- 
#     EXP_metadata %>% 
#     filter(Map == 1) %>% 
#     select(
#         IndicatorID,
#         MeasureID,
#         GeoType
#     ) %>% 
#     distinct() %>% 
#     left_join(
#         distinct_measures,
#         .,
#         by = c("IndicatorID", "MeasureID")
#     ) %>%     
#     group_by(IndicatorID, MeasureID) %>% 
#     summarise(GeoType = list(unname(unlist(GeoType)))) %>% 
#     ungroup()

# combining

measure_mapping <- 
    left_join(
        distinct_measures,
        measure_mapping_time,
        by = c("IndicatorID", "MeasureID")
    ) %>% 
    # left_join(
    #     measure_mapping_geo,
    #     by = c("IndicatorID", "MeasureID")
    # ) %>% 
    left_join(
        measure_mapping_rr,
        by = "MeasureID"
    ) %>% 
    group_by(IndicatorID, MeasureID) %>% 
    group_nest(.key = "Map", keep = FALSE)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# trend options
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# TimePeriodID

measure_trend_time <- 
    EXP_metadata %>% 
    filter(Trend == 1) %>% 
    select(
        IndicatorID,
        MeasureID,
        GeoType,
        TimePeriodID
    ) %>% 
    distinct() %>% 
    left_join(
        distinct_measures,
        .,
        by = c("IndicatorID", "MeasureID")
    ) %>%     
    group_by(IndicatorID, MeasureID, GeoType) %>% 
    summarise(TimePeriodID = list(unname(unlist(TimePeriodID)))) %>% 
    ungroup()

# GeoType

# measure_trend_geo <- 
#     EXP_metadata %>% 
#     filter(Trend == 1) %>% 
#     select(
#         IndicatorID,
#         MeasureID,
#         GeoType
#     ) %>% 
#     distinct() %>% 
#     left_join(
#         distinct_measures,
#         .,
#         by = c("IndicatorID", "MeasureID")
#     ) %>%     
#     group_by(IndicatorID, MeasureID) %>% 
#     summarise(GeoType = list(unname(unlist(GeoType)))) %>% 
#     ungroup()

# combining

measure_trend <- 
    left_join(
        distinct_measures,
        measure_trend_time,
        by = c("IndicatorID", "MeasureID")
    ) %>% 
    # left_join(
    #     measure_trend_geo,
    #     by = c("IndicatorID", "MeasureID")
    # ) %>% 
    group_by(IndicatorID, MeasureID) %>% 
    group_nest(.key = "Trend", keep = FALSE)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# measure (non-boro) trend comparisons
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# ==== specific comparisons view ==== #

EXP_comparisons <- 
    EHDP_odbc %>% 
    tbl("EXP_comparisons") %>% 
    collect() %>% 
    arrange(
        IndicatorID,
        ComparisonID,
        MeasureID
    )

# ==== nesting ComparisonIDs ==== #

indicator_comparisons <- 
    EXP_comparisons %>% 
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
    tbl("EXP_links") %>% 
    collect() %>% 
    arrange(
        BaseMeasureID,
        MeasureID
    )


# ==== nesting links ==== #

measure_links <- 
    MeasureID_links %>% 
    filter(disparity_flag == 0) %>% 
    select(-disparity_flag) %>% 
    distinct() %>% 
    left_join(
        distinct_measures %>% select(BaseMeasureID = MeasureID),
        .,
        by = "BaseMeasureID"
    ) %>% 
    group_by(BaseMeasureID) %>% 
    group_nest(.key = "Measures", keep = FALSE) %>% 
    rename(MeasureID = BaseMeasureID)


# ==== nesting disparities ==== #

# Disparities: 0/1

measure_disp <- 
    MeasureID_links %>% 
    filter(disparity_flag == 1) %>% 
    group_by(BaseMeasureID) %>% 
    summarise(Disparities = max(disparity_flag), .groups = "keep") %>% 
    rename(MeasureID = BaseMeasureID) %>% 
    left_join(
        distinct_measures %>% select(MeasureID),
        .,
        by = "MeasureID"
    ) %>% 
    mutate(Disparities = replace_na(Disparities, 0L))


# ==== nesting disparities ==== #

measure_links_disp <- 
    left_join(
        measure_links,
        measure_disp,
        by = "MeasureID"
    ) %>% 
    group_by(MeasureID) %>% 
    group_nest(.key = "Links", keep = FALSE)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# combining map, trend, and links, then nesting those under VisOptions
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

measure_vis_options <- 
    left_join(
        measure_table,
        measure_mapping,
        by = c("IndicatorID", "MeasureID")
    ) %>% 
    left_join(
        measure_trend,
        by = c("IndicatorID", "MeasureID")
    ) %>% 
    left_join(
        measure_links_disp,
        by = "MeasureID"
    ) %>% 
    group_by(IndicatorID, MeasureID) %>% 
    group_nest(.key = "VisOptions", keep = FALSE)


#-----------------------------------------------------------------------------------------#
# nesting geotypes
#-----------------------------------------------------------------------------------------#

measure_geotypes <- 
    EXP_metadata %>% 
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
    group_nest(.key = "AvailableGeoTypes", keep = FALSE)


#-----------------------------------------------------------------------------------------#
# nesting times
#-----------------------------------------------------------------------------------------#

measure_times <- 
    EXP_metadata %>% 
    select(
        IndicatorID,
        MeasureID,
        AvailableTimePeriodIDs = TimePeriodID
    ) %>% 
    distinct() %>% 
    group_by(IndicatorID, MeasureID) %>% 
    summarise(AvailableTimePeriodIDs = list(unname(unlist(AvailableTimePeriodIDs)))) %>% 
    ungroup()


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

# also making null values empty

metadata_json_pretty <- 
    metadata %>% 
    toJSON(pretty = TRUE, null = "null", na = "null") %>% 
    str_replace_all("\\[null\\]", "[]")

metadata_json <- 
    metadata %>% 
    toJSON(pretty = FALSE, null = "null", na = "null") %>% 
    str_replace_all("\\[null\\]", "[]")

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# saving JSON
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

write_file(metadata_json_pretty, path(base_dir, "indicators/metadata_pretty.json"))
write_file(metadata_json,        path(base_dir, "indicators/metadata.json"))

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
