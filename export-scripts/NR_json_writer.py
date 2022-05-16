###########################################################################################-
###########################################################################################-
##
##  NR_json_writer
##
###########################################################################################-
###########################################################################################-

#=========================================================================================#
# Setting up ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# Loading libraries
#-----------------------------------------------------------------------------------------#

import pyodbc
import pandas as pd

#-----------------------------------------------------------------------------------------#
# Connecting to BESP_Indicator database
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# determining which driver to use
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

drivers_list = pyodbc.drivers()

# odbc

odbc_driver_list = list(filter(lambda dl: "ODBC Driver" in dl, drivers_list))
odbc_driver_list.sort(reverse = True)

# native

native_driver_list = list(filter(lambda dl: "SQL Server Native Client" in dl, drivers_list))
native_driver_list.sort()

# deciding & setting

if len(odbc_driver_list) > 0:

    driver = odbc_driver_list[0]
    
elif len(native_driver_list) > 0:
    
    driver = native_driver_list[0]
    
else:
    
    driver = "SQL Server"

#-----------------------------------------------------------------------------------------#
# Connecting to BESP_Indicator
#-----------------------------------------------------------------------------------------#

EHDP_odbc = pyodbc.connect("DRIVER={" + driver + "};SERVER=SQLIT04A;DATABASE=BESP_Indicator;Trusted_Connection=yes;")

#=========================================================================================#
# Pulling data ----
#=========================================================================================#

# using existing views

#-----------------------------------------------------------------------------------------#
# Top-level report details
#-----------------------------------------------------------------------------------------#

report_level_1 = (
    pd.read_sql(
        """
        SELECT 
            report_id,
            report_title,
            geo_entity_name,
            report_description,
            report_text,
            report_footer,
            zip_code,
            unreliable_text
        FROM reportLevel1
        """, 
        EHDP_odbc
    )
)

# data_download_loc = 
#     str_c(
#         "http://a816-dohbesp.nyc.gov/IndicatorPublic/EPHTCsv/", 
#         report_title %>% 
#             str_replace_all("[:punct:]", "") %>% 
#             str_replace_all(" ", "_"),
#         ".csv"
#     )


#-----------------------------------------------------------------------------------------#
# Report topic details
#-----------------------------------------------------------------------------------------#

report_level_2 = (
    pd.read_sql(
        """
        SELECT 
            report_id,
            report_topic,
            report_topic_id,
            report_topic_description,
            borough_name,
            geo_entity_id,
            geo_entity_name,
            city,
            compared_with
        FROM reportLevel2
        """, 
        EHDP_odbc
    )
)


#-----------------------------------------------------------------------------------------#
# Report data
#-----------------------------------------------------------------------------------------#

adult_indicators = [657, 659, 661, 1175, 1180, 1182]

report_level_3 = (
    pd.read_sql(
        """
        SELECT 
            report_id,
            report_topic_id,
            geo_entity_id,
            indicator_id,
            indicator_data_name,
            indicator_short_name,
            indicator_URL,
            indicator_name,
            indicator_description,
            sort_key,
            data_value_nyc,
            data_value_borough,
            data_value_geo_entity,
            unmodified_data_value_geo_entity,
            nabe_data_note,
            trend_flag,
            data_value_rank,
            indicator_neighborhood_rank,
            measurement_type,
            units
        FROM reportLevel3
        """, 
        EHDP_odbc
    )
)

    # mutate(
    #     indicator_short_name = 
    #         case_when(
    #             indicator_id %in% adult_indicators ~ 
    #                 str_replace(indicator_short_name, "\\(children\\)", "(adults)"),
    #             TRUE ~ indicator_short_name
    #         ),
    #     indicator_data_name = str_replace(indicator_data_name, "PM2\\.", "PM2-"),
    #     summary_bar_svg = 
    #         str_c(
    #             indicator_data_name,
    #             "_",
    #             geo_entity_id,
    #             ".svg"
    #         ),
        
    #     across(
    #         c(indicator_name, indicator_description, measurement_type, units),
    #         ~ as_utf8_character(enc2native(.x))
    #     )
        
    # ) %>% 
    # select(-indicator_id)


#=========================================================================================#
# Nesting and joining data ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# Nesting by report_id, report_topic_id, geo_entity_id
#-----------------------------------------------------------------------------------------#

report_level_3_nested = (
    report_level_3
    .groupby(["report_id", "report_topic_id", "geo_entity_id"], dropna = False)
    .apply(lambda x: x[~x.index.isin(["report_id", "report_topic_id", "geo_entity_id"])].to_dict("records"))
    .reset_index()
    .rename(columns = {0: "report_topic_data"})
)

#-----------------------------------------------------------------------------------------#
# combining with topic details by nesting vars
#-----------------------------------------------------------------------------------------#

# report_level_23_nested <- 
#     left_join(
#         report_level_2,
#         report_level_3_nested,
#         by = c("report_id", "report_topic_id", "geo_entity_id")
#     ) 

#-----------------------------------------------------------------------------------------#
# adding report_title to nested data for filtering in the loop
#-----------------------------------------------------------------------------------------#

# report_level_123_nested <- 
#     left_join(
#         report_level_1 %>% select(report_id, geo_entity_name, report_title),
#         report_level_23_nested,
#         by = c("report_id", "geo_entity_name")
#     ) %>% 
#     arrange(geo_entity_name, report_title, report_topic) %>% 
#     select(-c(report_id, report_topic_id, geo_entity_id))


