###########################################################################################
###########################################################################################
##
## NR_sparkbars
##
###########################################################################################
###########################################################################################

#=========================================================================================#
# Setting up
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
suppressWarnings(suppressMessages(library(glue)))

#-----------------------------------------------------------------------------------------#
# set summarise options
#-----------------------------------------------------------------------------------------#

options(dplyr.summarise.inform = FALSE)

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
# create folders if they dont exist
#-----------------------------------------------------------------------------------------#

dir_create(path(base_dir, "neighborhood-reports/images/json"))


#=========================================================================================#
# Pulling & writing data ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# get viz data files
#-----------------------------------------------------------------------------------------#

# data_files = os.listdir(base_dir + "/neighborhood-reports/data/viz/")

data_files <- dir_ls(path(base_dir, "neighborhood-reports/data/viz/"))

#-----------------------------------------------------------------------------------------#
# all metadata
#-----------------------------------------------------------------------------------------#

chart <- fromJSON("neighborhood-reports/chart.json")

#-----------------------------------------------------------------------------------------#
# all metadata
#-----------------------------------------------------------------------------------------#

one_viz <- 
    fromJSON(data_files[1]) %>% 
    as_tibble() %>% 
    filter(geo_type == "UHF42")

one_viz_latest_time <- 
    one_viz %>% 
    mutate(end_date = as_date(end_date)) %>% 
    arrange(desc(end_date)) %>% 
    distinct(indicator_data_name, geo_join_id, .keep_all = TRUE) %>% 
    arrange(geo_join_id) %>% 
    select(
        indicator_data_name, 
        neighborhood, 
        unmodified_data_value_geo_entity, 
        geo_join_id
    )

# indicator_data_names <- unique(sort(one_viz_latest_time$indicator_data_name))
# 
# geo_join_ids <- unique(sort(one_viz_latest_time$geo_join_id))
# 
# for (i in 1:length(indicator_data_names)) {
#     
#     indicator <- indicator_data_names[i]
#     
#     one_ind <- 
#         one_viz_latest_time %>% 
#         filter(indicator_data_name == indicator) %>% 
#         arrange(unmodified_data_value_geo_entity) %>% 
#         mutate(sort_order = 1:nrow(.))
#     
#     indicator_plot <- 
#         one_ind %>% 
#         ggplot(aes(sort_order, unmodified_data_value_geo_entity)) +
#         theme_void()
#     
#     # going to be 42, but why hard code it?
#     
#     for (k in 1:length(geo_join_ids)) {
#         
#         geo <- geo_join_ids[k]
#         
#         one_geo <- one_ind %>% filter(geo_join_id == geo)
#         
#         neighborhood_plot <- 
#             indicator_plot +
#             geom_col(aes(fill = geo_join_id == geo, `aria-label` = neighborhood), show.legend = FALSE)
#         
#     }
#     
# }



indicator_data_names <- unique(sort(one_viz_latest_time$indicator_data_name))

geo_join_ids <- unique(sort(one_viz_latest_time$geo_join_id))



for (i in 1:length(indicator_data_names)) {
    
    cat(" <", i, "> ", sep = " ")
    
    this_chart <- chart
    
    indicator <- indicator_data_names[i]
    
    one_ind <- 
        one_viz_latest_time %>% 
        filter(indicator_data_name == indicator) %>% 
        arrange(unmodified_data_value_geo_entity)
    
    this_chart$datasets$the_data <- one_ind
    
    # going to be 42, but why hard code it?
    
    for (k in 1:length(geo_join_ids)) {
        
        cat("[", k, "]", sep = "")
        
        geo_id <- geo_join_ids[k]
        
        this_chart$encoding$color$condition$test <- glue("(datum.geo_join_id == '{geo_id}')")
        
        this_chart_json <- toJSON(this_chart, pretty = FALSE, auto_unbox = TRUE, null = "null")
        
        # write_file(this_chart_json, glue("neighborhood-reports/images/json/{indicator}_{geo_id}.json"))
        
        system2(
            command = "node",
            args = "node_modules/vega-lite/bin/vl2svg",
            input = this_chart_json,
            stdout = glue("neighborhood-reports/images/svg/{indicator}_{geo_id}.svg"),
            wait = FALSE
        )
        
    }
    
}


# node node_modules\vega-lite\bin\vl2svg C:\Users\Chris\Documents\DOHMH\Programming\BESP\EHDP-data\neighborhood-reports\images\json\bikeEDAA_201.json


