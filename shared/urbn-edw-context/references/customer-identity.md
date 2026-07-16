# Customer Identity at URBN

## The CDI process

URBN's **CDI (Customer Data Integration)** is the process that consolidates signals across web, store, email, and loyalty into a single resolved customer record. The vendor that runs this is **Merkle**, and the assigned customer key is the **IID (Individual Identifier)**.

Merkle runs two platforms: **KL (Merkury)** for North America, **AI** for international.

## The identifier hierarchy

| Identifier | Represents | Granularity |
|---|---|---|
| `IID` | Individual person — the canonical customer key everywhere | One per individual |
| `HID` | Household — multiple IIDs at one address | One per household |
| `RID` | Residence — multiple HIDs at one physical address | One per residence |

**Always use IID.** HID and RID are rarely used in marketing analytics.

## Formulated vs. Sustained IIDs

| Type | First digit | Meaning |
|---|---|---|
| **Sustained** | `0` | Matched to a real person via name + mailing address. High confidence. |
| **Formulated** | `1` | Email-only match. Lower confidence. Email sign-ups with no order history, or guest checkouts that couldn't be fully resolved. |

Formulated IIDs can promote to Sustained when the customer places a full order. The `DW_LINK_ORDER_KEYS_IID` table tracks IID changes per order over time (Type 2 history).

## All the customer identifiers — a complete crosswalk

### CRM / identity

| Identifier | Source | When to use it |
|---|---|---|
| `IID` | Merkle/CDI | **Default for all customer-level analysis.** Always `COUNT(DISTINCT IID)`. |
| `HID` | Merkle/CDI | Rarely used |
| `RID` | Merkle/CDI | Very rarely used |
| `PROFILE_ID` | A15 (URBN digital) | Joining SERVICES tables to CDI. Bridge: `DW_IID_WEB_PROFILE_XREF` |
| `Contact ID` | Salesforce Service Cloud | 18-char Salesforce ID, created when registered in Service Cloud. Use for SFMC campaign perf, Service Cloud data |
| `Sterling ID` (Bill_To_ID) | Sterling OMS | Legacy. Coverage shrinking for post-2025-migration customers |
| `LOYALTY_ID` | A15 / Salesforce | The customer's loyalty member ID |

### Advertising / web analytics signals

| Identifier | Source | When to use it |
|---|---|---|
| `UID2` / Unified ID 2.0 | The Trade Desk (open standard) | TTD identity resolution |
| `TDID` | The Trade Desk | Match TTD impressions to URBN customers |
| `USER_PSEUDO_ID` (`FULLVISITOR_ID`) | GA4 | Anonymous device/browser ID. Tracks the device, not the person. Used indirectly via `WEB_SESSION_SNUM` |
| `urbn_uuid` | URBN custom | Custom URBN identity cookie |

## Order linking priority

How orders get linked to IIDs (lowest priority number = best match):

| Priority | Match key | What it means |
|---|---|---|
| 0 (highest) | Direct SID (Sterling Bill_To_ID) | Order's bill-to ID matched directly via `DW_IID_SOM_CUSTOMER_XREF` |
| 2 | Direct Loyalty ID | Matched via loyalty ID on the order |
| 3 | Inferred SID via credit card | Credit card linked to known Sterling Bill_To_ID |
| 4 | Inferred Loyalty ID via credit card | Credit card linked to known loyalty ID |
| 6 | Direct email | Order email matched to IID via `DW_CDI_EMAIL` |
| No match | `IID = '-1'` | **Always exclude these from customer counts** |

> **As of March 2026 (RFC-5127):** `IID`, `TXN_MATCH_DT`, `TXN_MATCH_KEY`, and `TXN_LINK_TYPE` are columns directly on `DW_BLND_ORDER_HEADER`. You no longer need to join to `DW_LINK_ORDER_KEYS` to get the IID on an order.

## The Salesforce migration — Aug–Oct 2025 data gap

In 2025, URBN moved the customer system of record from Sterling to Salesforce Service Cloud.

| Phase | When | Impact on EDW |
|---|---|---|
| Phase 3 (EDW-2932) | Early 2025 | A15 async customer creates stopped going to Sterling — go directly to Salesforce. `DW_IID_SOM_CUSTOMER_XREF` stops being populated for new web customers |
| Phase 4 | June 2025 | Loyalty ID generation moved from Sterling to A15. POS loyalty sign-ups now go to Salesforce |
| POS rollout | Aug 20 → ~Sep 28, 2025 | POS stores switched store-by-store to new Tibco/Salesforce endpoint |

**Two consequences for analysts:**

