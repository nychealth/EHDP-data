SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER VIEW [dbo].[reportLevel3] AS
SELECT  TOP (100000) [report_content_id]
      ,report_topic_data.[report_id]
      ,[report_topic_id]
    --,ge.name as NABE
      ,report_topic_data.[indicator_id]
    --  ,report_topic_data.[year_id]	-- use a case statement to get the year description or if '0' find the most recent year from UHF42/indicatorID
    --  ,[use_most_recent_year]  --or use this in the case statement
      ,report_topic_data.[sort_key]
      ,report_topic_data.[rankReverse]
	  ,report_topic_data.indicator_desc + ' ' +
		(CASE WHEN [use_most_recent_year]=0 
				THEN (SELECT year_description FROM indicator_year iy WHERE report_topic_data.[year_id]=iy.year_id) 
				ELSE (SELECT top 1 iy.year_description      ---- most recent year subquery
					  FROM [indicator_data] idata
					  Left join [indicator_year] iy on idata.year_id=iy.year_id
					  GROUP BY iy.year_description, indicator_id, geo_type_id, end_period
					  HAVING indicator_id= report_topic_data.indicator_id and geo_type_id=3
					  ORDER BY end_period desc)-- most recent year logic
				END) as [indicator_name]  
	  ,ii.short_name as [indicator_short_name]
	  -- add in URL for indicator
	  --sample: http://a816-dohbesp.nyc.gov/IndicatorPublic/VisualizationData.aspx?id=2049,1,1,Summarize
	  ,'http://a816-dohbesp.nyc.gov/IndicatorPublic/VisualizationData.aspx?id='+CONVERT(varchar,ii.internal_id)+',1,1,Summarize' as [indicator_URL]
	  ,id.data_field_name as [indicator_data_name]
	  ,ii.description as [indicator_description]
	  ,ddt.description as [units]
	  ,mt.description as [measurement_type]
	  ,'4' as [indicator_neighborhood_rank] -- this is a placeholder for 4/42 and may be going away
	  ,CASE WHEN u.show_data_flag=0 THEN 'N/A' + COALESCE(u.character_display,'')
			ELSE Cast(CAST(nabeD.data_value as decimal(18,1)) as varchar) + COALESCE(u.character_display,'') 
			END as [data_value_geo_entity]
	  ,CASE WHEN u.show_data_flag=0 THEN NULL 
			ELSE CAST(nabeD.data_value as decimal(18,1))
			END as [unmodified_data_value_geo_entity]
	  ,CAST(boroD.data_value as decimal(18,1)) as [data_value_borough]
	  --,boroD.data_value as [unmodified_data_value_borough]
	  --,cityD.data_value as [data_value_nyc]
	  ,CAST(cityD.data_value as decimal(18,1)) as [data_value_nyc]
	  ,rr.reportRank as [data_value_rank]  -- this is the calculated rank that takes rank_reverse into account
	  --,nabeD.unreliability_flag as [unreliability_flag] --this is the reliability of the neighborhood value
	  ,u.character_display+u.message as nabe_data_note
	  ,s.source_list as data_source_list
	  ,rd.TimeCount
	  ,CASE WHEN (rd.TimeCount>1) then 1 else 0 end as trend_flag
	  ,ge.geo_entity_id
  FROM [report_content] report_topic_data
  join indicator_definition id on report_topic_data.indicator_id=id.indicator_id
  left join display_data_type ddt on id.display_type_id=ddt.display_type_id
  left join measurement_type mt on id.measurement_type_id=mt.measurement_type_id
  join internal_indicator ii on id.internal_id=ii.internal_id
  join report r on report_topic_data.report_id=r.report_id
  join report_geo_type on r.report_id=report_geo_type.report_id
  join geo_type gt on report_geo_type.geo_type_id=gt.geo_type_id
  join geo_entity ge on gt.geo_type_id=ge.geo_type_id
  --join (SELECT borough_id, name FROM geo_entity WHERE geo_type_id=1) geb on ge.borough_id=geb.borough_id
  join indicator_data cityD on report_topic_data.indicator_id=cityD.indicator_id 
					AND (cityD.geo_type_id=6 and cityD.geo_entity_id=1)
					AND cityD.year_id in (SELECT top 1 idata.year_id      ---- most recent year subquery
					  FROM [indicator_data] idata
					  Left join [indicator_year] iy on idata.year_id=iy.year_id
					  GROUP BY idata.year_id, indicator_id, geo_type_id, end_period
					  HAVING indicator_id= report_topic_data.indicator_id and geo_type_id=3
					  ORDER BY end_period desc)-- most recent year logic
  join indicator_data boroD on report_topic_data.indicator_id=boroD.indicator_id 
					AND (boroD.geo_type_id=1 and boroD.geo_entity_id=ge.borough_id)
					AND boroD.year_id in (SELECT top 1 idata.year_id      ---- most recent year subquery
					  FROM [indicator_data] idata
					  Left join [indicator_year] iy on idata.year_id=iy.year_id
					  GROUP BY idata.year_id, indicator_id, geo_type_id, end_period
					  HAVING indicator_id= report_topic_data.indicator_id and geo_type_id=3
					  ORDER BY end_period desc)-- most recent year logic
  join indicator_data nabeD on report_topic_data.indicator_id=nabeD.indicator_id 
					AND (nabeD.geo_type_id=3 and nabeD.geo_entity_id=ge.geo_entity_id)
					AND nabeD.year_id in (SELECT top 1 idata.year_id      ---- most recent year subquery
					  FROM [indicator_data] idata
					  Left join [indicator_year] iy on idata.year_id=iy.year_id
					  GROUP BY idata.year_id, indicator_id, geo_type_id, end_period
					  HAVING indicator_id= report_topic_data.indicator_id and geo_type_id=3
					  ORDER BY end_period desc)-- most recent year logic
	join unreliability u on nabeD.unreliability_flag=u.unreliability_id 
	join Report_UHF_indicator_Rank rr on rr.indicator_data_id=nabeD.indicator_data_id AND rr.report_id=report_topic_data.report_id 
	join Consolidated_Sources_by_IndicatorID s on report_topic_data.indicator_id=s.indicator_id
	join (select count(rd.Time) as TimeCount,report_id,geo_entity_id,indicator_id		--Trend time period count subquery
		  FROM [ReportData] rd
		  Group by report_id,geo_entity_id,indicator_id)
		rd on report_topic_data.indicator_id=rd.indicator_id AND ge.geo_entity_id=rd.geo_entity_id AND r.report_id=rd.report_id
  WHERE r.public_flag=1
			--and report_topic_data.report_content_id=336
  ORDER BY report_topic_data.report_id, report_topic_data.report_topic_id, report_topic_data.sort_key
GO
