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
import string
import re

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

# using "pd.read_sql" here because first argument (a string) doesn't have a read_sql method

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
    .assign(
        data_download_loc = 
            lambda d: "http://a816-dohbesp.nyc.gov/IndicatorPublic/EPHTCsv/" +
            d.report_title.str
            .replace("[" + string.punctuation + "]", "", regex = True) + ".csv"
    )
    .assign(
        data_download_loc = 
            lambda d: d.data_download_loc.str.replace(" ", "_")
    )
)


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
    .assign(
        indicator_short_name = 
            lambda d: 
                d.indicator_short_name
                    .where(
                        d["indicator_id"].isin(adult_indicators), 
                        d.indicator_short_name.str.replace("(children)", "(adults)", regex = False)
                    )
            
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

# DataFrames have pandas methods, so can chain them together

report_level_3_nested = (
    report_level_3
    .groupby(
        [
            "report_id", 
            "report_topic_id", 
            "geo_entity_id"
        ], 
        dropna = False
    )
    .apply(lambda x: x.loc[:, ~ x.columns.isin(["report_id", "report_topic_id", "geo_entity_id"])].to_dict("records"))
    .reset_index(drop = False)
    .rename(columns = {0: "report_topic_data"})
)

#-----------------------------------------------------------------------------------------#
# combining with topic details by nesting vars
#-----------------------------------------------------------------------------------------#

report_level_23_nested = (
    report_level_2
    .merge(
        report_level_3_nested,
        how = "left",
        on = ["report_id", "report_topic_id", "geo_entity_id"]
    )
    .reset_index(drop = True)
)

#-----------------------------------------------------------------------------------------#
# adding report_title to nested data for filtering in the loop
#-----------------------------------------------------------------------------------------#

report_level_123_nested = (
    report_level_1
    .loc[:, ["report_id", "geo_entity_name", "report_title"]]
    .merge(
        report_level_23_nested,
        how = "left",
        on = ["report_id", "geo_entity_name"]
    )
    .sort_values(by = ["geo_entity_name", "report_title", "report_topic"])
    .loc[:, 
        [
            "report_title",
            "report_topic",
            "report_topic_description",
            "geo_entity_id",
            "geo_entity_name",
            "borough_name",
            "city",
            "compared_with",
            "report_topic_data"
        ]
    ]
    .reset_index(drop = True)
)

#-----------------------------------------------------------------------------------------#
# dropping unneeded report details columns
#-----------------------------------------------------------------------------------------#

report_level_1_small = (
    report_level_1
    .loc[:, 
        [
            "report_title",
            "report_description",
            "report_text",
            "report_footer",
            "zip_code",
            "unreliable_text",
            "data_download_loc",
            "geo_entity_name"
        ]
    ]
    .sort_values(by = ["geo_entity_name", "report_title"])
    .reset_index(drop = True)
)


#=========================================================================================#
# Writing JSON ----
#=========================================================================================#

for i in report_level_1_small.index:
    
    
    #-----------------------------------------------------------------------------------------#
    # looping through unique spec and using it to filter data
    #-----------------------------------------------------------------------------------------#
    
    report_spec = (
        report_level_1_small
        .iloc[[i], :]
    )
    
    
    # This is safer than splitting by the spec outside the loop and then indexing with i. 
    #   It's probably slower, but that's inconsequential here.
    
    report_content = (
        report_level_123_nested
        .merge(
            report_spec,
            how = "inner",
            on = ["geo_entity_name", "report_title"]
        )
        .loc[:, 
            [
                "geo_entity_name",
                "report_topic",
                "report_topic_description",
                "borough_name",
                "city",
                "compared_with",
                "report_topic_data"
            ]
        ]
    )
    
    #-----------------------------------------------------------------------------------------#
    # nesting content under top-level report vars
    #-----------------------------------------------------------------------------------------#
    
    # create deep copy 
    
    report_spec_content = report_spec.copy()
    
    # modify deep copy
    
    report_spec_content["report_content"] = [report_content]
    
    
    #-----------------------------------------------------------------------------------------#
    # constructing a DataFrame with the exact right nesting structure
    #-----------------------------------------------------------------------------------------#
    
    report_list = pd.DataFrame()
    
    report_list["report"] = report_spec_content.to_dict(orient = "records")
    
    
    #-----------------------------------------------------------------------------------------#
    # converting to JSON
    #-----------------------------------------------------------------------------------------#
    
    report_json = report_list.to_json(orient = "records", indent = 2)
    
    # find outer brackets
    
    # remove outer brackets and associated padding, converting array to object
    
    inner_object = re.sub("^\\[\n\s*|\s*\n\\]$", "", report_json)
    
    
    #-----------------------------------------------------------------------------------------#
    # saving JSON
    #-----------------------------------------------------------------------------------------#
    
    # construct file name
    
    filename = (
        "neighborhoodreports/reports/" + 
        report_spec["report_title"].iat[0].strip(string.punctuation) + 
        " in " + 
        report_spec["geo_entity_name"].iat[0] +
        ".json"
    )
    
    # write file
    
    with open(filename, 'w') as f:

        f.write(inner_object)


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
