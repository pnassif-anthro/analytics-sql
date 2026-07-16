# MTA and Attribution

## What MTA does

Every URBN order was influenced by some combination of marketing touchpoints (paid search click, email open, display impression, organic visit, store walk-in). MTA distributes fractional credit across those touchpoints so the business can evaluate which channels drive demand.

Without MTA, every team takes 100% credit for every order they touched. MTA solves that.

## Two systems running in parallel

| System | Status | Primary table |
|---|---|---|
| **Legacy in-house MTA** | Active, being sunset | `EDW_PROD.ADVA.DW_MTA_TOTAL_POINTS_ATTRIBUTED` (use `_V` views) |
| **Rockerbox (RBX)** | Active, replacing legacy | `EDW_ODS_PROD.URBN.RBX_{BRAND}_LOG_LVL_PRCHS` + comparison views in sandbox |

Most current reporting uses **legacy in-house MTA via the `_V` views**. Rockerbox is the incoming replacement — comparison views are being built in sandbox. **Check `#marketingsystems_cloud_qa` for current migration status before building new reports.**

## Legacy in-house MTA — how it works

Points-based system over web sessions (GA4) and orders (Sterling D2C, IP retail).

1. For each order, look back at all marketing touchpoints in a defined window
2. Each touchpoint earns "points" based on rules — product views, sessions, email clicks, prior purchases
3. Points convert to fractional share of order's demand. 30% of points = 30% of demand $
4. Produces `ATTRIBUTED_DEMAND_AMT` at touchpoint level

**Attribution window:** **Same-Session (SS) is the primary model since FY20.** 14-Day Last Click (14DLC) retained historically but not primary.

**Coverage:** Direct channel (D2C web/app) is fully attributed. Retail orders enter via IP as sales records, included in blended demand but with limited touchpoint coverage.

## Rockerbox (RBX) — the incoming platform

Rockerbox collects touchpoints via a pixel on URBN websites and connects them to conversions using order ID.

### Key differences from legacy

| Attribute | Legacy | Rockerbox |
|---|---|---|
| Attribution weight | `POINTS` (not normalized, can exceed 1.0) | `EVENT_WEIGHT` (normalized to ~1.0 per conversion) |
| Models available | One (points-based) | **Four**: Normalized MTA, First Touch, Last Touch, Even |
| Channel taxonomy | Flat GA4 UTM fields (`MARKETING_CHANNEL`, `MEDIUM`, `SOURCE`, `CAMPAIGN`, `KEYWORD`, `CONTENT`) | **5-tier hierarchy** (`RBX_TIER_1`–`RBX_TIER_5`) + URBN-mapped rollups (`RBX_PARENT_CHANNEL`, `RBX_MARKETING_CHANNEL`, `RBX_SUBMARKETING_CHANNEL`, `RBX_AD_PLATFORM`) |
| Granularity | Line-item (`ORDER_LINE_SEQ`) | Event-level (`EVENT_ID`, `SEQUENCE_NUMBER`) |
| Session data | `WEB_SESSION_SNUM`-based | Event/conversion focused (`CONVERSION_KEY`, `EVENT_ID`) |
| Cancellation tracking | Full (`ATTRIBUTED_CANCEL_AMT/QTY`) | **Not tracked by design** |

### The four RBX attribution models

| Model | Weight column | Revenue column | When |
|---|---|---|---|
| Normalized MTA | `EVENT_WEIGHT` | `RBX_REVENUE_NORMALIZED` | **Primary — closest to legacy POINTS** |
| First Touch | `FIRST_TOUCH` | `RBX_REVENUE_FIRST_TOUCH` | 100% to first touchpoint |
| Last Touch | `LAST_TOUCH` | `RBX_REVENUE_LAST_TOUCH` | 100% to last touchpoint |
| Even | `EVEN_WEIGHT` | `RBX_REVENUE_EVEN` | Equal split across all touchpoints |

For most reporting that used legacy `ATTRIBUTED_DEMAND_AMT`, use `ATTRIBUTED_DEMAND_AMT` on RBX tables (calculated using `EVENT_WEIGHT`).

### RBX channel taxonomy — RBX_TIER_1 to RBX_TIER_5

