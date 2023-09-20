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
suppressWarnings(suppressMessages(library(jsonlite)))
suppressWarnings(suppressMessages(library(rlang)))
suppressWarnings(suppressMessages(library(svDialogs)))
suppressWarnings(suppressMessages(library(scales)))

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
    
    # default to network server
    
    server <- "SQLIT04A"
    
    Sys.setenv(server = server)

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
        server = server,
        database = db_name,
        trusted_connection = "yes",
        # encoding = "utf8",
        encoding = "latin1",
        trustservercertificate = "yes"
    )


#=========================================================================================#
# Pulling data ----
#=========================================================================================#

# formatting with comma and decimal

add_comma_dec <- label_comma(accuracy = 0.1, big.mark = ",")
add_comma_num <- label_comma(accuracy = 1.0, big.mark = ",")

# using existing views

EXP_data_export <- 
    EHDP_odbc %>% 
    tbl("EXP_data_export") %>% 
    collect() %>% 
    arrange(
        IndicatorID,
        MeasureID,
        GeoTypeID,
        GeoID,
        desc(Time)
    ) %>%

    mutate(
        across(
            where(is.character),
            ~ as_utf8_character(enc2native(.x))
            # ~ enc2native(.x)
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
    

# closing connection

dbDisconnect(EHDP_odbc)


#=========================================================================================#
# Writing JSON ----
#=========================================================================================#

IndicatorIDs <- sort(unique(EXP_data_export$IndicatorID))

for (i in 1:length(IndicatorIDs)) {
    
    this_indicator <- IndicatorIDs[i]
    
    # cat(i, "/", length(IndicatorIDs), " [", this_indicator, "]", "\n", sep = "")
    
    exp_json <- 
        EXP_data_export %>% 
        filter(IndicatorID == this_indicator) %>% 
        select(-IndicatorID) %>% 
        toJSON(
            pretty = FALSE, 
            na = "null", 
            auto_unbox = TRUE
        )
    
    write_lines(
        exp_json, 
        str_c(base_dir, "/indicators/data/", this_indicator, ".json")
    )
    
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
