SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER VIEW [dbo].[concat_sources] AS

    SELECT
        si.indicator_id,
        STRING_AGG(src.description, '; ') AS source_list

    FROM source AS src
        INNER JOIN source_indicator AS si ON si.source_id = src.source_id
        
    GROUP BY 
        si.indicator_id

GO