| Tier | Maps to (legacy GA4 UTM equivalent) | Examples |
|---|---|---|
| `RBX_TIER_1` | `MEDIUM` (broadest in the new taxonomy) | Paid Search, Paid Social, Email, Display, Organic |
| `RBX_TIER_2` | `SOURCE` | Google, Meta, etc. |
| `RBX_TIER_3` | `CAMPAIGN` | Specific campaign names |
| `RBX_TIER_4` | `KEYWORD` | Search keywords |
| `RBX_TIER_5` | `CONTENT` / ad creative | Ad-level identifiers |

URBN-mapped roll-up channel fields delivered in V4: **`RBX_PARENT_CHANNEL`**, **`RBX_MARKETING_CHANNEL`**, **`RBX_SUBMARKETING_CHANNEL`**, **`RBX_AD_PLATFORM`** (new).

> **Use the `RBX_` prefix on V4 fields.** Earlier docs referenced these as `BRAND_PARENT_MARKETING_CHANNEL` etc. — the actual columns delivered ship as `RBX_*`. The Phase 1 column reference Google Sheet (`TOTAL_POINTS_ATTR_MTA_RBX`) is authoritative.

The `MARKETING_TYPE` field is RBX-only. **`MARKETING_TYPE = 'conv_only'`** identifies orders with no recorded marketing touchpoint — this is the proxy for legacy "Unattributed" within RBX's `Direct` Tier 1 bucket.

## Key tables

### Analyst-facing MTA views (daily use)

| Table / view | Schema | Contents |
|---|---|---|
| `MTA_TOTAL_POINTS_ATTRIBUTED_V` | `EDW_PROD.ADVA` | **Primary view.** One row per order line per attributed touchpoint. `ATTRIBUTED_DEMAND_AMT`, `ATTRIBUTED_DEMAND_QTY`, `IID`, `NAR_BRAND_D`, `LOYALTY_YN`, `PURCHASE_CHANNEL_DERIVED`, `DEVICE_TYPE`, all channel dimensions |
| `MTA_TOTAL_POINTS_ROLLUP_V` | `EDW_PROD.ADVA` | **Pre-aggregated rollup.** Daily rollups with GA4 SS joins applied. `D2C_CHANNEL_SOURCE`, `ORDERS_SS`, `SESSIONS_SS`, `DEMAND_R_SS`. **Faster for summary queries by channel/date** |
| `DW_MTA_TOTAL_POINTS_ATTRIBUTED` | `EDW_PROD.ADVA` | Underlying physical (73 cols, ~11B rows). Use the `_V` view, not this directly |

> **Always use the `_V` views** — they handle legacy/RBX transition logic. `MTA_TOTAL_POINTS_ROLLUP_V` is what most brand analysts use for weekly dashboard queries. Use `MTA_TOTAL_POINTS_ATTRIBUTED_V` only when you need line-level detail.

### Rockerbox source tables

Log-level purchase tables, materialized per brand:

| Table | Brand |
|---|---|
| `EDW_ODS_PROD.URBN.RBX_AN_LOG_LVL_PRCHS` | Anthropologie |
| `EDW_ODS_PROD.URBN.RBX_UO_LOG_LVL_PRCHS` | Urban Outfitters |
| `EDW_ODS_PROD.URBN.RBX_FP_LOG_LVL_PRCHS` | Free People |
| `EDW_ODS_PROD.URBN.RBX_TR_LOG_LVL_PRCHS` | Terrain |

Primary key: `Q_PRCHS_SNUM = CONVERSION_KEY + '|' + EVENT_ID`. Clustered by `DATE`. Incremental daily via `UPDATED_AT` with 14-day lookback.

Aggregate tables (per brand): `RBX_AN_AGGREGATE_MTA`, `RBX_UO_AGGREGATE_MTA`, `RBX_FP_AGGREGATE_MTA`, `RBX_TR_AGGREGATE_MTA`.

### Ad feed / impression tables

| Table | Schema | Contents |
|---|---|---|
| `FT_IMPRESSIONS` | `EDW_ODS_PROD.URBN` | **Innovid (formerly Flashtalking)** impression log. ~1.8B rows. Covers Epsilon and TTD campaigns — Innovid serves as neutral ad server for both DSPs. Daily |
| `FT_MATCH_PLACEMENT` | `EDW_ODS_PROD.URBN` | Placement-level metadata |
| `FT_MATCH_SITE` | `EDW_ODS_PROD.URBN` | Site-level metadata |
| `THE_TRADE_DESK.REDS.IMPRESSIONS` | TTD Snowflake share | TTD impression data direct. Join via UID2 for identity |

