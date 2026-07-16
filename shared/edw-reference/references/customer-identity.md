# Customer Identity, Loyalty, NAR, CLV & RFM

This document covers URBN's customer identity framework (IID/CDI), loyalty programmes, the NAR lifecycle classification, and predictive models (CLV, RFM).

---

## The Golden Rule

**Always `COUNT(DISTINCT IID)` — never count emails, loyalty IDs, or web profile IDs.**

A single customer can have multiple email addresses, multiple loyalty IDs, and multiple web profile IDs. IID is the only deduplicated, cross-brand customer key.

**Always filter `IID <> '-1'`** — orders and records with IID = '-1' could not be matched to any customer. Always exclude these from customer counts and MTA analysis.

---

## The Identifier Hierarchy

| Identifier | What it represents | Granularity | Notes |
|-----------|-------------------|-------------|-------|
| IID | Individual person — primary key across all of EDW | One per individual | Assigned by Merkle via CDI |
| HID | Household — multiple IIDs at same address | One per household | e.g. family members |
| RID | Residence — multiple HIDs can share one RID | One per residence | e.g. apartment building |
| PROFILE_ID | A15 web account | 1:M with IID | Bridge: `DW_IID_WEB_PROFILE_XREF` |
| Contact ID | Salesforce 18-char ID | One per Salesforce registration | Bridge: `DW_SERVICES_PROFILES` → `DW_IID_WEB_PROFILE_XREF` |
| Sterling ID | Legacy OMS customer ID | Shrinking coverage | Not populated for customers acquired after Phase 3 (early 2025) |

### Formulated vs Sustained IIDs

| Type | Prefix | What it means |
|------|--------|--------------|
| Sustained | Starts with `0` | Merkle matched to a real person with name + address. High confidence. Appears when a full order with shipping address is placed. |
| Formulated | Starts with `1` | Email address only — no name/address match. Lower confidence. Appears for email sign-ups with no order history. |

IIDs can transition: Formulated → Sustained when an email-only customer places their first full order. `DW_LINK_ORDER_KEYS_IID` tracks IID changes over time (Type 2 history).

### IID is Now Directly on `DW_BLND_ORDER_HEADER` (as of March 2026)
RFC-5127 added `IID`, `TXN_MATCH_DT`, `TXN_MATCH_KEY`, and `TXN_LINK_TYPE` as columns on `DW_BLND_ORDER_HEADER`. You no longer need to join to `DW_LINK_ORDER_KEYS` to get IID on an order.

---

## Core Customer Tables

| Table | Contents | Key Notes |
|-------|----------|-----------|
| `EDW_PROD.URBN.DW_CDI_CUSTOMER` | ~99.7M rows. Core customer record — name, address, city, state, country, Merkle demographics. 68 columns. | PII fields masked under `RO_ROLE_PROD`. Join on `IID`. Primary source for customer attributes. |
| `EDW_PROD.URBN.DW_CDI_EMAIL` | ~134.9M rows. All email addresses per IID by brand. | 1:M — one IID can have many email rows. Use `DW_IID_EMAIL_XREF` for a simpler IID↔email bridge. |
| `EDW_PROD.URBN.DW_CDI_IDV` | ~129.1M rows. Individual Derived Values — store proximity, buyer/non-buyer flags by IID and brand. | Contains `BUYER_NON_BUYER_FLG`, `STORE_OF_RESIDENCE`, `STORE_OF_RESIDENCE_DISTANCE`. Distance calcs limited to US. |
| `EDW_PROD.URBN.DW_CDI_PREF` | Customer suppression/opt-out requests (~425K rows). | **Not for email opt-in analysis** — this tracks opt-outs. For email opt-in status use `Q_QL_ELS_V`. |
| `EDW_PROD.URBN.DW_IID_WEB_PROFILE_XREF` | Cross-reference IID ↔ PROFILE_ID (A15 web account). | 1:M — one IID can map to many PROFILE_IDs. |
| `EDW_PROD.URBN.DW_IID_EMAIL_XREF` | Cross-reference IID ↔ email address. | Use when joining email-keyed data to IID without going through `DW_CDI_EMAIL`. |
| `EDW_PROD.URBN.DW_SERVICES_PROFILES` | A15 customer profiles. Contains `PROFILE_ID`, `CONTACT_ID`, `STERLING_ID`. | Bridge to Salesforce Contact ID. Note: `STERLING_ID` not populated for customers after Phase 3 (early 2025). |
| `EDW_PROD.URBN.DW_SERVICES_SUBSCRIPTIONS` | A15 loyalty feed — digital channel only. | **Excludes POS sign-ups entirely.** Use `Q_QL_CDI_LOYALTY_V` for enterprise-wide totals. |
| `EDW_PROD.URBN.Q_QL_ELS_V` | Email List Subscription — email opt-in status by brand. | Filter: `PREF_FLG = 'Y' AND MOST_RECENT_FLG = 'Y'` for current active subscribers. |

