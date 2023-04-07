SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER VIEW dbo.reportLevel3_new AS

    SELECT DISTINCT

        -- rc.report_content_id,
        -- rc.report_id,
        -- rpt.title AS report_title,
        -- rc.report_topic_id,
        -- rt.description AS report_topic,
        rc.indicator_id AS MeasureID,
        -- rc.sort_key,
        rc.rankReverse,
        rc.indicator_desc + ', ' + (
            CASE WHEN use_most_recent_year = 0 THEN (
                SELECT year_description
                FROM indicator_year AS iy
                WHERE iy.year_id = rc.year_id
            )
            ELSE (
                -- most recent year subquery
                SELECT TOP 1 
                    iy.year_description
                FROM
                    indicator_data AS idata
                    LEFT JOIN indicator_year AS iy ON iy.year_id = idata.year_id
                GROUP BY
                    iy.year_description,
                    indicator_id,
                    geo_type_id,
                    end_period
                HAVING
                    indicator_id = rc.indicator_id AND 
                    geo_type_id = 3
                ORDER BY
                    end_period DESC
            )
            END
        ) AS indicator_name,
        
        ii.short_name        AS indicator_short_name,
        ii.internal_id       AS IndicatorID,
        idef.data_field_name AS indicator_data_name,
        ii.description       AS indicator_description,
        ddt.description      AS units,
        mt.description       AS measurement_type,
        rr.RankByValue       AS indicator_neighborhood_rank,

        CASE WHEN u.show_data_flag = 0 THEN 'N/A' + COALESCE(u.character_display, '')
            ELSE CAST(
                CAST(nbd.data_value AS decimal(18, 1)) AS varchar
            ) + COALESCE(u.character_display, '')
        END AS data_value_geo_entity,

        CASE WHEN u.show_data_flag = 0 THEN NULL
            ELSE CAST(nbd.data_value AS decimal(18, 1))
        END AS unmodified_data_value_geo_entity,

        CAST(brd.data_value AS decimal(18, 1)) AS data_value_borough,
        CAST(ctd.data_value AS decimal(18, 1)) AS data_value_nyc,

        rr.reportRank                   AS data_value_rank, -- this is the calculated rank that takes rank_reverse into account
        u.character_display + u.message AS nbr_data_note,
        s.source_list                   AS data_source_list,
        rd.TimeCount,

        CASE WHEN (rd.TimeCount > 1) THEN 1 ELSE 0
        END AS trend_flag,

        ge.geo_entity_id,
        ge.name     AS geo_entity_name,
        geb.name    AS borough_name,
        uz.Zipcodes AS zip_code,
        nbd.year_id

    FROM report_content AS rc

        INNER JOIN report               AS  rpt ON rpt.report_id          = rc.report_id
        INNER JOIN indicator_definition AS idef ON idef.indicator_id      = rc.indicator_id
        INNER JOIN display_data_type    AS  ddt ON ddt.display_type_id    = idef.display_type_id
        INNER JOIN measurement_type     AS   mt ON mt.measurement_type_id = idef.measurement_type_id
        INNER JOIN internal_indicator   AS   ii ON ii.internal_id         = idef.internal_id
        -- INNER JOIN report_topic         AS   rt ON rt.report_topic_id     = rc.report_topic_id
        INNER JOIN report_geo_type      AS  rgt ON rgt.report_id          = rpt.report_id
        INNER JOIN geo_type             AS   gt ON gt.geo_type_id         = rgt.geo_type_id
        INNER JOIN geo_entity           AS   ge ON ge.geo_type_id         = gt.geo_type_id
        INNER JOIN UHF_to_ZipList       AS   uz ON (
            uz.UHF42 = ge.geo_entity_id AND
            gt.geo_type_id = 3
        )

        INNER JOIN (
            SELECT
                borough_id,
                name
            FROM geo_entity
            WHERE geo_type_id = 1
        ) AS geb ON geb.borough_id = ge.borough_id

        INNER JOIN indicator_data AS ctd ON ctd.indicator_id = rc.indicator_id
            AND (
                ctd.geo_type_id = 6 AND 
                ctd.geo_entity_id = 1
            )
            AND ctd.year_id IN (
                -- most recent year subquery
                SELECT TOP 1 
                    idata.year_id
                FROM indicator_data AS idata
                    LEFT JOIN indicator_year AS iy ON iy.year_id = idata.year_id
                GROUP BY
                    idata.year_id,
                    indicator_id,
                    geo_type_id,
                    end_period
                HAVING
                    indicator_id = rc.indicator_id AND 
                    geo_type_id = 3
                ORDER BY
                    end_period DESC
            )

        INNER JOIN indicator_data AS brd ON brd.indicator_id = rc.indicator_id
            AND (
                brd.geo_type_id = 1 AND 
                brd.geo_entity_id = ge.borough_id
            )
            AND brd.year_id IN (
                -- most recent year subquery
                SELECT TOP 1 
                    idata.year_id 
                FROM indicator_data AS idata
                    LEFT JOIN indicator_year AS iy ON iy.year_id = idata.year_id
                GROUP BY
                    idata.year_id,
                    indicator_id,
                    geo_type_id,
                    end_period
                HAVING
                    indicator_id = rc.indicator_id AND 
                    geo_type_id = 3
                ORDER BY
                    end_period DESC
            )

        INNER JOIN indicator_data AS nbd ON nbd.indicator_id = rc.indicator_id
            AND (
                nbd.geo_type_id = 3 AND 
                nbd.geo_entity_id = ge.geo_entity_id
            )
            AND nbd.year_id IN (

                -- most recent year subquery
                SELECT TOP 1 
                    idata.year_id
                FROM indicator_data AS idata
                    LEFT JOIN indicator_year AS iy ON iy.year_id = idata.year_id
                GROUP BY
                    idata.year_id,
                    indicator_id,
                    geo_type_id,
                    end_period
                HAVING
                    indicator_id = rc.indicator_id AND 
                    geo_type_id = 3
                ORDER BY
                    end_period DESC
            )

        LEFT JOIN subtopic_indicators AS si ON (
            si.indicator_id        = rc.indicator_id AND 
            si.geo_type_id         = rgt.geo_type_id AND 
            si.year_id             = nbd.year_id
        )

        INNER JOIN unreliability AS u ON u.unreliability_id = nbd.unreliability_flag

        INNER JOIN Report_UHF_indicator_Rank AS rr ON (
            rr.indicator_data_id = nbd.indicator_data_id AND 
            rr.report_id         = rc.report_id
        )

        INNER JOIN Consolidated_Sources_by_IndicatorID AS s ON rc.indicator_id = s.indicator_id

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
        ) AS rd ON (
            rd.indicator_id  = rc.indicator_id AND
            rd.geo_entity_id = ge.geo_entity_id AND
            rd.report_id     = rpt.report_id
        )

    WHERE 
        rpt.public_flag = 1 AND 
        si.creator_id = 1 AND 
        rc.report_id IN (73, 77, 78, 79, 82)

    -- ORDER BY
    --     rc.report_id,
        -- rc.report_topic_id
    --     rc.sort_key

GO
