###########################################################################################-
###########################################################################################-
##
##  Creating TopoJSON files
##
###########################################################################################-
###########################################################################################-

# Simplifying geo boundaries and saving as TopoJSON. Script reads in source files (mostly 
#   shapefiles), simplifies lines, then saves. Source shapefile filenames are parameterized
#   to work across DCP release numbers. Values for the `keep` argument to `ms_simplify()`
#   are determined in advance for each geo type.

# MODEZCTA TO UHF, READ IN ZIP CODES SHAPE

#=========================================================================================#
# Setting up ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# Loading libraries
#-----------------------------------------------------------------------------------------#

suppressWarnings(suppressMessages(library(tidyverse)))
suppressWarnings(suppressMessages(library(sf)))
suppressWarnings(suppressMessages(library(geojsonio)))
suppressWarnings(suppressMessages(library(rmapshaper)))
suppressWarnings(suppressMessages(library(glue)))
suppressWarnings(suppressMessages(library(fs)))

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
# file names and version
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

release <- read_file(path(base_dir, "geography/release"))

#=========================================================================================#
# data ops ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# borough ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# reading in original data
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

boro <- 
    read_sf(path(base_dir, glue("geography/nybb_{release}"))) %>% 
    st_transform(4326) %>% 
    transmute(
        GEOCODE = 
            case_when(
                BoroName == "Bronx" ~ 1L,
                BoroName == "Brooklyn" ~ 2L,
                BoroName == "Manhattan" ~ 3L,
                .default = BoroCode
            ),
        name = BoroName,
        geometry
    ) %>% 
    arrange(GEOCODE) %>% 
    mutate(id = as.character(1:nrow(.)), .before = 1)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# simplifying and saving
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

boro_simple <- ms_simplify(boro, keep = 0.02)

# making into topojson object

boro_topojson <- 
    topojson_json(
        boro_simple, 
        group = GEOCODE,
        geometry = "polygon", 
        type = "GeometryCollection",
        object_name = "collection",
        quantization = 1e4,
        crs = 4326
    )

# writing topojson

write_lines(boro_topojson, "geography/borough.topo.json")

# fix with mapshaper

system("mapshaper -i geography/borough.topo.json -o quantization=1e4 geography/borough.topo.json")


#-----------------------------------------------------------------------------------------#
# PUMA 2010 ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# reading in original data
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

names <- read_csv("geography/puma2010_names.csv", show_col_types = FALSE)

PUMA2010 <- 
    read_sf(path(base_dir, glue("geography/nypuma2010_{release}"))) %>% 
    st_transform(4326) %>% 
    mutate(GEOCODE = as.integer(PUMA)) %>% 
    left_join(
        .,
        names,
        by = c("GEOCODE" = "PUMA2010")
    ) %>% 
    select(GEOCODE, GEONAME, geometry) %>%
    arrange(GEOCODE) %>% 
    mutate(id = as.character(1:nrow(.)), .before = 1)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# simplifying and saving
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

PUMA2010_simple <- ms_simplify(PUMA2010, keep = 0.05)

# making into topojson object

PUMA2010_topojson <- 
    topojson_json(
        PUMA2010_simple, 
        group = GEOCODE,
        geometry = "polygon", 
        type = "GeometryCollection",
        object_name = "collection",
        quantization = 1e4,
        crs = 4326
    )

# writing topojson

write_lines(PUMA2010_topojson, "geography/PUMA2010.topo.json")

# fix with mapshaper

system("mapshaper -i geography/PUMA2010.topo.json -o quantization=1e4 geography/PUMA2010.topo.json")

#-----------------------------------------------------------------------------------------#
# PUMA 2020 ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# reading in original data
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

names <- read_csv("geography/puma2020_names.csv", show_col_types = FALSE)

PUMA2020 <- 
    read_sf(path(base_dir, glue("geography/nypuma2020_{release}"))) %>% 
    st_transform(4326) %>% 
    mutate(GEOCODE = as.integer(PUMA)) %>% 
    left_join(
        .,
        names,
        by = c("GEOCODE" = "PUMA2020")
    ) %>% 
    select(GEOCODE, GEONAME, geometry) %>%
    arrange(GEOCODE) %>% 
    mutate(id = as.character(1:nrow(.)), .before = 1)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# simplifying and saving
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

PUMA2020_simple <- ms_simplify(PUMA2020, keep = 0.05)

# making into topojson object

PUMA2020_topojson <- 
    topojson_json(
        PUMA2020_simple, 
        group = GEOCODE,
        geometry = "polygon", 
        type = "GeometryCollection",
        object_name = "collection",
        quantization = 1e4,
        crs = 4326
    )

# writing topojson

write_lines(PUMA2020_topojson, "geography/PUMA2020.topo.json")

# fix with mapshaper

system("mapshaper -i geography/PUMA2020.topo.json -o quantization=1e4 geography/PUMA2020.topo.json")

#-----------------------------------------------------------------------------------------#
# CD ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# reading in original data
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

