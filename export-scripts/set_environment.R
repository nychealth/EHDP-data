###########################################################################################-
###########################################################################################-
##
## setting environemnt parameters
##
###########################################################################################-
###########################################################################################-

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

if (data_env == "" & interactive()) {
    
    # ask and set
    
    data_env <-
        dlgInput(
            message = "staging [s] or production [p]?",
            rstudio = FALSE
        )$res
    
    Sys.setenv(data_env = data_env)
    
} else {
    # default to staging
    data_env <- "s"
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


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
