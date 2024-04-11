#!/bin/bash

# deleting data files for merge

data_dirs=("indicators/data" "indicators/metadata" "neighborhood-reports/data/report" "neighborhood-reports/data/viz" "neighborhood-reports/metadata" "neighborhood-reports/images" "neighborhood-reports/images/json")

# get all the items first

json_to_delete=()
svg_to_delete=()

for dir in "${data_dirs[@]}"; do
    json_to_delete+=( $(find "$dir" -maxdepth 1 -type f -name "*.json") )
    svg_to_delete+=( $(find "$dir" -maxdepth 1 -type f -name "*.svg") )
done

# now delete all the items

for file in "${json_to_delete[@]}" "${svg_to_delete[@]}"; do
    rm "$file"
done
