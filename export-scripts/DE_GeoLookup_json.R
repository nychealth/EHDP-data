###########################################################################################-
###########################################################################################-
##
##  Creating GeoLookup.json
##
###########################################################################################-
###########################################################################################-

# turning source geo files into our geo metadata reference file. source files are mostly 
#   shapefiles, downloaded from the NYC Department of City Planning's BYTES of the BIG APPLE™
#   page (https://www.nyc.gov/site/planning/data-maps/open-data.page), using the script
#   at "geography/download_shapefiles.R".

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
suppressWarnings(suppressMessages(library(sf)))
suppressWarnings(suppressMessages(library(svDialogs)))

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
        encoding = "latin1",
        trustservercertificate = "yes"
    )


#-----------------------------------------------------------------------------------------#
# create folders if they don't exist
#-----------------------------------------------------------------------------------------#

dir_create(path(base_dir, "geography"))

#-----------------------------------------------------------------------------------------#
# get geo file version
#-----------------------------------------------------------------------------------------#

release <- read_file(path(base_dir, "geography/release"))

#=========================================================================================#
# data ops ----
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
        geo_type_description,
        geo_type_short_desc = description
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
        by = "geo_type_id",
        multiple = "all"
    ) %>% 
    arrange(geo_type_id, geo_entity_id) %>% 
    select(
        GeoType = geo_type_name,
        GeoTypeDesc = geo_type_description,
        GeoTypeShortDesc = geo_type_short_desc,
        GeoID = geo_entity_id,
        Name = name,
        BoroID = borough_id,
        Borough
    )


#-----------------------------------------------------------------------------------------#
# geography data ----
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

# https://s-media.nyc.gov/agencies/dcp/assets/files/zip/data-tools/bytes/nybb_24c.zip

boro <- 
    read_sf(path(base_dir, glue("geography/nybb_{release}"))) %>% 
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
    read_sf(path(base_dir, "geography/UHF 34")) %>% 
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
    read_sf(path(base_dir, "geography/UHF 42")) %>% 
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

# https://s-media.nyc.gov/agencies/dcp/assets/files/zip/data-tools/bytes/nypuma2010_24c.zip

puma_to_subboro <- read_csv(path(base_dir, "geography/puma_to_subboro.csv"), show_col_types = FALSE)

subboro <- 
    read_sf(path(base_dir, glue("geography/nypuma2010_{release}"))) %>% 
    as_tibble() %>% 
    mutate(
        PUMA = as.integer(PUMA2010),
        center = st_centroid(geometry)
    ) %>% 
    inner_join(
        .,
        puma_to_subboro,
        by = "PUMA",
        multiple = "all"
    ) %>% 
    transmute(
        GeoType = "Subboro",
        GeoID = Subboro,
        Lat = st_coordinates(st_transform(center, st_crs(4326)))[, 2],
        Long = st_coordinates(st_transform(center, st_crs(4326)))[, 1]
    ) %>%  
    arrange(GeoID)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# PUMA 2010
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# https://s-media.nyc.gov/agencies/dcp/assets/files/zip/data-tools/bytes/nypuma2010_24c.zip

puma2010 <- 
    read_sf(path(base_dir, glue("geography/nypuma2010_{release}"))) %>% 
    as_tibble() %>% 
    mutate(center = st_centroid(geometry)) %>% 
    transmute(
        GeoType = "PUMA2010",
        GeoID = PUMA2010,
        Lat = st_coordinates(st_transform(center, st_crs(4326)))[, 2],
        Long = st_coordinates(st_transform(center, st_crs(4326)))[, 1]
    ) %>%  
    arrange(GeoID)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# PUMA 2020
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# https://s-media.nyc.gov/agencies/dcp/assets/files/zip/data-tools/bytes/nypuma2020_24c.zip

puma2020 <- 
    read_sf(path(base_dir, glue("geography/nypuma2020_{release}"))) %>% 
    as_tibble() %>% 
    mutate(center = st_centroid(geometry)) %>% 
    transmute(
        GeoType = "PUMA2020",
        GeoID = PUMA2020,
        Lat = st_coordinates(st_transform(center, st_crs(4326)))[, 2],
        Long = st_coordinates(st_transform(center, st_crs(4326)))[, 1]
    ) %>%  
    arrange(GeoID)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# CD
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# https://s-media.nyc.gov/agencies/dcp/assets/files/zip/data-tools/bytes/nycd_24c.zip

