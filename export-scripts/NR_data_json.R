###########################################################################################-
###########################################################################################-
##
##  NR_data_writer
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
suppressWarnings(suppressMessages(library(jsonlite))) # needs to be version 1.8.4
suppressWarnings(suppressMessages(library(svDialogs)))
suppressWarnings(suppressMessages(library(yaml)))
suppressWarnings(suppressMessages(library(gert)))
suppressWarnings(suppressMessages(library(httr)))

#-----------------------------------------------------------------------------------------#
# get and set env vars
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# base_dir for absolute path
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

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


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# server
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

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


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# database
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

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

dir_create(
    c(
        path(base_dir, "neighborhood-reports/metadata"),
        path(base_dir, "neighborhood-reports/data/report"),
        path(base_dir, "neighborhood-reports/data/viz")
    )
)


#=========================================================================================#
# data ops ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# getting NR measures from site repo
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# download NR_content YAML files
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# download yaml file

nr_content_links <- 
    GET(
        paste0(
            "https://api.github.com/repos/nychealth/EH-dataportal/contents/data/globals/NR_content?ref=",
            Sys.getenv("site_branch")
        )
    ) %>% 
    content(as = "text") %>% 
    fromJSON() %>%
    pull(download_url)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# map over YAML files to get measure_ids
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# using base R short function format to make mapped objects unambiguous and usable inside lower levels

nr_indicators <- 
    nr_content_links %>% 
    map_dfr( 
        
        function (x) {
            read_file(x) %>% 
            yaml.load() %>% 
            pluck("report_topics") %>% 
            map_dfr(
                function (y) {
                    as_tibble(y) %>% 
                    select(report_topic, MeasureID) %>% 
                    transmute(
                        report = x %>% path_file() %>% path_ext_remove() %>% unique(),
                        report_topic = report_topic %>% str_remove_all(":"),
                        indicator_id = MeasureID
                    )
                }
            )
        }
    )


#-----------------------------------------------------------------------------------------#
# selecting columns
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# add list of indicators to database
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# overwrite every time this script is run, but persist between runs

dbWriteTable(
    EHDP_odbc,
    name = "nr_indicators",
    value = nr_indicators,
    append = FALSE,
    overwrite = TRUE
)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# pull from view
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

adult_measures <- c(657, 659, 661, 1175, 1180, 1182)

NR_data_export <- 
    EHDP_odbc %>% 
    tbl("NR_data_base") %>% 
    arrange(MeasureID, geo_entity_id) %>% 
    collect() %>% 
    mutate(
        indicator_short_name = 
            case_when(
                MeasureID %in% adult_measures ~ str_replace(indicator_short_name, "\\(children\\)", "(adults)"),
                TRUE ~ indicator_short_name
            ),
        indicator_data_name = str_replace(indicator_data_name, "PM2\\.", "PM2-"),
        summary_bar_svg = str_replace(summary_bar_svg, "PM2\\.", "PM2-"),
        time_type = str_trim(time_type),
        across(
            c(indicator_name, indicator_description, measurement_type, units),
            ~ as_utf8_character(enc2native(.x))
        )
    )


#=========================================================================================#
# JSON data for Vega Lite viz and data download ----
#=========================================================================================#

# Hugo will produce the CSVs this is looking for

#-----------------------------------------------------------------------------------------#
# selecting columns
#-----------------------------------------------------------------------------------------#

viz_data_for_hugo_0 <- 
    NR_data_export %>% 
    select(
        report,
        report_topic,
        MeasureID,
        IndicatorID,
        indicator_data_name,
        indicator_name,
        indicator_description,
        measurement_type,
        units,
        year_id,
        start_date,
        end_date,
        time_type,
        time,
        geo_entity_id,
        geo_join_id,
        geo_type,
        neighborhood,
        data_value_geo_entity,
        unmodified_data_value_geo_entity,
        nbr_data_note
    )


#-----------------------------------------------------------------------------------------#
# identifying indicators that have an annual average measure
#-----------------------------------------------------------------------------------------#

ind_has_annual <- 
    viz_data_for_hugo_0 %>% 
    filter(time_type %>% str_detect("(?i)Annual Average")) %>% 
    semi_join(
        viz_data_for_hugo_0,
        .,
        by = c("indicator_data_name", "neighborhood")
    ) %>% 
    mutate(has_annual = TRUE) %>% 
    select(indicator_data_name, has_annual) %>% 
    distinct()


