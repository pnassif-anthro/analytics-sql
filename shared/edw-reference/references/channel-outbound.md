# Channel Outbound Tables (Email, SMS, Push)

This document covers URBN's outbound marketing channel data — email, SMS, and mobile push — including table schemas, campaign classification logic used for MMM, and known data gaps.

---

## Quick Reference

| Channel | Primary Table | Vendor | Known Issue |
|---------|--------------|--------|-------------|
| Email | `EDW_PROD.URBN.DW_EMAIL_SENT` (+ sibling tables) | Salesforce Marketing Cloud (SFMC) | ~2-day delay; filter `Q_DT_IT` not `LOAD_DATE` |
| SMS | `EDW_PROD.URBN.DW_SMS_ACTIVITY` | Attentive | **STALE as of Jan 31 2026** — pipeline migration in progress |
| Push | `EDW_PROD.URBN.DW_PUSH_MOBILE` | SFMC MobilePush | Filter `STATUS != 'FAIL'`; use `DATETIME_SEND` |
| Triggered email (click data) | Bluecore UI only as of early FY27 | Bluecore → SFMC | Bluecore click tracking not flowing into EDW |

**SMS data gap**: `DW_SMS_ACTIVITY` stopped updating Jan 31 2026 due to a pipeline migration. Until resolved, do not use for current-period analysis. Post in #marketingsystems_cloud_qa for the current recommended approach.

---

## Email Tables

All email tables live in `EDW_PROD.URBN`. All event tables join to `DW_EMAIL_SEND_JOBS` on `CLIENT_ID + SEND_ID`.

### `DW_EMAIL_SEND_JOBS`
**Grain**: One row per email campaign send (`SEND_ID`)  
**Use for**: Campaign metadata — parent table for all email event joins

Key columns: `SEND_ID`, `CLIENT_ID`, `EMAIL_NAME`, `SUBJECT`, `BRAND_CD`, `SENT_TIME`, `Q_DT_ID` (send date — use this), `TRIGGERED_SEND_EXTERNAL_KEY`

**Filter broadcast vs triggered sends:**
```sql
-- Broadcast only (exclude triggered)
WHERE (TRIGGERED_SEND_EXTERNAL_KEY IS NULL OR TRIGGERED_SEND_EXTERNAL_KEY = '')
```

### `DW_EMAIL_SENT`
**Grain**: One row per email address per send  
**Use for**: Deliverability / unique send counts

Key columns: `SEND_ID`, `CLIENT_ID`, `EMAIL`, `LIST_ID`, `BATCH_ID`, `BRAND_CD`, `event_date`

**Correct deduplication for send counting:**
```sql
COUNT(DISTINCT ES.CLIENT_ID || '.' || ES.SEND_ID || '.' || ES.EMAIL || '.' || ES.LIST_ID || '.' || ES.BATCH_ID) AS SENDS
```

### `DW_EMAIL_OPENS`
**Grain**: One row per open event per subscriber per send  
Key columns: `SEND_ID`, `EMAIL`, `IS_UNIQUE`, `BRAND_CD`  
**Note**: Apple Mail Privacy Protection pre-fetches tracking pixels — treat unique open rate as directional. CTOR is a more reliable engagement signal.

### `DW_EMAIL_CLICKS`
**Grain**: One row per click event per subscriber per send per URL  
Key columns: `SEND_ID`, `EMAIL`, `IS_UNIQUE`, `BRAND_CD`  
**Note**: Bluecore click tracking not flowing into EDW as of early FY27 — Bluecore UI only.

### `DW_EMAIL_BOUNCES`
Key columns: `SEND_ID`, `EMAIL`, `BOUNCE_CATEGORY`  
Hard bounces: `WHERE BOUNCE_CATEGORY = 'HardBounce'`

### Standard Email KPI Calculations

