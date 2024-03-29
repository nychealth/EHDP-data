# This script is to take the report data, and create bar graph svgs for each neighborhood and indicator
# SVGs will be used to populate the front report page
# Note: saving as SVG requires `selenium` and a webdriver; I'm using `chromedriver-binary`

# Step one: import the csv into a pandas data frame
# https://www.datacamp.com/community/tutorials/pandas-to-csv

import pandas as pd
import altair as alt
import os
import warnings
import subprocess
import re
import platform
from joblib import Parallel, delayed

# set cores

cpus = (int(os.cpu_count()/2) - 1) if os.cpu_count() <= 8 else 6

# prevent other warnings

warnings.simplefilter("ignore")

# get environemnt vars

base_dir = os.environ.get("base_dir", "")
conda_prefix = os.environ.get("CONDA_PREFIX")

# get system

system = platform.system()

if (base_dir == ""):
    
    # get current folder
    
    this_dir = os.path.basename(os.path.abspath("."))
    
    # if the current folder is "EHDP-data", use the absolute path to it
    
    if (this_dir == "EHDP-data"):
        
        base_dir = os.path.abspath(".")
        
    else:
        
        # if the current folder is below "EHDP-data", switch it
        
        base_dir = re.sub(r"(.*EHDP-data)(.*)", r"\1", os.path.abspath("."))
        
    os.environ["base_dir"] = base_dir

# create images dir if not exists

os.makedirs(base_dir + "/neighborhood-reports/images/", exist_ok = True)

# define chart fun

def chart_fun(ind, df, base_dir, conda_prefix):

    # - filter by data field name to create dataset

    dset = df[df.indicator_data_name == df['indicator_data_name'][ind]]
    dset = dset.sort_values('unmodified_data_value_geo_entity')

    # - use Altair, the python connector to Vega-Lite
    # - https://altair-viz.github.io/getting_started/overview.html

    chart = (
        alt.Chart(dset)
            .mark_bar()
            .encode(
                x = alt.X('neighborhood', sort = 'y', axis = None),
                y = alt.Y('unmodified_data_value_geo_entity', axis = None),
                
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

    # get VL json spec

    chart_json = chart.to_json()

    # - name each SVG with the indicator_data_name and the Neighborhood

    image_name = base_dir + '/neighborhood-reports/images/' + df['indicator_data_name'][ind] + '_' + df['geo_join_id'][ind] + '.svg'

    # use VL CLI program to create SVG

    if (system == "Windows"):
        vl2svg = 'node ' + conda_prefix + '/Library/share/vega-lite-cli/node_modules/vega-lite/bin/vl2svg'
    else:
        vl2svg = "vl2svg"

    chart_svg = subprocess.run(vl2svg, input = chart_json, text = True, capture_output = True).stdout

    # - viewBox="0 0 310 110" must be removed for ModLab team
    # - also adding in preserveAspectRatio="none" to allow Modlab designers more flexibility
    # - https://stackoverflow.com/questions/59058521/creating-a-script-in-python-to-alter-the-text-in-an-svg-file

    chart_svg = chart_svg.replace('viewBox="0 0 310 110"', '').replace('<svg class="marks"','<svg class="marks" preserveAspectRatio="none"')

    # create file for chart

    chart_file = open(image_name, "wt")
    chart_file.write(chart_svg)
    chart_file.close()


# get viz data files

data_files = os.listdir(base_dir + "/neighborhood-reports/data/viz/")

# looping through files (run this in parallel)

for file in data_files:
    
    print("> ", file)
    
    df = pd.read_json(base_dir + "/neighborhood-reports/data/viz/" + file)
    
    # convert End Date to date data type
    
    df.end_date = pd.to_datetime(df.end_date)
    
    # Step two: reduce the report file to only the rows we need
    # - only neighborhood level records (geo_type_name of UHF42)
    
    df = df[df.geo_type == 'UHF42']
    
    # - only the most recent data End Date for each data field
    
    df = df.sort_values('end_date')
    df = df.drop_duplicates(subset = ['indicator_data_name', 'geo_join_id'], keep = 'last')
    df = df.sort_values('geo_join_id')
    
    # - converted the integer to string so that I can concatenate to an image title later
    
    df['geo_join_id'] = df['geo_join_id'].astype(str)
    
    # Step three: for each indicator_data_name in the data frame, create a graph and write to SVG file
    # - create a list of distinct indicator_data_name / Neighborhood s,
    
    df = pd.DataFrame(
        df, 
        columns = ['indicator_data_name', 'neighborhood', 'unmodified_data_value_geo_entity', 'geo_join_id']
    )
    
    # - then loop through the list

    results = Parallel(
        n_jobs = cpus, 
        prefer = "threads", 
        verbose = 1
    )(delayed(chart_fun)(ind, df, base_dir, conda_prefix) for ind in df.index)
