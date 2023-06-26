SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER VIEW [dbo].[reportLevel1] AS

    SELECT
        rpt.report_id,
        rpt.title    AS report_title,
        rpt.report_description,
        ge.name      AS geo_entity_name,
        uz.Zipcodes  AS zip_code,
        'Categories based on whether the most recent neighborhood value falls among the best, middle or worse performing third of all NYC neighborhoods. NYC is divided into 42 neighborhoods based on the United Hospital Fund (UHF) approach of aggregating zip code areas to approximate Community Planning Districts.' AS report_text,
        '**Estimate is based on small numbers so should be interpreted with caution.' AS unreliable_text,
        rpt.report_footer 

    FROM report AS rpt

        JOIN report_geo_type AS rgt ON rpt.report_id    = rgt.report_id
        JOIN geo_type        AS gt  ON rgt.geo_type_id  = gt.geo_type_id
        JOIN geo_entity      AS ge  ON gt.geo_type_id   = ge.geo_type_id
        JOIN UHF_to_ZipList  AS uz  ON ge.geo_entity_id = uz.UHF42

    WHERE
        rpt.public_flag = 1 AND 
        rgt.geo_type_id = 3 --UHF only
GO