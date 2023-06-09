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

EHDP_stage <-
    dbConnect(
        drv = odbc::odbc(),
        driver = paste0("{", odbc_driver, "}"),
        # server = "DESKTOP-PU7DGC1",
        server = "SQLIT04A",
        database = "BESP_IndicatorAnalysis",
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
        "display_data_type",
        "geo_entity",
        "geo_type",
        "i_to_i",
        "indicator_definition",
        "indicator_group",
        "indicator_group_title",
        "indicator_year",
        "internal_indicator",
        "m_to_m",
        "measure_compare",
        # "measure_labels",
        "measurement_type",
        "report",
        "report_content",
        "report_geo_type",
        "report_topic",
        "source",
        "source_indicator",
        "subtopic_indicators",
        "subtopic_internal_indicator",
        "subtopic_measuremnt_type_linkage",
        "unreliability"
    )

for (i in 1:length(table_names)) {
    
    print(paste0(i, "/", length(table_names), ": ", table_names[i]))
    
    table_name <- table_names[i]
    
    # JS json output converts numbers to character, so we do that here too, to make the diffs meaningful
    
    table_data <-
        EHDP_stage %>% 
        tbl(table_name) %>% 
        collect() %>% 
        select(-contains("date")) %>% 
        mutate(
            across(where(is_logical), ~ as.integer(.x)),
            across(everything(), ~ as_utf8_character(enc2native(as.character(.x)))),
        )
    
    
    # rename the repurposed "creator_id" column in subtopic_indicators
    
    if (table_name == "subtopic_indicators") {
        
        table_data <- 
            table_data %>% 
            rename(stage_flag = creator_id)
        
    }
    
    # drop unneeded columns
    
    table_data <- 
        table_data %>% 
        select(
            -any_of(
                c(
                    "creator_id",
                    "modifier_id",
                    "cdc_ind",
                    "bar_build_a_table",
                    "sort_key",
                    "FileName",
                    "secure_flag",
                    "status",
                    "goal",
                    "label_set_id",
                    "CountIndicatorRequest",
                    "geographic_supress",
                    "report_footer",
                    "static_pdf",
                    "use_most_recent_year",
                    "top_flag",
                    "notes"
                )
            )
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
        paste0("data-editor/data/full_data/BESP_IndicatorAnalysis/", table_name, ".json")
    )
    
}


#-----------------------------------------------------------------------------------------#
# indicator_measure_names ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# for joining
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

indicator_measure_names <- 
    EHDP_stage %>% 
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
    paste0("data-editor/data/full_data/BESP_IndicatorAnalysis/indicator_measure_names.json")
)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# concat measure names / ids, for flexdatalist
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

indicator_measure_names_concat <- 
    EHDP_stage %>% 
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
    paste0("data-editor/data/full_data/BESP_IndicatorAnalysis/indicator_measure_names_concat.json")
)


#-----------------------------------------------------------------------------------------#
# indicator_measure_names ----
#-----------------------------------------------------------------------------------------#

dbDisconnect(EHDP_stage)


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
