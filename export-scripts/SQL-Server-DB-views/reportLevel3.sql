SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER VIEW dbo.reportLevel3_new AS

    SELECT DISTINCT TOP (100) PERCENT 

        -- rtd.report_content_id,
        -- rtd.report_id,
        -- r.title AS report_title,
        -- rtd.report_topic_id,
        -- rt.description AS report_topic,
        rtd.indicator_id AS MeasureID,
        -- rtd.sort_key,
        rtd.rankReverse,
        rtd.indicator_desc + ' ' + (
            CASE
                WHEN use_most_recent_year = 0 THEN (
                    SELECT year_description
                    FROM indicator_year AS iy
                    WHERE rtd.year_id = iy.year_id
                )
                ELSE (
                    -- most recent year subquery
                    SELECT TOP 1 
                        iy.year_description
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
                )
            END
        ) AS indicator_name,
        
        ii.short_name      AS indicator_short_name,
        ii.internal_id     AS IndicatorID,
        id.data_field_name AS indicator_data_name,
        ii.description     AS indicator_description,
        ddt.description    AS units,
        mt.description     AS measurement_type,
        '4'                AS indicator_neighborhood_rank, -- this is a placeholder for 4/42 and may be going away

        CASE
            WHEN u.show_data_flag = 0 THEN 'N/A' + COALESCE(u.character_display, '')
            ELSE CAST(
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
        
        ge.geo_entity_id,
        ge.name AS geo_entity_name,
        geb.name AS borough_name,
        uz.Zipcodes  AS zip_code

    FROM report_content AS rtd

        INNER JOIN indicator_definition AS  id ON rtd.indicator_id       = id.indicator_id
         LEFT JOIN display_data_type    AS ddt ON id.display_type_id     = ddt.display_type_id
         LEFT JOIN measurement_type     AS  mt ON id.measurement_type_id = mt.measurement_type_id
        INNER JOIN internal_indicator   AS  ii ON id.internal_id         = ii.internal_id
        INNER JOIN report               AS   r ON rtd.report_id          = r.report_id
        INNER JOIN report_topic         AS  rt ON rt.report_topic_id     = rtd.report_topic_id
        INNER JOIN report_geo_type      AS rgt ON r.report_id            = rgt.report_id
        INNER JOIN geo_type             AS  gt ON rgt.geo_type_id        = gt.geo_type_id
        INNER JOIN geo_entity           AS  ge ON gt.geo_type_id         = ge.geo_type_id
         LEFT JOIN UHF_to_ZipList       AS  uz ON (
            gt.geo_type_id = 3 AND
            uz.UHF42 = ge.geo_entity_id
        )

        INNER JOIN (
            
            SELECT
                borough_id,
                name
            FROM geo_entity
            WHERE geo_type_id = 1

        ) AS geb ON ge.borough_id = geb.borough_id

        INNER JOIN indicator_data AS cityD ON (
                rtd.indicator_id = cityD.indicator_id
            )
            AND (
                cityD.geo_type_id = 6 AND 
                cityD.geo_entity_id = 1
            )
            AND cityD.year_id IN (

                -- most recent year subquery
                SELECT TOP 1 
                    idata.year_id
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
            )

        INNER JOIN indicator_data AS boroD ON rtd.indicator_id = boroD.indicator_id
            AND (
                boroD.geo_type_id = 1 AND 
                boroD.geo_entity_id = ge.borough_id
            )
            AND boroD.year_id IN (

                -- most recent year subquery
                SELECT TOP 1 
                    idata.year_id 
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
            )

        INNER JOIN indicator_data AS nabeD ON rtd.indicator_id = nabeD.indicator_id
            AND (
                nabeD.geo_type_id = 3 AND 
                nabeD.geo_entity_id = ge.geo_entity_id
            )
            AND nabeD.year_id IN (

                -- most recent year subquery
                SELECT TOP 1 
                    idata.year_id
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
            )

        INNER JOIN unreliability AS u ON nabeD.unreliability_flag = u.unreliability_id

        INNER JOIN Report_UHF_indicator_Rank AS rr ON (
            rr.indicator_data_id = nabeD.indicator_data_id AND 
            rr.report_id = rtd.report_id
        )

        INNER JOIN Consolidated_Sources_by_IndicatorID AS s ON rtd.indicator_id = s.indicator_id

        INNER JOIN (

            -- Trend time period count subquery
            SELECT
                count(rd.Time) AS TimeCount,
                report_id,
                geo_entity_id,
                indicator_id
            FROM ReportData AS rd
            GROUP BY
                report_id,
                geo_entity_id,
                indicator_id
        ) AS rd ON rtd.indicator_id = rd.indicator_id
                AND ge.geo_entity_id = rd.geo_entity_id
                AND r.report_id      = rd.report_id

    WHERE r.public_flag = 1 

    -- ORDER BY
    --     rtd.report_id,
        -- rtd.report_topic_id
    --     rtd.sort_key

GO
