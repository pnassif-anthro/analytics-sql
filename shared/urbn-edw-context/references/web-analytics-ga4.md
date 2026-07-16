# Web Analytics (GA4) at URBN

## How GA4 data gets into EDW

```
GA4 (web/app events)
    ↓ daily export
Google BigQuery (urbn-edw-prod.GA4.*)
    ↓ Skybot ETL (GA4_HIT_SETUP job suite)
EDW_PROD.MARKETINGQA  ← staging/QA — DO NOT QUERY
    ↓ promotion to PROD
EDW_PROD.URBN ← analyst-facing tables (use these)
```

**Always query `EDW_PROD.URBN`, never `EDW_PROD.MARKETINGQA`** (that's ETL staging).

Pipeline owner: Ryan Sweigart (contractor). Skybot job suites: `GA4_GOLDEN_TABLE_NOTIFY`, `GA4_HIT_SETUP`, `GA4_WEB_SUMMARY`, `GA4_WEB_HITS_*`.

## Properties currently loading

- **Web** — UO, AN, FP, Terrain
- **Mobile** — iOS and Android apps for UO, AN, FP

**History boundary:** GA4 data in PROD starts **October 1, 2023**. Terrain's GA4 data starts **February 6, 2024** (pre-Feb 2024 Terrain came from UA360). For pre-Oct 2023 data on any brand, use the `_UA360` suffix tables.

## The seven core DW_WA tables

All seven live in `EDW_PROD.URBN`. **Join key across the entire family is `WEB_SESSION_SNUM + VISIT_DATE`** — always include both for partition pruning.

### Session-level

| Table | Grain | Rows | What it contains |
|---|---|---|---|
| `DW_WA_WEB_SUMMARY` | Session | ~8.2B | **Primary table.** One row per session. Traffic source, device, geo, engagement flags. 87 cols. |
| `DW_WA_WEB_SUMMARY_DAILY` | Session | ~1.8B | Fresh daily feed — typically available earlier than main summary table. Use for same-day reporting |

### Hit-level

| Table | Grain | Rows | Contains |
|---|---|---|---|
| `DW_WA_WEB_HITS_SUMMARY` | Hit | ~220B | Hit detail — event params, page referrer, login status. **Hit numbers are synthetic (EDW-assigned)**, not native GA4 |
| `DW_WA_WEB_HITS_SUMMARY_DAILY` | Hit | ~70.9B | Fresh daily feed |
| `DW_WA_WEB_HITS_PAGE` | Page view | ~220B | URLs, hostnames, page titles, search keywords |
| `DW_WA_WEB_HITS_EVENTS` | Event | ~167B | Event category/action/label/value |
| `DW_WA_WEB_HITS_PRODUCT` | Product | ~46.7B | PDP views, add-to-cart, SKU, name, category, brand, variant, revenue. **Essential for style-level engagement** |
| `DW_WA_WEB_HITS_ECOMACTION` | E-commerce event | ~135B | Funnel events (see map below) |
| `DW_WA_WEB_HITS_ORDER_HEADER` | Purchase | ~170M | Transaction data (`event_name = 'purchase'`) |

### Ecom funnel event map

| GA4 event | Funnel step |
|---|---|
| `session_start` | Session |
| `view_item` | PDP View |
| `add_to_cart` | Add to Cart |
| `view_cart` | Cart View |
| `begin_checkout` | Begin Checkout |
| `purchase` | Purchase |

## Key columns on `DW_WA_WEB_SUMMARY`

| Column | Notes |
|---|---|
| `WEB_SESSION_SNUM` | Join key. Composite of user identifier + ga_session_id. **Always join with `VISIT_DATE`** |
| `VISIT_DATE` | Session date. Always include in joins for partition pruning |
| `GA_VIEW_CD` | `WEB`, `IOS`, or `ANDROID`. **Use this, not `SITE_CHANNEL`** — `SITE_CHANNEL` has many nulls in GA4 |
| `FIXED_TRAFFIC_SOURCE_*` | Corrected traffic source. **Always use these, not raw `TRAFFIC_SOURCE_*`** — the `FIXED_` columns apply a correction layer |
| `ENGAGED_SESSION_FLG` | TRUE if session >10s, conversion event, or >1 page view |
| `FULLVISITOR_ID` | Anonymous device/browser ID. Maps to native GA4 `USER_PSEUDO_ID`. Tracks device, not person |
| `USER_ID` | Authenticated user ID. Only populated for logged-in sessions. Use `WEB_SESSION_SNUM` regardless of login state |
| `BRAND_CD` | UO/AN/FP/TR. **Always filter on this** — all brands in one table |

## Funnel and attribution views

### Product funnel

| Table / view | Schema | What it is |
|---|---|---|
| `DW_WA_WEB_SSSN_PRD_FUNNEL_DSN` | `EDW_PROD.URBN` | Hit-level product funnel: PDP → ATC → purchase. ~26.4B rows |
| `DW_WEB_SESSION_PRODUCTS_FUNNEL_V` | `EDW_PROD.ADVA` | Style-level funnel — traffic source, campaigns, products, revenue. Tagged Marketing Priority List |
| `Q_QF_WA_WEB_SUMMARY_V` | `EDW_PROD.URBN` | Session summary view with currency conversion. Used in Qlik. Tagged Marketing Priority List |

### Web response attribution

These connect web sessions to marketing channel attribution. Subset of `DW_WA_WEB_SSSN_PRD_FUNNEL_DSN` — converted population only. They feed the MTA pipeline.

| Table | Model |
|---|---|
| `DW_WA_RSPNS_ATRBTN_WEB_NEW` | New / same-session attribution |
| `DW_WA_RSPNS_ATRBTN_WEB_SS` | Same-session attribution |
| `DW_WA_RSPNS_ATRBTN_WEB_14DLC` | 14-day last click |

> **For attributed demand / channel analysis, use the MTA views in `EDW_PROD.ADVA`** rather than these source tables.

### Incremental customer sessions

| Table | What it is |
|---|---|
| `DW_WA_ICS` | Incremental Customer Sessions — used in MTA pipeline |
| `DW_WA_ICS_UA360` | Legacy UA360-era ICS, static |

## UA360 historical tables

For dates before Oct 2023 (or pre-Feb 2024 for Terrain). Static — no new data.

| Table | Contains |
|---|---|
| `DW_WA_WEB_HITS_SUMMARY_UA360` | UA360 hit history (up to June 2024) |
| `DW_WA_WEB_HITS_EVENTS_UA360` | UA360 events |
| `DW_WA_WEB_HITS_PAGE_UA360` | UA360 page views |
| `DW_WA_WEB_HITS_ECOMACTION_UA360` | UA360 ecomaction |

## Common query patterns

### Sessions by brand and week

```sql
USE ROLE RO_ROLE_PROD;
USE WAREHOUSE RO_WH_PROD;
USE DATABASE EDW_PROD;
USE SCHEMA URBN;

SELECT
    BRAND_CD,
    DATE_TRUNC('week', VISIT_DATE)  AS week_start,
    GA_VIEW_CD,
    COUNT(DISTINCT WEB_SESSION_SNUM) AS sessions,
    COUNT(DISTINCT CASE WHEN ENGAGED_SESSION_FLG THEN WEB_SESSION_SNUM END) AS engaged_sessions
FROM DW_WA_WEB_SUMMARY
WHERE VISIT_DATE >= DATEADD(week, -4, CURRENT_DATE)
  AND BRAND_CD = 'AN'
GROUP BY 1, 2, 3
ORDER BY 2 DESC;
```

### Traffic source breakdown

```sql
SELECT
    FIXED_TRAFFIC_SOURCE_MEDIUM,
    FIXED_TRAFFIC_SOURCE_SOURCE,
    COUNT(DISTINCT WEB_SESSION_SNUM) AS sessions,
    COUNT(DISTINCT USER_ID)          AS logged_in_users
FROM DW_WA_WEB_SUMMARY
WHERE VISIT_DATE >= DATEADD(week, -1, CURRENT_DATE)
  AND BRAND_CD = 'UO'
  AND GA_VIEW_CD = 'WEB'
GROUP BY 1, 2
ORDER BY sessions DESC
LIMIT 25;
```

### PDP → purchase funnel

```sql
SELECT
    BRAND_CD,
    DATE_TRUNC('week', VISIT_DATE) AS week_start,
    COUNT(DISTINCT CASE WHEN ECOM_ACTION_TYPE = 'PDP View'    THEN WEB_SESSION_SNUM END) AS pdp_sessions,
    COUNT(DISTINCT CASE WHEN ECOM_ACTION_TYPE = 'Add to Cart' THEN WEB_SESSION_SNUM END) AS atc_sessions,
    COUNT(DISTINCT CASE WHEN ECOM_ACTION_TYPE = 'Purchase'    THEN WEB_SESSION_SNUM END) AS purchase_sessions
FROM DW_WA_WEB_HITS_ECOMACTION
WHERE VISIT_DATE >= DATEADD(week, -4, CURRENT_DATE)
  AND BRAND_CD = 'FP'
GROUP BY 1, 2
ORDER BY 2 DESC;
```

> Verify exact column names in Atlan before running — schema names like `ECOM_ACTION_TYPE` may have variants.

## Known issues and gotchas

| Issue | What happens | Fix |
|---|---|---|
| `SITE_CHANNEL` has many nulls in GA4 | Wrong/missing device categorization | Use `GA_VIEW_CD` (WEB/IOS/ANDROID) |
| Raw `TRAFFIC_SOURCE_*` misclassified | Channel attribution wrong | Always use `FIXED_TRAFFIC_SOURCE_*` |
| Synthetic hit numbers | EDW-assigned, not native GA4 hits | Don't cross-reference to native GA4 reports by hit number |
| **PDP inflation Jan 6–21 2025** | ~22.4M duplicate `view_item` hits in BigQuery | Fixed Feb 2026 (RFC-5010, ETL-11552, ETL-11707). PROD tables restated. Data correct now |
| Terrain history gap | GA4 starts Feb 6 2024 | Use `_UA360` for Terrain pre-Feb 2024 |
| MARKETINGQA confusion | Same table names, partial data | Always query `EDW_PROD.URBN` |
| Joining without `VISIT_DATE` | Query times out or wrong cross-session joins | **Always join on `WEB_SESSION_SNUM + VISIT_DATE`** |
| Posting to `#edw-ga4-squad` | Internal channel, no analyst support | Use `#marketingsystems_cloud_qa` |

## Refresh

| Table | Refresh |
|---|---|
| `DW_WA_WEB_SUMMARY` | Daily |
| `DW_WA_WEB_SUMMARY_DAILY` | Daily, earlier availability |
| `DW_WA_WEB_HITS_*` | Daily (same Skybot suite) |
| `DW_WA_WEB_HITS_*_DAILY` | Daily, earlier availability |
| `DW_WA_RSPNS_ATRBTN_*` | Nightly with MTA — depends on CDI completing |
| `DW_WA_WEB_SSSN_PRD_FUNNEL_DSN` | Nightly with MTA |
| `_UA360` | Static — no new data |
