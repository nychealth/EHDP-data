###########################################################################################-
###########################################################################################-
##
##  Creating GeoLookup.csv
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
suppressWarnings(suppressMessages(library(sf)))
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
        trusted_connection = "yes",
        encoding = "latin1"
    )


#=========================================================================================#
# pulling, calculating, joining ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# pulling geo_type & geo_entity ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# geo_type
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

geo_type <- 
    EHDP_odbc %>% 
    tbl("geo_type") %>% 
    select(
        geo_type_id, 
        geo_type_name,
        geo_type_description
    ) %>% 
    filter(
        !geo_type_name %in% 
            c(
                "UHF33",
                "State",
                "National",
                "Nationwide",
                "AllBoroughs",
                "MCL",
                "County",
                "Zip"
            )
    ) %>% 
    collect()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# geo_entity
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

geo_entity <- 
    EHDP_odbc %>% 
    tbl("geo_entity") %>% 
    select(
        geo_type_id, 
        geo_entity_id,
        name,
        borough_id
    ) %>% 
    mutate(
        Borough = 
            case_when(
                borough_id == 1 ~ "Bronx",
                borough_id == 2 ~ "Brooklyn",
                borough_id == 3 ~ "Manhattan",
                borough_id == 4 ~ "Queens",
                borough_id == 5 ~ "Staten Island"
            )
    ) %>% 
    collect()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# combining
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

geo_type_entity <- 
    inner_join(
        geo_type,
        geo_entity,
        by = "geo_type_id"
    ) %>% 
    arrange(geo_type_id, geo_entity_id) %>% 
    select(
        GeoType = geo_type_name,
        GeoTypeDesc = geo_type_description,
        GeoID = geo_entity_id,
        Name = name,
        BoroID = borough_id,
        Borough
    )


# closing connection

dbDisconnect(EHDP_odbc)


#-----------------------------------------------------------------------------------------#
# shapefile data ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# citywide (no shape, specifying for inner join later)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

citywide <-
    tibble(
        GeoType = "Citywide",
        GeoID = 1
    )

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# Borough Boundaries
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

boro <- 
    read_sf("geography/nybb_22c") %>% 
    as_tibble() %>% 
    mutate(center = st_centroid(geometry)) %>% 
    transmute(
        GeoType = "Borough",
        GeoID = 
            case_when(
                BoroName == "Bronx" ~ 1L,
                BoroName == "Brooklyn" ~ 2L,
                BoroName == "Manhattan" ~ 3L,
                BoroName == "Queens" ~ 4L,
                BoroName == "Staten Island" ~ 5L
            ),
        Lat = st_coordinates(st_transform(center, st_crs(4326)))[, 2],
        Long = st_coordinates(st_transform(center, st_crs(4326)))[, 1]
    ) %>% 
    arrange(GeoID)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# UHF 34
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

uhf_34 <- 
    read_sf("geography/UHF 34") %>% 
    as_tibble() %>% 
    filter(UHF34_CODE != 0) %>% 
    mutate(center = st_centroid(geometry)) %>% 
    transmute(
        GeoType = "UHF34",
        GeoID = UHF34_CODE,
        Lat = st_coordinates(st_transform(center, st_crs(4326)))[, 2],
        Long = st_coordinates(st_transform(center, st_crs(4326)))[, 1]
    ) %>% 
    arrange(GeoID)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# UHF 42
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

uhf_42 <- 
    read_sf("geography/UHF 42") %>% 
    as_tibble() %>% 
    filter(UHFCODE != 0) %>% 
    mutate(center = st_centroid(geometry)) %>% 
    transmute(
        GeoType = "UHF42",
        GeoID = UHFCODE,
        Lat = st_coordinates(st_transform(center, st_crs(4326)))[, 2],
        Long = st_coordinates(st_transform(center, st_crs(4326)))[, 1]
    ) %>% 
    arrange(GeoID)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# PUMA/Subboro
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

puma_to_subboro <- read_csv("geography/puma_to_subboro.csv")

subboro <- 
    read_sf("geography/nypuma2010_22c") %>% 
    as_tibble() %>% 
    mutate(
        PUMA = as.integer(PUMA),
        center = st_centroid(geometry)
    ) %>% 
    inner_join(
        .,
        puma_to_subboro,
        by = "PUMA"
    ) %>% 
    transmute(
        GeoType = "Subboro",
        GeoID = Subboro,
        Lat = st_coordinates(st_transform(center, st_crs(4326)))[, 2],
        Long = st_coordinates(st_transform(center, st_crs(4326)))[, 1]
    ) %>%  
    arrange(GeoID)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# CD
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

cd <- 
    read_sf("geography/nycd_22c") %>% 
    as_tibble() %>% 
    mutate(center = st_centroid(geometry)) %>% 
    transmute(
        GeoType = "CD",
        GeoID = BoroCD,
        Lat = st_coordinates(st_transform(center, st_crs(4326)))[, 2],
        Long = st_coordinates(st_transform(center, st_crs(4326)))[, 1]
    ) %>%  
    arrange(GeoID)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# CDTA
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

