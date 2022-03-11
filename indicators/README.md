# Indicators

This folder contains indicator data. `indicators.json` contains an index of contents and metadata.

Each numbered json file contains data for a single dataset, which corresponds to the `indicatorID` in `indicators.json`.

## Indicators.json
This file includes the following key fields:

| Field    | Description   |
|----------|---|
| IndicatorID  | The internal ID associated with this indicator |
| Indicator Name | The full name of this indicator  |
| IndicatorShortname | The short name used for display purposes  |
| IndicatorDescription        | A text description of this indicator  |
| Measures         | Measures associated with this indicator  |

For each measure, there are the following fields:

| Field    | Description   |
|----------|---|
| MeasureID  | The measure ID associated with this indicator |
| MeasurementType | The type of measurement. This may be a number, a rate, a percent, or other. |
| how_calculated | Text information on how this measure was calculated  |
| Sources        | Text information on this measure's data source |
| DisplayType         | Text field that includes measure information to be displayed with the value  |
| AvailableGeographyTypes         | Geographic resolutions available in in the data  |
| AvailableTimes         | Time units available in the data. Includes `TimeDescription`, `start_period`, and `end_period`  |
| VisOptions         | Specific visualization options associated with this indicator, including `map`, `trends`, `disparities`, and `links`. 1 = yes, and 0 = no.  |

## Data json files
Each data file is numbered corresponding to the IndicatorID. They include the following key fields:

| Field    | Description   |
|----------|---|
| MeasureID  | The measure ID |
| MeasureName | The name of the measure |
| MeasurementType | The type of measurement. This may be a number, a rate, a percent, or other.  |
| GeoType        | The geography type for this entry |
| GeoID         | The geography ID for this entry  |
| Time         | The time for this entry  |
| Value         | The data value for this entry |
| DisplayValue         | The value to be displayed. In most instances this will be the same as the value, but in some instances, the actual value will be suppressed   |
| CI   | The confidence interval, if present for this data type.  |
| Note   | A text note for this value. |