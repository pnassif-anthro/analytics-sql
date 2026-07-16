# Email and SFMC

## How email data gets into EDW

All email engagement originates from **Salesforce Marketing Cloud (SFMC)**. SFMC exports a daily zip file per brand, transferred via MoveIt, and ingested into Snowflake.

There is **always a ~2 day lag**. **Always filter on `Q_DT_IT` (the send date), not `LOAD_DATE`** for send-date reporting.

## History boundary

Email history begins **June 30, 2021** when SFMC went live. Pre-July 2021 data was on Cheetah Digital and is not in `DW_EMAIL_*` tables. For pre-2021 history, ask the EDW team.

## The email data model

| Table | Grain | Joins to |
|---|---|---|
| `DW_EMAIL_SEND_JOBS` | One row per campaign send (`SEND_ID`). All campaign metadata. | Parent — all event tables join here on `CLIENT_ID + SEND_ID` |
| `DW_EMAIL_SENT` | One row per email per send. Base deliverability table | `DW_EMAIL_SEND_JOBS` on `SEND_ID` |
| `DW_EMAIL_OPENS` | One row per open event per subscriber per send | `DW_EMAIL_SEND_JOBS` on `SEND_ID` |
| `DW_EMAIL_CLICKS` | One row per click event per subscriber per send per URL | `DW_EMAIL_SEND_JOBS` on `SEND_ID` |
| `DW_EMAIL_BOUNCES` | One row per bounce with `BOUNCE_CATEGORY` | `DW_EMAIL_SEND_JOBS` on `SEND_ID` |
| `DW_EMAIL_NOT_SENT` | Unsent records with `REASON` | `DW_EMAIL_SEND_JOBS` on `SEND_ID` |

## Standard KPI calculations

| Metric | Calculation |
|---|---|
| Total Sends | `COUNT(*)` from `DW_EMAIL_SENT` |
| Unique Opens | `COUNT(*)` from `DW_EMAIL_OPENS WHERE IS_UNIQUE = TRUE` |
| Unique Open Rate | Unique Opens / Total Sends |
| Unique Clicks | `COUNT(*)` from `DW_EMAIL_CLICKS WHERE IS_UNIQUE = TRUE` |
| Unique CTR | Unique Clicks / Total Sends |
| CTOR (Click-to-Open) | Unique Clicks / Unique Opens |
| Hard Bounces | `COUNT(*)` from `DW_EMAIL_BOUNCES WHERE BOUNCE_CATEGORY = 'HardBounce'` |

## Broadcast vs. triggered sends

Filter `TRIGGERED_SEND_EXTERNAL_KEY IS NULL OR = ''` for broadcast marketing sends. Not null = triggered/automated (welcome series, abandonment, etc.).

## Joining email events to IID

Join `EMAIL` from event table → `EMAIL_ADDRESS + BRAND_CD` on `DW_CDI_EMAIL`.

## Example — campaign performance summary

```sql
USE ROLE RO_ROLE_PROD;
USE WAREHOUSE RO_WH_PROD;
USE DATABASE EDW_PROD;
USE SCHEMA URBN;

SELECT
    sj.SEND_ID,
    sj.EMAIL_NAME,
    sj.SUBJECT,
    sj.SENT_TIME::DATE                               AS SEND_DATE,
    COUNT(DISTINCT sent.EMAIL)                       AS TOTAL_SENDS,
    COUNT(DISTINCT CASE WHEN o.IS_UNIQUE THEN o.EMAIL END) AS UNIQUE_OPENS,
    COUNT(DISTINCT CASE WHEN c.IS_UNIQUE THEN c.EMAIL END) AS UNIQUE_CLICKS,
    ROUND(COUNT(DISTINCT CASE WHEN o.IS_UNIQUE THEN o.EMAIL END)
          / NULLIF(COUNT(DISTINCT sent.EMAIL), 0) * 100, 2) AS OPEN_RATE_PCT,
    ROUND(COUNT(DISTINCT CASE WHEN c.IS_UNIQUE THEN c.EMAIL END)
          / NULLIF(COUNT(DISTINCT sent.EMAIL), 0) * 100, 2) AS CTR_PCT
FROM DW_EMAIL_SEND_JOBS sj
JOIN DW_EMAIL_SENT sent ON sj.SEND_ID = sent.SEND_ID
LEFT JOIN DW_EMAIL_OPENS o  ON sj.SEND_ID = o.SEND_ID  AND sent.EMAIL = o.EMAIL
LEFT JOIN DW_EMAIL_CLICKS c ON sj.SEND_ID = c.SEND_ID  AND sent.EMAIL = c.EMAIL
WHERE sj.BRAND_CD = 'AN'
  AND sj.Q_DT_ID >= DATEADD(week, -4, CURRENT_DATE)
  AND (sj.TRIGGERED_SEND_EXTERNAL_KEY IS NULL OR sj.TRIGGERED_SEND_EXTERNAL_KEY = '')
GROUP BY 1, 2, 3, 4
ORDER BY 4 DESC;
```

## Active subscribers — single brand

```sql
SELECT IID, EMAIL_ADDRESS, BRAND_CD
FROM EDW_PROD.URBN.Q_QL_ELS_V
WHERE BRAND_CD = 'AN'
  AND PREF_FLG = 'Y'
  AND MOST_RECENT_FLG = 'Y';
```

## Known gotchas

| Issue | Detail | Workaround |
|---|---|---|
| ~2-day data delay | `LOAD_DATE` is ~2 days after actual send `Q_DT_IT` | **Always filter on `Q_DT_IT`** (send date) for send-date reporting |
| Pre-July 2021 history gap | Cheetah Digital era — not in DW_EMAIL tables | Ask EDW team for legacy access |
| **Bluecore click gap** | As of early FY27, Bluecore click tracking is not flowing through SFMC into EDW. **Send data is in EDW; clicks must be retrieved from Bluecore UI** | Watch `#marketingsystems_cloud_qa` |
| A/B test `EMAIL_NAME` collision | Two A/B variations may share one `EMAIL_NAME` | Group by `SEND_ID + SUBJECT` to split |
| Open rate inflation (Apple MPP) | Apple Mail Privacy Protection pre-fetches tracking pixels, inflating opens | Treat unique open rate as **directional**. CTOR is more reliable |
| **SMS data gap** | `DW_SMS_ACTIVITY` stopped updating Jan 31 2026 | Post in `#marketingsystems_cloud_qa` for current recommended SMS table |

## Email vendor stack — current state

| Channel | Vendor | EDW data |
|---|---|---|
| Broadcast email | Salesforce Marketing Cloud (SFMC) | All `DW_EMAIL_*` tables |
| Triggered/behavioural email | Bluecore → SFMC (Bluecore fires triggers, SFMC delivers) | Sends in `DW_EMAIL_SENT`, **clicks not in EDW** as of FY27 |
| SMS | Attentive | `DW_SMS_ACTIVITY` (currently stale) |
| Push | SFMC MobilePush (Braze for Nuuly) | — |
| On-site personalization | Dynamic Yield (replaced Salesforce Interaction Studio Q1 FY27) | — |

## Cheetah Digital cutover

Pre-2021 → June 30 2021: cutover from Cheetah Digital to SFMC. Engagement history split — anything before June 30 2021 lives in legacy tables, not `DW_EMAIL_*`.