```
Total Sends        = COUNT(*) from DW_EMAIL_SENT
Unique Opens       = COUNT(*) from DW_EMAIL_OPENS WHERE IS_UNIQUE = TRUE
Unique Open Rate   = Unique Opens / Total Sends
Unique Clicks      = COUNT(*) from DW_EMAIL_CLICKS WHERE IS_UNIQUE = TRUE
CTR                = Unique Clicks / Total Sends
CTOR               = Unique Clicks / Unique Opens   ← more reliable than open rate (MPP)
Hard Bounces       = COUNT(*) from DW_EMAIL_BOUNCES WHERE BOUNCE_CATEGORY = 'HardBounce'
```

### Sample — Campaign Performance Summary (AN, last 4 weeks)
```sql
USE ROLE RO_ROLE_PROD; USE WAREHOUSE RO_WH_PROD; USE DATABASE EDW_PROD; USE SCHEMA URBN;

SELECT
    sj.SEND_ID,
    sj.EMAIL_NAME,
    sj.SUBJECT,
    sj.SENT_TIME::DATE                                              AS SEND_DATE,
    COUNT(DISTINCT sent.EMAIL)                                      AS TOTAL_SENDS,
    COUNT(DISTINCT CASE WHEN o.IS_UNIQUE THEN o.EMAIL END)         AS UNIQUE_OPENS,
    COUNT(DISTINCT CASE WHEN c.IS_UNIQUE THEN c.EMAIL END)         AS UNIQUE_CLICKS,
    ROUND(COUNT(DISTINCT CASE WHEN o.IS_UNIQUE THEN o.EMAIL END)
        / NULLIF(COUNT(DISTINCT sent.EMAIL), 0) * 100, 2)          AS OPEN_RATE_PCT,
    ROUND(COUNT(DISTINCT CASE WHEN c.IS_UNIQUE THEN c.EMAIL END)
        / NULLIF(COUNT(DISTINCT sent.EMAIL), 0) * 100, 2)          AS CTR_PCT
FROM DW_EMAIL_SEND_JOBS sj
JOIN DW_EMAIL_SENT sent ON sj.SEND_ID = sent.SEND_ID AND sj.CLIENT_ID = sent.CLIENT_ID
LEFT JOIN DW_EMAIL_OPENS o  ON sj.SEND_ID = o.SEND_ID AND sent.EMAIL = o.EMAIL
LEFT JOIN DW_EMAIL_CLICKS c ON sj.SEND_ID = c.SEND_ID AND sent.EMAIL = c.EMAIL
WHERE sj.BRAND_CD = 'AN'
  AND sj.Q_DT_ID >= DATEADD(week, -4, CURRENT_DATE)
  AND (sj.TRIGGERED_SEND_EXTERNAL_KEY IS NULL OR sj.TRIGGERED_SEND_EXTERNAL_KEY = '')
GROUP BY 1, 2, 3, 4
ORDER BY 4 DESC;
```

### Pre-History Gap
`DW_EMAIL_*` tables only contain SFMC data from **June 30, 2021 onward**. Prior email history lived in Cheetah Digital — ask the EDW team if you need pre-2021 data.

---

## SMS Table

### `EDW_PROD.URBN.DW_SMS_ACTIVITY`
**Status**: **STALE as of Jan 31 2026.** Do not use for current-period analysis.  
**Vendor**: Attentive  
**Grain**: One row per message event  

Key columns: `TIMESTAMP`, `BRAND_CD`, `TYPE`, `MESSAGE_NAME`, `MESSAGE_TYPE`

For historical queries (pre-Jan 2026):
```sql
WHERE TYPE LIKE '%MESSAGE_RECEIPT%'
  AND CAST(TIMESTAMP AS DATE) BETWEEN '2023-02-01' AND '2026-01-31'
  AND BRAND_CD = 'AN'
```

---

## Push Table

### `EDW_PROD.URBN.DW_PUSH_MOBILE`
**Vendor**: SFMC MobilePush  
**Grain**: One row per push notification send attempt  

Key columns: `DATETIME_SEND`, `BRAND_CD`, `MESSAGE_NAME`, `STATUS`

Always filter failed sends:
```sql
WHERE UPPER(STATUS) != 'FAIL'
  AND CAST(DATETIME_SEND AS DATE) BETWEEN '...' AND '...'
  AND BRAND_CD = 'AN'
```

