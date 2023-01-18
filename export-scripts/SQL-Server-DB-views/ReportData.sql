SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER VIEW [dbo].[ReportData] AS

    SELECT DISTINCT TOP (100) PERCENT 
        rc.report_id,
        a.indicator_id,
        b.data_field_name,
        c.name             AS 'indicator_name',
        c.description      AS 'indicator_description',
        m.description      AS 'measure_name',
        d.description      AS 'display_type',
        y.start_period     AS 'start_date',
        y.end_period       AS 'end_date',
        y.time_type        AS 'time_type',
        y.year_description AS 'time',
        a.geo_entity_id,
        ge.geo_id          AS 'geo_join_id',
        g.geo_type_name    AS 'geo_type',
        ge.name            AS 'neighborhood',

        CASE
            WHEN u.show_data_flag = 1 THEN data_value
            ELSE NULL
        END AS 'data_value',

        CASE
            WHEN u.message IS NULL THEN ''
            ELSE u.message
        END AS 'message'

    FROM indicator_data AS a

        LEFT JOIN subtopic_indicators AS si ON (
            si.indicator_id        = a.indicator_id AND 
            si.geo_type_id         = a.geo_type_id AND 
            si.year_id             = a.year_id
        )

        LEFT JOIN indicator_definition AS b  ON a.indicator_id    = b.indicator_id
        LEFT JOIN internal_indicator   AS c  ON b.internal_id     = c.internal_id
        LEFT JOIN display_data_type    AS d  ON d.display_type_id = b.display_type_id
        LEFT JOIN indicator_year       AS y  ON a.year_id         = y.year_id
        LEFT JOIN geo_type             AS g  ON a.geo_type_id     = g.geo_type_id
        LEFT JOIN geo_entity           AS ge ON (
            a.geo_type_id   = ge.geo_type_id AND
            a.geo_entity_id = ge.geo_entity_id
        )
        LEFT JOIN measurement_type AS m  ON b.measurement_type_id = m.measurement_type_id
        LEFT JOIN unreliability    AS u  ON a.unreliability_flag  = u.unreliability_id
        LEFT JOIN report_content   AS rc ON rc.indicator_id       = b.indicator_id
        LEFT JOIN report           AS r  ON rc.report_id          = r.report_id

    WHERE
        a.geo_type_id = 3 AND
        r.public_flag = 1 AND -- only public reports
        si.push_ready = 1

    ORDER BY
        b.data_field_name,
        year_description,
        data_value ASC

GO