1. **New customer counts and POS loyalty data Aug–Oct 2025 may be understated.** Treat WoW/YoY comparisons spanning this window with caution. Add a footnote in deliverables.
2. **Approximately 2% of in-store loyalty sign-ups during the rollout were assigned loyalty IDs that had previously been used by Sterling for different customers.** If joining on loyalty ID for this period, verify carefully.

## Core customer tables

| Table | Contains | Notes |
|---|---|---|
| `EDW_PROD.URBN.DW_CDI_CUSTOMER` | Resolved customer record — name, address, demographics. 68 cols, ~99.7M rows | PII fields masked under `RO_ROLE_PROD` |
| `EDW_PROD.URBN.DW_CDI_EMAIL` | All email addresses linked to each IID by brand. 12 cols, ~134.9M rows | One IID can have many email rows across brands |
| `EDW_PROD.URBN.DW_CDI_IDV` | Individual Derived Value — store proximity, buyer flag, store of residence. 14 cols, ~129.1M rows | Distance limited to US |
| `EDW_PROD.URBN.DW_CDI_PREF` | **Suppression / opt-out** requests. Keyed `IID + BRAND_CD + PREF_TYPE` | NOT for general opt-in. Use `Q_QL_ELS_V` for subscribers |
| `EDW_PROD.URBN.DW_CDI_DEMO_APPEND` | Legacy 26-attribute demographics | Prefer `DW_CDI_CUSTOMER` for new analysis |
| `EDW_PROD.URBN.DW_IID_WEB_PROFILE_XREF` | IID ↔ PROFILE_ID bridge | 1:M — one IID can map to many profile IDs |
| `EDW_PROD.URBN.DW_IID_EMAIL_XREF` | IID ↔ email bridge | Use when joining email-keyed data without going through `DW_CDI_EMAIL` |
| `EDW_PROD.URBN.DW_LINK_ORDER_KEYS_IID` | Type 2 history — IID changes per order over time | Longitudinal analysis only |
| `EDW_PROD.URBN.Q_QL_ELS_V` | **Email opt-in / subscribers.** Filter `PREF_FLG='Y' AND MOST_RECENT_FLG='Y'` | Use this, not `DW_CDI_PREF`, for subscribers |
| `EDW_PROD.URBN.DW_SERVICES_PROFILES` | A15 customer profiles. `PROFILE_ID`, `ID_OID`, `CONTACT_ID`, `STERLING_ID`, `LOYALTY_ID` | Bridge to Salesforce Contact ID. `STERLING_ID` not populated for post-Phase-3 customers |
| `EDW_PROD.URBN.DW_SERVICES_SUBSCRIPTIONS` | A15 loyalty/subscription, **digital-only** | Same-day availability ~6:45 AM EST |
| `EDW_ODS_PROD.SFSC.CONTACT` | Raw Salesforce Contact via FiveTran | Updated every few minutes |

## Bridging between identity systems

### Contact ID → IID

```sql
USE ROLE RO_ROLE_PROD;
USE WAREHOUSE RO_WH_PROD;
USE DATABASE EDW_PROD;
USE SCHEMA URBN;

SELECT
    P.CONTACT_ID,
    P.PROFILE_ID,
    X.IID,
    P.BRAND_CD
FROM DW_SERVICES_PROFILES P
JOIN DW_IID_WEB_PROFILE_XREF X
    ON X.PROFILE_ID = P.PROFILE_ID
   AND X.BRAND_CD   = P.BRAND_CD
WHERE P.BRAND_CD = 'AN'
  AND P.CONTACT_ID IS NOT NULL;
```

### Email → IID (requires PII_ROLE_PROD)

```sql
USE ROLE PII_ROLE_PROD;
USE WAREHOUSE RO_WH_PROD;
USE DATABASE EDW_PROD;
USE SCHEMA URBN;

SELECT EMAIL_ADDRESS, IID, BRAND_CD, RECENT_DT
FROM DW_CDI_EMAIL
WHERE EMAIL_ADDRESS = 'customer@example.com'
ORDER BY RECENT_DT DESC;
```

## CDI maintenance windows

CDI runs nightly, but is **paused once a month for NCOA + Rekey** — typically one business day. During that window, **MTA, NAR, new-customer, and dashboard refreshes are also paused** (MTA depends on CDI). Hari posts an `@here` notice in `#marketingsystems_cloud_qa` ahead of time. Data catches up the next morning.

## Privacy / suppressed records

URBN complies with GDPR, CCPA, and equivalent global privacy laws. Customers can request deletion or restriction. You'll see empty or masked fields in CDI tables for these — that's intentional, not a data quality issue. Don't flag them.
