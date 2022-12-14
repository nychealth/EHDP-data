SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER VIEW [dbo].[EXP_data_export] AS
    
    SELECT DISTINCT
    
    SELECT DISTINCT

        -- "DISTINCT" because an indicator can have multiple subtopics, but we have no subtopic data here
    
        si.internal_id       AS IndicatorID,
        ind.indicator_id     AS MeasureID,
        gt.geo_type_name     AS GeoType,
        ind.geo_type_id      AS GeoTypeID,
        ind.geo_entity_id    AS GeoID,
        iy.year_description  AS Time,
        un.character_display AS flag,
        si.ban_summary_flag,
        mt.number_decimal_ind,

        -- null out value when show data = 0
        -- null out value when show data = 0

        CASE WHEN un.show_data_flag = 1 THEN ind.data_value 
            ELSE null 
        END AS Value,
        CASE WHEN un.show_data_flag = 1 THEN ind.data_value 
            ELSE null 
        END AS Value,

        -- replace CI nulls with empty strings

        CASE 
            WHEN ind.ci IS null OR un.show_data_flag = 0 THEN ''
            ELSE ind.ci
        END AS CI,

        -- include unreliability message

        CASE 
            WHEN un.message IS null THEN ''
            ELSE un.character_display + ' ' + un.message
        END AS Note

    FROM dbo.indicator_data AS ind
    FROM dbo.indicator_data AS ind

        INNER JOIN dbo.subtopic_indicators AS si ON (
            si.indicator_id = ind.indicator_id AND 
            si.geo_type_id  = ind.geo_type_id AND 
            si.year_id      = ind.year_id 
        )
        INNER JOIN dbo.subtopic_indicators AS si ON (
            si.indicator_id = ind.indicator_id AND 
            si.geo_type_id  = ind.geo_type_id AND 
            si.year_id      = ind.year_id 
        )

        INNER JOIN dbo.subtopic             AS st ON st.subtopic_id         = si.subtopic_id
        INNER JOIN dbo.internal_indicator   AS ii ON ii.internal_id         = si.internal_id
        INNER JOIN dbo.measurement_type     AS mt ON mt.measurement_type_id = si.measurement_type_id
        INNER JOIN dbo.geo_type             AS gt ON gt.geo_type_id         = ind.geo_type_id
        INNER JOIN dbo.indicator_year       AS iy ON iy.year_id             = ind.year_id
        INNER JOIN dbo.unreliability        AS un ON un.unreliability_id    = ind.unreliability_flag
        INNER JOIN dbo.subtopic             AS st ON st.subtopic_id         = si.subtopic_id
        INNER JOIN dbo.internal_indicator   AS ii ON ii.internal_id         = si.internal_id
        INNER JOIN dbo.measurement_type     AS mt ON mt.measurement_type_id = si.measurement_type_id
        INNER JOIN dbo.geo_type             AS gt ON gt.geo_type_id         = ind.geo_type_id
        INNER JOIN dbo.indicator_year       AS iy ON iy.year_id             = ind.year_id
        INNER JOIN dbo.unreliability        AS un ON un.unreliability_id    = ind.unreliability_flag

    -- only export data flagged for public view
    -- only export data flagged for public view

    WHERE 
        st.public_display_flag = 'Y' AND
        si.push_ready = 1
    WHERE 
        st.public_display_flag = 'Y' AND
        si.push_ready = 1

GO