> Note: Innovid acquired Flashtalking (Mediaocean) in 2025. EDW retains the `FT_` prefix — don't rename in existing queries.

## Channel taxonomy

**On legacy MTA tables** (current production reporting): `BRAND_PARENT_MARKETING_CHANNEL` is the broadest rollup; `BRAND_MARKETING_CHANNEL` is mid-level.

**On RBX V4 sandbox tables**: `RBX_PARENT_CHANNEL` is the broadest rollup; `RBX_MARKETING_CHANNEL` is mid-level; `RBX_SUBMARKETING_CHANNEL` is sub-level; `RBX_AD_PLATFORM` is new.

The categorical values themselves (Paid Search, Paid Social, etc.) align across both:

| Channel | Covers |
|---|---|
| Paid Search | Google, Bing paid (via SA360 / crealytics) |
| Paid Social | Meta (Facebook/Instagram), TikTok, Pinterest |
| Display | Programmatic — TTD and Epsilon via Innovid |
| Email | All SFMC sends |
| Affiliate | Rakuten |
| Organic Search | Unpaid Google/Bing |
| Direct / Unattributed | No trackable touchpoint. **In RBX: `TIER_1 = 'Direct'` AND `MARKETING_TYPE = 'conv_only'` is URBN's "Unattributed" proxy** |
| Retail | In-store — limited MTA coverage |

> **The "Direct" problem in Rockerbox:** Legacy had a distinct `Unmatched Conversion` touchpoint type. RBX consolidates direct load orders AND unattributed demand into a single `TIER_1 = 'Direct'` bucket. Workaround: filter `MARKETING_TYPE = 'conv_only'` within Direct to isolate the Unattributed equivalent. Ticket EDW-4508 (New Request) is filed to formalize this in comparison views. **Until that's done, consult `#marketingsystems_cloud_qa` before using the Direct bucket in cross-model comparisons.**

## KPIs

### Attributed Demand

`ATTRIBUTED_DEMAND_AMT = ORDER_DEMAND_AMT × ATTRIBUTION_SHARE`

Where `ATTRIBUTION_SHARE = POINTS / TOTAL_POINTS` (legacy) or `EVENT_WEIGHT` (RBX, normalized to ~1.0).

### ROAS

`ROAS = Attributed Demand ($) / Paid Media Spend ($)`

Demand from MTA views. Spend ingested separately by channel — `DEMAND_R_SS` in rollup view carries spend-aligned demand. Ask in `#marketingsystems_cloud_qa` for current spend source table (not consolidated as of FY27).

### CPA

`CPA = Paid Media Spend ($) / Attributed Conversions`

Conversions = orders in same-session window.

### Customer counting in MTA — fractional, not distinct

Use `DAY_FRACTIONAL_CUSTOMER_BRAND` (or week/month variants), **not `COUNT(DISTINCT IID)`**, when counting customers within MTA. Fractional handles repeat purchasers in a period correctly.

## NAR (New / Active / Reactivated) — fields on MTA view

| Field | Grain |
|---|---|
| `NAR_BRAND_D` | NAR at brand level (omni-channel) — day |
| `NAR_BRAND_RETAIL_D` | NAR within retail channel — day |
| `NAR_BRAND_CHANNEL_D` | NAR within specific channel (direct or retail) — day |
| `NAR_BRAND_M` | NAR at brand level — month |

Values: `'1. NEW'`, `'2. ACTIVE'`, `'3. REACTIVATED'` — prefixed with sort order.

## Common query patterns

### Channel summary — rollup view (faster)

```sql
USE ROLE RO_ROLE_PROD;
USE WAREHOUSE RO_WH_PROD;
USE DATABASE EDW_PROD;
USE SCHEMA ADVA;

SELECT
    ch.WEEK_OF_YEAR_NUM,
    r.BRAND_CD,
    r.D2C_CHANNEL_SOURCE,
    SUM(r.ORDERS_SS)      AS orders,
    SUM(r.SESSIONS_SS)    AS sessions,
    SUM(r.DEMAND_R_SS)    AS attributed_demand
FROM MTA_TOTAL_POINTS_ROLLUP_V r
JOIN EDW_PROD.URBN.DW_CALENDAR_HIERARCHY ch
    ON ch.CALENDAR_DT = r.ORDER_DT
WHERE r.BRAND_CD = 'AN'
  AND ch.CURRENT_YEAR_ID IN (0, -1)
GROUP BY 1, 2, 3
ORDER BY 1, 3 DESC;
```

