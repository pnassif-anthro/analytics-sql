# MTA & Attribution Tables

This document covers URBN's multi-touch attribution data — both the legacy in-house model and the incoming Rockerbox platform — plus the AN-specific rollup table and ROAS calculation patterns.

---

## Quick Reference

**Two MTA systems run in parallel.** For current reporting use the legacy views. Rockerbox V3 is in UAT and nearly ready to replace them.

| System | Primary Table | Status |
|--------|--------------|--------|
| Legacy in-house | `EDW_PROD.ADVA.MTA_TOTAL_POINTS_ATTRIBUTED_V` | Active — use for all current reporting |
| Legacy rollup | `EDW_PROD.ADVA.MTA_TOTAL_POINTS_ROLLUP_V` | Active — faster for summary queries |
| AN custom rollup | `EDW_PROD.URBN.AN_MTA_ROLLUP_BASE_DTB` | Active — AN/AN_EU with `MRKTG_CHN_NAME`, `MTA_DEMAND_AMT` |
| Rockerbox log-level | `EDW_ODS_PROD.URBN.RBX_AN_LOG_LVL_PRCHS` | Active, materialized — foundation for RBX work |
| Rockerbox V4 view | `EDW_SANDBOX_PROD.URBN.RBX_MTA_POINTS_ATTRIBUTED_V4_RJ` | UAT — do not build production reports on this yet |

---

## Analyst-Facing MTA Views (Daily Use)

### `EDW_PROD.ADVA.MTA_TOTAL_POINTS_ATTRIBUTED_V`
**Grain**: One row per order line per attributed touchpoint  
**Use for**: Order-level attribution, NAR breakdown by channel, fractional customer counts  
**Refresh**: Nightly — depends on CDI completing first

Key columns:

| Column | Description |
|--------|-------------|
| `IID` | Customer key — always filter `IID <> '-1'` |
| `BRAND_CD` | Brand (`'AN'`, `'UO'`, `'FP'`, `'AN_EU'`, etc.) |
| `ORDER_DT` | Order date — use for joins to `DW_CALENDAR_HIERARCHY` |
| `ORDER_ID` | Order identifier |
| `ORDER_LINE_SEQ` | Line within order |
| `ATTRIBUTED_DEMAND_AMT` | Dollar credit to this touchpoint |
| `ATTRIBUTED_DEMAND_QTY` | Unit credit |
| `ATTRIBUTED_RETURN_QTY` | Return units credited back |
| `ATTRIBUTED_CANCEL_AMT` | Cancellation credit (legacy only — not in RBX) |
| `MARKETING_CHANNEL` | Flat channel field (legacy taxonomy) |
| `BRAND_PARENT_MARKETING_CHANNEL` | Broadest channel rollup — use for channel grouping |
| `BRAND_MARKETING_CHANNEL` | Mid-level channel |
| `BRAND_SUBMARKETING_CHANNEL` | Sub-channel |
| `NAR_BRAND_D` | NAR at brand level/day — values: `'1. NEW'`, `'2. ACTIVE'`, `'3. REACTIVATED'` |
| `NAR_BRAND_M` | NAR at brand level/month |
| `DAY_FRACTIONAL_CUSTOMER_BRAND` | Fractional customer count — use instead of COUNT(DISTINCT IID) |
| `PURCHASE_CHANNEL_DERIVED` | D2C vs Retail |
| `DEVICE_TYPE` | Desktop, Mobile, Tablet |
| `LOYALTY_YN` | Y/N — was the customer a loyalty member at time of purchase |
| `SITE_ID` | e.g. `'US_EU'` for cross-region pulls |

**Always use `_V` views — not the underlying `DW_MTA_TOTAL_POINTS_ATTRIBUTED` table directly.**

---

### `EDW_PROD.ADVA.MTA_TOTAL_POINTS_ROLLUP_V`
**Grain**: Pre-aggregated by date + channel  
**Use for**: Weekly/monthly dashboard queries by channel — much faster than aggregating from the attributed view  
**Refresh**: Nightly

Key columns:

| Column | Description |
|--------|-------------|
| `ORDER_DT` | Date |
| `BRAND_CD` | Brand |
| `D2C_CHANNEL_SOURCE` | Channel source for rollup |
| `ORDERS_SS` | Order count (same-session window) |
| `SESSIONS_SS` | Session count |
| `DEMAND_R_SS` | Attributed demand (same-session, spend-aligned) |