cdta <- 
    read_sf("geography/nycdta2020_22c") %>% 
    as_tibble() %>% 
    filter(CDTAType == "0") %>% 
    mutate(center = st_centroid(geometry)) %>% 
    transmute(
        GeoType = "CDTA2020",
        GeoID = 
            CDTA2020 %>% 
            str_remove("^\\w{2}") %>% 
            str_c(CountyFIPS, .) %>% 
            as.integer(),
        Lat = st_coordinates(st_transform(center, st_crs(4326)))[, 2],
        Long = st_coordinates(st_transform(center, st_crs(4326)))[, 1]
    ) %>%  
    arrange(GeoID)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# NTA (date not specified - same as 2010)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

nta_nodate <- 
    read_sf("geography/nynta2010_22c") %>% 
    as_tibble() %>% 
    mutate(center = st_centroid(geometry)) %>% 
    transmute(
        GeoType = "NTA",
        GeoID =
            NTACode %>% 
            str_remove("^\\w{2}") %>% 
            str_c(CountyFIPS, .) %>% 
            as.integer(),
        Lat = st_coordinates(st_transform(center, st_crs(4326)))[, 2],
        Long = st_coordinates(st_transform(center, st_crs(4326)))[, 1]
    ) %>%  
    arrange(GeoID)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# NTA 2010
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

nta2010 <- 
    read_sf("geography/nynta2010_22c") %>% 
    as_tibble() %>% 
    mutate(center = st_centroid(geometry)) %>% 
    transmute(
        GeoType = "NTA2010",
        GeoID =
            NTACode %>% 
            str_remove("^\\w{2}") %>% 
            str_c(CountyFIPS, .) %>% 
            as.integer(),
        Lat = st_coordinates(st_transform(center, st_crs(4326)))[, 2],
        Long = st_coordinates(st_transform(center, st_crs(4326)))[, 1]
    ) %>%  
    arrange(GeoID)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# NTA 2020
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

nta2020 <- 
    read_sf("geography/nynta2020_22c") %>% 
    as_tibble() %>% 
    filter(NTAType == "0") %>% 
    mutate(center = st_centroid(geometry)) %>% 
    transmute(
        GeoType = "NTA2020",
        GeoID =
            NTA2020 %>% 
            str_remove("^\\w{2}") %>% 
            str_c(CountyFIPS, .) %>% 
            as.integer(),
        Lat = st_coordinates(st_transform(center, st_crs(4326)))[, 2],
        Long = st_coordinates(st_transform(center, st_crs(4326)))[, 1]
    ) %>%  
    arrange(GeoID)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# NYC Kids (date not specified - same as 2017)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# only have our own topojson file, no official shapefile

nyc_kids_nodate <- 
    read_sf("geography/NYCKids.topo.json", crs = st_crs(4326)) %>% 
    st_transform(st_crs(2263)) %>% # planar coords for centroid
    mutate(center = st_centroid(geometry)) %>% 
    as_tibble() %>% 
    transmute(
        GeoType = "NYCKIDS",
        GeoID = GEOCODE,
        Lat = st_coordinates(st_transform(center, st_crs(4326)))[, 2],
        Long = st_coordinates(st_transform(center, st_crs(4326)))[, 1]
    ) %>%  
    arrange(GeoID)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# NYC Kids 
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# only have our own topojson file, no official shapefile

nyc_kids_2017 <- 
    read_sf("geography/NYCKids_2017.topo.json", crs = st_crs(4326)) %>% 
    st_transform(st_crs(2263)) %>% 
    mutate(center = st_centroid(geometry)) %>% 
    as_tibble() %>% 
    transmute(
        GeoType = "NYCKIDS2017",
        GeoID = GEOCODE,
        Lat = st_coordinates(st_transform(center, st_crs(4326)))[, 2],
        Long = st_coordinates(st_transform(center, st_crs(4326)))[, 1]
    ) %>%  
    arrange(GeoID)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# NYC Kids
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# only have our own topojson file, no official shapefile

nyc_kids_2019 <- 
    read_sf("geography/NYCKids_2019.topo.json", crs = st_crs(4326)) %>% 
    st_transform(st_crs(2263)) %>% 
    mutate(center = st_centroid(geometry)) %>% 
    as_tibble() %>% 
    transmute(
        GeoType = "NYCKIDS2019",
        GeoID = GEOCODE,
        Lat = st_coordinates(st_transform(center, st_crs(4326)))[, 2],
        Long = st_coordinates(st_transform(center, st_crs(4326)))[, 1]
    ) %>%  
    arrange(GeoID)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# row-binding
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

all_geos <- 
    bind_rows(
        citywide,
        boro,
        uhf_34,
        uhf_42,
        subboro,
        cd,
        cdta,
        nta_nodate,
        nta2010,
        nta2020,
        nyc_kids_nodate,
        nyc_kids_2017,
        nyc_kids_2019
    ) %>% 
    mutate(roworder = 1:nrow(.))


#-----------------------------------------------------------------------------------------#
# combining centroids with geo names ----
#-----------------------------------------------------------------------------------------#

geolookup <- 
    inner_join(
        geo_type_entity,
        all_geos,
        by = c("GeoType", "GeoID")
    ) %>% 
    mutate(Lat = round(Lat, 5), Long = round(Long, 5)) %>% 
    arrange(roworder) %>% 
    select(-roworder)


write_csv(geolookup, "geography/GeoLookup.csv", na = "", progress = FALSE)


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
