###########################################################################################-
###########################################################################################-
##
##  download geo files
##
###########################################################################################-
###########################################################################################-

# download the geography source files needed to construct the portal's TopoJSON and GeoLookup
#   files from scratch (more or less).

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
# versioned shapefiles ----
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



#=========================================================================================#
# other geo files ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# PUMA names
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# set url params
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
tigerweb_url <- "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb"

# where=STATE='36'&outFields=BASENAME,+PUMA&returnGeometry=false&f=geojson
tigerweb_query <- "where=STATE%3D%2736%27&outFields=BASENAME%2C+PUMA&returnGeometry=false&f=geojson"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# 2010
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# download and clean

 nyc_puma2010_names <- 
    read_sf(glue("{tigerweb_url}/tigerWMS_Census2010/MapServer/0/query?{tigerweb_query}")) %>% 
    as_tibble() %>% 
    filter(BASENAME %>% str_starts("NYC")) %>% 
    mutate(
        PUMA = as.integer(PUMA),
        GEONAME = str_split_i(BASENAME, "--", 2)
    ) %>% 
    select(PUMA2010 = PUMA, GEONAME)

# save 

write_csv(nyc_puma2010_names, path(base_dir, "geography/puma2010_names.csv"))

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# 2020
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# download and clean

 nyc_puma2020_names <- 
    read_sf(glue("{tigerweb_url}/tigerWMS_Census2020/MapServer/0/query?{tigerweb_query}")) %>% 
    as_tibble() %>% 
    filter(BASENAME %>% str_starts("NYC")) %>% 
    mutate(
        PUMA = as.integer(PUMA),
        GEONAME = str_split_i(BASENAME, "--", 2)
    ) %>% 
    select(PUMA2020 = PUMA, GEONAME)

# save 

write_csv(nyc_puma2020_names, path(base_dir, "geography/puma2020_names.csv"))
 

#-----------------------------------------------------------------------------------------#
# UHF 42 & UHF 34
#-----------------------------------------------------------------------------------------#

# UHFs are made from ZCTAs, with a crosswalk mapping one to other



"https://data.cityofnewyork.us/resource/pri4-ifjk.geojson"



download.file(
    "https://data.cityofnewyork.us/api/geospatial/pri4-ifjk?accessType=DOWNLOAD&method=export&format=Shapefile", 
    path(base_dir, "geography", "modzcta.zip"), 
    method = "libcurl"
)


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
