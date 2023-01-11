library(tidyverse)
library(DBI)
library(dbplyr)
library(odbc)
library(jsonlite)

EHDP_odbc <-
    dbConnect(
        drv = odbc::odbc(),
        driver = "{ODBC Driver 17 for SQL Server}",
        server = "DESKTOP-PU7DGC1",
        database = "BESP_Indicator",
        trusted_connection = "yes"
    )

EXP_measure_comparisons <- 
    EHDP_odbc %>% 
    tbl("EXP_measure_comparisons") %>% 
    collect()

# add to indicators.json

indicator_comparisons <- 
    EXP_measure_comparisons %>%
    select(IndicatorID, ComparisonID) %>% 
    drop_na() %>% 
    distinct() %>% 
    group_by(IndicatorID) %>% 
    group_nest(.key = "Comparisons", keep = FALSE) %>% 
    ungroup()

comparisons_nested <- 
    EXP_measure_comparisons %>% 
    drop_na() %>% 
    rename(Measures = MeasureID) %>% 
    group_by(ComparisonID, ComparisonName, LegendTitle, Y_axis_title, IndicatorID) %>% 
    mutate(Measures = list(unlist(Measures))) %>% 
    distinct() %>% 
    ungroup() %>%
    group_by(ComparisonID, ComparisonName, LegendTitle, Y_axis_title) %>%
    group_nest(.key = "Indicators", keep = FALSE) %>%
    ungroup()

comparisons_json <- comparisons_nested %>% toJSON(pretty = TRUE)

write_lines(comparisons_json, "indicators/comparisons.json")
