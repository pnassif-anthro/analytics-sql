# Loyalty, CLV, and RFM

## Loyalty programmes — current state (FY27)

| Brand | Programme | Structure |
|---|---|---|
| Urban Outfitters (US/EU) | UO Rewards | **Frequency-based.** Tiers + points removed FY26. US: $5 reward after spend threshold. UK/EU: £5 after purchase frequency threshold. SessionM fully removed. |
| Anthropologie (US/EU) | Anthro Perks | Active. No recent redesign. |
| Free People (US/UK) | FP Loyalty | Active. |

> **⚠️ SessionM is gone for UO.** Tables `DW_USER_POINTS_ACCOUNTS`, `DW_TIER_MEMBERS`, `DW_POINTS_ACCOUNTS` still exist but contain historical data only. **Do not use points or tier fields for current programme analysis.** `SFME_LOYALTY_UO.CURRENT_TIER` reflects stale SessionM-era data — do not use.

## Two sources of truth — which to use

| Table | Source | Includes POS | Has IID | Use when |
|---|---|---|---|---|
| `EDW_PROD.URBN.Q_QL_CDI_LOYALTY_V` | CDI / Merkle | ✅ Yes | ✅ Yes (T-2 lag) | **Default.** Enterprise-wide reporting, enrolment trends, anything needing IID |
| `EDW_PROD.URBN.DW_SERVICES_SUBSCRIPTIONS` | A15 | ❌ No | ❌ Not directly | Same-day digital signup counts (~6:45 AM EST refresh). **Excludes POS — under-counts** |

**`DW_SERVICES_SUBSCRIPTIONS` excludes POS sign-ups entirely.** Default to `Q_QL_CDI_LOYALTY_V` for enterprise totals.

## `Q_QL_CDI_LOYALTY_V` — the columns to know

| Column | What it is |
|---|---|
| `IID` | Customer identifier — join to customer tables |
| `LOYALTY_ID` | Programme member ID |
| `BRAND_CD` | UO, AN, FP, UO_EU, AN_EU, etc. |
| `CUSTOMER_ID` | Legacy customer ID |
| `ENROLLMENT_DT` | When the customer enrolled |
| `EMAIL` | Email at time of enrolment |
| `SIGNUP_STORE` | Store number for POS signups |
| `SIGNUP_CHANNEL` | Channel — see gotchas below |
| `PRIMARY_LOYALTY_ID_FLG` | `Y` if customer's primary record for the brand. **Filter `= 'Y'` when counting unique enrollees** |
| `EXTN_SIGN_UP_CHANNEL_ID` | Extended source channel |

> **There is no `LOYALTY_TIER` column on `Q_QL_CDI_LOYALTY_V`.** UO tiers were removed FY26. Don't reach for it.

## `SIGNUP_CHANNEL` values — common gotcha

| Value | What it is |
|---|---|
| `WEB` | Web browser |
| `APP_IOS` | iOS app |
| `ANDROID_APP` | Android app |
| `POS` / `MPOS` | In-store |
| `MOBILE` | **Legacy value** for an older sign-up flow — does NOT mean current app traffic |

When grouping for reporting, normalize:

```sql
CASE
    WHEN SIGNUP_CHANNEL IN ('POS','MPOS')            THEN 'RETAIL'
    WHEN SIGNUP_CHANNEL IN ('WEB')                   THEN 'WEB'
    WHEN SIGNUP_CHANNEL IN ('APP_IOS','ANDROID_APP') THEN 'APP'
    ELSE SIGNUP_CHANNEL
END AS channel_group
```

## Example — weekly loyalty signups by channel

```sql
USE ROLE RO_ROLE_PROD;
USE WAREHOUSE RO_WH_PROD;
USE DATABASE EDW_PROD;
USE SCHEMA URBN;

SELECT
    ch.WEEK_OF_YEAR_NUM,
    CASE
        WHEN l.SIGNUP_CHANNEL IN ('POS','MPOS')            THEN 'RETAIL'
        WHEN l.SIGNUP_CHANNEL IN ('WEB')                   THEN 'WEB'
        WHEN l.SIGNUP_CHANNEL IN ('APP_IOS','ANDROID_APP') THEN 'APP'
        ELSE l.SIGNUP_CHANNEL
    END AS channel_group,
    COUNT(DISTINCT l.IID) AS signups
FROM EDW_PROD.URBN.Q_QL_CDI_LOYALTY_V l
JOIN EDW_PROD.URBN.DW_CALENDAR_HIERARCHY ch
    ON ch.CALENDAR_DT = DATE(l.ENROLLMENT_DT)
WHERE ch.CURRENT_YEAR_ID IN (0, -1)
  AND l.BRAND_CD = 'AN'
  AND l.PRIMARY_LOYALTY_ID_FLG = 'Y'
GROUP BY 1, 2
ORDER BY 1, 2;
```

## `LOYALTY_DATE` parsing quirk

The `LOYALTY_DATE` field on `DW_SERVICES_SUBSCRIPTIONS` has inconsistent formatting:

