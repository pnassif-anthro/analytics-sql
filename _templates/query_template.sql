-- =========================================================================
-- Title:            <Short descriptive title>
-- Vertical:         <Marketing | Customer | Digital | Shared>
-- Author:           <Your name>
-- Created:          <YYYY-MM-DD>
-- Last validated:   <YYYY-MM-DD>
-- Purpose:          <1-2 sentences: what question does this answer / what
--                    does it produce>
-- Key tables:       <e.g. DW_RFM_HISTORY, Q_QF_BLND_ORDER_HEADER_V>
-- Filters applied:  <e.g. BRAND_CD='AN', PURCHASE_CHANNEL='DIRECT'>
-- Grain:            <e.g. one row per customer per week>
-- Known caveats:    <e.g. CLOUD_IID resolution anomaly post-2026-06-22 —
--                    see linked doc / analysis .md>
-- Related doc:      <link to analysis .md, dashboard, or Confluence page>
-- Supersedes:       <path to prior version, if applicable, else "n/a">
-- =========================================================================

-- Diagnostic block (optional, delete if not applicable):
-- run this first to sanity-check row counts / dedup before trusting the
-- production query below.
/*
select count(*) as row_ct, count(distinct <key_column>) as distinct_ct
from <table>
where <filters>;
*/

with

-- Step 1: <one-sentence description of what this CTE does>
base as (
    select
        <columns>
    from <schema>.<table>
    where <filters>          -- explicit, not inherited from a view
),

-- Step 2: <identity resolution / join step, if applicable>
resolved as (
    select
        b.*
        -- , x.<resolved_id>
    from base b
    -- left join <shared_identity_bridge_table> x
    --     on b.<key> = x.<key>
),

-- Step 3: <aggregation / final shaping>
final as (
    select
        <grain columns>,
        <metrics>
    from resolved
    group by <grain columns>
)

select * from final
order by <sort columns>
;
