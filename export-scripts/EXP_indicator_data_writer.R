###########################################################################################-
###########################################################################################-
##
##  Writing data explorer data
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
suppressWarnings(suppressMessages(library(lubridate)))
suppressWarnings(suppressMessages(library(fs)))
suppressWarnings(suppressMessages(library(jsonlite)))
suppressWarnings(suppressMessages(library(rlang)))
suppressWarnings(suppressMessages(library(svDialogs)))

#-----------------------------------------------------------------------------------------#
# get or set database to use
#-----------------------------------------------------------------------------------------#

data_env <- Sys.getenv("data_env")

if (str_to_lower(data_env) == "s") {
    
    db_name <- "BESP_IndicatorAnalysis"
    
} else if (str_to_lower(data_env) == "p") {
    
    db_name <- "BESP_Indicator"
    
} else if (data_env == "") {
    
    data_env <-
        dlgInput(
            message = "staging [s] or prod [p]?",
            rstudio = TRUE
        )$res
    
    Sys.setenv(data_env = data_env)
    
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
        database = db_name,
        trusted_connection = "yes"
    )


#=========================================================================================#
# Pulling data ----
#=========================================================================================#

# using existing views

EXP_data_export <- 
    EHDP_odbc %>% 
    tbl("EXP_data_export") %>% 
    collect() %>% 
    arrange(
        IndicatorID,
        MeasureID,
        GeoTypeID,
        GeoID,
        desc(Time)
    ) %>%
    select(-GeoTypeID) %>% 

    # removing "Rank" measure values
    
    # filter(MeasurementType != "Rank") %>%
    mutate(
        across(
            where(is.character),
            ~ as_utf8_character(enc2native(.x))
        )
    )

# closing connection

dbDisconnect(EHDP_odbc)


#=========================================================================================#
# Writing JSON ----
#=========================================================================================#

IndicatorIDs <- sort(unique(EXP_data_export$IndicatorID))

for (i in 1:length(IndicatorIDs)) {
    
    this_indicator <- IndicatorIDs[i]
    
    # cat(i, "/", length(IndicatorIDs), " [", this_indicator, "]", "\n", sep = "")
    
    exp_json <- 
        EXP_data_export %>% 
        filter(IndicatorID == this_indicator) %>% 
        select(-IndicatorID) %>% 
        toJSON(
            pretty = FALSE, 
            na = "null", 
            auto_unbox = TRUE
        )
    
    write_lines(
        exp_json, 
        str_c(
            "indicators/data/", this_indicator, ".json"
        )
    )
    
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
