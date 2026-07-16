---
name: urbn-edw-context
description: |
  URBN Enterprise Data Warehouse (Snowflake) reference for marketing analysts. Provides database/schema layout, table prefix conventions, customer identity (IID/CDI), email, loyalty, web analytics (GA4/DW_WA_*), and multi-touch attribution (MTA, including Rockerbox migration) context. ALWAYS load this skill before writing SQL against EDW_PROD or EDW_ODS_PROD, before counting customers, before computing any marketing KPI, or before joining web/email/order/attribution data. Triggers on any mention of: EDW, URBN, Snowflake, IID, CDI, MTA, Rockerbox, RBX, NAR, CLV, RFM, DW_*, Q_QL_*, Q_QF_*, Q_QA_*, ADVA, BLND, BRAND_CD, AN/UO/FP/TR, loyalty, GA4, web summary, attributed demand, ROAS.
---

# URBN EDW Context

You are working with URBN's Enterprise Data Warehouse on Snowflake. This skill encodes what an experienced URBN marketing analyst knows. Apply these rules before writing any query.

## Critical rules — apply to every query

1. **Always set the session header before querying:**
   ```sql
   USE ROLE RO_ROLE_PROD;
   USE WAREHOUSE RO_WH_PROD;
   USE DATABASE EDW_PROD;
   USE SCHEMA URBN;
   ```
   Use `PII_ROLE_PROD` only when unmasked PII is genuinely needed (rare for analytics). Use `SCHEMA ADVA` when querying MTA/CLV/RFM tables.

2. **Read-only SQL only.** Never run DDL or DML against PROD. Sandbox work goes in `EDW_SANDBOX_PROD.URBN`. No PII allowed in sandbox — use IID, never names/emails/addresses.

3. **Always count customers as `COUNT(DISTINCT IID)`** — never count emails, loyalty IDs, or web profile IDs as a customer proxy. One customer can have many of each.

4. **Always filter `IID <> '-1'`** when counting customers or aggregating MTA. `-1` = unmatched orders.

5. **For MTA customer counts, prefer `DAY_FRACTIONAL_CUSTOMER_BRAND` over `COUNT(DISTINCT IID)`** — fractional counting handles repeat purchasers in the period correctly.

6. **Use the fiscal calendar, not Gregorian.** Join to `EDW_PROD.URBN.DW_CALENDAR_HIERARCHY` on `CALENDAR_DT`. `CURRENT_YEAR_ID = 0` is TY, `-1` is LY. Use `WEEK_OF_YEAR_NUM` for fiscal weeks.

7. **Cite the source table and column for every metric** in the deliverable. If a metric isn't in the data, say so — don't estimate.

8. **For very large tables, always filter on the date column** (`VISIT_DATE`, `ORDER_DT`, `Q_DT_ID`) for partition pruning. The DW_WA_WEB_HITS_* tables are 100B+ rows.

9. **Always use the `_V` views in ADVA, not the underlying physical tables.** They handle legacy/RBX transition logic.

10. **Before running anything that scans more than ~1B rows, give a row-count estimate first** and confirm.

## Brand codes

`BRAND_CD` is the universal brand filter. Most tables include all brands — always filter explicitly.

| Code | Brand |
|---|---|
| `AN` | Anthropologie (US) |
| `AN_EU` | Anthropologie (EU) |
| `UO` | Urban Outfitters (US) |
| `UO_EU` | Urban Outfitters (EU) |
| `FP` | Free People (US) |
| `FP_UK` | Free People (UK) |
| `TR` | Terrain |

`SRC_ID = 100` = North America, `SRC_ID = 200` = Europe.

## Reading a table name

| Prefix | Layer | Where it lives |
|---|---|---|
| `DW_*` | Data Warehouse — analyst-ready, cleaned, joined. **Start here.** | `EDW_PROD.URBN` |
| `Q_QF_*_V` | Quantisense Fact view (legacy naming, still active — NOT Qlik) — row-level facts | `EDW_PROD.URBN` |
| `Q_QL_*_V` | Quantisense Lookup view — dimension/reference data | `EDW_PROD.URBN` |
| `Q_QA_*_V` | Quantisense Aggregate view — pre-rolled summaries | `EDW_PROD.URBN` |
| `Q_QR_*_V` | Quantisense Report view — purpose-built for one question | `EDW_PROD.URBN` |
| `AA_*`, `MTA_*_V`, `DW_RFM_*` | Advanced Analytics model outputs, MTA, RFM | `EDW_PROD.ADVA` |
| `RBX_*` | Rockerbox (raw, ODS layer) | `EDW_ODS_PROD.URBN` |
| `FT_*` | Flashtalking/Innovid impression logs | `EDW_ODS_PROD.URBN` |
| `SOM_STER_*` | Sterling OMS raw tables | `EDW_ODS_PROD.URBN` |
| `IP_*` | Island Pacific (ERP) raw tables | `EDW_ODS_PROD.URBN` |

