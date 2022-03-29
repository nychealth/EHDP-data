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

library(tidyverse)
library(DBI)
library(dbplyr)
library(odbc)
library(lubridate)
library(fs)
library(jsonlite)

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
        database = "BESP_Indicator",
        trusted_connection = "yes"
    )


#=========================================================================================#
# Pulling data ----
#=========================================================================================#

# using existing views

EXP_data_export <- 
    EHDP_odbc %>% 
    tbl("EXP_data_export") %>% 
    arrange(
        IndicatorID,
        MeasureID,
        GeoTypeID,
        GeoID,
        desc(Time)
    ) %>%
    select(-GeoTypeID) %>% 
    collect() 

# closing connection

dbDisconnect(EHDP_odbc)

#=========================================================================================#
# Writing JSON ----
#=========================================================================================#

IndicatorIDs <- unique(EXP_data_export$IndicatorID)

for (i in 1:length(IndicatorIDs)) {
    
    this_indicator <- IndicatorIDs[i]
    
    cat(i, "/", length(IndicatorIDs), " [", this_indicator, "]", "\n", sep = "")
    
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
