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
        server = server,
        database = db_name,
        trusted_connection = "yes",
        encoding = "utf8",
        trustservercertificate = "yes"
    )


#=========================================================================================#
# Pulling data ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# getting NR measures from site repo
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# download NR_content YAML files
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

nr_content_links <- 
    system("curl --no-progress-meter -L https://api.github.com/repos/nychealth/EH-dataportal/contents/data/globals/NR_content?ref=feature-all-site-changes-2023-12", intern = TRUE) %>% 
    fromJSON() %>% 
    pull(download_url)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# map over YAML files to get measure_ids
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

nr_indicators <- 
    nr_content_links %>% 
    map( 
        ~ yaml.load_file(.x)$report_topics %>% 
            map( ~ .x$MeasureID) %>% 
            list_c()
    ) %>% 
    list_c() %>% 
    unique() %>% 
    sort() %>% 
    tibble(indicator_id = .)


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

topic_data_for_hugo_0 <- 
    NR_data_export %>% 
    select(
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
    topic_data_for_hugo_0 %>% 
    filter(time_type %>% str_detect("(?i)Annual Average")) %>% 
    semi_join(
        topic_data_for_hugo_0,
        .,
        by = c("indicator_data_name", "neighborhood")
    ) %>% 
    mutate(has_annual = TRUE) %>% 
    select(indicator_data_name, has_annual) %>% 
    distinct()


#-----------------------------------------------------------------------------------------#
# keeping annual average measure if it exists
#-----------------------------------------------------------------------------------------#

topic_data_for_hugo <- 
    left_join(
        topic_data_for_hugo_0,
        ind_has_annual,
        by = "indicator_data_name",
        multiple = "all"
    ) %>% 
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
# Saving ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# saving one big data file, which hugo will split into data for each report
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# split by report_id, named using title

# one big report json file, read by hugo

# write JSON

topic_data_for_hugo %>% 
    toJSON(
        dataframe = "rows",
        pretty = FALSE, 
        na = "null", 
        auto_unbox = TRUE
    ) %>% 
    write_lines(paste0(base_dir, "/neighborhood-reports/data/topic_data_for_hugo.json"))


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# saving indicator names for the reports
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

nr_indicator_names <- 
    topic_data_for_hugo %>% 
    select(indicator_name, indicator_description) %>% 
    distinct() %>% 
    summarise(
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
    write_lines(paste0(base_dir, "/neighborhood-reports/data/nr_indicator_names.json"))


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
# Saving ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# saving big report data file
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

report_data_for_hugo %>% 
    toJSON(
        dataframe = "rows",
        pretty = TRUE, 
        na = "null", 
        auto_unbox = TRUE
    ) %>% 
    write_lines(paste0(base_dir, "/neighborhood-reports/data/report_data_for_hugo.json"))


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
