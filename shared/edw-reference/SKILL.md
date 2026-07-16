---
name: urbn-an-data-analyst
description: "URBN Anthropologie data analysis skill. Provides context for querying the URBN EDW in Snowflake. Use when analyzing Anthropologie (AN) data for: (1) MTA/attribution and ROAS reporting across paid, email, SMS, and push channels, (2) cross-channel outbound send data for MMM and campaign analysis, (3) customer identity, NAR, CLV, and loyalty reporting, or any data question requiring URBN-specific Snowflake context."
---

# URBN Anthropologie — EDW Data Analysis

## SQL Dialect: Snowflake

- Account: `urbanoutfittersinc.us-central1.gcp`
- Use `GROUP BY ALL` — Snowflake supports this and it's used throughout URBN queries
- Use `TO_CHAR(date_col, 'YYYY-MM')` for month bucketing
- Use `REGEXP_LIKE(col, pattern)` for regex (not `RLIKE`)
- Use `TRY_TO_TIMESTAMP()` for safe timestamp casting (especially on `DW_SMS_ACTIVITY.LOYALTY_DATE` which has malformed values)
- Date arithmetic: `DATEADD(year, -1, CURRENT_DATE)`, `DATEADD(week, -4, CURRENT_DATE)`
- No backticks for identifiers — use double quotes if needed, but usually not required

**Standard session header:**
```sql
USE ROLE RO_ROLE_PROD;
USE WAREHOUSE RO_WH_PROD;
USE DATABASE EDW_PROD;
USE SCHEMA URBN;
```
For MTA/attribution queries switch schema: `USE SCHEMA ADVA;`

---

## Primary Brand Context

Default brand: **Anthropologie = `'AN'`** (NA). EU variant = `'AN_EU'`.

Always filter `BRAND_CD = 'AN'` (or `'AN_EU'` for EU) unless a cross-brand query is explicitly requested.

`SRC_ID = 100` → North America | `SRC_ID = 200` → Europe

---

## Entity Disambiguation

**"Customer" always means IID** — the Merkle-assigned Individual Identifier. Never count by email, loyalty ID, or web profile ID.

| Term | What it is | Primary Table |
|------|-----------|---------------|
| IID | Individual person — the enterprise customer key | `DW_CDI_CUSTOMER` |
| HID | Household (multiple IIDs at same address) | `DW_CDI_CUSTOMER` |
| PROFILE_ID | A15 web account ID — 1:M with IID | `DW_IID_WEB_PROFILE_XREF` |
| Contact ID | Salesforce Service Cloud 18-char ID | `EDW_ODS_PROD.SFSC.CONTACT` |
| Sterling ID | Legacy OMS ID — not populated for customers after Phase 3 (early 2025) | `DW_SERVICES_PROFILES` |

**"Order" can mean demand or sales** — marketing uses demand (order placed), finance/merch use sales (fulfilled + paid). MTA tables contain demand.

**"Attributed demand"** is always `ORDER_DEMAND_AMT × ATTRIBUTION_SHARE`, not gross demand.

---

## Standard Filters — Always Apply

```sql
-- Customer counting
WHERE IID <> '-1'           -- unmatched orders; always exclude

-- Product tables
WHERE PURGE_FLG = 'N'       -- DW_PRD_SKU: excludes retired/reused SKU rows

-- Loyalty unique enrollee counts
WHERE PRIMARY_LOYALTY_ID_FLG = 'Y'

-- Email active subscribers
WHERE PREF_FLG = 'Y' AND MOST_RECENT_FLG = 'Y'   -- on Q_QL_ELS_V

-- MTA views
AND IID <> '-1'             -- also exclude unmatched from all MTA queries

-- Active retail stores (Anthropologie US)
WHERE Q_CHN_SNUM = 'RTL'
  AND STR_COL_06 = 'US'
  AND BRAND_CD = 'AN'
  AND STR_COL_41 LIKE '%Retail Store'
  AND STR_COL_03 <> 'GAP'   -- excludes test/gap entries
  AND Q_STR_CLOSE_DT = '9999-12-31'  -- active stores only
```

---

## Key Metrics