---

### `EDW_PROD.URBN.AN_MTA_ROLLUP_BASE_DTB`
**AN-specific rollup table** — not in the standard EDW documentation but used in practice for ROAS calculations.  
**Grain**: By `ORDER_DT`, `MRKTG_CHN_NAME`, `SUB_MRKTG_CHN_NAME`, `BRND_CD`  
**Use for**: ROAS calculations joining to spend sources; EU brand (AN_EU) channel-level demand

Key columns:

| Column | Description |
|--------|-------------|
| `ORDER_DT` | Order date |
| `BRND_CD` | Brand code — use `'AN'` or `'AN_EU'` |
| `MRKTG_CHN_NAME` | Marketing channel (e.g. `'PAID SEARCH'`, `'EMAIL'`) |
| `SUB_MRKTG_CHN_NAME` | Sub-channel (e.g. `'PAID SEARCH - BRAND TEXT'`) |
| `MTA_DEMAND_AMT` | Attributed demand amount |

**Sample — monthly channel demand for AN EU paid search:**
```sql
SELECT
    TO_CHAR(ORDER_DT, 'YYYY-MM') AS year_month,
    MRKTG_CHN_NAME,
    SUB_MRKTG_CHN_NAME,
    SUM(MTA_DEMAND_AMT) AS MTA_DEMAND
FROM EDW_PROD.URBN.AN_MTA_ROLLUP_BASE_DTB
WHERE MRKTG_CHN_NAME = 'PAID SEARCH'
  AND BRND_CD = 'AN_EU'
GROUP BY ALL;
```

---

## Rockerbox (RBX) Tables

Rockerbox is replacing the legacy in-house model. Log-level tables are live; V3 comparison view is in UAT.

### `EDW_ODS_PROD.URBN.RBX_AN_LOG_LVL_PRCHS`
**Grain**: One row per marketing touchpoint per conversion  
**Rows**: ~183M for AN  
**Refresh**: Daily incremental with 14-day lookback  
**Primary key**: `Q_PRCHS_SNUM = CONVERSION_KEY || '|' || EVENT_ID`  
**Clustered by**: `DATE`

Other brand tables: `RBX_UO_LOG_LVL_PRCHS`, `RBX_FP_LOG_LVL_PRCHS`, `RBX_TR_LOG_LVL_PRCHS`

Key columns (vs legacy):

| RBX column | Legacy equivalent | Notes |
|-----------|------------------|-------|
| `EVENT_WEIGHT` | `POINTS / TOTAL_POINTS` | Normalized ~1.0 per conversion — do NOT compare raw values to legacy POINTS |
| `ATTRIBUTED_DEMAND_AMT` | `ATTRIBUTED_DEMAND_AMT` | Calculated using EVENT_WEIGHT — comparable |
| `TIER_1` | `MARKETING_CHANNEL` (broadest) | e.g. `'Paid Search'`, `'Email'`, `'Direct'` |
| `TIER_2` | `MEDIUM` | e.g. `'Paid Search - Google'` |
| `TIER_3` | `CAMPAIGN` | Campaign name |
| `TIER_4` | `KEYWORD` | Search keyword |
| `TIER_5` | `CONTENT` | Ad-level |
| `BRAND_MARKETING_CHANNEL` | `BRAND_MARKETING_CHANNEL` | URBN taxonomy mapped field |
| `BRAND_PARENT_MARKETING_CHANNEL` | `BRAND_PARENT_MARKETING_CHANNEL` | URBN broadest rollup — use this for channel grouping |
| `MARKETING_TYPE` | N/A | `'conv_only'` within `TIER_1 = 'Direct'` = proxy for legacy "Unattributed" |
| `CONVERSION_KEY` | N/A | Replaces `WEB_SESSION_SNUM` for session linkage |
| `EVENT_ID` | N/A | Touchpoint identifier |

**RBX "Direct" ≠ legacy "Unmatched Conversion"** — RBX Direct includes both true direct-load orders and unattributed demand. To isolate Unattributed: `WHERE TIER_1 = 'Direct' AND MARKETING_TYPE = 'conv_only'`.

**Cancellations not tracked in RBX** — `ATTRIBUTED_CANCEL_AMT/QTY` from the legacy model are not being replicated.

