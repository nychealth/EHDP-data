###########################################################################################-
###########################################################################################-
##
## exporting data tables
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
suppressWarnings(suppressMessages(library(rlang)))
suppressWarnings(suppressMessages(library(jsonlite)))

#-----------------------------------------------------------------------------------------#
# Connecting to database
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# get driver
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
# connect
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

EHDP_data <-
    dbConnect(
        drv = odbc::odbc(),
        driver = paste0("{", odbc_driver, "}"),
        server = "DESKTOP-PU7DGC1",
        database = "BESP_EHDP_data",
        trusted_connection = "yes",
        encoding = "latin1",
        trustservercertificate = "yes"
    )


#=========================================================================================#
# exporting ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# tables and views ----
#-----------------------------------------------------------------------------------------#

table_names <- 
    c(
        "indicator",
        "measurement_type",
        "geography_type",
        "geography",
        "time_period",
        "unit",
        "source",
        "data_flag",
        "measure",
        "source_measure",
        "visualization_type",
        "visualization",
        "dataset",
        "visualization_dataset_flags"
    )

for (i in 1:length(table_names)) {
    
    print(paste0(i, "/", length(table_names), ": ", table_names[i]))
    
    table_name <- table_names[i]
    
    # JS json output converts numbers to character, so we do that here too, to make the diffs meaningful
    
    table_data <-
        EHDP_data %>% 
        tbl(table_name) %>% 
        collect() %>% 
        mutate(
            across(where(is_logical), ~ as.integer(.x)),
            across(everything(), ~ as_utf8_character(enc2native(as.character(.x))))
        )
    
    # save as named columns, instead of array of objects

    table_json <- 
        toJSON(
            table_data, 
            dataframe = "columns",
            pretty = FALSE, 
            na = "string"
        )

    write_file(
        table_json, 
        paste0("data-editor/data/full_data/BESP_EHDP_data/", table_name, ".json")
    )
    
}


#-----------------------------------------------------------------------------------------#
# indicator_measure_names ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# for joining
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

indicator_measure_names <- 
    EHDP_data %>% 
    tbl("indicator_measure_names") %>% 
    collect() %>% 
    distinct() %>% 
    mutate(across(everything(), ~ as_utf8_character(enc2native(as.character(.x)))))

# # save as named columns, instead of array of objects

indicator_measure_names_json <- 
    toJSON(
        indicator_measure_names, 
        dataframe = "columns",
        pretty = FALSE, 
        na = "string"
    )

write_file(
    indicator_measure_names_json, 
    paste0("data-editor/data/full_data/BESP_EHDP_data/indicator_measure_names.json")
)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# concat measure names / ids, for flexdatalist
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

indicator_measure_names_concat <- 
    EHDP_data %>% 
    tbl("indicator_measure_names_concat") %>% 
    collect() %>% 
    distinct() %>% 
    mutate(across(everything(), ~ as_utf8_character(enc2native(as.character(.x)))))

# save as of array of objects, to work with flexdatalist

indicator_measure_names_concat_json <- 
    toJSON(
        indicator_measure_names_concat, 
        dataframe = "rows",
        pretty = FALSE, 
        na = "string"
    )

write_file(
    indicator_measure_names_concat_json, 
    paste0("data-editor/data/full_data/BESP_EHDP_data/indicator_measure_names_concat.json")
)


#-----------------------------------------------------------------------------------------#
# indicator_measure_names ----
#-----------------------------------------------------------------------------------------#

dbDisconnect(EHDP_data)


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
