###########################################################################################-
###########################################################################################-
##
##  download geo shapefiles
##
###########################################################################################-
###########################################################################################-

#=========================================================================================#
# Setting up ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# Loading libraries
#-----------------------------------------------------------------------------------------#

suppressWarnings(suppressMessages(library(glue)))
suppressWarnings(suppressMessages(library(readr)))
suppressWarnings(suppressMessages(library(purrr)))
suppressWarnings(suppressMessages(library(fs)))
suppressWarnings(suppressMessages(library(stringr)))

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
# set geo file params
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# base url
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

base_url <- "https://s-media.nyc.gov/agencies/dcp/assets/files/zip/data-tools/bytes"


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# file names and version
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

geos    <- read_file(path(base_dir, "geography/geos"))
release <- read_file(path(base_dir, "geography/release"))


#=========================================================================================#
# data ops ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# delete existing files
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# get existing
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

geo_files <- 
    dir_ls(path(base_dir, "geography")) %>% 
    keep( ~ str_detect(.x, paste0(geos, collapse = "|")))

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# get release number
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

geo_files_release <- 
    geo_files %>% 
    str_extract("(_)(\\d{2}[a-z])", group = 2) %>% 
    max()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# check file version against release
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

up_to_date <- geo_files_release == release

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# delete files and folders if not up to date
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

if (!up_to_date) {
    
    # first print a message
    
    cat("Updating", geo_files_release, "to", release, "\n")
    
    # now actually delete
    
    geo_files %>% path_filter(regexp = "\\.zip") %>% walk( ~ file_delete(.x))
    geo_files %>% path_filter(regexp = "\\.zip", invert = TRUE) %>% walk( ~ dir_delete(.x))
    
} 


#-----------------------------------------------------------------------------------------#
# download updated files
#-----------------------------------------------------------------------------------------#

if (!up_to_date) {

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # build arguments to `download.file`
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
    # set download URLs
    
    urls <- glue("{base_url}/{geos}_{release}.zip")
    
    # set downloaded file names
    
    destfiles <- path(base_dir, glue("geography/{geos}_{release}.zip"))
    
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # download
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
    download.file(urls, destfiles, method = "libcurl")
    
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # unzip
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
    destfiles %>% walk( ~ unzip(.x, exdir = path(base_dir, "geography")))
    
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # list zip files
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
    zip_files <- 
        dir_ls(path(base_dir, "geography"), glob = "*.zip") %>% 
        keep( ~ str_detect(.x, paste0(geos, collapse = "|")))
    
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # delete zip files
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
    zip_files %>% walk( ~ file_delete(.x))

}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