---

## Campaign Classification Logic (MMM)

For Marketing Mix Modeling and cross-channel analysis, campaigns are classified into `MODVAR` buckets. The logic below is the authoritative AN classification — apply consistently across channels.

### Email Campaign Classification

```sql
CASE
    -- 1. REMOVE first: internal/test/low-volume
    WHEN UPPER(CAMPAIGN) LIKE '%BANK_ALERT%'
        OR UPPER(CAMPAIGN) LIKE '%_SEED%'
        OR UPPER(CAMPAIGN) = 'TEST'
        OR (UPPER(CAMPAIGN) LIKE '%TEST%' AND SENDS < 10)
        OR (UPPER(CAMPAIGN) LIKE '%PERKSUPDATED%' AND SENDS < 10)
        THEN 'REMOVE'

    -- 2. EMAIL - MKTG: Survey (always MKTG even if trigger-like)
    WHEN UPPER(CAMPAIGN) LIKE '%SURVEY%'
        OR UPPER(CAMPAIGN) LIKE '%CUSTOMERPANEL%'
        THEN 'EMAIL - MKTG'

    -- 3. TRIGGER overrides (before general MKTG patterns)
    WHEN UPPER(CAMPAIGN) LIKE '%NEWTONEXT%'                                        THEN 'EMAIL - TRIGGER'
    WHEN UPPER(CAMPAIGN) LIKE 'CUSTOMERJOURNEY%LAPSED%'                            THEN 'EMAIL - TRIGGER'
    WHEN UPPER(CAMPAIGN) LIKE 'LAPSED%'                                            THEN 'EMAIL - TRIGGER'
    WHEN UPPER(CAMPAIGN) LIKE 'NEWINRECS_UK_V1%'
         AND UPPER(CAMPAIGN) NOT LIKE '%BLADES%'                                   THEN 'EMAIL - TRIGGER'
    WHEN UPPER(CAMPAIGN) LIKE 'ONETIMEBUYER_SURVEY%'                               THEN 'EMAIL - TRIGGER'
    WHEN UPPER(CAMPAIGN) LIKE '%PERKSSIGNUPINCENTIVE%'
         AND NOT REGEXP_LIKE(CAMPAIGN, '^[0-9]{6}_')                               THEN 'EMAIL - TRIGGER'

    -- 4. EMAIL - MKTG: Campaigns with MMDDYY date pattern anywhere in name
    WHEN REGEXP_LIKE(CAMPAIGN, '.*[0-9]{6}.*')
         AND UPPER(CAMPAIGN) NOT LIKE '%24_08_RATE_AND_REVIEW%'                    THEN 'EMAIL - MKTG'

    -- 5. EMAIL - MKTG: Additional non-date patterns
    WHEN UPPER(CAMPAIGN) LIKE '%AN_EMAIL%'
        OR LEFT(UPPER(TRIM(CAMPAIGN)), 3) = 'MON'
        OR (UPPER(CAMPAIGN) LIKE '%PROMO%' AND UPPER(CAMPAIGN) NOT LIKE '%BANK_ALERT%')
        OR UPPER(CAMPAIGN) LIKE '%COUPON%'
        OR UPPER(CAMPAIGN) LIKE '%NOMTO%'
        OR UPPER(CAMPAIGN) LIKE '%NEWMOVER%'
        OR (UPPER(CAMPAIGN) LIKE '%WINBACK%' AND UPPER(CAMPAIGN) NOT LIKE '%RFM%')
        OR UPPER(CAMPAIGN) LIKE '%SIGNUPTOPERKS%'
        OR UPPER(CAMPAIGN) LIKE 'TRENDINGRECS%'
        OR UPPER(CAMPAIGN) LIKE 'BF24%'
        OR UPPER(CAMPAIGN) LIKE 'ANUS_MISC_CCPROMO'
        THEN 'EMAIL - MKTG'

    -- 6. EMAIL - TRIGGER: Behavioral/lifecycle campaigns
    WHEN UPPER(CAMPAIGN) LIKE '%_BC'
        OR UPPER(CAMPAIGN) LIKE '%ONETIMEBUYER%'
        OR UPPER(CAMPAIGN) LIKE '%1X BUYER%'
        OR UPPER(CAMPAIGN) LIKE '%FIRST_TIME_BUYER%'
        OR UPPER(CAMPAIGN) LIKE '%TRIGGER%'
        OR UPPER(CAMPAIGN) LIKE '%CUSTOMERJOURNEY%'
        OR UPPER(CAMPAIGN) LIKE '%PERKSANNIVERSARY%'
        OR UPPER(CAMPAIGN) LIKE '%ABANDON%'
        OR UPPER(CAMPAIGN) LIKE '%BIRTHDAY%'
        OR UPPER(CAMPAIGN) LIKE '%PURCHASE%'
        OR UPPER(CAMPAIGN) LIKE '%POSTPURCHASE%'
        OR UPPER(CAMPAIGN) LIKE '%WELCOME%'
            AND NOT REGEXP_LIKE(CAMPAIGN, '^[0-9]{6}_')
        OR UPPER(CAMPAIGN) LIKE '%BLUECORE%'
        OR UPPER(CAMPAIGN) LIKE '%AN_LOYALTY%'
        OR UPPER(CAMPAIGN) LIKE '%LAPSED%'
        OR UPPER(CAMPAIGN) LIKE '%RETENTION%'
        OR UPPER(CAMPAIGN) LIKE '%PRICE DROP%'
        OR UPPER(CAMPAIGN) LIKE '%BACK_IN_STOCK%'
        OR (UPPER(CAMPAIGN) LIKE '%BACKINSTOCK%'
            AND UPPER(CAMPAIGN) NOT LIKE '%BACKINSTOCKNOTIF%')
        THEN 'EMAIL - TRIGGER'

    -- 7. EMAIL - EVENT
    WHEN UPPER(CAMPAIGN) LIKE '%NOWOPEN%'
        OR UPPER(CAMPAIGN) LIKE '%COMINGSOON%'
        OR UPPER(CAMPAIGN) LIKE '%EVENT%'
        THEN 'EMAIL - EVENT'

    -- 8. EMAIL - TRANSACT: Order/shipping/fulfillment notifications
    WHEN UPPER(CAMPAIGN) LIKE '%TRANSACT%'
        OR UPPER(CAMPAIGN) LIKE '%AN_SHIP%'
        OR UPPER(CAMPAIGN) LIKE '%AN_ORDER%'
        OR UPPER(CAMPAIGN) LIKE '%AN%ORDERCONFIRMATION%'
        OR UPPER(CAMPAIGN) LIKE '%AN%SHIPMENTCONFIRMATION%'
        OR UPPER(CAMPAIGN) LIKE '%DELIVERY_NOTIFICATION%'
        OR UPPER(CAMPAIGN) LIKE '%EGIFTCARD%'
        OR UPPER(CAMPAIGN) LIKE 'ANUS_%'
        OR UPPER(CAMPAIGN) LIKE '%OPTIN%'
        OR UPPER(CAMPAIGN) LIKE 'ISPU%'
        OR UPPER(CAMPAIGN) LIKE '%_ACCT_%'
        OR UPPER(CAMPAIGN) LIKE '%_MBR_%'
        THEN 'EMAIL - TRANSACT'

    ELSE 'EMAIL - OTHER'
END AS MODVAR
```