CD <- 
    read_sf(path(base_dir, glue("geography/nynta2010_{release}"))) %>% 
    st_transform(4326) %>% 
    mutate(
        GEOCODE =
            NTACode %>% 
            str_remove("^\\w{2}") %>% 
            str_c(CountyFIPS, .) %>% 
            as.integer(),
        .after = NTAName
    ) %>% 
    select(NTACode, GEOCODE, GEONAME = NTAName, geometry) %>%
    arrange(GEOCODE) %>% 
    mutate(id = as.character(1:nrow(.)), .before = 1)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# simplifying and saving
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

CD_simple <- ms_simplify(CD, keep = 0.04)

# making into topojson object

CD_topojson <- 
    topojson_json(
        CD_simple, 
        group = GEOCODE,
        geometry = "polygon", 
        type = "GeometryCollection",
        object_name = "collection",
        quantization = 1e4,
        crs = 4326
    )

# writing topojson

write_lines(CD_topojson, "geography/CD.topo.json")

# fix with mapshaper

system("mapshaper -i geography/CD.topo.json -o quantization=1e4 geography/CD.topo.json")

#-----------------------------------------------------------------------------------------#
# CDTA 2020 ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# reading in original data
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

CDTA2020 <- 
    read_sf(path(base_dir, glue("geography/nycdta2020_{release}"))) %>% 
    # filter(CDTAType == "0") %>%
    st_transform(4326) %>% 
    mutate(
        GEOCODE =
            CDTA2020 %>% 
            str_remove("^\\w{2}") %>% 
            str_c(CountyFIPS, .) %>% 
            as.integer(),
        .after = CDTAName
    ) %>% 
    select(CDTA2020, GEOCODE, GEONAME = CDTAName, geometry) %>%
    arrange(GEOCODE) %>% 
    mutate(id = as.character(1:nrow(.)), .before = 1)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# simplifying and saving
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

CDTA2020_simple <- ms_simplify(CDTA2020, keep = 0.035)

# making into topojson object

CDTA2020_topojson <- 
    topojson_json(
        CDTA2020_simple, 
        group = GEOCODE,
        geometry = "polygon", 
        type = "GeometryCollection",
        object_name = "collection",
        quantization = 1e4,
        crs = 4326
    )

# writing topojson

write_lines(CDTA2020_topojson, "geography/CDTA2020.topo.json")

# fix with mapshaper

system("mapshaper -i geography/CDTA2020.topo.json -o quantization=1e4 geography/CDTA2020.topo.json")

#-----------------------------------------------------------------------------------------#
# NTA 2010 ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# reading in original data
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

NTA2010 <- 
    read_sf(path(base_dir, glue("geography/nynta2010_{release}"))) %>% 
    st_transform(4326) %>% 
    mutate(
        GEOCODE =
            NTACode %>% 
            str_remove("^\\w{2}") %>% 
            str_c(CountyFIPS, .) %>% 
            as.integer(),
        .after = NTAName
    ) %>% 
    select(NTACode, GEOCODE, GEONAME = NTAName, geometry) %>%
    arrange(GEOCODE) %>% 
    mutate(id = as.character(1:nrow(.)), .before = 1)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# simplifying and saving
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

NTA2010_simple <- ms_simplify(NTA2010, keep = 0.04)

# making into topojson object

NTA2010_topojson <- 
    topojson_json(
        NTA2010_simple, 
        group = GEOCODE,
        geometry = "polygon", 
        type = "GeometryCollection",
        object_name = "collection",
        quantization = 1e4,
        crs = 4326
    )

# writing topojson

write_lines(NTA2010_topojson, "geography/NTA2010.topo.json")
write_lines(NTA2010_topojson, "geography/NTA.topo.json") # pre-2020 name

# fix with mapshaper

system("mapshaper -i geography/NTA2010.topo.json -o quantization=1e4 geography/NTA2010.topo.json")
system("mapshaper -i geography/NTA.topo.json -o quantization=1e4 geography/NTA.topo.json")

#-----------------------------------------------------------------------------------------#
# NTA 2020 ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# reading in original data
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

NTA2020 <- 
    read_sf(path(base_dir, glue("geography/nynta2020_{release}"))) %>% 
    st_transform(4326) %>% 
    mutate(
        GEOCODE =
            NTA2020 %>% 
            str_remove("^\\w{2}") %>% 
            str_c(CountyFIPS, .) %>% 
            as.integer(),
        .after = NTAName
    ) %>% 
    select(NTACode = NTA2020, GEOCODE, GEONAME = NTAName, geometry) %>%
    arrange(GEOCODE) %>% 
    mutate(id = as.character(1:nrow(.)), .before = 1)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# simplifying and saving
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

NTA2020_simple <- ms_simplify(NTA2020, keep = 0.04)

# making into topojson object

NTA2020_topojson <- 
    topojson_json(
        NTA2020_simple, 
        group = GEOCODE,
        geometry = "polygon", 
        type = "GeometryCollection",
        object_name = "collection",
        quantization = 1e4,
        crs = 4326
    )

# writing topojson

write_lines(NTA2020_topojson, "geography/NTA2020.topo.json")

# fix with mapshaper

system("mapshaper -i geography/NTA2020.topo.json -o quantization=1e4 geography/NTA2020.topo.json")


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
