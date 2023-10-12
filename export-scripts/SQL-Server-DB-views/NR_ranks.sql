SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER VIEW dbo.NR_ranks AS
    SELECT
        rc.report_id,
        id.indicator_data_id,
        id.indicator_id,
        id.geo_entity_id,
        id.year_id,
        id.data_value,
        id.unreliability_flag,
        rc.rankReverse,
        rc.indicator_desc,

        --higher values (tertile 1) usually worse for health
        NTILE(3) OVER (
            PARTITION BY 
                rc.report_id,
                id.indicator_id,
                id.geo_type_id,
                id.year_id
            ORDER BY 
                id.data_value DESC,
                id.indicator_data_id -- arbitrarily breaking ties, but it'll be consistent at least
        ) AS Tertile,

        RANK() OVER (
            PARTITION BY 
                rc.report_id,
                id.indicator_id,
                id.geo_type_id,
                id.year_id
            ORDER BY 
                id.data_value DESC,
                id.indicator_data_id
        ) AS RankByValue,

        -- now calculate tertiles, accounting for rank reverse
        CASE WHEN rc.rankReverse = 0 
            THEN NTILE(3) OVER (
                PARTITION BY 
                    rc.report_id,
                    id.indicator_id,
                    id.geo_type_id,
                    id.year_id
                ORDER BY 
                    id.data_value DESC,
                    id.indicator_data_id
            )
            --if rank is reversed, tertile 1 is better!
            ELSE NTILE(3) OVER (
                PARTITION BY 
                    rc.report_id,
                    id.indicator_id,
                    id.geo_type_id,
                    id.year_id
                ORDER BY 
                    id.data_value ASC,
                    id.indicator_data_id
            ) 
        END AS reportRank  -- note that 3=better, 2=middle, 1=worse
            
        FROM indicator_data AS id
            INNER JOIN report_content AS  rc ON id.indicator_id = rc.indicator_id
            INNER JOIN report         AS rpt ON rpt.report_id   = rc.report_id

        WHERE 
             --UHF ranks only 
            id.geo_type_id = 3 AND
            rpt.public_flag = 1
    
GO
