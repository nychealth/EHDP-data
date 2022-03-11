# Data feature: Air quality explorer

The file `aqe-nta.csv` feeds the Neighborhood Air Quality interactive page. This file contains data by NYC Neighborhood Tabulation Area, and includes the following key fields:

| Field    | Description   |
|----------|---|
| NTACode  | Neighborhood Tabulation Area code  |
| BoroCode | NYC Borough code  |
| BoroName | NYC Borough name  |
| NTAName        | Name of Neighborhood Tabulation Area  |
| Avg_annavg_PM25         | Average annual value of PM 2.5 (fine particles), measured in micrograms per cubic meter  |
| Avg_annavg_NO2         | Average annual value of Nitrogen Dioxide (NO2), measured in parts per billion, or ppb  |
| tertile_buildingemissions         | Neighborhoods' estimates for building emissions are sorted into tertiles. 3 = high, 2 = medium, and 1 = low.  |
| tertile_buildingdensity         | Neighborhoods' estimates for building density are sorted into tertiles. 3 = high, 2 = medium, and 1 = low.  |
| tertile_trafficdensity         | Neighborhoods' estimates for traffic density are sorted into tertiles. 3 = high, 2 = medium, and 1 = low.  |
| tertile_industrial         | Neighborhoods' estimates for industrial area are sorted into tertiles. 3 = high, 2 = medium, and 1 = low.  |