cd <- 
    read_sf(path(base_dir, glue("geography/nycd_{release}"))) %>% 
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
# CDTA (2020 only)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# https://s-media.nyc.gov/agencies/dcp/assets/files/zip/data-tools/bytes/nycdta2020_24c.zip

cdta <- 
    read_sf(path(base_dir, glue("geography/nycdta2020_{release}"))) %>% 
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

# https://s-media.nyc.gov/agencies/dcp/assets/files/zip/data-tools/bytes/nynta2010_24c.zip

nta_nodate <- 
    read_sf(path(base_dir, glue("geography/nynta2010_{release}"))) %>% 
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

# https://s-media.nyc.gov/agencies/dcp/assets/files/zip/data-tools/bytes/nynta2010_24c.zip

nta2010 <- 
    read_sf(path(base_dir, glue("geography/nynta2010_{release}"))) %>% 
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

# https://s-media.nyc.gov/agencies/dcp/assets/files/zip/data-tools/bytes/nynta2020_24c.zip

nta2020 <- 
    read_sf(path(base_dir, glue("geography/nynta2020_{release}"))) %>% 
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
    read_sf(path(base_dir, "geography/NYCKids.topo.json"), crs = st_crs(4326)) %>% 
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
    read_sf(path(base_dir, "geography/NYCKids_2017.topo.json"), crs = st_crs(4326)) %>% 
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
    read_sf(path(base_dir, "geography/NYCKids_2019.topo.json"), crs = st_crs(4326)) %>% 
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
# NYC Kids
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# only have our own topojson file, no official shapefile

nyc_kids_2021 <- 
    read_sf(path(base_dir, "geography/NYCKids_2021.topo.json"), crs = st_crs(4326)) %>% 
    st_transform(st_crs(2263)) %>% 
    mutate(center = st_centroid(geometry)) %>% 
    as_tibble() %>% 
    transmute(
        GeoType = "NYCKIDS2021",
        GeoID = GEOCODE,
        Lat = st_coordinates(st_transform(center, st_crs(4326)))[, 2],
        Long = st_coordinates(st_transform(center, st_crs(4326)))[, 1]
    ) %>%  
    arrange(GeoID)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# harbor areas
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

ny_harbor <- 
    read_sf(path(base_dir, "geography/ny_harbor.topo.json"), crs = st_crs(4326)) %>% 
    st_transform(st_crs(2263)) %>% 
    mutate(center = st_centroid(geometry)) %>% 
    as_tibble() %>% 
    transmute(
        GeoType = "NYHarbor",
        GeoID = GEOCODE,
        Lat = st_coordinates(st_transform(center, st_crs(4326)))[, 2],
        Long = st_coordinates(st_transform(center, st_crs(4326)))[, 1]
    ) %>%  
    arrange(GeoID)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# RMZ
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

rmz <- 
    read_sf(path(base_dir, "geography/RMZ.topo.json"), crs = st_crs(4326)) %>% 
    st_transform(st_crs(2263)) %>% 
    mutate(center = st_centroid(geometry)) %>% 
    as_tibble() %>% 
    transmute(
        GeoType = "RMZ",
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
        nyc_kids_2019,
        nyc_kids_2021,
        ny_harbor,
        rmz
    ) %>% 
    mutate(roworder = 1:nrow(.))


#-----------------------------------------------------------------------------------------#
# combining centroids with geo names ----
#-----------------------------------------------------------------------------------------#

geolookup <- 
    inner_join(
        geo_type_entity,
        all_geos,
        by = c("GeoType", "GeoID"),
        multiple = "all"
    ) %>% 
    mutate(Lat = round(Lat, 4), Long = round(Long, 4)) %>% 
    arrange(roworder) %>% 
    select(-roworder)

#-----------------------------------------------------------------------------------------#
# saving ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# converting to JSON
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

geolookup_json <- geolookup %>% toJSON(dataframe = "columns", pretty = FALSE, null = "null", na = "null")

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# write
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

write_file(geolookup_json, path(base_dir, "geography/GeoLookup.json"))

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