### Attributed Demand
- **Definition**: Fractional order demand credited to a touchpoint
- **Formula (legacy MTA)**: `ATTRIBUTED_DEMAND_AMT = ORDER_DEMAND_AMT × (POINTS / TOTAL_POINTS)`
- **Formula (Rockerbox)**: `ATTRIBUTED_DEMAND_AMT = ORDER_DEMAND_AMT × EVENT_WEIGHT` (EVENT_WEIGHT normalized ~1.0)
- **Source**: `EDW_PROD.ADVA.MTA_TOTAL_POINTS_ATTRIBUTED_V` or `EDW_PROD.URBN.AN_MTA_ROLLUP_BASE_DTB`

### ROAS
- **Formula**: `Attributed Demand ($) / Paid Media Spend ($)`
- **Demand source**: `MTA_TOTAL_POINTS_ROLLUP_V.DEMAND_R_SS` or `AN_MTA_ROLLUP_BASE_DTB.MTA_DEMAND_AMT`
- **Spend source (EU)**: `FUNNEL_ANTHROPOLOGIE_EU.FUNNEL__OLFS6ZBWHZRUFMJO5ZS.ANEU_DAILY_FUNNEL_DATA`
- **Spend source (NA)**: `FUNNEL_ANTHROPOLOGIE_NA.FUNNEL__NNDSUPWUYZG2XIVK6NB.AN_DAILY_FUNNEL_DATA`

### NAR (New / Active / Reactivated)
- **New**: First-ever purchase at brand (IID has no prior demand history)
- **Active**: Purchased within last 365 days
- **Reactivated**: Previously purchased, lapsed 365+ days, purchased again
- **Column**: `NAR_BRAND_D` on `MTA_TOTAL_POINTS_ATTRIBUTED_V` — values always prefixed `'1. NEW'`, `'2. ACTIVE'`, `'3. REACTIVATED'`
- **Fractional counting**: Use `DAY_FRACTIONAL_CUSTOMER_BRAND` (not `COUNT(DISTINCT IID)`) when working within MTA

### Fractional Customer Count
- Use `SUM(DAY_FRACTIONAL_CUSTOMER_BRAND)` instead of `COUNT(DISTINCT IID)` within MTA views — handles customers who order multiple times in a period correctly

---

## Data Freshness

| Table / View | Refresh | Notes |
|---|---|---|
| `MTA_TOTAL_POINTS_ATTRIBUTED_V` | Nightly (after CDI) | Delays if CDI maintenance in progress |
| `MTA_TOTAL_POINTS_ROLLUP_V` | Nightly | Same dependency on CDI |
| `AN_MTA_ROLLUP_BASE_DTB` | Check Atlan for schedule | AN-specific rollup |
| `RBX_{BRAND}_LOG_LVL_PRCHS` | Daily incremental (14-day lookback) | |
| `AA_CLV_FINAL_PREDICTIONS` | Weekly, Mondays | |
| `Q_QL_CDI_LOYALTY_V` | Nightly CDI run (~10:00–10:30 AM EST) | T-2 IID lag by design |
| `DW_SERVICES_SUBSCRIPTIONS` | Daily (~6:45–7 AM EST from A15) | Digital-only, no POS |
| `DW_EMAIL_SENT / OPENS / CLICKS` | ~2-day lag from SFMC | Filter on `Q_DT_IT`, not `LOAD_DATE` |
| `DW_SMS_ACTIVITY` | **STALE as of Jan 31 2026** — pipeline migration in progress | Check #marketingsystems_cloud_qa |
| `DW_PUSH_MOBILE` | Check Atlan | `STATUS != 'FAIL'` filter required |
| `DW_CALENDAR_HIERARCHY` | Static reference | Use for fiscal week joins |

**CDI maintenance**: Monthly, ~1 business day. MTA and NAR do NOT refresh on those nights. Watch #marketingsystems_cloud_qa for Hari's @here notices.

---

## Knowledge Base Navigation

| Domain | Reference File | Use For |
|--------|---------------|---------|
| MTA & Attribution | `references/mta-attribution.md` | Attributed demand, ROAS, channel taxonomy, Rockerbox migration, AN rollup table |
| Channel Outbound (Email/SMS/Push) | `references/channel-outbound.md` | Email/SMS/push tables, MMM campaign classification logic, send counting |
| Customer Identity | `references/customer-identity.md` | IID/CDI, loyalty, NAR, CLV, RFM tables |
| Database Structure | `references/db-structure.md` | Schema map, naming conventions, table prefix guide |

