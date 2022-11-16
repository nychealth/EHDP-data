SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER VIEW [dbo].[reportLevel3] AS

	SELECT TOP (100) PERCENT 

        rtd.report_content_id,
        rtd.report_id,
        rtd.report_topic_id,
        rtd.indicator_id,
        rtd.sort_key,
        rtd.rankReverse,
        rtd.indicator_desc + ' ' + (
            CASE
                WHEN use_most_recent_year = 0 THEN (
                    SELECT year_description
                    FROM indicator_year AS iy
                    WHERE rtd.year_id = iy.year_id
                )
                ELSE (
                    SELECT TOP 1 
                        iy.year_description ---- most recent year subquery
                    FROM
                        indicator_data AS idata
                        LEFT JOIN indicator_year AS iy ON idata.year_id = iy.year_id
                    GROUP BY
                        iy.year_description,
                        indicator_id,
                        geo_type_id,
                        end_period
                    HAVING
                        indicator_id = rtd.indicator_id AND 
                        geo_type_id = 3
                    ORDER BY
                        end_period DESC
                ) -- most recent year logic
            END
        ) AS indicator_name,
        
        ii.short_name AS indicator_short_name,

        -- add in URL for indicator
        --sample: http://a816-dohbesp.nyc.gov/IndicatorPublic/VisualizationData.aspx?id=2049,1,1,Summarize

        'http://a816-dohbesp.nyc.gov/IndicatorPublic/VisualizationData.aspx?id=' + CONVERT(varchar, ii.internal_id) + ',1,1,Summarize' AS indicator_URL,
        ii.internal_id     AS IndicatorID,
        id.data_field_name AS indicator_data_name,
        ii.description     AS indicator_description,
        ddt.description    AS units,
        mt.description     AS measurement_type,
        '4'                AS indicator_neighborhood_rank, -- this is a placeholder for 4/42 and may be going away

        CASE
            WHEN u.show_data_flag = 0 THEN 'N/A' + COALESCE(u.character_display, '')
            ELSE Cast(
                CAST(nabeD.data_value AS decimal(18, 1)) AS varchar
            ) + COALESCE(u.character_display, '')
        END AS data_value_geo_entity,

        CASE
            WHEN u.show_data_flag = 0 THEN NULL
            ELSE CAST(nabeD.data_value AS decimal(18, 1))
        END AS unmodified_data_value_geo_entity,

        CAST(boroD.data_value AS decimal(18, 1)) AS data_value_borough,
        CAST(cityD.data_value AS decimal(18, 1)) AS data_value_nyc,

        rr.reportRank                   AS data_value_rank, -- this is the calculated rank that takes rank_reverse into account
        u.character_display + u.message AS nabe_data_note,
        s.source_list                   AS data_source_list,
        rd.TimeCount,

        CASE
            WHEN (rd.TimeCount > 1) THEN 1
            ELSE 0
        END AS trend_flag,
        
        ge.geo_entity_id

    FROM report_content AS rtd

        JOIN indicator_definition   AS    id ON rtd.indicator_id       = id.indicator_id
        LEFT JOIN display_data_type AS   ddt ON id.display_type_id     = ddt.display_type_id
        LEFT JOIN measurement_type  AS    mt ON id.measurement_type_id = mt.measurement_type_id
        JOIN internal_indicator     AS    ii ON id.internal_id         = ii.internal_id
        JOIN report                 AS     r ON rtd.report_id          = r.report_id
        JOIN report_geo_type        AS   rgt ON r.report_id            = rgt.report_id
        JOIN geo_type               AS    gt ON rgt.geo_type_id        = gt.geo_type_id
        JOIN geo_entity             AS    ge ON gt.geo_type_id         = ge.geo_type_id

        JOIN indicator_data         AS cityD ON rtd.indicator_id       = cityD.indicator_id
            AND (
                cityD.geo_type_id = 6 AND 
                cityD.geo_entity_id = 1
            )
            AND cityD.year_id IN (

                SELECT TOP 1 
                    idata.year_id ---- most recent year subquery
                FROM indicator_data AS idata
                    LEFT JOIN indicator_year AS iy ON idata.year_id = iy.year_id
                GROUP BY
                    idata.year_id,
                    indicator_id,
                    geo_type_id,
                    end_period
                HAVING
                    indicator_id = rtd.indicator_id AND 
                    geo_type_id = 3
                ORDER BY
                    end_period DESC

            ) -- most recent year logic

        JOIN indicator_data AS boroD ON rtd.indicator_id = boroD.indicator_id
            AND (
                boroD.geo_type_id = 1 AND 
                boroD.geo_entity_id = ge.borough_id
            )
            AND boroD.year_id IN (

                SELECT TOP 1 
                    idata.year_id ---- most recent year subquery
                FROM indicator_data AS idata
                    LEFT JOIN indicator_year AS iy ON idata.year_id = iy.year_id
                GROUP BY
                    idata.year_id,
                    indicator_id,
                    geo_type_id,
                    end_period
                HAVING
                    indicator_id = rtd.indicator_id AND 
                    geo_type_id = 3
                ORDER BY
                    end_period DESC

            ) -- most recent year logic

        JOIN indicator_data AS nabeD ON rtd.indicator_id = nabeD.indicator_id
            AND (
                nabeD.geo_type_id = 3 AND 
                nabeD.geo_entity_id = ge.geo_entity_id
            )
            AND nabeD.year_id IN (

                SELECT TOP 1 
                    idata.year_id ---- most recent year subquery
                FROM indicator_data AS idata
                    LEFT JOIN indicator_year AS iy ON idata.year_id = iy.year_id
                GROUP BY
                    idata.year_id,
                    indicator_id,
                    geo_type_id,
                    end_period
                HAVING
                    indicator_id = rtd.indicator_id AND 
                    geo_type_id = 3
                ORDER BY
                    end_period DESC

            ) -- most recent year logic

        JOIN unreliability AS u ON nabeD.unreliability_flag = u.unreliability_id
        JOIN Report_UHF_indicator_Rank AS rr ON rr.indicator_data_id = nabeD.indicator_data_id
            AND rr.report_id = rtd.report_id
        JOIN Consolidated_Sources_by_IndicatorID AS s ON rtd.indicator_id = s.indicator_id
        JOIN (
            SELECT
                count(rd.Time) AS TimeCount,
                report_id,
                geo_entity_id,
                indicator_id --Trend time period count subquery
            FROM ReportData AS rd
            GROUP BY
                report_id,
                geo_entity_id,
                indicator_id
        ) AS rd ON rtd.indicator_id = rd.indicator_id
                AND ge.geo_entity_id = rd.geo_entity_id
                AND r.report_id      = rd.report_id

    WHERE 
        r.public_flag = 1 

    ORDER BY
        rtd.report_id,
        rtd.report_topic_id,
        rtd.sort_key

GO