### SMS Campaign Classification

Same bucket structure (SMS - MKTG, SMS - TRIGGER, SMS - TRANSACT, SMS - EVENT, SMS - SURVEY):

- **SMS - MKTG**: Campaigns starting with a digit (date-prefixed), `%AN_SMS%`, `%PROMO%`, `LEFT(...) = 'MON'`
- **SMS - TRIGGER**: `%_BC`, `%ABANDON%`, `%BIRTHDAY%`, `%PERKS%`, `%WELCOME%` (not digit-prefixed), `%BLUECORE%`, `%LAPSED%`, `%RETENTION%`, `%PRICE DROP%`, `%BACKINSTOCK%`
- **SMS - TRANSACT**: `%TRANSACT%`, `%AN_SHIP%`, `%AN_ORDER%`, `%AN%SHIPMENTCONFIRMATION%`, `%DELIVERY_NOTIFICATION%`, `%OPTIN%`, `ISPU%`, `AN%` catch-all at end
- **SMS - EVENT**: `%NOWOPEN%`, `%COMINGSOON%`, `%EVENT%`
- **SMS - SURVEY**: `%SURVEY%`, `%CUSTOMERPANEL%`

### Push Campaign Classification

Same bucket structure (PUSH - MKTG, PUSH - TRIGGER, PUSH - TRANSACT, PUSH - EVENT → MKTG, PUSH - SURVEY → MKTG, PUSH - OTHER):

