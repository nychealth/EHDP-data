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
        server = server,
        database = db_name,
        trusted_connection = "yes",
        encoding = "utf8",
        trustservercertificate = "yes"
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
        by = "report_id",
        multiple = "all"
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
        by = "data_field_name",
        multiple = "all"
    ) %>% 
    mutate(has_annual = if_else(has_annual == TRUE, TRUE, FALSE, FALSE)) %>% 
    filter(
        has_annual == FALSE | (has_annual == TRUE & str_detect(time_type, "(?i)Annual Average")),
        indicator_id != 386 | (indicator_id == 386 & str_detect(time_type, "(?i)Seasonal"))
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
# saving big report data files
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# split by report_id, named using title

report_data_list <- 
    report_data %>% 
    select(-indicator_description) %>% 
    group_by(report_id) %>% 
    group_split() %>% 
    walk(
        ~ write_csv(
            .x,
            paste0(base_dir, "/neighborhood-reports/data/", str_replace_all(unique(.x$title), " ", "_"), "_data.csv")
            
        )
    )


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# saving indicator names for the reports
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

nr_indicator_names <- 
    report_data %>% 
    select(title, indicator_name, indicator_description) %>% 
    distinct() %>% 
    group_by(title) %>% 
    transmute(
        title = title %>% str_replace_all(" ", "_"),
        indicator_names = list(unlist(indicator_name)),
        indicator_descriptions = list(unlist(indicator_description))
    ) %>% 
    ungroup() %>% 
    distinct()

nr_indicator_names_json <- 
    toJSON(
        nr_indicator_names, 
        pretty = TRUE, 
        na = "null", 
        auto_unbox = TRUE
    )

write_lines(
    nr_indicator_names_json, 
    paste0(base_dir, "/neighborhood-reports/data/nr_indicator_names.json")
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
