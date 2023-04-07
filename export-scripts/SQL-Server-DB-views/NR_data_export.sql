SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER VIEW [dbo].[NR_data_export] AS

    SELECT DISTINCT

        rc.report_id,
        rpt.title,
        id.indicator_id      AS MeasureID,
        ii.internal_id       AS IndicatorID,
        idef.data_field_name AS indicator_data_name,
        ii.name              AS indicator_name,
        ii.description       AS indicator_description,
        ii.short_name        AS indicator_short_name,
        rc.indicator_desc + ', ' + iy.year_description AS indicator_long_name,
        mt.description       AS measurement_type,
        ddt.description      AS units,
        iy.year_id,
        iy.start_period      AS start_date,
        iy.end_period        AS end_date,
        iy.time_type         AS time_type,
        iy.year_description  AS time,
        id.geo_entity_id,
        ge.geo_id            AS geo_join_id,
        gt.geo_type_name     AS geo_type,
        ge.name              AS neighborhood,
        geb.name             AS borough_name,
        s.source_list        AS data_source_list,
        uz.Zipcodes          AS zip_code,
        idef.rankReverse,
        rr.RankByValue       AS indicator_neighborhood_rank,
        rr.reportRank        AS data_value_rank,
        idef.data_field_name + '-' + CAST(id.geo_entity_id AS varchar) + '.svg' AS summary_bar_svg,

        CASE WHEN un.show_data_flag = 0 THEN 'N/A' + COALESCE(un.character_display, '')
            ELSE CAST(
                CAST(id.data_value AS decimal(18, 1)) AS varchar
            ) + COALESCE(un.character_display, '')
        END AS data_value_geo_entity,

        CASE WHEN un.show_data_flag = 0 THEN NULL
            ELSE CAST(id.data_value AS decimal(18, 1))
        END AS unmodified_data_value_geo_entity,

        CAST(boro.data_value AS decimal(18, 1)) AS data_value_borough,
        CAST(city.data_value AS decimal(18, 1)) AS data_value_nyc,

        CASE WHEN un.message IS null THEN ''
            ELSE un.character_display + ' ' + un.message
        END AS nbr_data_note

    FROM report_content AS rc

        INNER JOIN (
            SELECT * 
            FROM indicator_data 
            WHERE geo_type_id = 3
        ) AS id ON (
            id.indicator_id  = rc.indicator_id
        )

        INNER JOIN subtopic_indicators AS si ON (
            si.indicator_id        = id.indicator_id AND 
            si.geo_type_id         = id.geo_type_id AND 
            si.year_id             = id.year_id
        )
        INNER JOIN indicator_definition AS idef ON id.indicator_id     = idef.indicator_id
        INNER JOIN internal_indicator   AS   ii ON idef.internal_id    = ii.internal_id
        INNER JOIN display_data_type    AS  ddt ON ddt.display_type_id = idef.display_type_id
        INNER JOIN indicator_year       AS   iy ON id.year_id          = iy.year_id
        INNER JOIN geo_type             AS   gt ON id.geo_type_id      = gt.geo_type_id
        INNER JOIN geo_entity           AS   ge ON (
            id.geo_type_id   = ge.geo_type_id AND
            id.geo_entity_id = ge.geo_entity_id
        )
        INNER JOIN measurement_type AS  mt ON idef.measurement_type_id = mt.measurement_type_id
        INNER JOIN unreliability    AS  un ON id.unreliability_flag    = un.unreliability_id
        INNER JOIN report           AS rpt ON rc.report_id             = rpt.report_id

        INNER JOIN UHF_to_ZipList AS uz ON (
            uz.UHF42 = ge.geo_entity_id AND
            gt.geo_type_id = 3
        )

        INNER JOIN (
            SELECT borough_id, name
            FROM geo_entity
            WHERE geo_type_id = 1
        ) AS geb ON geb.borough_id = ge.borough_id

        -- INNER JOIN indicator_data AS city ON (
        --         city.indicator_id = rc.indicator_id AND
        --         city.geo_type_id = 6 AND 
        --         city.geo_entity_id = 1 AND
        --         city.year_id = id.year_id
        --     )

        -- INNER JOIN indicator_data AS boro ON (
        --         boro.indicator_id = rc.indicator_id AND
        --         boro.geo_type_id = 1 AND 
        --         boro.geo_entity_id = ge.borough_id AND
        --         boro.year_id = id.year_id
        --     )

        INNER JOIN (
            SELECT 
                indicator_id, 
                year_id, 
                data_value
            FROM indicator_data 
            WHERE 
                geo_type_id = 6 AND 
                geo_entity_id = 1
        ) AS city ON (
            city.indicator_id  = rc.indicator_id AND
            city.year_id = id.year_id
        )

        INNER JOIN (
            SELECT 
                indicator_id, 
                year_id, 
                geo_entity_id, 
                data_value
            FROM indicator_data 
            WHERE geo_type_id = 1
        ) AS boro ON (
            boro.indicator_id  = rc.indicator_id AND
            boro.geo_entity_id = ge.borough_id AND
            boro.year_id = id.year_id
        )

        INNER JOIN Report_UHF_indicator_Rank AS rr ON (
            rr.indicator_data_id = id.indicator_data_id AND 
            rr.report_id         = rc.report_id
        )

        INNER JOIN Consolidated_Sources_by_IndicatorID AS s ON rc.indicator_id = s.indicator_id

    WHERE
        id.geo_type_id = 3 AND
        rpt.public_flag = 1 AND -- only public reports
        si.creator_id = 1 AND -- repurpose as stage_flag: 0 = don't stage, 1 = stage
        rpt.report_id IN (73, 77, 78, 79, 82)

GO
