# deleting data files

$data_dirs = "indicators/data", "indicators/metadata", "neighborhood-reports/data/report", "neighborhood-reports/data/viz", "neighborhood-reports/metadata", "neighborhood-reports/images"

# get al the items first (which is necessary for some reason)

$json_to_delete = Get-ChildItem -Path $data_dirs -Filter *.json
$svg_to_delete = Get-ChildItem -Path $data_dirs -Filter *.svg

# now delete all the items

Remove-Item $json_to_delete
Remove-Item $svg_to_delete



