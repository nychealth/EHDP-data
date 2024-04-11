###########################################################################################
###########################################################################################
##
## NR_sparkbars
##
###########################################################################################
###########################################################################################

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
# some other things
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# get viz data filenames for looping
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

data_files <- dir_ls(path(base_dir, "neighborhood-reports/data/viz/"))


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# get + parse prepoared bar chart spec
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# working on a way of making this programmatic without needing the python dependency

sparkbar_spec <- fromJSON("neighborhood-reports/sparkbar_spec.json")


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# create folders if they dont exist
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

dir_create(path(base_dir, "neighborhood-reports/images/json"))


#=========================================================================================#
# Data ops ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# looping ----
#-----------------------------------------------------------------------------------------#

# 3 nested loops: data file, indicator name, neighborhood

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# loop through data files (x5)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

for (d in 1:length(data_files)) {
    
    # get file path
    
    this_file_path <- data_files[d]
    
    # get filename
    
    this_file_name <- path_file(this_file_path)
    
    # print filename
    
    cat(" ||", this_file_name, "||", sep = " ")
    
    # read in report data
    
    one_report <- 
        fromJSON(this_file_path) %>% 
        as_tibble() %>% 
        
        # probably unnecessary, but why assume?
        
        filter(geo_type == "UHF42")
    
    # get latest time for each neighborhood
    
    one_viz_latest_time <- 
        
        one_report %>% 
        mutate(end_date = as_date(end_date)) %>% 
        
        # sort latest time first, so distinct will keep that one
        
        arrange(desc(end_date)) %>% 
        distinct(indicator_data_name, geo_join_id, .keep_all = TRUE) %>% 
        
        # keep just the columns we need
        
        select(
            indicator_data_name, 
            neighborhood, 
            unmodified_data_value_geo_entity, 
            geo_join_id
        )
    
    
    # ==== geting arrays for next 2 loops ==== #
    
    indicator_data_names <- unique(sort(one_viz_latest_time$indicator_data_name))
    
    geo_join_ids <- unique(sort(one_viz_latest_time$geo_join_id))
    
    
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # loop through indicator IDs
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
    for (i in 1:length(indicator_data_names)) {
        
        # get indicator short name
        
        indicator <- indicator_data_names[i]
        
        # print indicator iter
        
        cat(" <", indicator, "> ", sep = " ")
        
        # don't bork the spec
        
        this_spec <- sparkbar_spec
        
        # filter for this indicator
        
        one_ind <- 
            one_viz_latest_time %>% 
            filter(indicator_data_name == indicator) %>% 
            
            # arrange by value
            
            arrange(unmodified_data_value_geo_entity)
        
        # insert data frame into data element - will be jsonified into the correct format
        
        this_spec$datasets$the_data <- one_ind
        
        
        # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
        # loop through neighborhoods
        # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
        
        # going to be 42, but why hard code it?
        
        for (j in 1:length(geo_join_ids)) {
            
            # print neighborhood iter
            
            # cat("[", j, "]", sep = "")
            
            # get neighborhood goe ID
            
            geo_id <- geo_join_ids[j]
            
            # insert neighborhood highlight test into spec - will be rendered by Vega-Lite
            
            this_spec$encoding$color$condition$test <- glue("datum.geo_join_id == '{geo_id}'")
            
            # serialize back into JSON
            
            this_spec_json <- toJSON(this_spec, pretty = FALSE, auto_unbox = TRUE, null = "null")
            
            # render spec into SVG
            
            system2(
                command = "node",
                args = path(base_dir, "node_modules/vega-lite/bin/vl2svg"),
                input = this_spec_json,
                stdout = path(
                    base_dir,
                    glue("neighborhood-reports/images/{indicator}_{geo_id}.svg")
                ),
                stderr = NULL,
                wait = FALSE
            )
            
        }
        
    }
    
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