- **PUSH - MKTG**: Campaigns with `MM/DD/YY` or `MMDDYY_` date patterns, `%AN_PUSH%`, `%AN_MOBPUSH%`, `%WEEKLYNEW%`, `LEFT(...) = 'MON'`, `%PROMO%` (not abandon), `%_INAPPMESSAGE`
- **PUSH - TRIGGER**: `%_BC`, `%ABANDON%`, `%BIRTHDAY%`, `%PERKS%`, `%WELCOME%` (not date-prefixed), `%BLUECORE%`, `%LAPSED%`, `%RETENTION%`, `%BROWSE%`, `%AFFINITY%`, `%LOWINVENTORY%`
- **PUSH - TRANSACT**: `%ORDER%`, `%SHIP%`, `%DELIVERY%`, `%PICKUP%`, `%BOPIS%`, `%OPTIN%`, `ISPU%`
- **PUSH - OTHER**: `%GEO_FENCE%`, `EVERGREEN_PUSHENABLE%`, `COPY OF %`, `AMPSCRIPT%` — remove from analysis
- Events and Surveys → **PUSH - MKTG** (per channel lead direction)

---

## MMM Sandbox Tables (AN, FY26)

Pre-built tables in `EDW_SANDBOX_PROD.URBN` for Marketing Mix Modeling work. **These are analyst-created tables — not official EDW tables.** 30-day drop policy applies.

| Table | Description |
|-------|-------------|
| `MMM_EMAIL_RAW_DATA_AN_26` | Daily send counts by campaign for AN, FY23–FY26 |
| `MMM_EMAIL_DAILY_DATA_AN_26` | Email sends bucketed by MODVAR (MKTG/TRIGGER/TRANSACT/EVENT) |
| `MMM_SMS_DAILY_DATA_AN_26` | SMS sends bucketed by MODVAR, from DW_SMS_ACTIVITY |
| `MMM_MOBPUSH_DAILY_DATA_AN_2026` | Push sends bucketed by MODVAR, from DW_PUSH_MOBILE |

If these tables have expired (30-day policy), recreate them using the queries in `sms, push, email - AN NA.sql`.

---

## Common Gotchas

1. **`Q_DT_IT` vs `LOAD_DATE` on email** — Always filter by `Q_DT_IT` (the send date). `LOAD_DATE` is ~2 days after the actual send due to SFMC file transfer lag.

2. **SMS data is stale** — `DW_SMS_ACTIVITY` stopped updating Jan 31 2026. Do not use for TY comparisons.

3. **Bluecore clicks not in EDW** — As of early FY27, Bluecore click tracking does not flow through SFMC into EDW. Use Bluecore platform UI for click metrics on triggered campaigns.

4. **Push `STATUS` filter required** — `DW_PUSH_MOBILE` includes failed sends. Always filter `UPPER(STATUS) != 'FAIL'`.

5. **Email send deduplication** — use the composite key `CLIENT_ID || '.' || SEND_ID || '.' || EMAIL || '.' || LIST_ID || '.' || BATCH_ID` in COUNT DISTINCT to avoid double-counting when joining multiple event tables.

6. **A/B test name collision** — Two A/B test variations may share one `EMAIL_NAME` in `DW_EMAIL_SEND_JOBS`. Group by `SEND_ID + SUBJECT` to split variations.
