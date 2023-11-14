SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER VIEW [dbo].[UHF_to_ZipList] AS

    SELECT
        zl2.UHF42,
        STUFF(
            (
                SELECT ',' + CAST(Zip AS varchar(5))
                FROM
                    (
                        SELECT DISTINCT 
                            Zip,
                            UHF42
                        FROM zipcode_lookup
                    ) AS zl1
                    
                WHERE zl1.UHF42 = zl2.UHF42 FOR XML PATH('')
            ), 1, 1, ''
        ) AS Zipcodes
    FROM zipcode_lookup AS zl2
    GROUP BY UHF42

GO