```sql
SELECT *,
    CASE
        WHEN trim(LOYALTY_DATE) LIKE '%.%'
            THEN try_to_timestamp(
                    CAST(substr(trim(LOYALTY_DATE), 1,
                         position('.', trim(LOYALTY_DATE), 1) - 1) AS STRING))
        ELSE try_to_timestamp(CAST(LOYALTY_DATE AS STRING))
    END AS LOYALTY_TS
FROM EDW_PROD.URBN.DW_SERVICES_SUBSCRIPTIONS
```

## Refresh timing

- `Q_QL_CDI_LOYALTY_V` — refreshes via nightly CDI (~10:00–10:30 AM EST). T-2 lag for IID-linked records by design.
- `DW_SERVICES_SUBSCRIPTIONS` — once daily from A15 ~6:45–7 AM EST. Same-day, but digital-only.
- EU enrolments may not be fully available until the following morning.

---

## Customer Lifetime Value (CLV)

CLV at URBN is a **predictive model** — forecasts likelihood of returning and likely spend over the **next 12 months**. **Not historical revenue.** Refreshed weekly on Mondays.

### How it works

Two sub-models per brand:

- **P(Alive) classification** — predicts whether customer will make a net purchase in next 12 months, given at least one brand purchase in past 3 years. Output: `p_alive` (0–1) and `p_alive_label` (Low/Mid/High). ~78% accuracy avg.
- **Spend regression** — for predicted-alive customers, forecasts percentile rank by expected spend. Output: `predicted_spend_rank` (0–1), `predicted_spend` (one of 20 dollar buckets), `predicted_spend_label` (Low/Mid/High).

The two combine into 9 distinct customer segments.

### CLV tables

| Table | Contents |
|---|---|
| `EDW_PROD.ADVA.AA_CLV_FINAL_PREDICTIONS` | All weekly snapshots — one row per IID per brand **per weekly run**. |
| `EDW_PROD.ADVA.AA_CLV_FINAL_PREDICTIONS_MAX_ANCHOR_DT` | **Most recent snapshot only — use this for current state.** |
| `EDW_PROD.URBN.AA_CLV_RFM` | CLV + RFM keyed on email — for SFMC export only. Exported Mondays ~12:30 PM |

> **Always use `_MAX_ANCHOR_DT`** unless doing historical model comparison. Querying `AA_CLV_FINAL_PREDICTIONS` directly without `ANCHOR_DATE` filter returns one row per customer per weekly run — duplicates everywhere.

### When citing CLV in deliverables

State explicitly: *"CLV is a forward-looking 12-month prediction (anchor date YYYY-MM-DD), not realised revenue. Source: `AA_CLV_FINAL_PREDICTIONS_MAX_ANCHOR_DT`."* Do not present projected CLV as if it were realised.

---

## RFM Segmentation

RFM classifies customers based on past 12 months of purchase behaviour. Backward-looking — describes current engagement state. (Contrast with CLV which is forward-looking.)

### Scoring (per brand, recalculated weekly)

- **Recency (R, 1–5)** — days since last purchase. Score 5 = most recent. Scale is reversed.
- **Frequency (F, 1–5)** — number of purchases. Score 5 = most frequent.
- **Monetary (M, 1–5)** — total net spend. Score 5 = highest.

Quantile breakpoints differ by brand.

### Labels

| Label | R | F | Meaning |
|---|---|---|---|
| Champions | 5 | 4–5 | Recent, frequent, top spend |
| Loyal Customers | 3–4 | 4–5 | Frequent, good spend |
| Potential Loyalists | 4–5 | 2–3 | Recent, multiple buys |
| New Customers | 5 | 1 | Most recent first-timer |
| Promising | 4 | 1 | Recent first-timer |
| Need Attention | 3 | 3 | Above average, no recent purchase |
| About to Sleep | 3 | 1–2 | Below avg recency and frequency |
| At Risk | 1–2 | 3–4 | High historical frequency, lapsed |
| Can't Lose Them | 1–2 | 5 | Top historical spenders, lapsed |
| Hibernating | 1–2 | 1–2 | Long ago, low value |
| Lapsed | — | — | In last 3 yrs but not last 12 mo |
| Demand Lapsed | — | — | Ordered last 12 mo but returned everything (net = 0) |

### RFM tables

| Table | Contents |
|---|---|
| `EDW_PROD.ADVA.AA_CLV_FINAL_PREDICTIONS` | RFM combined with CLV: `RFM_LABEL`, `RFM_RECENCY`, `RFM_FREQUENCY`, `RFM_MONETARY`, `RFM_SCORE`. Updated weekly Mondays |
| `EDW_PROD.ADVA.DW_RFM_HISTORY` | Historical snapshots — for trend analysis. **Key column is `CLOUD_IID`, not `IID`** |
| `EDW_PROD.URBN.AA_CLV_RFM` | CLV + RFM keyed on email — Salesforce export, not primary analytical source |

> **`DW_RFM_HISTORY` joins on `CLOUD_IID`, not `IID`.** This trips up everyone the first time.
