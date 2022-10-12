###########################################################################################-
###########################################################################################-
##
##  NR_json_writer
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
suppressWarnings(suppressMessages(library(rlang)))
suppressWarnings(suppressMessages(library(jsonlite)))
suppressWarnings(suppressMessages(library(svDialogs)))

#-----------------------------------------------------------------------------------------#
# get base_dir for absolute path
#-----------------------------------------------------------------------------------------#

# get envionment var

base_dir <- Sys.getenv("base_dir")

if (base_dir == "") {
    
    base_dir <- path_dir(getwd())
    Sys.setenv(data_env = base_dir)

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
        database = db_name,
        trusted_connection = "yes"
    )


#=========================================================================================#
# Pulling data ----
#=========================================================================================#

# using existing views

#-----------------------------------------------------------------------------------------#
# Top-level report details
#-----------------------------------------------------------------------------------------#

report_level_1 <- 
    EHDP_odbc %>% 
    tbl("reportLevel1") %>% 
    select(
        report_id,
        report_title,
        geo_entity_name,
        report_description,
        report_text,
        report_footer,
        zip_code,
        unreliable_text
    ) %>% 
    collect() %>% 
    mutate(
        data_download_loc = 
            str_c(
                report_title %>% 
                    str_replace_all("[:punct:]", "") %>% 
                    str_replace_all(" ", "_"),
                "_data.csv"
            )
    )


#-----------------------------------------------------------------------------------------#
# Report topic details
#-----------------------------------------------------------------------------------------#

report_level_2 <- 
    EHDP_odbc %>% 
    tbl("reportLevel2") %>% 
    select(
        report_id,
        report_topic,
        report_topic_id,
        report_topic_description,
        borough_name,
        geo_entity_id,
        geo_entity_name,
        city,
        compared_with
    ) %>% 
    collect()


#-----------------------------------------------------------------------------------------#
# Report data
#-----------------------------------------------------------------------------------------#

adult_indicators <- c(657, 659, 661, 1175, 1180, 1182)

report_level_3 <- 
    EHDP_odbc %>% 
    tbl("reportLevel3") %>% 
    select(
        report_id,
        report_topic_id,
        geo_entity_id,
        indicator_id,
        indicator_data_name,
        indicator_short_name,
        indicator_URL,
        indicator_name,
        indicator_description,
        sort_key,
        data_value_nyc,
        data_value_borough,
        data_value_geo_entity,
        unmodified_data_value_geo_entity,
        nabe_data_note,
        trend_flag,
        data_value_rank,
        indicator_neighborhood_rank,
        measurement_type,
        units
    ) %>% 
    collect() %>% 
    mutate(
        indicator_short_name = 
            case_when(
                indicator_id %in% adult_indicators ~ 
                    str_replace(indicator_short_name, "\\(children\\)", "(adults)"),
                TRUE ~ indicator_short_name
            ),
        indicator_data_name = str_replace(indicator_data_name, "PM2\\.", "PM2-"),
        summary_bar_svg = 
            str_c(
                indicator_data_name,
                "_",
                geo_entity_id,
                ".svg"
            ),
        
        across(
            c(indicator_name, indicator_description, measurement_type, units),
            ~ as_utf8_character(enc2native(.x))
        )
        
    ) %>% 
    select(-indicator_id)


# closing connection

dbDisconnect(EHDP_odbc)


#=========================================================================================#
# Nesting and joining data ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# Nesting by report_id, report_topic_id, geo_entity_id
#-----------------------------------------------------------------------------------------#

report_level_3_nested <- 
    report_level_3 %>%
    group_by(report_id, report_topic_id, geo_entity_id) %>% 
    group_nest(.key = "report_topic_data", keep = FALSE) %>% 
    ungroup()

#-----------------------------------------------------------------------------------------#
# combining with topic details by nesting vars
#-----------------------------------------------------------------------------------------#

report_level_23_nested <- 
    left_join(
        report_level_2,
        report_level_3_nested,
        by = c("report_id", "report_topic_id", "geo_entity_id")
    ) 

#-----------------------------------------------------------------------------------------#
# adding report_title to nested data for filtering in the loop
#-----------------------------------------------------------------------------------------#

report_level_123_nested <- 
    left_join(
        report_level_1 %>% select(report_id, geo_entity_name, report_title),
        report_level_23_nested,
        by = c("report_id", "geo_entity_name")
    ) %>% 
    arrange(geo_entity_name, report_title, report_topic) %>% 
    select(-c(report_id, report_topic_id, geo_entity_id))


#-----------------------------------------------------------------------------------------#
# dropping unneeded report details columns
#-----------------------------------------------------------------------------------------#

report_level_1_small <- 
    report_level_1 %>% 
    select(
        report_title,
        report_description,
        report_text,
        report_footer,
        zip_code,
        unreliable_text,
        data_download_loc,
        geo_entity_name
    ) %>% 
    arrange(geo_entity_name, report_title)


#=========================================================================================#
# Writing JSON ----
#=========================================================================================#

for (i in 1:nrow(report_level_1_small)) {
    
    #-----------------------------------------------------------------------------------------#
    # looping through unique spec and using it to filter data
    #-----------------------------------------------------------------------------------------#
    
    report_spec <- report_level_1_small[i, ]
    
    # This is safer than splitting by the spec outside the loop and then indexing with i. 
    #   It's probably slower, but that's inconsequential here.
    
    report_content <- 
        semi_join(
            report_level_123_nested, 
            report_spec,
            by = c("geo_entity_name", "report_title")
        ) %>% 
        select(-report_title)
    
    #-----------------------------------------------------------------------------------------#
    # constructing a list with the exact right nesting structure
    #-----------------------------------------------------------------------------------------#
    
    report_list <- 
        list(
            "report" = 
                c(
                    c(report_spec), 
                    "report_content" = list(report_content)
                )
        )
    
    #-----------------------------------------------------------------------------------------#
    # converting to JSON
    #-----------------------------------------------------------------------------------------#
    
    report_json <- 
        toJSON(
            report_list, 
            pretty = FALSE, 
            na = "null", 
            auto_unbox = TRUE
        )
    
    #-----------------------------------------------------------------------------------------#
    # writing JSON
    #-----------------------------------------------------------------------------------------#
    
    write_lines(
        report_json, 
        str_c(
            base_dir, "/neighborhood-reports/reports/",
            str_replace_all(report_spec$report_title, "[:punct:]", ""),
            " in ",
            report_spec$geo_entity_name,
            ".json"
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