### Bridge Contact ID → IID
```sql
SELECT
    P.CONTACT_ID,
    P.PROFILE_ID,
    X.IID,
    P.BRAND_CD
FROM EDW_PROD.URBN.DW_SERVICES_PROFILES P
JOIN EDW_PROD.URBN.DW_IID_WEB_PROFILE_XREF X
    ON X.PROFILE_ID = P.PROFILE_ID
    AND X.BRAND_CD = P.BRAND_CD
WHERE P.BRAND_CD = 'AN'
  AND P.CONTACT_ID IS NOT NULL;
```

### Active Email Subscribers (AN)
```sql
SELECT IID, EMAIL_ADDRESS, BRAND_CD
FROM EDW_PROD.URBN.Q_QL_ELS_V
WHERE BRAND_CD = 'AN'
  AND PREF_FLG = 'Y'
  AND MOST_RECENT_FLG = 'Y';
```

---

## Loyalty Data

URBN operates loyalty programmes for Anthropologie (Anthro Perks), Urban Outfitters (UO Rewards), and Free People (FP Loyalty).

**UO Rewards was redesigned in FY26** — SessionM removed, tier/points system eliminated, replaced with frequency-based rewards. Do not use any tier or points columns for current UO analysis.

### `EDW_PROD.URBN.Q_QL_CDI_LOYALTY_V` — Primary Loyalty View
**The default for all loyalty analysis.** Covers all channels (web, app, POS).

Key columns:

| Column | Description |
|--------|-------------|
| `IID` | Customer key — join to CDI tables |
| `LOYALTY_ID` | Programme member ID |
| `BRAND_CD` | Brand (`'AN'`, `'UO'`, `'FP'`, `'UO_EU'`, `'AN_EU'`, etc.) |
| `ENROLLMENT_DT` | Timestamp enrolled |
| `EMAIL` | Email at time of enrolment |
| `SIGNUP_STORE` | Store number for POS sign-ups |
| `SIGNUP_CHANNEL` | See channel values below |
| `PRIMARY_LOYALTY_ID_FLG` | `'Y'` = customer's primary record. **Always filter `= 'Y'` when counting unique enrollees** |
| `EXTN_SIGN_UP_CHANNEL_ID` | Extended source channel |

**Signup channel values:**

| Value | Meaning |
|-------|---------|
| `POS`, `MPOS` | In-store retail |
| `WEB` | Web browser |
| `APP_IOS` | iOS app |
| `ANDROID_APP` | Android app |
| `MOBILE` | Legacy — an older sign-up flow, NOT current app traffic |

**Refresh timing**: Nightly CDI run (~10:00–10:30 AM EST). IID-linked records have T-2 lag by design.

### Weekly loyalty sign-ups by channel (AN)
```sql
SELECT
    ch.WEEK_OF_YEAR_NUM AS WEEK_NUM,
    CASE
        WHEN l.SIGNUP_CHANNEL IN ('POS', 'MPOS') THEN 'RETAIL'
        WHEN l.SIGNUP_CHANNEL IN ('WEB')           THEN 'WEB'
        WHEN l.SIGNUP_CHANNEL IN ('APP_IOS', 'ANDROID_APP') THEN 'APP'
        ELSE l.SIGNUP_CHANNEL
    END AS channel_group,
    COUNT(DISTINCT CASE WHEN ch.CURRENT_YEAR_ID = 0  THEN l.IID END) AS signups_ty,
    COUNT(DISTINCT CASE WHEN ch.CURRENT_YEAR_ID = -1 THEN l.IID END) AS signups_ly
FROM EDW_PROD.URBN.Q_QL_CDI_LOYALTY_V l
JOIN EDW_PROD.URBN.DW_CALENDAR_HIERARCHY ch
    ON ch.CALENDAR_DT = DATE(l.ENROLLMENT_DT)
WHERE ch.CURRENT_YEAR_ID IN (-1, 0)
  AND l.BRAND_CD = 'AN'
  AND l.PRIMARY_LOYALTY_ID_FLG = 'Y'
GROUP BY 1, 2
ORDER BY 1;
```