---

## Common Query Patterns

### Channel attribution by week (rollup view — fast)
```sql
USE ROLE RO_ROLE_PROD;
USE WAREHOUSE RO_WH_PROD;
USE DATABASE EDW_PROD;
USE SCHEMA ADVA;

SELECT
    ch.WEEK_OF_YEAR_NUM,
    r.D2C_CHANNEL_SOURCE,
    SUM(r.ORDERS_SS)       AS orders,
    SUM(r.SESSIONS_SS)     AS sessions,
    SUM(r.DEMAND_R_SS)     AS attributed_demand
FROM MTA_TOTAL_POINTS_ROLLUP_V r
JOIN EDW_PROD.URBN.DW_CALENDAR_HIERARCHY ch
    ON ch.CALENDAR_DT = r.ORDER_DT
WHERE r.BRAND_CD = 'AN'
  AND ch.CURRENT_YEAR_ID IN (0, -1)   -- 0 = TY, -1 = LY
GROUP BY ALL
ORDER BY 1, 2;
```

### Attribution by channel + NAR (line-item view)
```sql
SELECT
    ch.WEEK_OF_YEAR_NUM,
    mta.BRAND_PARENT_MARKETING_CHANNEL,
    mta.NAR_BRAND_D,
    SUM(mta.ATTRIBUTED_DEMAND_AMT)          AS attributed_demand,
    SUM(mta.DAY_FRACTIONAL_CUSTOMER_BRAND)  AS customers
FROM EDW_PROD.ADVA.MTA_TOTAL_POINTS_ATTRIBUTED_V mta
JOIN EDW_PROD.URBN.DW_CALENDAR_HIERARCHY ch
    ON ch.CALENDAR_DT = mta.ORDER_DT
WHERE mta.BRAND_CD = 'AN'
  AND ch.CURRENT_YEAR_ID = 0
  AND mta.IID <> '-1'
GROUP BY ALL
ORDER BY 1, 2;
```

### ROAS — AN EU affiliate/search (with spend from Funnel)
```sql
WITH marketing AS (
    SELECT
        TO_CHAR(DATE(DATE), 'YYYY-MM')    AS year_month,
        UPPER(MARKETING_CHANNEL)           AS MARKETING_CHANNEL,
        SUM(COST)                          AS SPEND
    FROM FUNNEL_ANTHROPOLOGIE_EU.FUNNEL__OLFS6ZBWHZRUFMJO5ZS.ANEU_DAILY_FUNNEL_DATA
    WHERE MARKETING_CHANNEL LIKE '%SEARCH%'
    GROUP BY ALL
),
mta_demand AS (
    SELECT
        TO_CHAR(ORDER_DT, 'YYYY-MM')      AS year_month,
        MRKTG_CHN_NAME,
        SUM(MTA_DEMAND_AMT)               AS MTA_DEMAND
    FROM EDW_PROD.URBN.AN_MTA_ROLLUP_BASE_DTB
    WHERE BRND_CD = 'AN_EU'
    GROUP BY ALL
)
SELECT
    f.year_month,
    f.MARKETING_CHANNEL,
    f.SPEND,
    m.MTA_DEMAND,
    ROUND(m.MTA_DEMAND / NULLIF(f.SPEND, 0), 2) AS ROAS
FROM marketing f
JOIN mta_demand m ON f.year_month = m.year_month
ORDER BY year_month;
```

### Attributed demand + customer postal code (display example)
```sql
SELECT
    m.IID,
    m.ORDER_DT,
    SUM(m.ATTRIBUTED_DEMAND_AMT)  AS demand,
    COUNT(m.ORDER_ID)              AS conversions,
    SUM(m.ATTRIBUTED_DEMAND_QTY)  AS qty,
    SUM(m.ATTRIBUTED_RETURN_QTY)  AS returned_qty,
    c.POSTAL_CD
FROM EDW_PROD.ADVA.MTA_TOTAL_POINTS_ATTRIBUTED_V m
JOIN EDW_PROD.URBN.DW_CDI_CUSTOMER c ON m.IID = c.IID
WHERE m.ORDER_DT BETWEEN '2024-02-01' AND '2025-01-31'
  AND m.MARKETING_CHANNEL LIKE '%DISPLAY%'
  AND m.IID <> '-1'
GROUP BY ALL;
```

