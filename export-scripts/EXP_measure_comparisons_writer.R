###########################################################################################-
###########################################################################################-
##
##  EXP_measure_comparisons
##
###########################################################################################-
###########################################################################################-

#=========================================================================================#
# Setting up ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# Loading libraries
#-----------------------------------------------------------------------------------------#

suppressWarnings(suppressMessages(library(tidyverse)))
suppressWarnings(suppressMessages(library(DBI)))
suppressWarnings(suppressMessages(library(dbplyr)))
suppressWarnings(suppressMessages(library(odbc)))
suppressWarnings(suppressMessages(library(fs)))
suppressWarnings(suppressMessages(library(jsonlite)))
suppressWarnings(suppressMessages(library(svDialogs)))

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
# get or set database to use
#-----------------------------------------------------------------------------------------#

# get envionment var

data_env <- Sys.getenv("data_env")

if (data_env == "") {
    
    # ask and set
    
    data_env <-
        dlgInput(
            message = "staging [s] or production [p]?",
            rstudio = TRUE
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
# Connecting to BESP_Indicator
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
        server = "SQLIT04A",
        # server = "DESKTOP-PU7DGC1",
        database = db_name,
        trusted_connection = "yes",
        encoding = "latin1",
        trustservercertificate = "yes"
    )


#=========================================================================================#
# Pulling and nesting data ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# Measure comparisons view
#-----------------------------------------------------------------------------------------#

EXP_measure_comparisons <- 
    EHDP_odbc %>% 
    tbl("EXP_measure_comparisons") %>% 
    collect()

#-----------------------------------------------------------------------------------------#
# Nesting
#-----------------------------------------------------------------------------------------#

comparisons_nested <- 
    EXP_measure_comparisons %>% 
    mutate(ComparisonName = ComparisonName %>% str_remove_all("<.*?>")) %>% # remove HTML tags
    # rename(Measures = MeasureID) %>% 
    group_by(ComparisonID, ComparisonName, LegendTitle, Y_axis_title) %>% 
    # group_nest(.key = "Measures", keep = FALSE) %>%
    # ungroup() %>%
    # group_by(ComparisonID, ComparisonName, LegendTitle, Y_axis_title) %>%
    group_nest(.key = "Indicators", keep = FALSE) %>%
    ungroup()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# converting to JSON
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# comparisons_json <- comparisons_nested %>% toJSON(pretty = TRUE, null = "null", na = "null")
comparisons_json <- comparisons_nested %>% toJSON(pretty = FALSE, null = "null", na = "null")

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# saving JSON
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

write_lines(comparisons_json, "indicators/comparisons.json")

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
