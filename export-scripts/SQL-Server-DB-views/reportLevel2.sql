SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER VIEW [dbo].[reportLevel2] AS

    SELECT TOP (100) PERCENT 

        rcnt.report_id,
        report_topic_id,
        rcnt.description AS report_topic,
        details AS report_topic_description,
        ge.name AS geo_entity_name,
        ge.geo_entity_id,
        ge.borough_id,
        geb.name AS borough_name,
        'NYC'    AS city,
        'Compared with other NYC neighborhoods*' AS compared_with

    FROM report_topic AS rcnt

        INNER JOIN report          AS rpt ON rcnt.report_id  = rpt.report_id
        INNER JOIN report_geo_type AS rgt ON rpt.report_id   = rgt.report_id
        INNER JOIN geo_type        AS gt  ON rgt.geo_type_id = gt.geo_type_id
        INNER JOIN geo_entity      AS ge  ON gt.geo_type_id  = ge.geo_type_id

        INNER JOIN (
            
            SELECT
                borough_id,
                name
            FROM geo_entity
            WHERE geo_type_id = 1

        ) AS geb ON ge.borough_id = geb.borough_id

    WHERE rpt.public_flag = 1

    ORDER BY
        rcnt.report_id,
        rcnt.sort_key

GO