### Channel + NAR — attributed view

```sql
SELECT
    ch.WEEK_OF_YEAR_NUM,
    mta.BRAND_PARENT_MARKETING_CHANNEL,
    mta.NAR_BRAND_D,
    SUM(mta.ATTRIBUTED_DEMAND_AMT)              AS attributed_demand,
    SUM(mta.DAY_FRACTIONAL_CUSTOMER_BRAND)      AS customers
FROM EDW_PROD.ADVA.MTA_TOTAL_POINTS_ATTRIBUTED_V mta
JOIN EDW_PROD.URBN.DW_CALENDAR_HIERARCHY ch
    ON ch.CALENDAR_DT = mta.ORDER_DT
WHERE mta.BRAND_CD = 'UO'
  AND ch.CURRENT_YEAR_ID = 0
  AND mta.IID <> '-1'
GROUP BY 1, 2, 3
ORDER BY 1, 2;
```

## Legacy → RBX migration status (as of April 30, 2026 — Phase 1 Data Enrichment delivered)

**Operational launch target: October 2026** = the date when RBX MTA is ready to run in parallel with legacy reporting, fully validated, code-translated, and waiting. The actual cutover decision comes later, once YoY comparisons can be made with confidence.

**What Phase 1 delivered:** Three sandbox objects to begin code translation against. **All names will change** when these productionalize before October — your reporting code will need to be updated at that point. EDW will communicate final production names ahead of launch.

### The three RBX sandbox objects (use `RO_ROLE_PROD` — no role request needed)

| # | Object | Purpose | Status |
|---|---|---|---|
| 1 | `EDW_SANDBOX_PROD.URBN.RBX_MTA_TOTAL_POINTS_ATTRIBUTED_V4_RJ` | **The points table** — line-level attribution data | ✅ All campaign-optimization dimensions added. Product-category enrichment columns still in validation |
| 2 | `EDW_SANDBOX_PROD.URBN.RBX_MTA_ORDER_LKUP_V1_RJ` | **The order lookup** — NAR segments + customer metrics | 🔄 Base join delivered. NAR (`BRAND_NAR_D`), NAR-by-Direct/Retail, fractional customer counts, time-aggregated metrics (week/month/YTD) **still in validation** |
| 3 | `EDW_SANDBOX_PROD.URBN.RBX_MTA_TOTAL_POINTS_ATTRIBUTED_V_RJ` | **The joined view — what brand reporting code runs against** | 🔄 Skeleton view live, sufficient to begin code translation. Lookup columns (NAR, fractional customer, time-agg) added as they clear QA |