### Loyalty Data Gotchas

| Gotcha | Fix |
|--------|-----|
| Using `DW_SERVICES_SUBSCRIPTIONS` for total counts | Under-counts — excludes POS. Use `Q_QL_CDI_LOYALTY_V` |
| Forgetting `PRIMARY_LOYALTY_ID_FLG = 'Y'` | Double-counts enrollees |
| Looking for `LOYALTY_TIER` on `Q_QL_CDI_LOYALTY_V` | Column doesn't exist — UO's tier system was removed in FY26 |
| Using `SIGNUP_CHANNEL = 'MOBILE'` as current app | Legacy value — app is `APP_IOS` or `ANDROID_APP` |
| Aug–Oct 2025 data gap | POS loyalty data may be understated for this window (Salesforce migration rollout) |

### CDI Maintenance Windows
CDI runs on a monthly cadence for NCOA/Rekey — typically ~1 business day. During this window MTA, NAR, and loyalty refreshes are suspended. Hari posts @here notices in #marketingsystems_cloud_qa.

---

## NAR (New / Active / Reactivated)

NAR classifies every customer purchase into a lifecycle status at the brand level.

| Status | Definition | Column value |
|--------|-----------|-------------|
| New | First-ever matched purchase at this brand | `'1. NEW'` |
| Active | Purchased at this brand within last 365 days | `'2. ACTIVE'` |
| Reactivated | Had purchased before, lapsed 365+ days, now purchasing again | `'3. REACTIVATED'` |

Values are always prefixed with sort order to ensure consistent ordering.

**NAR fields on `MTA_TOTAL_POINTS_ATTRIBUTED_V`:**

| Field | Grain |
|-------|-------|
| `NAR_BRAND_D` | Brand-level NAR by day (omni-channel) |
| `NAR_BRAND_RETAIL_D` | Retail channel NAR by day |
| `NAR_BRAND_CHANNEL_D` | Channel-specific NAR by day |
| `NAR_BRAND_M` | Brand-level NAR by month |

Use `SUM(DAY_FRACTIONAL_CUSTOMER_BRAND)` (not `COUNT(DISTINCT IID)`) when counting NAR customers within MTA.

For historical NAR analysis outside MTA context: `EDW_PROD.URBN.DW_NAR_ORDER_HEADER`

---

## CLV (Customer Lifetime Value)

A predictive model per customer per brand. **Not historical revenue — a forward-looking forecast.**  
Refreshed weekly on Mondays.  
Owner: Valerie Amoroso (Data Science).

Two sub-models per brand:
- **P(Alive)** (classification): Predicts likelihood of net purchase in next 12 months. Output: `P_ALIVE` (0–1), `P_ALIVE_LABEL` (Low/Mid/High). ~78% average accuracy.
- **Spend** (regression): For predicted-to-return customers, forecasts spend percentile rank. Output: `PREDICTED_SPEND_RANK`, `PREDICTED_SPEND` (one of 20 dollar buckets), `PREDICTED_SPEND_LABEL` (Low/Mid/High).

### CLV Tables

| Table | Use For |
|-------|---------|
| `EDW_PROD.ADVA.AA_CLV_FINAL_PREDICTIONS` | Full history — one row per IID per brand per weekly run. ~37M rows, 16 columns. |
| `EDW_PROD.ADVA.AA_CLV_FINAL_PREDICTIONS_MAX_ANCHOR_DT` | **Use this for current-state queries.** Most recent snapshot only — avoids per-run duplication. |
| `EDW_PROD.ADVA.DW_RFM_HISTORY` | Historical RFM snapshots by brand. Join key is `CLOUD_IID` (not `IID`). |
| `EDW_PROD.URBN.AA_CLV_RFM` | CLV + RFM keyed on `EMAIL_ADDRESS + BRAND_CD` — for Salesforce Marketing Cloud export only. Not the primary analytical source. |