### Active AN retail stores with open/close dates
```sql
SELECT DISTINCT
    Q_STR_OPN_DT,
    Q_STR_CLOSE_DT,
    Q_STR_DESC,
    STR_COL_03,   -- state/region
    STR_COL_04,
    STR_COL_05,
    STR_COL_41,   -- store type label
    CASE WHEN Q_STR_CLOSE_DT = '9999-12-31' THEN 1 ELSE 0 END AS ACTIVE_STR,
    SUM(CASE WHEN Q_STR_CLOSE_DT = '9999-12-31' THEN 1 ELSE 0 END)
        OVER (ORDER BY Q_STR_OPN_DT) AS CUMULATIVE_STORE_COUNT
FROM EDW_PROD.URBN.DW_LOC_STR
WHERE Q_CHN_SNUM = 'RTL'
  AND STR_COL_06 = 'US'
  AND BRAND_CD = 'AN'
  AND STR_COL_41 LIKE '%Retail Store'
  AND STR_COL_03 <> 'GAP'
ORDER BY Q_STR_OPN_DT;
```

---

## Troubleshooting

### Common Mistakes

| Mistake | What happens | Fix |
|---------|-------------|-----|
| `COUNT(DISTINCT IID)` in MTA | Overcounts customers who order multiple times | Use `SUM(DAY_FRACTIONAL_CUSTOMER_BRAND)` |
| Forgetting `IID <> '-1'` | Unmatched orders inflate channel counts | Always add this filter |
| Using `LOAD_DATE` on email tables | ~2-day offset from actual send date | Filter on `Q_DT_IT` instead |
| Querying `DW_RFM_HISTORY` on `IID` | No results — key is `CLOUD_IID` | Use `CLOUD_IID` on the RFM side |
| Querying `AA_CLV_FINAL_PREDICTIONS` without anchor filter | One row per customer per weekly run | Use `_MAX_ANCHOR_DT` view |
| Querying `DW_PRD_SKU` without `PURGE_FLG = 'N'` | Duplicate rows for reused SKUs | Always filter |
| Using `DW_SERVICES_SUBSCRIPTIONS` for total loyalty counts | Misses all POS sign-ups | Use `Q_QL_CDI_LOYALTY_V` |
| Treating `DW_SMS_ACTIVITY` as current | Stopped updating Jan 31 2026 | Check #marketingsystems_cloud_qa for current table |
| Comparing RBX `EVENT_WEIGHT` to legacy `POINTS` | Incompatible scales | Compare attributed revenue totals, not weights |
| Looking for `MARKETING_CHANNEL` in raw RBX tables | Field doesn't exist | Use `BRAND_MARKETING_CHANNEL` or map from `TIER_1–TIER_5` |
| Counting loyalty signups with `PRIMARY_LOYALTY_ID_FLG` missing | Double-counts enrollees | Always filter `PRIMARY_LOYALTY_ID_FLG = 'Y'` |

### Access Issues
- PII fields (name, address, email) masked under `RO_ROLE_PROD` → request `PII_ROLE_PROD` via Jira or #edw-support-snowflake
- Sandbox tables drop after 30 days → raise Jira EDW ticket to add to Do Not Drop list
- `EDW_DATA_VAULT_PROD` is generally not needed for analyst work; EDW team will point you there for specific joins (e.g. `PRD_YFS_ITEM_XREF`)

### Performance Tips
- Always include a date filter on large tables (`DW_MTA_TOTAL_POINTS_ATTRIBUTED` is ~11B rows)
- Use `MTA_TOTAL_POINTS_ROLLUP_V` instead of aggregating from `_ATTRIBUTED_V` when you don't need line-level detail
- Join `DW_CALENDAR_HIERARCHY` for fiscal week/year logic rather than computing calendar week yourself
- `LIMIT` during exploration on billion-row tables

### Help Channels
| Question | Where |
|---|---|
| CDI maintenance, MTA, loyalty, RBX migration status | #marketingsystems_cloud_qa |
| Snowflake access, roles, missing tables | #edw-support-snowflake |
| Table discovery and column definitions | Atlan |
| RBX-specific tables/views | Rakesh Jain / Cherry Jain |
| CLV/RFM methodology | Valerie Amoroso (Data Science) |
