SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER VIEW [dbo].[EXP_measure_links] AS 

    SELECT DISTINCT

        /* for debugging / sanity check: */

        -- i_to_i.base_indicator_id,
        -- i_to_i.linked_indicator_id,
        -- st1.subtopic_id AS st1,
        -- st2.subtopic_id AS st2,
        -- st1.public_display_flag AS pdf1,
        -- st2.public_display_flag AS pdf2

        base_indicator_id   AS BaseMeasureID,
        linked_indicator_id AS MeasureID,

        CASE x_axis 
            WHEN 1 THEN 'x'
            WHEN 0 THEN 'y'
        END AS SecondaryAxis

    FROM i_to_i 

        LEFT JOIN subtopic_indicators AS si1 ON si1.indicator_id = i_to_i.base_indicator_id
        LEFT JOIN subtopic_indicators AS si2 ON si2.indicator_id = i_to_i.linked_indicator_id
		LEFT JOIN subtopic            AS st1 ON st1.subtopic_id  = si1.subtopic_id
		LEFT JOIN subtopic            AS st2 ON st2.subtopic_id  = si2.subtopic_id

    -- removing base or linked Measures whose subtopics aren't publicly displayed. If 
    --  a measure is part of 2 subtopics, one of which is public, then the measure will
    --  still be shown.

    -- for portal rollout, treating disparities as just another link, so removing the disparity_flag test

    WHERE 
        -- disparity_flag != 1 AND
		st1.public_display_flag = 'Y' AND
		st2.public_display_flag = 'Y' AND
		si1.push_ready = 1 AND
		si2.push_ready = 1

GO
