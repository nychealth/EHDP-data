# Geography files

This folder contains geography files used on the EH Data Portal. 

`GeoLookup.csv` and `GeoLookup.json` are used to join to data files to display the names of the geographies, and the latitude and longitude of their centroids for the purpose of mapping counts. `GeoLookup.json` is produced from the same source data by `export-scripts/DE_GeoLookup_json.R`.

`[geography].topo.json` files are topo.json files for the geography used in the name. These include:
- NTA: Neighborhood Tabulation Area (also versioned as `NTA2010`/`NTA_2010` and `NTA2020`/`NTA_2020`)
- UHF42: United Hospital Fund 42 neighborhoods
- UHF34: United Hospital Fund 34 neighborhoods
- CD: Community Districts
- CDTA2020/CDTA_2020: 2020 Community District Tabulation Areas
- PUMA/Subborough: Public Use Microdata Areas (also versioned as `PUMA2010` and `PUMA2020`)
- MODZCTA: Modified ZIP Code Tabulation Areas
- Borough: NYC Boroughs
- CityCouncilDistrict: NYC Council Districts
- RMZ: Hurricane evacuation / coastal flood risk zones
- NYCKids: NYC Kids neighborhoods (also versioned by year — 2017, 2019, 2021, 2023)
- ny_harbor: NY Harbor shoreline, used as a map overlay

Note: some geography types have two naming conventions in use (e.g. `NTA2010.topo.json` vs `NTA_2010.topo.json`) depending on when the file was added — check both if a lookup fails.

## Source data and generation

The `.topo.json`/`.geojson` files above are built from raw source shapefiles downloaded via `download_geo_files.R` (from the [BYTES of the BIG APPLE](https://www.nyc.gov/site/planning/data-maps/open-data.page)) and converted with `create_TopoJSON.R`. Source shapefiles live in per-geography subfolders (`UHF 34/`, `UHF 42/`, `modzcta/`, `nybb_24c/`, `nycd_24c/`, `nycdta2020_24c/`, `nynta2010_24c/`, `nynta2020_24c/`, `nypuma2010_24c/`, `nypuma2020_24c/`), named for the DCP shapefile release version (`24c`, tracked in the `release` file; the `geos` file lists which shapefile sets to process). Supporting name/crosswalk CSVs: `cd_names.csv`, `puma_2010_names.csv`, `puma_2020_names.csv`, `puma_to_subboro.csv`, `zcta_to_uhf.csv`.