**Always use `_MAX_ANCHOR_DT`** — querying `AA_CLV_FINAL_PREDICTIONS` directly without filtering `ANCHOR_DATE` returns one row per customer per weekly run.

### Join CLV to email list (AN)
```sql
SELECT
    clv.IID,
    clv.BRAND_CD,
    clv.P_ALIVE_LABEL,
    clv.PREDICTED_SPEND,
    clv.PREDICTED_SPEND_LABEL,
    e.EMAIL_ADDRESS
FROM EDW_PROD.ADVA.AA_CLV_FINAL_PREDICTIONS_MAX_ANCHOR_DT clv
JOIN EDW_PROD.URBN.DW_CDI_EMAIL e
    ON clv.IID = e.IID
    AND clv.BRAND_CD = e.BRAND_CD
WHERE clv.BRAND_CD = 'AN'
  AND e.BRAND_CD = 'AN';
```

---

## RFM (Recency, Frequency, Monetary)

RFM describes current engagement based on purchase behaviour over the past 12 months. Unlike CLV (forward-looking), RFM describes current state.  
Refreshed weekly on Mondays.

| Dimension | Score (1–5) | Meaning |
|-----------|------------|---------|
| Recency (R) | 5 = most recent | Days since last purchase — scale reversed (lower days = higher score) |
| Frequency (F) | 5 = most frequent | Total number of purchases |
| Monetary (M) | 5 = highest spender | Total net spend |

Key RFM segment labels (from CLV predictions table):

| Label | R | F | Meaning |
|-------|---|---|---------|
| Champions | 5 | 4–5 | Bought recently, buy often |
| Loyal Customers | 3–4 | 4–5 | Frequent, good spend |
| At Risk | 1–2 | 3–4 | High historical frequency, long lapsed |
| Can't Lose Them | 1–2 | 5 | Top spenders, not seen recently |
| Lapsed | — | — | Purchased within 3 years but not in last 12 months |

### RFM Tables

| Table | Contents |
|-------|----------|
| `EDW_PROD.ADVA.AA_CLV_FINAL_PREDICTIONS` | Most recent RFM snapshot combined with CLV: `RFM_LABEL`, `RFM_RECENCY`, `RFM_FREQUENCY`, `RFM_MONETARY`, `RFM_SCORE`. Updated weekly Mondays. |
| `EDW_PROD.ADVA.DW_RFM_HISTORY` | Historical RFM snapshots. **Key column is `CLOUD_IID` (not `IID`)** — always use `CLOUD_IID` when joining this table. |

### Join RFM history to email list
```sql
SELECT
    rfm.CLOUD_IID AS IID,
    rfm.BRAND_CD,
    rfm.RFM_LABEL,
    rfm.ANCHOR_DATE,
    cdi.EMAIL_ADDRESS
FROM EDW_PROD.ADVA.DW_RFM_HISTORY rfm
JOIN EDW_PROD.URBN.DW_CDI_EMAIL cdi
    ON rfm.CLOUD_IID = cdi.IID
    AND rfm.BRAND_CD = cdi.BRAND_CD
WHERE rfm.BRAND_CD = 'AN'
  AND rfm.ANCHOR_DATE = (
      SELECT MAX(ANCHOR_DATE)
      FROM EDW_PROD.ADVA.DW_RFM_HISTORY
      WHERE BRAND_CD = 'AN'
  );
```

---

## Data Quality Notes

- **Salesforce Migration (Aug–Oct 2025)**: New customer counts and POS loyalty sign-up data from this window may be understated. Treat WoW/YoY comparisons involving new POS customers or loyalty sign-ups from Aug 20 – ~Oct 2025 with caution.
- **Privacy masking**: PII fields (name, address, email) are masked under `RO_ROLE_PROD`. Request `PII_ROLE_PROD` via Jira or #edw-support-snowflake if genuinely needed.
- **Demographic data retention**: Merkle demo append data for older inactive customers purged at year-end. Age/income history kept for up to 3 full fiscal years. Treat age, education, occupation as modelled estimates, not self-reported facts.
