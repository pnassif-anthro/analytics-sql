-- =========================================================================
-- Title:            EXAMPLE — Channel-level attributed demand, 8-week window
-- Vertical:         Marketing
-- Author:           <your name here>
-- Created:          2026-07-15
-- Last validated:   2026-07-15
-- Purpose:          Reference example showing repo header + style
--                    conventions. Delete or replace once real queries
--                    populate this folder.
-- Key tables:        MTA_TOTAL_POINTS_ATTRIBUTED_V
-- Filters applied:   BRAND_CD='AN', PURCHASE_CHANNEL='DIRECT'
-- Grain:             one row per channel per week
-- Known caveats:     n/a (example file)
-- Related doc:       n/a
-- Supersedes:        n/a
-- =========================================================================

select 
    CASE WHEN marketing_channel = 'Display' THEN 'Remarketing'
         ELSE MARKETING_CHANNEL
    END,
    sum(spend),
    sum(spend_fcst)
from funnel_anthropologie_na.funnel__nndsupwuyzg2xivk6nb.an_daily_funnel_data
where date between '2026-07-01' and '2026-07-13'
group by all
;