### Rockerbox Aggregate Tables
`EDW_ODS_PROD.URBN.RBX_AN_AGGREGATE_MTA` — daily aggregate, same naming for other brands. Use for fast summary queries without line-level detail.

### V3 Working View (UAT — not for production)
`EDW_SANDBOX_PROD.URBN.RBX_MTA_POINTS_ATTRIBUTED_V3_RJ`  
- Data starts 2025-09-01
- Adds GBP currency, EU VAT, PRODUCT_NAME (97% coverage), `SHIP_TO_STATE_CODE`, `MARKETING_TYPE`
- QA shows <0.3% demand variance vs legacy
- **Do not build production reports on top of this yet** — schema may change. Check with Rakesh Jain / Cherry Jain first.

**Channel-level comparison views (also sandbox, under development):**
- `EDW_SANDBOX_PROD.URBN.RBX_MTA_CHNL_COMPARISON_CHNL_DT_AN_WITH_SPEND`
- `EDW_SANDBOX_PROD.URBN.RBX_MTA_CHNL_COMPARISON_CHNL_DT_AN_EU_WITH_SPEND`

---

## Spend Data Sources

| Channel | Source | Notes |
|---------|--------|-------|
| AN EU search/affiliate | `FUNNEL_ANTHROPOLOGIE_EU.FUNNEL__OLFS6ZBWHZRUFMJO5ZS.ANEU_DAILY_FUNNEL_DATA` | Columns: `DATE`, `MARKETING_CHANNEL`, `CAMPAIGN`, `COST` |
| NA paid media spend | Not in a single EDW table as of early FY27 | Ask in #marketingsystems_cloud_qa |
| TTD impressions | `THE_TRADE_DESK.REDS.IMPRESSIONS` (Snowflake data share) | T-1 refresh |
| Innovid/Flashtalking (Epsilon + TTD) | `EDW_ODS_PROD.URBN.FT_IMPRESSIONS` | ~1.8B rows, daily |

---

## Channel Taxonomy

URBN's marketing channel hierarchy, used across legacy MTA and RBX:

| `BRAND_PARENT_MARKETING_CHANNEL` | What it covers |
|---|---|
| Paid Search | Google, Bing paid search (SA360 / Crealytics) |
| Paid Social | Meta (Facebook/Instagram), TikTok, Pinterest |
| Display | Programmatic display — TTD and Epsilon via Innovid |
| Email | All SFMC email marketing sends |
| Affiliate | Rakuten affiliate network |
| Organic Search | Unpaid Google/Bing |
| Direct / Unattributed | Orders with no trackable touchpoint; in RBX: `TIER_1='Direct'` + `MARKETING_TYPE='conv_only'` |
| Retail | In-store purchase |

---

## Key KPI Formulas

```
Attributed Demand     = ORDER_DEMAND_AMT × ATTRIBUTION_SHARE
                        (legacy: POINTS/TOTAL_POINTS; RBX: EVENT_WEIGHT)

ROAS                  = Attributed Demand ($) / Paid Media Spend ($)

CPA                   = Paid Media Spend ($) / Attributed Conversions

Fractional Customers  = SUM(DAY_FRACTIONAL_CUSTOMER_BRAND)
                        -- use inside MTA views, not COUNT(DISTINCT IID)
```

---

## Common Gotchas

1. **`MARKETING_CHANNEL` vs `BRAND_PARENT_MARKETING_CHANNEL`** — the flat `MARKETING_CHANNEL` field may not align with URBN's internal channel taxonomy. Use `BRAND_PARENT_MARKETING_CHANNEL` for consistent channel grouping across dashboards.

2. **RBX `EVENT_WEIGHT` vs legacy `POINTS`** — scales are incompatible. Legacy POINTS can exceed 1.0; RBX EVENT_WEIGHT normalizes to ~1.0 per conversion. Compare revenue totals, not weight values.

3. **`WEB_SESSION_SNUM` doesn't exist in RBX** — replaced by `EVENT_ID` / `CONVERSION_KEY`. Any join logic built on `WEB_SESSION_SNUM` needs to be rewritten for RBX.

4. **MTA runs after CDI** — if CDI maintenance is running, MTA will also be delayed that night. Check #marketingsystems_cloud_qa before investigating stale MTA numbers.

5. **`AN_MTA_ROLLUP_BASE_DTB` uses `BRND_CD`** (not `BRAND_CD`) — match your filter accordingly.
