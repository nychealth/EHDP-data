# Neighborhood reports

This folder contains the data behind the Neighborhood Reports feature of the EH Data Portal, which presents indicator data by neighborhood, grouped into topic areas.

- `data/report` — one JSON file per topic area / report-topic combination (e.g. `Climate_and_Health Climate Hazards.json`), with one record per indicator per neighborhood. Topic areas: Active_Design_Physical_Activity_and_Health, Asthma_and_the_Environment, Climate_and_Health, Housing_and_Health, Outdoor_Air_and_Health.
- `data/viz` — one JSON file per topic area (e.g. `Climate_and_Health.json`) with the visualization data for that topic's charts/maps.
- `metadata/nr_indicator_names.json` — indicator names and descriptions per topic area, keyed by `title` (topic) and `indicator_name`.