Column suffixes: `_ID` = surrogate key, `_SNUM` = concatenated business key, `_CD` = code, `_DT` = date, `_TS` = timestamp, `_FLG` = boolean flag, `_AMT` = dollar amount, `_QTY` = unit quantity. A `Q_` *column* prefix = EDW-derived (computed by EDW, not from source).

## The starter tables — what to reach for first

| Question | Start here |
|---|---|
| Find a customer / lookup IID by email | `EDW_PROD.URBN.DW_CDI_EMAIL` |
| Customer attributes (name, address, demo) | `EDW_PROD.URBN.DW_CDI_CUSTOMER` |
| Email subscribers (opted in) | `EDW_PROD.URBN.Q_QL_ELS_V` — filter `PREF_FLG='Y' AND MOST_RECENT_FLG='Y'` |
| Loyalty enrolments — all channels | `EDW_PROD.URBN.Q_QL_CDI_LOYALTY_V` — filter `PRIMARY_LOYALTY_ID_FLG='Y'` |
| Loyalty enrolments — digital only, same-day | `EDW_PROD.URBN.DW_SERVICES_SUBSCRIPTIONS` (excludes POS — use only when you specifically need digital-only) |
| Email campaign sends | `DW_EMAIL_SEND_JOBS` + `DW_EMAIL_SENT` |
| Email engagement | `DW_EMAIL_OPENS`, `DW_EMAIL_CLICKS`, `DW_EMAIL_BOUNCES` |
| Web sessions / traffic source | `EDW_PROD.URBN.DW_WA_WEB_SUMMARY` |
| Funnel events (PDP → ATC → purchase) | `EDW_PROD.URBN.DW_WA_WEB_HITS_ECOMACTION` |
| Product-level web engagement | `EDW_PROD.URBN.DW_WA_WEB_HITS_PRODUCT` |
| MTA — line-level attribution (legacy/current) | `EDW_PROD.ADVA.MTA_TOTAL_POINTS_ATTRIBUTED_V` |
| MTA — pre-aggregated daily rollup (legacy/current) | `EDW_PROD.ADVA.MTA_TOTAL_POINTS_ROLLUP_V` |
| **MTA — Rockerbox V4 (sandbox, code translation only)** | `EDW_SANDBOX_PROD.URBN.RBX_MTA_TOTAL_POINTS_ATTRIBUTED_V_RJ` (the joined view — start here) |
| CLV predictions (current snapshot) | `EDW_PROD.ADVA.AA_CLV_FINAL_PREDICTIONS_MAX_ANCHOR_DT` |
| RFM history | `EDW_PROD.ADVA.DW_RFM_HISTORY` (key column is `CLOUD_IID`, not `IID`) |
| Blended order data (D2C + retail) | `EDW_PROD.URBN.Q_QF_BLND_ORDER_HEADER_V` |
| Fiscal calendar | `EDW_PROD.URBN.DW_CALENDAR_HIERARCHY` |

## Progressive disclosure — load these reference files when relevant

The following files in `references/` contain the deeper detail. Load only when the task requires it:

- `references/database-structure.md` — Full database/schema map, schema purposes, table prefix system, column conventions, deprecated table patterns. **Load when:** a query touches a table you don't recognise, or you need to confirm what database/schema something lives in.
- `references/customer-identity.md` — IID/HID/RID hierarchy, Formulated vs. Sustained IIDs, order linking priority, Salesforce migration data gaps, full identifier crosswalk (Contact ID, PROFILE_ID, Sterling ID, UID2, USER_PSEUDO_ID). **Load when:** working with customer counts, identity resolution, joining customer data across systems, or any analysis touching the Aug–Oct 2025 POS rollout window.
- `references/loyalty-and-clv.md` — Loyalty programme structure (UO/AN/FP, post-FY26), `Q_QL_CDI_LOYALTY_V` columns, signup channel value gotchas, CLV model methodology, RFM scoring and labels. **Load when:** analysing loyalty enrolment, CLV segments, or RFM.
- `references/email-and-sfmc.md` — Email pipeline, ~2 day lag, all DW_EMAIL_* tables, KPI calculations, Bluecore click gap, A/B test gotchas, MPP open inflation. **Load when:** querying email engagement or campaign performance.
- `references/web-analytics-ga4.md` — GA4 pipeline, all 7 DW_WA_* tables, join key (`WEB_SESSION_SNUM + VISIT_DATE`), `FIXED_TRAFFIC_SOURCE_*` columns, funnel events, UA360 history boundary, response attribution tables. **Load when:** querying web/app sessions, traffic source, conversion funnels, product engagement.
- `references/mta-and-attribution.md` — Legacy MTA vs. Rockerbox, channel taxonomy (BRAND_PARENT_MARKETING_CHANNEL vs. RBX TIER_1–TIER_5), the Rockerbox `Direct`/`conv_only` proxy for legacy "Unattributed", ROAS/CPA formulas, V3 sandbox table status. **Load when:** computing attributed demand, ROAS, channel performance, or comparing legacy and RBX numbers.
- `references/refresh-and-maintenance.md` — Refresh cadences for every major table, CDI maintenance windows (and downstream MTA pause), where to ask if data looks stale. **Load when:** numbers look flat, missing, or you need to set stakeholder expectations on data freshness.
- `references/glossary.md` — Business terms (NAR, NCOA, demand vs. sales, BOP/EOP, sell-through), abbreviations, vendor/system names. **Load when:** you encounter an unfamiliar term in a request or in the data.

