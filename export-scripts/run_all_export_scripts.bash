#!/bin/bash

###########################################################################################-
###########################################################################################-
##
## Running all data export scripts
##
###########################################################################################-
###########################################################################################-

#-----------------------------------------------------------------------------------------#
# setup
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# get parent dir for absolute path
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

base_dir=$(pwd)
export base_dir=$base_dir

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# source script to set environment params
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

source "$base_dir/export-scripts/set_environment.bash"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# choose to export spark bars
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

echo "-------------------------------------------------------------"
read -p "Run 'NR_sparkbars.R'? Yes [y] / No [*n] -- " -n 1 sparkbar
if [[ "$sparkbar" ]]; then
  printf "\n"
fi
echo "-------------------------------------------------------------"

#=========================================================================================#
# R
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# DE data
#-----------------------------------------------------------------------------------------#

echo ">>> DE_data_json"
Rscript "$base_dir/export-scripts/DE_data_json.R"

#-----------------------------------------------------------------------------------------#
# DE metadata
#-----------------------------------------------------------------------------------------#

echo ">>> DE_metadata_json"
Rscript "$base_dir/export-scripts/DE_metadata_json.R"

#-----------------------------------------------------------------------------------------#
# DE comparisons
#-----------------------------------------------------------------------------------------#

echo ">>> DE_comparisons_json"
Rscript "$base_dir/export-scripts/DE_comparisons_json.R"

#-----------------------------------------------------------------------------------------#
# DE TimePeriods
#-----------------------------------------------------------------------------------------#

echo ">>> DE_TimePeriods_json"
Rscript "$base_dir/export-scripts/DE_TimePeriods_json.R"

#-----------------------------------------------------------------------------------------#
# DE GeoLookup
#-----------------------------------------------------------------------------------------#

echo ">>> DE_GeoLookup_json"
Rscript "$base_dir/export-scripts/DE_GeoLookup_json.R"

#-----------------------------------------------------------------------------------------#
# NR data (for hugo & VegaLite)
#-----------------------------------------------------------------------------------------#

echo ">>> NR_data_json"
Rscript "$base_dir/export-scripts/NR_data_json.R"

#-----------------------------------------------------------------------------------------#
# NR spark bars
#-----------------------------------------------------------------------------------------#

if [[ "$sparkbar" == "y" ]]; then

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # run script to construct the spec
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

    echo ">>> NR_sparkbar_spec"
    npm install --silent
    node "$base_dir/export-scripts/NR_sparkbar_spec.js"

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # run the SVG export script
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

    echo ">>> NR_sparkbars"
    Rscript "$base_dir/export-scripts/NR_sparkbars.R"

fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
