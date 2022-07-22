SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER VIEW [dbo].[EXP_metadata_export] AS 

	SELECT DISTINCT
		si.indicator_id      AS MeasureID,
		id.how_calculated,
		id.internal_id       AS IndicatorID,
		iy.year_description  AS TimeDescription,
		iy.start_period,
		iy.end_period,
		iy.time_type         AS TimeType,
		gt.geo_type_name     AS GeoType,
		ii.name              AS IndicatorName,
		ii.description       AS IndicatorDescription,
		ii.label             AS IndicatorLabel,
		mt.description       AS MeasurementType,
		ddt.description      AS DisplayType,
		cs.source_list       AS Sources,
		si2.mapping          AS Map,
		si2.trend_time_graph AS Trend,

		-- replacing missing flag values with 0
		
		CASE WHEN dsp.Disparities IS null THEN 0
			ELSE dsp.Disparities
		END AS Disparities,

		CASE WHEN rc.RankReverse IS null THEN 0
			ELSE rc.RankReverse
		END AS RankReverse

	FROM subtopic_indicators AS si

		-- getting 1 mapping + trend row per Measure - if the indicator is mapped at all, set flag to 1

		LEFT JOIN (

			SELECT 
				indicator_id,
				max(cast(mapping AS int)) AS mapping, 
				max(cast(trend_time_graph AS int)) AS trend_time_graph
			FROM subtopic_indicators
			GROUP BY indicator_id

		) AS si2 ON si2.indicator_id = si.indicator_id

		LEFT JOIN subtopic             AS  st ON st.subtopic_id         = si.subtopic_id
		LEFT JOIN indicator_definition AS  id ON id.indicator_id        = si.indicator_id
		LEFT JOIN indicator_year       AS  iy ON iy.year_id             = si.year_id
		LEFT JOIN geo_type             AS  gt ON gt.geo_type_id         = si.geo_type_id
		LEFT JOIN internal_indicator   AS  ii ON ii.internal_id         = id.internal_id
		LEFT JOIN measurement_type     AS  mt ON mt.measurement_type_id = id.measurement_type_id
		LEFT JOIN display_data_type    AS ddt ON ddt.display_type_id    = id.display_type_id
		LEFT JOIN Consolidated_Sources_by_IndicatorID AS cs ON cs.indicator_id = id.indicator_id
		
		-- if there's a disparities link for the measure, Disparities will be 1

		LEFT JOIN (

			SELECT DISTINCT 
				base_indicator_id,
				1 AS Disparities
			FROM i_to_i 
			WHERE disparity_flag = 1

		) AS dsp ON dsp.base_indicator_id = si.indicator_id
		
		-- if this measure is rank-reversed, rankReverse will be 1
		
		LEFT JOIN (

			SELECT 
				indicator_id,
				max(cast(rankReverse AS int)) AS rankReverse
			FROM report_content
			GROUP BY indicator_id

		) AS rc ON rc.indicator_id = si.indicator_id
	
	WHERE 
		st.public_display_flag = 'Y'

GO
