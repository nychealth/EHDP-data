###########################################################################################-
###########################################################################################-
##
## reconstructing NR indicator_desc
##
###########################################################################################-
###########################################################################################-

#=========================================================================================#
# Setting up ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# Loading libraries
#-----------------------------------------------------------------------------------------#

library(tidyverse)
library(DBI)
library(dbplyr)
library(odbc)
library(rlang)
library(writexl)
library(yaml)
library(jsonlite)

#-----------------------------------------------------------------------------------------#
# Connecting to database
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# get driver
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

odbc_driver <- 
    odbcListDrivers() %>% 
    pull(name) %>% 
    unique() %>% 
    str_subset("ODBC Driver") %>% 
    sort(decreasing = TRUE) %>% 
    head(1)

if (length(odbc_driver) == 0) odbc_driver <- "SQL Server"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# connect
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# using Windows auth with no DSN

EHDP_odbc <-
    dbConnect(
        drv = odbc::odbc(),
        driver = paste0("{", odbc_driver, "}"),
        server = "DESKTOP-PU7DGC1",
        database = "BESP_IndicatorAnalysis",
        trusted_connection = "yes",
        encoding = "latin1",
        trustservercertificate = "yes"
    )

#=========================================================================================#
# Setting up ----
#=========================================================================================#

ReportData <- EHDP_odbc %>% tbl("ReportData") %>% collect()
reportLevel3 <- EHDP_odbc %>% tbl("reportLevel3") %>% collect()
reportLevel3_new <- EHDP_odbc %>% tbl("reportLevel3_new") %>% collect()


nr_measures

# INNER JOIN unreliability AS u ON nabeD.unreliability_flag = u.unreliability_id
# 
# INNER JOIN Report_UHF_indicator_Rank AS rr ON (
#     rr.indicator_data_id = nabeD.indicator_data_id AND 
#     rr.report_id = rtd.report_id
# )
# 
# INNER JOIN Consolidated_Sources_by_IndicatorID AS s ON rtd.indicator_id = s.indicator_id


unreliability <- 
    EHDP_odbc %>% 
    tbl("unreliability") %>% 
    collect()

Report_UHF_indicator_Rank <- 
    EHDP_odbc %>% 
    tbl("Report_UHF_indicator_Rank") %>% 
    collect()

Consolidated_Sources_by_IndicatorID <- 
    EHDP_odbc %>% 
    tbl("Consolidated_Sources_by_IndicatorID") %>% 
    collect()

indicator_data <- 
    EHDP_odbc %>%
    tbl("indicator_data") %>% 
    select(
        indicator_id, 
        geo_type_id, 
        geo_entity_id, 
        year_id, 
        data_value
    ) %>% 
    filter(geo_type_id %in% c(1, 6)) %>% 
    collect()

report_measure_years <- ReportData %>% distinct(indicator_id, year_id)


boro_data <- 
    semi_join(
        indicator_data %>% filter(geo_type_id == 1),
        report_measure_years,
        by = c("indicator_id", "year_id")
    )

city_data <- 
    semi_join(
        indicator_data %>% filter(geo_type_id == 6),
        report_measure_years,
        by = c("indicator_id", "year_id")
    )




ReportData %>% glimpse()
reportLevel3 %>% glimpse()
reportLevel3_new %>% glimpse()

ReportData %>% select(report_id, indicator_id, geo_entity_id) %>% distinct()
reportLevel3 %>% select(report_id, indicator_id, geo_entity_id)


# SELECT DISTINCT
#     r2.report_id,
#     r1.report_title,
#     r2.report_topic_id,
#     r2.report_topic,
#     r2.report_topic_description
# FROM reportLevel2 AS r2
#     LEFT JOIN reportLevel1 AS r1 ON r1.report_id = r2.report_id
# WHERE r2.report_id IN (73, 77, 78, 79, 82)
# ORDER BY r2.report_id, r2.report_topic


reportLevel1 <- 
    EHDP_odbc %>% 
    tbl("reportLevel1") %>% 
    select(report_id, report_title) %>% 
    filter(report_id %in% c(73, 77, 78, 79, 82)) %>% 
    distinct() %>% 
    collect()

reportLevel2 <- 
    EHDP_odbc %>% 
    tbl("reportLevel2") %>% 
    select(
        report_id,
        report_topic_id,
        report_topic,
        report_topic_description
    ) %>% 
    filter(report_id %in% c(73, 77, 78, 79, 82)) %>% 
    arrange(report_id, report_topic) %>% 
    distinct() %>% 
    collect()

reportLevel3 <- 
    EHDP_odbc %>% 
    tbl("reportLevel3") %>% 
    select(
        report_id,
        report_topic_id,
        MeasureID = indicator_id
    ) %>% 
    filter(report_id %in% c(73, 77, 78, 79, 82)) %>% 
    arrange(report_id, MeasureID) %>% 
    collect() %>% 
    distinct()


report_topics_measures <- 
    left_join(
        reportLevel1,
        reportLevel2,
        by = "report_id",
        multiple = "all"
    ) %>% 
    left_join(
        .,
        reportLevel3,
        by = c("report_id", "report_topic_id"),
        multiple = "all"
    ) %>% 
    group_by(report_id, report_topic_id) %>% 
    nest(MeasureID = MeasureID) %>% 
    mutate(MeasureID = list(MeasureID =as.integer(unlist(MeasureID)))) %>% 
    group_by(report_title, report_topic) %>% 
    nest(report_topics = c(report_topic, report_topic_description, MeasureID)) %>% 
    group_by(report_title) %>%
    # nest(top = c(report_topic, report_topics)) %>% 
    select(-report_id, -report_topic_id)


report_topics_measures %>% 
    group_walk(
        ~ .x %>% 
            as.yaml(indent.mapping.sequence = TRUE) %>% 
            write_lines(paste0("neighborhood-reports/", .y, ".yaml"))
    )


adult_indicators <- c(657, 659, 661, 1175, 1180, 1182)

reportLevel3_new <- 
    EHDP_odbc %>% 
    tbl("reportLevel3_new") %>% 
    collect() %>% 
    mutate(
        indicator_short_name = 
            case_when(
                MeasureID %in% adult_indicators ~ 
                    str_replace(indicator_short_name, "\\(children\\)", "(adults)"),
                TRUE ~ indicator_short_name
            ),
        indicator_data_name = str_replace(indicator_data_name, "PM2\\.", "PM2-"),
        summary_bar_svg = 
            str_c(
                indicator_data_name,
                "_",
                geo_entity_id,
                ".svg"
            ),
        across(
            c(indicator_name, indicator_description, measurement_type, units),
            ~ as_utf8_character(enc2native(.x))
        )
    ) %>% 
    distinct(MeasureID, geo_entity_id, .keep_all = TRUE)


reportLevel3_new %>% glimpse()

reportLevel3_new %>% toJSON() %>% write_lines("neighborhood-reports/data/reportLevel3_new.json")


reportLevel3_new %>% nrow()
reportLevel3_new %>% distinct(MeasureID, indicator_desc) %>% nrow()
reportLevel3_new %>% distinct(MeasureID, geo_entity_id, indicator_desc) %>% nrow()


reportLevel3_new %>% 
    select(MeasureID, geo_entity_id, indicator_desc) %>% 
    add_count(MeasureID, geo_entity_id) %>% 
    filter(n > 1)

reportLevel3_new %>% 
    distinct(MeasureID, indicator_desc) %>% 
    add_count(MeasureID) %>% 
    filter(n > 1)

