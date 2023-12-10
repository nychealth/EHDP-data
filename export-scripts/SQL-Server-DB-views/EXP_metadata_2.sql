SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER VIEW dbo.EXP_metadata_2 AS 

    SELECT DISTINCT
        si.indicator_id     AS MeasureID,
        id.how_calculated,
        id.internal_id      AS IndicatorID,
        iy.year_id          AS TimePeriodID,
        gt.geo_type_name    AS GeoType,
        gt.description      AS GeoTypeDescription,
        ii.name             AS IndicatorName,
        ii.description      AS IndicatorDescription,
        ii.label            AS IndicatorLabel,
        mt.description      AS MeasurementType,
        ddt.description     AS DisplayType,
        cs.source_list      AS Sources,
        si.mapping          AS Map,
        si.trend_time_graph AS Trend,
        
        CASE WHEN si.ban_summary_flag = 1 THEN 0 ELSE 1
        END AS [Table],

        -- format measure name

        CASE WHEN ii.short_name IS NOT null 
             THEN ii.short_name + ', ' + mt.description 
             ELSE ii.name       + ', ' + mt.description 
        END AS MeasureName,

        -- replacing missing flag values with 0
        
        CASE WHEN id.rankReverse IS null THEN 0
             ELSE id.rankReverse
        END AS RankReverse

    FROM subtopic_indicators AS si

        LEFT JOIN subtopic             AS  st ON st.subtopic_id         = si.subtopic_id
        LEFT JOIN indicator_definition AS  id ON id.indicator_id        = si.indicator_id
        LEFT JOIN indicator_year       AS  iy ON iy.year_id             = si.year_id
        LEFT JOIN geo_type             AS  gt ON gt.geo_type_id         = si.geo_type_id
        LEFT JOIN internal_indicator   AS  ii ON ii.internal_id         = id.internal_id
        LEFT JOIN measurement_type     AS  mt ON mt.measurement_type_id = id.measurement_type_id
        LEFT JOIN display_data_type    AS ddt ON ddt.display_type_id    = id.display_type_id
        LEFT JOIN Consolidated_Sources_by_IndicatorID AS cs ON cs.indicator_id = id.indicator_id

    WHERE 
        st.public_display_flag = 'Y' AND
        si.creator_id = 1 -- repurpose as stage_flag: 0 = don't stage, 1 = stage

GO
