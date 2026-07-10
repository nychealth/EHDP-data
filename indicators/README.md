# Indicators

This folder contains indicator data. `metadata/metadata.json` contains an index of indicator contents and metadata (there is no separate `indicators.json`).

Each numbered json file in `data/` contains data for a single dataset, which corresponds to the `IndicatorID` in `metadata.json`.

## metadata/metadata.json
This file includes the following key fields:

| Field    | Description   |
|----------|---|
| IndicatorID  | The internal ID associated with this indicator |
| IndicatorName | The full name of this indicator  |
| IndicatorLabel | The label used for display purposes  |
| IndicatorDescription        | A text description of this indicator  |
| Comparisons | Comparison group(s) this indicator belongs to, if any — cross-referenced in `metadata/comparisons.json` (`null` if none) |
| Measures         | Measures associated with this indicator  |

`metadata_pretty.json` is the same content, pretty-printed for readability.

For each measure, there are the following fields:

| Field    | Description   |
|----------|---|
| MeasureID  | The measure ID associated with this indicator |
| MeasureName | The name of the measure |
| MeasurementType | The type of measurement. This may be a number, a rate, a percent, or other. |
| how_calculated | Text information on how this measure was calculated  |
| Sources        | Text information on this measure's data source |
| DisplayType         | Text field that includes measure information to be displayed with the value  |
| AvailableGeoTypes         | Geographic resolutions available in in the data  |
| AvailableTimePeriodIDs         | `TimePeriodID`s (referencing `metadata/TimePeriods.json`) for which this measure has data  |
| TrendNoCompare | Whether trend comparison is disabled for this measure (see `metadata/threshold_measures.csv`) |
| TrendThreshold | Threshold value used to flag notable trends for this measure, if applicable |
| VisOptions         | Specific visualization options associated with this indicator, including `map`, `trends`, `disparities`, and `links`. 1 = yes, and 0 = no.  |

## metadata/TimePeriods.json
Maps each `TimePeriodID` referenced elsewhere to its display label and range:

| Field | Description |
|-------|---|
| TimePeriodID | The internal ID referenced by `AvailableTimePeriodIDs` and data files' `TimePeriodID` |
| TimePeriod | The display label (e.g. `"1998"`, or a `YYYY-YY` range) |
| TimeType | The type of period (e.g. `year`) |
| start_period / end_period | Start/end of the period, as Unix epoch milliseconds |

## metadata/comparisons.json
Defines named comparison groups (e.g. for trend charts), each with a `ComparisonID`, `ComparisonName`, `LegendTitle`, `Y_axis_title`, and a list of `Indicators` (each an `IndicatorID`/`MeasureID`/`GeoTypeID`/`GeoTypeName`/`GeoID`/`Geography` combination).

## data json files
Each data file is numbered corresponding to the `IndicatorID`. Unlike the metadata files, each is a single JSON object of parallel arrays (one array per field, all the same length; significantly reduces file size) rather than an array of row objects — i.e. `data[0].MeasureID[i]`, `data[0].GeoID[i]`, etc. all refer to the same record at index `i`. Fields:

| Field    | Description   |
|----------|---|
| MeasureID  | The measure ID |
| GeoType        | The geography type for this entry |
| GeoID         | The geography ID for this entry  |
| TimePeriodID         | The time period for this entry, referencing `metadata/TimePeriods.json`  |
| Value         | The data value for this entry |
| DisplayValue         | The value to be displayed. In most instances this will be the same as the value, but in some instances, the actual value will be suppressed   |
| CI   | The confidence interval, if present for this data type.  |
| Note   | A text note for this value. |

(`MeasureName` and `MeasurementType` live in `metadata.json`, not in the data files.)
