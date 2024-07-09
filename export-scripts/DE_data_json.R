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
suppressWarnings(suppressMessages(library(jsonlite))) # needs to be version 1.8.4
suppressWarnings(suppressMessages(library(rlang)))
suppressWarnings(suppressMessages(library(svDialogs)))
suppressWarnings(suppressMessages(library(scales)))

#-----------------------------------------------------------------------------------------#
# get and set env vars
#-----------------------------------------------------------------------------------------#

# find script

set_environment_loc <-
    list.files(
        getwd(),
        pattern = "set_environment.R",
        full.names = TRUE,
        recursive = TRUE
    )

# run script

source(set_environment_loc)


#-----------------------------------------------------------------------------------------#
# Connect to database
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


#-----------------------------------------------------------------------------------------#
# create folders if they don't exist
#-----------------------------------------------------------------------------------------#

dir_create(path(base_dir, "indicators/data"))


#=========================================================================================#
# data ops ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# pulling
#-----------------------------------------------------------------------------------------#

# formatting with comma and decimal

add_comma_dec <- label_comma(accuracy = 0.1, big.mark = ",")
add_comma_num <- label_comma(accuracy = 1.0, big.mark = ",")

# using existing views

DE_data <- 
    EHDP_odbc %>% 
    tbl("DE_data") %>% 
    collect() %>% 
    arrange(
        IndicatorID,
        MeasureID,
        GeoTypeID,
        GeoID,
        TimePeriodID
    ) %>%

    mutate(
        across(
            where(is.character),
            ~ as_utf8_character(enc2native(.x))
        ),
        DisplayValue = 
            case_when(
                is.na(flag)  & is.na(Value) ~ "-",
                is.na(flag)  & number_decimal_ind == "N" ~ add_comma_num(Value),
                is.na(flag)  & number_decimal_ind == "D" ~ add_comma_dec(Value),
                is.na(flag)  & is.na(number_decimal_ind) ~ add_comma_dec(Value),
                !is.na(flag) & is.na(Value) ~ flag,
                !is.na(flag) & number_decimal_ind == "N" ~ str_c(add_comma_num(Value), flag),
                !is.na(flag) & number_decimal_ind == "D" ~ str_c(add_comma_dec(Value), flag),
                !is.na(flag) & is.na(number_decimal_ind) ~ str_c(add_comma_dec(Value), flag)
            ),
        CI = CI %>% str_replace(",", ", ") %>% str_replace(",\\s{2,}", ", ")
    ) %>% 
    
    # dropping unneeded columns
    
    select(-GeoTypeID, -number_decimal_ind, -flag)
    

#-----------------------------------------------------------------------------------------#
# saving
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# get unique indicator IDs in data
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

IndicatorIDs <- sort(unique(DE_data$IndicatorID))

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# loop through indicator IDs
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

for (i in 1:length(IndicatorIDs)) {
    
    this_indicator <- IndicatorIDs[i]
    
    # convert to JSON
    
    exp_json <- 
        DE_data %>% 
        filter(IndicatorID == this_indicator) %>% 
        select(-IndicatorID) %>% 
        toJSON(
            dataframe = "columns",
            pretty = FALSE, 
            na = "null", 
            auto_unbox = TRUE
        )
    
    # write

    write_file(
        exp_json, 
        path(base_dir, "indicators/data", this_indicator, ext = "json")
    )
    
}


#=========================================================================================#
# closing database connection ----
#=========================================================================================#

dbDisconnect(EHDP_odbc)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
