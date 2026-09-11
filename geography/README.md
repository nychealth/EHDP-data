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

## PUMA to Community District

`puma2020_to_cd.csv` (`PUMA2020,CD`) and `puma2010_to_subboro_cd.csv` (`PUMA2010,Subboro,CD`) map each Community District to the PUMA — and, in the 2010 vintage, the subborough area — that reports on it. Both are 59 rows, one per CD. Every CD maps to exactly one PUMA, and four PUMAs cover two CDs each, so each file resolves to 55 distinct PUMAs. The key columns join directly to `GeoLookup.json`: `CD` values are DCP `BoroCode` ids matching CD's own `GeoID` (Manhattan CD 1 is `101`), and the `PUMA2010`, `PUMA2020` and `Subboro` values match their own geography types' `GeoID` values, 55 of 55 in each case with none missing and none extra (checked 2026-09-11).

**The two vintages are not interchangeable.** Both merge exactly four PUMAs across two CDs each, but not the same four. PUMA2010 merges Manhattan CD 4 with CD 5 and leaves CD 6 on its own; PUMA2020 merges CD 5 with CD 6 and leaves CD 4 on its own. The other three merged pairs are identical in both files (Manhattan CD 1+2, Bronx CD 1+2, Bronx CD 3+6). So picking the wrong vintage is correct for 56 of the 59 districts and silently wrong for three, in one borough — which no spot check outside Manhattan will catch. Anything consuming these should name the vintage it means; never an unqualified `PUMA`.

The CD-level demographic indicators published here are on the PUMA2010 merge structure. The four CD pairs that report one shared value across indicators 103, 2335, 2334, 17 and 2336 are exactly PUMA2010's four merged groups, and differ from PUMA2020's (checked 2026-09-11, at each indicator's latest time period).

**Provenance:** both files are hand-maintained inputs in the working repo where geography is prepared; no script there generates them. TODO: record the source they were transcribed from.
