# Export scripts    
This folder contains R and shell (bash/PowerShell) scripts used to export data and metadata from our database to this repo.

## Data/metadata export scripts

- `DE_data_json.R` produces the JSON files in [indicators/data](/indicators/data). File structure is detailed in the _indicators_ folder README under [Data json files](/indicators#data-json-files).
- `DE_metadata_json.R` produces `indicators/metadata/metadata.json` (and `metadata_pretty.json`), which contains an index of indicator contents and metadata. File structure is detailed in the _indicators_ folder README under [metadata/metadata.json](/indicators#metadatametadatajson).
- `DE_comparisons_json.R` produces `indicators/metadata/comparisons.json`.
- `DE_TimePeriods_json.R` produces `indicators/metadata/TimePeriods.json`.
- `DE_GeoLookup_json.R` produces `geography/GeoLookup.json` from the shapefile-derived source data in `geography/` (see the [geography README](/geography)).
- `NR_data_json.R` produces the neighborhood-report JSON files in `neighborhood-reports/data/viz` and the indicator name/description metadata in `neighborhood-reports/metadata/nr_indicator_names.json`. See the [neighborhood-reports README](/neighborhood-reports).
- `syndromic_push.r` pulls and pushes the daily syndromic surveillance (heat) data update on RStudio Server — see [key-topics/heat-syndrome](/key-topics/heat-syndrome).

## Orchestration / setup scripts

- `run_all_export_scripts.bash` / `.ps1` — runs all of the data/metadata export scripts above in sequence.
- `set_environment.R` / `.bash` / `.ps1` — sets environment parameters (e.g. database connection details) used by the export scripts.
- `update_sql_views_procedures.bash` / `.ps1` — applies the view/stored-procedure definitions in `SQL-Server-DB-views/` to the database.

## `SQL-Server-DB-views/`

SQL view definitions that the export scripts query against: `DE_data.sql`, `DE_metadata.sql`, `DE_comparisons.sql`, `DE_links.sql`, `NR_data.sql`, `UHF_to_ZipList.sql`, `concat_sources.sql`.
