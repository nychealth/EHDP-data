SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER VIEW dbo.NR_data_base AS

    -- need to integrate this with NR_data.sql

    SELECT DISTINCT

        ind.report,
        ind.report_topic,
        dt.indicator_id      AS MeasureID,
        ii.internal_id       AS IndicatorID,
        ii.name              AS indicator_name,
        ii.description       AS indicator_description,
        ii.short_name        AS indicator_short_name,
        id.data_field_name   AS indicator_data_name,
        ii.name + ', ' + iy.year_description AS indicator_long_name,
        mt.description       AS measurement_type,
        ddt.description      AS units,
        iy.year_id,
        iy.start_period      AS start_date,
        iy.end_period        AS end_date,
        iy.time_type         AS time_type,
        iy.year_description  AS time,
        dt.geo_entity_id,
        ge.geo_id            AS geo_join_id,
        gt.geo_type_name     AS geo_type,
        ge.name              AS neighborhood,
        geb.name             AS borough_name,
        src.source_list      AS data_source_list,
        uz.Zipcodes          AS zip_code,
        id.rankReverse,
        rr.RankByValue       AS indicator_neighborhood_rank,
        rr.reportRank        AS data_value_rank,

        -- bar chart filename

        id.data_field_name + '_' + CAST(dt.geo_entity_id AS varchar) + '.svg' AS summary_bar_svg,

        -- formatted neighborhood data value

        CASE WHEN un.show_data_flag = 0 THEN 'N/A' + COALESCE(un.character_display, '')
            ELSE CAST(
                CAST(dt.data_value AS decimal(18, 1)) AS varchar
            ) + COALESCE(un.character_display, '')
        END AS data_value_geo_entity,

        -- unformatted neighborhood data value

        CASE WHEN un.show_data_flag = 0 THEN NULL
            ELSE CAST(dt.data_value AS decimal(18, 1))
        END AS unmodified_data_value_geo_entity,

        -- unformatted borough data value

        CAST(boro.data_value AS decimal(18, 1)) AS data_value_boro,

        -- unformatted city data value

        CAST(city.data_value AS decimal(18, 1)) AS data_value_nyc,

        -- data reliability flag

        CASE WHEN un.message IS null THEN ''
            ELSE un.character_display + ' ' + un.message
        END AS nbr_data_note


    FROM nr_indicators AS ind

        -- joining UHF42 data

        INNER JOIN (
            SELECT * 
            FROM indicator_data 
            WHERE geo_type_id = 3
        ) AS dt ON (
            dt.indicator_id  = ind.indicator_id
        )

        -- joining subtopic indicators, to get flags

        INNER JOIN subtopic_indicators AS si ON (
            si.indicator_id        = dt.indicator_id AND 
            si.geo_type_id         = dt.geo_type_id AND 
            si.year_id             = dt.year_id
        )
        INNER JOIN indicator_definition AS  id ON dt.indicator_id     = id.indicator_id
        INNER JOIN internal_indicator   AS  ii ON id.internal_id      = ii.internal_id
        INNER JOIN display_data_type    AS ddt ON ddt.display_type_id = id.display_type_id
        INNER JOIN indicator_year       AS  iy ON dt.year_id          = iy.year_id
        INNER JOIN geo_type             AS  gt ON dt.geo_type_id      = gt.geo_type_id
        INNER JOIN geo_entity           AS  ge ON (
            dt.geo_type_id   = ge.geo_type_id AND
            dt.geo_entity_id = ge.geo_entity_id
        )
        INNER JOIN measurement_type AS  mt ON id.measurement_type_id = mt.measurement_type_id
        INNER JOIN unreliability    AS  un ON dt.unreliability_flag  = un.unreliability_id

        -- getting zips from UHFs

        INNER JOIN UHF_to_ZipList AS uz ON (
            uz.UHF42 = ge.geo_entity_id AND
            gt.geo_type_id = 3
        )

        -- getting boro names

        INNER JOIN (
            SELECT borough_id, name
            FROM geo_entity
            WHERE geo_type_id = 1
        ) AS geb ON geb.borough_id = ge.borough_id

        -- joining city data

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
            city.indicator_id  = ind.indicator_id AND
            city.year_id = dt.year_id
        )

        -- joining boro data

        INNER JOIN (
            SELECT 
                indicator_id, 
                year_id, 
                geo_entity_id, 
                data_value
            FROM indicator_data 
            WHERE geo_type_id = 1
        ) AS boro ON (
            boro.indicator_id  = ind.indicator_id AND
            boro.geo_entity_id = ge.borough_id AND
            boro.year_id = dt.year_id
        )

        -- getting UHF ranks for this indicator

        INNER JOIN Report_UHF_indicator_Rank AS rr ON (
            rr.indicator_data_id = dt.indicator_data_id
        )

        -- getting indicator sources
        
        INNER JOIN Consolidated_Sources_by_IndicatorID AS src ON ind.indicator_id = src.indicator_id

    WHERE
        dt.geo_type_id  = 3 AND
        si.creator_id   = 1      -- repurpose as stage_flag: 0 = don't stage, 1 = stage

GO
