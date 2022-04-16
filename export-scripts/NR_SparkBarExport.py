# This script is to take the report data, and create bar graph svgs for each neighborhood and indicator
# SVGs will be used to populate the front report page
# Note: saving as SVG requires `selenium` and a webdriver; I'm using `chromedriver-binary`

# Step one: import the csv into a pandas data frame
# https://www.datacamp.com/community/tutorials/pandas-to-csv

import pandas as pd
import altair as alt
from altair_saver import save

data_files = [
    "Housing and Health _data.csv", 
    "Outdoor Air and Health_data.csv",
    "Active Design Physical Activity and Health_data.csv", 
    "Asthma and the Environment_data.csv", 
    "Climate and Health_data.csv"
]

# looping through files

for file in data_files:

    print(file)

    df = pd.read_csv("neighborhoodreports/data/" + file)

    # convert End Date to date data type

    df.end_date = pd.to_datetime(df.end_date)

    # Step two: reduce the report file to only the rows we need
    # - only neighborhood level records (geo_type_name of UHF42)

    df = df[df.geo_type == 'UHF42']
    
    # - only the most recent data End Date for each data field
    
    df = df.sort_values('end_date')
    df = df.drop_duplicates(subset = ['data_field_name', 'geo_join_id'], keep = 'last')
    df = df.sort_values('geo_join_id')

    # - converted the integer to string so that I can concatenate to an image title later

    df['geo_join_id'] = df['geo_join_id'].astype(str)
    
    # Step three: for each data_field_name in the data frame, create a graph and write to SVG file
    # - create a list of distinct data_field_name / Neighborhood s,

    df = pd.DataFrame(
        df, 
        columns = ['data_field_name', 'neighborhood', 'data_value', 'geo_join_id']
    )
    # - then loop through the list
    
    for ind in df.index:
        
        # - filter by data field name to create dataset

        dset = df[df.data_field_name == df['data_field_name'][ind]]
        dset = dset.sort_values('data_value')

        # - use Altair, the python connector to Vega-Lite
        # - https://altair-viz.github.io/getting_started/overview.html

        chart = (
            alt.Chart(dset)
                .mark_bar()
                .encode(
                    x = alt.X('neighborhood', sort = 'y', axis = None),
                    y = alt.Y('data_value', axis = None),
                    
                    # The highlight will be set on the result of a conditional statement
                    
                    color = alt.condition(
                        
                        # If the neighborhoods match this test returns True,
                        
                        alt.datum.neighborhood == df['neighborhood'][ind],
                        alt.value('#00923E'),     # which sets the bar orange.
                        
                        # And if it's not true it sets the bar steelblue.
                        
                        alt.value('#D2D4CE')
                    )
                )
                .configure(background = 'transparent')
                .configure_axis(grid = False)
                .configure_view(strokeWidth = 0)
                .properties(height = 100, width = 300)
        )

        # - name each SVG with the data_field_name and the Neighborhood
        
        image_name = 'neighborhoodreports/images/' + df['data_field_name'][ind] + '_' + df['geo_join_id'][ind] + '.svg'

        save(chart, fp = image_name)
        
        # - viewBox="0 0 310 110" must be removed for ModLab team
        # - also adding in preserveAspectRatio="none" to allow Modlab designers more flexibility
        # - https://stackoverflow.com/questions/59058521/creating-a-script-in-python-to-alter-the-text-in-an-svg-file

        Change = open(image_name, "rt")
        data = Change.read()
        data = data.replace('viewBox="0 0 310 110"', '')
        data = data.replace('<svg class="marks"','<svg class="marks" preserveAspectRatio="none"')
        Change.close()
        
        Change = open(image_name, "wt")
        Change.write(data)
        Change.close()
        