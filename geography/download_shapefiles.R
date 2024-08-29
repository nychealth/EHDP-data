library(glue)
library(readr)
library(purrr)
library(fs)
library(stringr)

base_url <- "https://s-media.nyc.gov/agencies/dcp/assets/files/zip/data-tools/bytes"

release <- read_file("geography/release")

geos <- read_file("geography/geos")

# delete existing files

geo_files <- 
    dir_ls("geography") %>% 
    keep( ~ str_detect(.x, paste0(geos, collapse = "|")))

geo_files_release <- 
    geo_files %>% 
    str_extract("(_)(\\d{2}[a-z])", group = 2) %>% 
    unique()

# COMPARE TO RELEASE, IF THE SAME, DON'T DO ANYTHING

# delete files and folders

cat("||", "Delete existing", "||", sep = " ")

geo_files %>% path_filter(regexp = "\\.zip") %>% walk( ~ file_delete(.x))
geo_files %>% path_filter(regexp = "\\.zip", invert = TRUE) %>% walk( ~ dir_delete(.x))


# match geos

urls <- glue("{base_url}/{geos}_{release}.zip")
destfiles <- glue("geography/{geos}_{release}.zip")

# download

download.file(urls, destfiles, method = "libcurl")

# unzip

destfiles %>% walk( ~ unzip(.x, exdir = "geography"))

# delete zip files

zip_files <- 
    dir_ls("geography", glob = "*.zip") %>% 
    keep( ~ str_detect(.x, paste0(geos, collapse = "|")))

# delete files and folders

cat("||", "Delete new zip", "||", sep = " ")

zip_files %>% walk( ~ file_delete(.x))
