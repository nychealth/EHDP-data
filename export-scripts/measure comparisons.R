library(tidyverse)
library(DBI)
library(dbplyr)
library(odbc)
library(jsonlite)

EHDP_odbc <-
    dbConnect(
        drv = odbc::odbc(),
        driver = "{ODBC Driver 17 for SQL Server}",
        server = "SQLIT04A",
        database = "BESP_Indicator",
        trusted_connection = "yes"
    )

EXP_measure_comparisons <- 
    EHDP_odbc %>% 
    tbl("EXP_measure_comparisons") %>% 
    collect()


indicator_measures <- 
    EXP_measure_comparisons %>%
    select(IndicatorID, MeasureID) %>% 
    drop_na() %>% 
    group_by(IndicatorID) %>% 
    group_nest(.key = "Measures", keep = FALSE) %>% 
    ungroup()


EXP_measure_comparisons %>%
    select(IndicatorID, MeasureID) %>% 
    drop_na() %>% 
    group_by(IndicatorID) %>% 
    # group_walk( ~ str(.x),.keep = TRUE)
    group_map( ~ tibble(IndicatorID = .x$IndicatorID, Measures = unlist(.x$MeasureID)), .keep = TRUE)