## Common gotchas — apply universally

These come up constantly. Bake them into every query.

| Gotcha | What to do |
|---|---|
| Counting emails as customers | `COUNT(DISTINCT IID)` — always |
| Forgetting `IID <> '-1'` | Add it to every customer/MTA query |
| Forgetting `PRIMARY_LOYALTY_ID_FLG = 'Y'` on loyalty | Filter it when counting unique enrollees |
| Looking for `LOYALTY_TIER` on `Q_QL_CDI_LOYALTY_V` | Doesn't exist — UO tiers were removed FY26. Don't use `SFME_LOYALTY_UO.CURRENT_TIER` either (stale SessionM) |
| Reading `SIGNUP_CHANNEL = 'MOBILE'` as app | App = `APP_IOS` or `ANDROID_APP`. `MOBILE` = legacy flow |
| Using `DW_CDI_PREF` for opt-in subscribers | `DW_CDI_PREF` is suppression/opt-out. Use `Q_QL_ELS_V` for subscribers |
| Joining `DW_RFM_HISTORY` on `IID` | Column is `CLOUD_IID`, not `IID` |
| Querying `AA_CLV_FINAL_PREDICTIONS` directly | Returns one row per weekly run per IID. Use `_MAX_ANCHOR_DT` view |
| `SITE_CHANNEL` for device/property | Has many nulls in GA4. Use `GA_VIEW_CD` (`WEB`/`IOS`/`ANDROID`) |
| Using raw `TRAFFIC_SOURCE_*` columns | Use `FIXED_TRAFFIC_SOURCE_*` — apply correction layer |
| Joining web tables on `WEB_SESSION_SNUM` alone | Always include `VISIT_DATE` for partition pruning |
| Filtering email on `LOAD_DATE` | Use `Q_DT_IT` (send date). LOAD_DATE is ~2 days later |
| Comparing RBX `EVENT_WEIGHT` to legacy `POINTS` | Different scales. Compare attributed revenue, not weights |
| Treating RBX `Direct` as legacy "Unattributed" | RBX Direct includes both. Filter `MARKETING_TYPE = 'conv_only'` to isolate Unattributed |
| Querying `EDW_PROD.MARKETINGQA` | That's ETL staging. Use `EDW_PROD.URBN` |
| Using `STERLING_ID` for post-Phase-3 customers | Not populated for new customers acquired after early 2025 |
| Running customer reports during CDI maintenance | Numbers will be flat. Check `#marketingsystems_cloud_qa` for the monthly notice |

## Where to ask when stuck

| Question | Channel |
|---|---|
| Marketing data, customer tables, MTA, GA4 questions | `#marketingsystems_cloud_qa` |
| Snowflake access, role issues | `#edw-support-snowflake` |
| Table discovery, column definitions, lineage | Atlan — `urbn.atlan.com` |
| Specific RBX questions | Rakesh Jain / Cherry Jain |
| GA4 pipeline / Skybot ETL questions | Ryan Sweigart (contractor) via `#marketingsystems_cloud_qa` |

## Output expectations for analytics deliverables

When producing any deliverable using EDW data:

- Lead with the headline number, then the methodology
- Cite the source table for every metric: `(Source: MTA_TOTAL_POINTS_ATTRIBUTED_V, ORDER_DT 2026-04-01 to 2026-04-30)`
- Currency always specified, even when obvious — and especially when EU brands are involved (RBX V3 has GBP logic for EU brands)
- For MTA: state which model (legacy in-house vs. RBX V4 default vs. URBN Tuned) and which window (Same-Session vs. 14DLC). For RBX V4 specifically, note that data starts Sept 2025 (Sept 24 for UO/UO_EU) and is the **default model, not the URBN Tuned Model** — deep dives should use legacy until tuning lands.
- For CLV: state the anchor date and that it's a forward-looking 12-month prediction, not realised revenue
- For NAR: include the time-window basis (1. NEW = no prior brand purchase ever; 2. ACTIVE = within 365 days; 3. REACTIVATED = lapsed >365 days then returned)
- For comparisons spanning Aug–Oct 2025: add a footnote about the Salesforce migration POS data gap
- If MTA is being used and CDI ran into maintenance that period: flag it