#-----------------------------------------------------------------------------------------#
# keeping annual average measure if it exists
#-----------------------------------------------------------------------------------------#

viz_data_for_hugo <- 
    left_join(
        viz_data_for_hugo_0,
        ind_has_annual,
        by = "indicator_data_name",
        multiple = "all"
    ) %>% 
    # left_join(
    #     .,
    #     nr_indicators,
    #     by = c("MeasureID" = "indicator_id"),
    #     relationship = "many-to-many"
    # ) %>% 
    mutate(has_annual = if_else(has_annual == TRUE, TRUE, FALSE, FALSE)) %>% 
    filter(
        has_annual == FALSE | (has_annual == TRUE & str_detect(time_type, "(?i)Annual Average")),
        MeasureID != 386 | (MeasureID == 386 & str_detect(time_type, "(?i)Seasonal"))
    ) %>% 
    select(-has_annual) %>% 
    mutate(
        across(
            where(is.character),
            ~ as_utf8_character(enc2native(.x))
        )
    )


#-----------------------------------------------------------------------------------------#
# saving ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# one viz dataset for each report
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# split by report, named using title, then write JSON

viz_data_for_hugo %>% 
    group_by(report) %>% 
    group_walk(
        ~ toJSON(
            .x,
            dataframe = "rows",
            pretty = FALSE, 
            na = "null", 
            auto_unbox = TRUE
        ) %>% 
            write_file(path(base_dir, "neighborhood-reports/data/viz", unique(.x$report), ext = "json")),
        .keep = TRUE
    )
    


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# indicator names for the reports
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# get unique names and descriptions

nr_indicator_names <- 
    viz_data_for_hugo %>% 
    select(title = report, indicator_name, indicator_description) %>% 
    distinct() %>% 
    summarise(
        title = list(unlist(title)),
        indicator_names = list(unlist(indicator_name)),
        indicator_descriptions = list(unlist(indicator_description))
    )

# write JSON

nr_indicator_names %>% 
    toJSON(
        dataframe = "rows",
        pretty = TRUE, 
        na = "null", 
        auto_unbox = TRUE
    ) %>% 
    write_file(path(base_dir, "neighborhood-reports/metadata/nr_indicator_names.json"))


#=========================================================================================#
# JSON for NR page ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# selecting columns
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# counting distinct times
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

time_count <- 
    NR_data_export %>% 
    distinct(
        geo_type,
        geo_entity_id,
        MeasureID,
        year_id
    ) %>% 
    count(
        geo_type,
        geo_entity_id,
        MeasureID, 
        name = "TimeCount"
    )


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# keeping only most recent
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# `NR_data_export` won't be the right length, but `report_data_for_hugo` will be

report_data_for_hugo <- 
    NR_data_export %>% 
    select(
        report,
        report_topic,
        MeasureID,
        rankReverse,
        indicator_name,
        indicator_short_name,
        indicator_long_name,
        IndicatorID,
        indicator_data_name,
        indicator_description,
        units,
        measurement_type,
        indicator_neighborhood_rank,
        data_value_geo_entity,
        unmodified_data_value_geo_entity,
        data_value_boro,
        data_value_nyc,
        data_value_rank,
        nbr_data_note,
        data_source_list,
        geo_type,
        geo_entity_id,
        neighborhood,
        borough_name,
        zip_code,
        year_id,
        summary_bar_svg,
        end_date
    ) %>% 
    arrange(
        geo_type,
        geo_entity_id,
        MeasureID,
        desc(end_date)
    ) %>% 
    distinct(
        geo_type,
        geo_entity_id,
        MeasureID,
        .keep_all = TRUE
    ) %>% 
    left_join(
        .,
        time_count,
        c("geo_type", "geo_entity_id", "MeasureID")
    ) %>% 
    mutate(trend_flag = if_else(TimeCount > 1, 1L, 0L)) %>% 
    select(-geo_type)


#-----------------------------------------------------------------------------------------#
# saving ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# one report dataset for each report x topic section
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

report_data_for_hugo %>% 
    group_by(report, report_topic) %>% 
    group_walk(
        ~ toJSON(
            .x,
            dataframe = "rows",
            pretty = FALSE, 
            na = "null", 
            auto_unbox = TRUE
        ) %>% 
            write_file(
                path(
                    base_dir, "neighborhood-reports/data/report",
                    paste0(unique(.x$report), " ", unique(.x$report_topic), ".json")
                )
            ),
        .keep = TRUE
    )


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
