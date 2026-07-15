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

with

base as (
    select
        marketing_channel,
        date_trunc('week', order_date) as order_week,
        demand_r_ss,
        orders_ss
    from mta_total_points_attributed_v
    where brand_cd = 'AN'
      and purchase_channel = 'DIRECT'
      and order_date >= dateadd('week', -8, current_date())
),

final as (
    select
        marketing_channel,
        order_week,
        sum(demand_r_ss) as attributed_demand,
        sum(orders_ss)   as attributed_orders
    from base
    group by marketing_channel, order_week
)

select * from final
order by order_week, marketing_channel
;
