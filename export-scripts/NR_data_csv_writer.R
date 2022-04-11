###########################################################################################-
###########################################################################################-
##
##  Writing neighborhod report data
##
###########################################################################################-
###########################################################################################-

# This script writes data for the neighborhood reports, all saved as CSV. The data files
#   contain data broken out by report (e.g., Asthma and the Environment) and by
#   Measure (i.e., Indicator x Time Period)

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

#-----------------------------------------------------------------------------------------#
# Connecting to BESP_Indicator database
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# determining which driver to use
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

odbc_driver <- 
    odbcListDrivers() %>% 
    pull(name) %>% 
    unique() %>% 
    str_subset("ODBC Driver") %>% 
    sort(decreasing = TRUE) %>% 
    head(1)

if (length(odbc_driver) == 0) odbc_driver <- "SQL Server"


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# connecting using Windows auth with no DSN
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

EHDP_odbc <-
    dbConnect(
        drv = odbc::odbc(),
        driver = paste0("{", odbc_driver, "}"),
        server = "SQLIT04A",
        database = "BESP_Indicator",
        trusted_connection = "yes"
    )


#=========================================================================================#
# Pulling and saving data ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# Pulling
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# getting list of neighborhood reports
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

report_list <- 
    EHDP_odbc %>% 
    tbl("ReportPublicList") %>% 
    filter(report_id != 80) %>% 
    collect()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# getting neighborhood report data
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# also joining report names to report data

report_data_0 <- 
    EHDP_odbc %>% 
    tbl("ReportData") %>% 
    filter(geo_type == "UHF42", report_id != 80) %>% 
    collect() %>% 
    left_join(
        report_list %>% select(report_id, title),
        .,
        by = "report_id"
    ) %>% 
    mutate(
        time_type = str_trim(time_type),
        data_field_name = str_replace(data_field_name, "PM2\\.", "PM2-")
    )


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# identifying indicators that have an annual average measure
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

ind_has_annual <- 
    report_data_0 %>% 
    filter(time_type %>% str_detect("(?i)Annual Average")) %>% 
    semi_join(
        report_data_0,
        .,
        by = c("data_field_name", "neighborhood")
    ) %>% 
    mutate(has_annual = TRUE) %>% 
    select(data_field_name, has_annual) %>% 
    distinct()


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# keeping annual average measure if it exists
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

report_data <- 
    left_join(
        report_data_0,
        ind_has_annual,
        by = "data_field_name"
    ) %>% 
    mutate(has_annual = if_else(has_annual == TRUE, TRUE, FALSE, FALSE)) %>% 
    filter(
        has_annual == FALSE | 
            (has_annual == TRUE & str_detect(time_type, "(?i)Annual Average")),
        indicator_id != 386 | 
            (indicator_id == 386 & str_detect(time_type, "(?i)Seasonal"))
    ) %>% 
    select(-has_annual)


#-----------------------------------------------------------------------------------------#
# Saving ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# saving big report data files
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# split by report_id, named using title

report_data_list <- 
    report_data %>% 
    group_by(report_id) %>% 
    group_split() %>% 
    walk(
        ~ write_csv(
            .x,
            paste0("neighborhoodreports/data/", unique(.x$title), "_data.csv")
            
        )
    )


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# saving measure-specific data
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

measure_data_list <-
    report_data %>% 
    select(
        data_field_name,
        end_date,
        geo_join_id, 
        neighborhood,
        data_value, 
        message
    ) %>% 
    distinct() %>% 
    group_by(data_field_name, neighborhood) %>% 
    arrange(desc(end_date)) %>% 
    slice(1) %>% 
    select(-end_date) %>% 
    group_by(data_field_name) %>% 
    group_split() %>% 
    walk(
        ~ write_csv(
            select(.x, -data_field_name),
            paste0("neighborhoodreports/data/", unique(.x$data_field_name), ".csv")
        )
    )


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# saving measure-specific data with trend variables
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

measure_data_trend_list <- 
    report_data %>% 
    select(
        data_field_name,
        start_date, 
        time, 
        geo_join_id, 
        neighborhood,
        data_value, 
        message
    ) %>% 
    distinct() %>% 
    group_by(data_field_name) %>% 
    group_split() %>% 
    walk(
        ~ write_csv(
            select(.x, -data_field_name), 
            paste0("neighborhoodreports/data/", unique(.x$data_field_name), "_trend.csv")
            
        )
    )


#=========================================================================================#
# Cleaning up ----
#=========================================================================================#

dbDisconnect(EHDP_odbc)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
