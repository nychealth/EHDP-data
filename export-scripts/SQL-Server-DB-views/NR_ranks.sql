SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER VIEW [dbo].[NR_ranks] AS
    SELECT
        dt.indicator_data_id,
        dt.indicator_id,
        dt.geo_entity_id,
        dt.year_id,
        dt.data_value,
        dt.unreliability_flag,
        id.rankReverse,

        --higher values (tertile 1) usually worse for health
        NTILE(3) OVER (
            PARTITION BY 
                dt.indicator_id,
                dt.geo_type_id,
                dt.year_id
            ORDER BY 
                dt.data_value DESC,
                dt.indicator_data_id -- arbitrarily breaking ties, but it'll be consistent at least
        ) AS Tertile,

        RANK() OVER (
            PARTITION BY 
                dt.indicator_id,
                dt.geo_type_id,
                dt.year_id
            ORDER BY 
                dt.data_value DESC,
                dt.indicator_data_id
        ) AS RankByValue,

        -- now calculate tertiles, accounting for rank reverse
        CASE WHEN id.rankReverse = 0 
            THEN NTILE(3) OVER (
                PARTITION BY 
                    dt.indicator_id,
                    dt.geo_type_id,
                    dt.year_id
                ORDER BY 
                    dt.data_value DESC,
                    dt.indicator_data_id
            )
            --if rank is reversed, tertile 1 is better!
            ELSE NTILE(3) OVER (
                PARTITION BY 
                    dt.indicator_id,
                    dt.geo_type_id,
                    dt.year_id
                ORDER BY 
                    dt.data_value ASC,
                    dt.indicator_data_id
            ) 
        END AS reportRank  -- note that 3=better, 2=middle, 1=worse
            
        FROM nr_indicators AS ind
            INNER JOIN indicator_definition AS id ON id.indicator_id = ind.indicator_id
            INNER JOIN indicator_data       AS dt ON dt.indicator_id = ind.indicator_id

        WHERE dt.geo_type_id = 3 --UHF ranks only 
    
GO
