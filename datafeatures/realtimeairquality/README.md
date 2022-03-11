# Data feature: Real-time Air Quality in New York City.

This repository contains near-real-time air quality from monitors in NYC. You can view these data in context on the [Environment and Health Data Portal's Air Quality Hub, here](https://a816-dohbesp.nyc.gov/IndicatorPublic/AQHub/realtime.html).

![image](https://user-images.githubusercontent.com/55593359/137518896-bbee3dfe-6f55-4e45-8182-e32bd582f6cf.png)

## About the data 
### Measurements (RT_flat.csv)
The data are hourly PM<sub>2.5</sub> measurements, in micrograms per cubic meter of air. Fine particles (PM<sub>2.5</sub>) are tiny airborne solid and liquid particles less than 2.5 microns in diameter. PM<sub>2.5</sub> is the most harmful urban air pollutant. It is small enough to penetrate deep into the lungs and enter the bloodstream, which can worsen lung and heart disease and lead to hospital admissions and premature deaths. 

PM<sub>2.5</sub> can either be directly emitted or formed in the atmosphere from other pollutants. Fuel combustion in vehicles, boilers in buildings, power plants, construction equipment, marine vessels and commercial cooking are all common sources of PM<sub>2.5</sub>. Up to 40% of the PM<sub>2.5</sub> in New York City's air comes from sources in areas upwind from the city, such as coal-burning power plants in the Midwest. 

Measurements included are from monitors located along high-traffic corridors or neighborhood locations to assess PM<sub>2.5</sub> concentrations in the immediate vicinity. The results shown may not be indicative of overall PM<sub>2.5</sub> concentrations in the neighborhood. 

Times shown (starttime) are in eastern standard time and do not change based on daylight savings time. The measurements are an average of all the PM<sub>2.5</sub> measurements during the given hour. For example, all measurements collected between 9:00 AM and 10:00 AM are averaged and stored as 9:00 AM.

All data are preliminary and subject to change.

### Monitor locations
| Location            | Latitude  | Longitude  |
|---------------------|-----------|------------|
| Broadway/35th St    |40.75069	  |-73.98783   |
| Cross Bronx Expy  	|40.845167	|-73.906143  |
| Hale Bus Depot	    |40.821311	|-73.936315  |
| Hunts Point	        |40.819009	|-73.886198  |
| Manhattan Bridge	  |40.71651	  |-73.997004  |
| Midtown-DOT	        |40.755082	|-73.990415  |
| Queens College	    |40.737107	|-73.821556  |
| Queensboro Bridge	  |40.761234	|-73.963886  |
| Williamsburg	      |40.710614	|-73.95938   |
| Williamsburg Bridge	|40.718073	|-73.986059  |

Not all monitoring locations will necessarily be utilized at the same time due to operational constraints.


### Update frequency
Data are pushed to this repository every hour and cover the last five days. However, each hourly update might not include new data.

## About the New York City Community Air Survey
The [NYC Community Air Survey](https://nyccas.cityofnewyork.us/nyccas2021v9/report/2) is the largest ongoing urban air monitoring program of any U.S. City.  NYCCAS, which began collecting data in December 2008, is a collaboration between the Health Department and Queens College of the City University of New York and provides data to:
- Help inform OneNYC, the City’s sustainability plan
- Track changes in air quality over time
- Estimate exposures for health research
- Inform the public about local topics, such as air quality in the time of COVID-19, recent air quality improvements, car-free zones, unique studies conducted in New York City and what NYCCAS monitoring tells us about the city's neighborhoods.

## Contact us
If you have questions about the data, you can log issues and we'll follow up as soon as we can. 

## Communications disclaimer
With regard to GitHub platform communications, staff from the New York City Department of Health and Mental Hygiene are authorized to answer specific questions of a technical nature with regard to this repository. Staff may not disclose private or sensitive data. 
