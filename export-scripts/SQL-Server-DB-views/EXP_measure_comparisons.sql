SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER VIEW dbo.EXP_measure_comparisons AS

    SELECT
        mc.measure_compare_id  AS ComparisonID,
        mc.name                AS ComparisonName,
        mc.group_title_display AS LegendTitle,
        mc.Y_axis_title,
        idef.internal_id       AS IndicatorID,
        mm.indicator_id        AS MeasureID,
        gt.geo_type_name       AS GeoTypeName,
        mm.geo_entity_id       AS GeoEntityID,
        ge.name                AS Geography

    FROM measure_compare AS mc
        LEFT JOIN m_to_m               AS   mm ON mm.measure_compare_id = mc.measure_compare_id
        LEFT JOIN geo_type             AS   gt ON gt.geo_type_id        = mm.geo_type_id
        LEFT JOIN geo_entity           AS   ge ON (
            ge.geo_type_id   = mm.geo_type_id   AND
            ge.geo_entity_id = mm.geo_entity_id
        )
        LEFT JOIN indicator_definition AS idef ON idef.indicator_id     = mm.indicator_id

GO