> **Start with the view (#3), not the points table.** It joins #1 and #2 into the structure brand reports currently use against legacy. Run your existing campaign optimization reporting logic against it and identify what maps cleanly vs. what needs to be rewritten.

**Coverage:**
- AN, FP, TR, AN_EU, FP_UK: from **September 1, 2025** to current date – 2
- UO, UO_EU: from **September 24, 2025** to current date – 2

### What's blocked / what to wait on

- **Full attribution deep dives:** V4 reflects the **RBX default model, not the URBN Tuned Model**. Deeper QA and deep-dives should wait until tuning is in place across brands.
- **NAR-dependent queries on RBX:** customer segment cuts blocked until lookup table validation completes.
- **End-to-end report parity:** the view is a skeleton — it doesn't yet have NAR or customer metric columns.
- **MTA Roll-Up (#4) is fully blocked.** The legacy roll-up joins attribution and GA4 session data using a shared UTM-based channel taxonomy. **That shared taxonomy doesn't exist in RBX** — RBX doesn't carry the same UTM Google tracks. Session-side columns (`SESSION_ID`, `ORDERS_SS`, `DEMAND_R_SS`, `DEMAND_U_SS`, `ONE_PAGE_SESSIONS_SS`, country, Site ID, Device type) **are not available at the grain the rollup requires.** Only NA/EU + date + tier-level splits are available right now. A dedicated brand alignment session will happen before this moves forward. **No brand action needed on the rollup yet.**

### Schema changes from legacy → V4 — what breaks reporting code

**Replaced columns (UTM → RBX channel taxonomy):**

| Legacy field (GA4 UTM) | V4 RBX field |
|---|---|
| `MEDIUM`, `SOURCE`, `CAMPAIGN`, `KEYWORD`, `CONTENT` | `RBX_TIER_1`, `RBX_TIER_2`, `RBX_TIER_3`, `RBX_TIER_4`, `RBX_TIER_5` |
| `MARKETING_CHANNEL` (parent rollup) | `RBX_PARENT_CHANNEL` |
| `MARKETING_CHANNEL` (mid-level) | `RBX_MARKETING_CHANNEL` |
| `SUBMARKETING_CHANNEL` | `RBX_SUBMARKETING_CHANNEL` |
| (no equivalent) | `RBX_AD_PLATFORM` (new) |

> **Note on naming:** the Confluence guide referenced earlier brand-mapped fields as `BRAND_PARENT_MARKETING_CHANNEL`, `BRAND_MARKETING_CHANNEL`, `BRAND_SUBMARKETING_CHANNEL`. The actual columns delivered in V4 are prefixed `RBX_` (not `BRAND_`). Use the `RBX_` prefix when querying V4. The column reference Google Sheet (`TOTAL_POINTS_ATTR_MTA_RBX`, Drive ID `1DKsu94PoGK5XVuKWj6CYOTmBxPoDnwUy`) is authoritative for the actual V4 column list.

**Removed columns (no RBX equivalent):**

- `NET_AMT`, `NET_QTY`
- All Gross / Return / Cancel attributed columns (e.g. `ATTRIBUTED_GROSS_AMT`, `ATTRIBUTED_RETURN_AMT`, `ATTRIBUTED_CANCEL_AMT/QTY`)
- `POINTS_DEV`, `POINTS_GROUP`, `TOTAL_ITEM_POINTS`

Code referencing any of these will fail. There is no replacement — these concepts don't exist in the RBX model.

### QA results EDW completed (Oct 2025 – Apr 2026 vs. legacy PROD)

- **Overall match rate:** 96% of orders are an exact match. 2% mismatch, 1.84% PROD-only, 0.10% RBX-only. Gap is primarily September (UO data starts late Sep).
- **By brand:** AN, FP, TR, AN_EU, UO_EU all within **±0.25%** on attributed demand. UO aligned from Oct 2025 onward (after the Sep gap).
- **By device type:** Desktop, Mobile, iOS App, Call Center, MPOS all within **±0.2%**. No concerns.
- **Order count differences:** Oct 2025–Apr 2026 minimal (<10K per month out of millions).
- **Customer counts:** very close, with slight RBX-side increases in recent months.

> These QA numbers used **default lookback windows** that brands haven't aligned on. Variance may shift once windows are set per brand.

### What you (the analyst) should do now

| Object | Action | AN team owner (per Maya's 5/5 forward) |
|---|---|---|
| Points table (V4) | Familiarize with new schema. Confirm tier mapping looks right. **Defer deep QA until URBN Tuned Model lands** | Caity (lead), Paul (support) |
| Order Lookup (V1) | No action yet — wait for NAR validation to complete | Erica's team to support when ready |
| **Joined View** | **Start code translation here.** Run existing campaign optimization reporting logic against it. Note what breaks, what doesn't map cleanly | **Paul (lead), Nicole (support)** |
| Roll-Up | No action | — |

Flag findings and gaps to EDW via a Jira ticket. Feedback shapes Phase 2 scope.

### What the Roll-Up problem actually means for reporting

The legacy `MTA_TOTAL_POINTS_ROLLUP_V` is what most brand weekly dashboards run against — it merges attribution + GA4 sessions using the shared UTM channel taxonomy. The conceptual issue: RBX collects touchpoints via its own pixel, not GA4 events. The two systems don't share UTM taxonomy. So you can't simply rebuild the rollup with the same shape against RBX — it requires a different join structure and probably a different set of session metrics.

**Practical implication:** Until a Phase 2 RBX rollup design exists, weekly dashboard code that joins attribution to sessions is the part that won't translate cleanly. Code that operates only on attributed demand (what the V_RJ view supports today) will translate first.

## Don't forget — legacy is still primary

Until October 2026 operational launch, **all production reporting continues to run on legacy MTA**:
- `EDW_PROD.ADVA.MTA_TOTAL_POINTS_ATTRIBUTED_V`
- `EDW_PROD.ADVA.MTA_TOTAL_POINTS_ROLLUP_V`

The V4 sandbox objects are for code translation work, not for replacing reporting.

## Refresh

| Table | Refresh |
|---|---|
| `MTA_TOTAL_POINTS_ATTRIBUTED_V` / `MTA_TOTAL_POINTS_ROLLUP_V` (legacy production) | Nightly — depends on CDI completing first |
| `RBX_{BRAND}_LOG_LVL_PRCHS` | Incremental daily, 14-day lookback |
| `RBX_{BRAND}_AGGREGATE_MTA` | Daily |
| `RBX_MTA_TOTAL_POINTS_ATTRIBUTED_V4_RJ` (sandbox points table) | Daily |
| `RBX_MTA_ORDER_LKUP_V1_RJ` (sandbox lookup) | Daily |
| `RBX_MTA_TOTAL_POINTS_ATTRIBUTED_V_RJ` (sandbox joined view) | Daily |
| `FT_IMPRESSIONS` | Daily |
| `THE_TRADE_DESK.REDS.IMPRESSIONS` | T-1 per TTD share schedule |

> **MTA depends on CDI.** When CDI is paused for monthly maintenance, MTA does not refresh. If MTA looks flat in the morning, check `#marketingsystems_cloud_qa` before investigating.

## Common gotchas

| Gotcha | Fix |
|---|---|
| Aggregating MTA without `IID <> '-1'` filter | Always filter — unmatched orders inflate counts |
| Querying `DW_RFM_HISTORY` on `IID` | Column is `CLOUD_IID`, not `IID` |
| Comparing RBX `EVENT_WEIGHT` to legacy `POINTS` directly | Different scales. Compare attributed revenue, not weights |
| Using legacy `MARKETING_CHANNEL` / `BRAND_PARENT_MARKETING_CHANNEL` against V4 RBX tables | Field doesn't exist on V4. **Use `RBX_PARENT_CHANNEL` / `RBX_MARKETING_CHANNEL` / `RBX_SUBMARKETING_CHANNEL` on V4**, or build from `RBX_TIER_1`–`RBX_TIER_5` |
| Reading RBX `Direct` as legacy "Unattributed" | RBX Direct includes both true direct AND unattributed. **Filter `MARKETING_TYPE = 'conv_only'` to isolate** |
| Querying V4 expecting `NET_AMT`, `POINTS_DEV`, `POINTS_GROUP`, `TOTAL_ITEM_POINTS`, or any `Gross/Return/Cancel` attributed columns | None of these exist in V4. Removed by design — no RBX equivalent. Code referencing them will fail |
| Looking for NAR / fractional customer columns on V4 right now | The order lookup table (`RBX_MTA_ORDER_LKUP_V1_RJ`) is still in validation. NAR not yet in the joined view |
| Trying to rebuild the legacy rollup against RBX | Rollup is fully blocked. RBX doesn't share GA4's UTM taxonomy, so attribution-to-session join can't be reconstructed at the same grain. Only NA/EU + date + tier splits available currently |
| Building production reports on V4 sandbox names | All sandbox names will change before October 2026 launch |
| Looking for `FT_IMPRESSIONS` in `EDW_PROD` | It's in `EDW_ODS_PROD.URBN` — fully qualify |
| Forgetting MTA runs after CDI | MTA T-2 on days CDI lags. Check `#marketingsystems_cloud_qa` |

## Output expectations for MTA deliverables

When citing MTA in any deliverable:

- Specify which model: legacy in-house (production) vs. RBX V4 default (sandbox) vs. URBN Tuned (forthcoming)
- Specify the window: Same-Session (default) vs. 14-Day Last Click
- For RBX: which of the four models (Normalized MTA / First / Last / Even)
- For RBX V4 work specifically:
  - Note the data start date — Sept 1 2025 for AN/FP/TR/AN_EU/FP_UK; **Sept 24 2025 for UO/UO_EU**
  - State that V4 reflects the **RBX default model, not the URBN Tuned Model** — deep-dive conclusions should wait for tuning
  - Note that the tables are sandbox paths and **names will change** before the October 2026 operational launch
- For EU brand reporting: state currency (GBP for AN_EU, UO_EU, FP_UK)
- If using Direct/Unattributed split: explicitly note the `MARKETING_TYPE = 'conv_only'` filter
