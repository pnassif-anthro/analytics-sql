# Database Structure & Naming Conventions

Quick reference for URBN's Snowflake environment — databases, schemas, table prefixes, and column conventions.

---

## The Four Production Databases

| Database | What it is | When you use it |
|----------|-----------|----------------|
| `EDW_PROD` | Main data warehouse. Transformed, analytics-ready tables. | **Start here.** All reporting and analysis. |
| `EDW_ODS_PROD` | Operational Data Store. Near-raw data from source systems and vendors. | Raw source records before transformation — Rockerbox log-level, GA4 events, Innovid impression logs, Salesforce SFSC tables. Read-only. |
| `EDW_DATA_VAULT_PROD` | Long-term storage. Cross-reference tables, CDI history, bridge tables. | Only when EDW team points you here (e.g. `PRD_YFS_ITEM_XREF` for the Sterling-to-IP bridge). Reports generally don't use this. |
| `EDW_SANDBOX_PROD` | Personal workspace. Tables dropped after 30 days. | Creating your own working tables. No PII allowed — use IID or Contact ID only. |

Each database also exists in Dev (`EDW_*_DEV`) and UAT (`EDW_*_UAT`). As an analyst you will almost always be in PROD.

---

## Schemas in EDW_PROD

| Schema | What lives here | Who uses it |
|--------|----------------|-------------|
| `URBN` | Default. The majority of `DW_*` tables and all `Q_QF_`, `Q_QL_`, `Q_QA_`, `Q_QR_` views. | Everyone — start here for almost everything. |
| `ADVA` | Advanced Analytics model outputs — MTA attribution, CLV, RFM, session/product funnel views. | Marketing analysts, data scientists |
| `DATASCI` | Data Science team model outputs — price sensitivity tables. | Data science |
| `PLAN` | Planning and allocation tables (`PLN_` prefix). Feeds to/from o9. | Merch planning |
| `SFDC_MO` | Salesforce materialised objects and Data Cloud feeds. | Marketing / Salesforce team |
| `MCRSTRTTGY` | MicroStrategy-specific tables and views. | BI / MicroStrategy |
| `EXPORT` | Consumer-facing export tables (`CE_` prefix). Outbound feeds to vendors. | Engineering, BA |
| `MARKETINGQA` | GA4/MTA ETL staging. **Not for analyst queries** — tables are mid-pipeline and may be incomplete. | Data Engineering (internal only) |
| `ARCHIVE` | Legacy historical tables. Often suffixed `_UA360`, `_GA4`, or dated. Not actively updated. | Read-only reference only |

**For 95% of analyst queries, you only need `URBN` and `ADVA`.**

---

## Standard Session Header

```sql
USE ROLE RO_ROLE_PROD;
USE WAREHOUSE RO_WH_PROD;
USE DATABASE EDW_PROD;
USE SCHEMA URBN;
-- For MTA/attribution work: USE SCHEMA ADVA;
```

---

## Table Prefix Guide — EDW_PROD.URBN

| Prefix | What it means | Examples |
|--------|--------------|---------|
| `DW_` | Data Warehouse — main analytics layer. Cleaned, transformed, joined. Start here. | `DW_BLND_ORDER_HEADER`, `DW_CDI_CUSTOMER`, `DW_PRD_SKU` |
| `Q_QF_*_V` | Query Fact view — row-level fact data, typically joining across DW tables. | `Q_QF_BLND_ORDER_HEADER_V`, `Q_QF_SLS_TXN_DTL_V` |
| `Q_QL_*_V` | Query Lookup view — dimension/reference data. | `Q_QL_CDI_LOYALTY_V`, `Q_QL_ELS_V`, `Q_QL_PRD_SKU_V` |
| `Q_QA_*_V` | Query Aggregate view — pre-aggregated summaries (store+day, class+week). Often have `_XTD_`, `_LY_`, `_CCY_` variants. | `Q_QA_SLS_CLS_D_V` |
| `Q_QR_*_V` | Query Report view — purpose-built for a specific business question. Embeds business logic. | `Q_QR_LOC_CMP_STR_D_V` |
| `DM_` | Data Mart — purpose-built summary tables from BA/BI business rules. | `DM_LOYALTY_SUMMARY` |
| `CE_` | Common Export — outbound tables for vendor/downstream consumption. Lives in EXPORT schema. | `CE_CDI_EXPORT` |

> `Q_` does NOT mean Qlik — the prefix stands for Quantisense, the original DW vendor. The naming has been preserved because thousands of reports depend on it.

---

## Table Prefix Guide — EDW_PROD.ADVA

| Pattern | Examples |
|---------|---------|
| `AA_*` | Advanced Analytics models — `AA_CLV_FINAL_PREDICTIONS`, `AA_CUSTOMER_PRICE_SENSITIVITY_CATEGORY` |
| `DW_MTA_*` | In-house MTA tables — `DW_MTA_TOTAL_POINTS_ATTRIBUTED` |
| `MTA_*_V` | Analyst-facing MTA views — `MTA_TOTAL_POINTS_ATTRIBUTED_V`, `MTA_TOTAL_POINTS_ROLLUP_V` |
| `DW_RFM_*` | RFM history — `DW_RFM_HISTORY` |
| `DW_WEB_*` | Web funnel tables — `DW_WEB_SESSION_PRODUCTS_FUNNEL_V` |

---

## Table Prefix Guide — EDW_ODS_PROD.URBN (Source Systems)

| Prefix | Source system | Example |
|--------|--------------|---------|
| `SOM_STER_PRD_SCH_*` | Sterling OMS (CDC-sourced) | `SOM_STER_PRD_SCH_YFS_ORDER_HEADER` |
| `SOM_STERPRD_*` | Sterling OMS (ETL-sourced, legacy naming) | `SOM_STERPRD_YFS_CUSTOMER` |
| `IP_*` | Island Pacific (ERP) | `IP_UORNIATT` |
| `POS_*` | Point of Sale | `POS_TR_RTL` |
| `A15_*` | A15 / URBN digital platform | `A15_MASTER_PRODUCT_SKU` |
| `FT_*` | Flashtalking / Innovid (ad server) | `FT_IMPRESSIONS`, `FT_MATCH_PLACEMENT` |
| `RBX_*` | Rockerbox (MTA) | `RBX_AN_LOG_LVL_PRCHS`, `RBX_AN_AGGREGATE_MTA` |
| `GA4_*` | Google Analytics 4 (BigQuery pipeline) | GA4 raw event tables |
| `SFMC_*` | Salesforce Marketing Cloud | `SFMC_EMAIL_SENT` |

---

## Column Name Conventions

**`Q_` prefix on a column = EDW-derived value** — not pulled directly from source.

Examples: `Q_DT_ID` (EDW date key), `Q_SKU_ID` (surrogate PK), `Q_SKU_SNUM` (concatenated business key)

Common column suffixes:

| Suffix | Type | Example |
|--------|------|---------|
| `_ID` | Surrogate identifier | `Q_SKU_ID`, `Q_CLS_ID` |
| `_SNUM` | Surrogate number (concatenated business key) | `Q_SKU_SNUM`, `Q_BLND_ORD_HDR_SNUM` |
| `_DNUM` | Display number (human-readable) | `Q_SKU_DNUM` |
| `_CD` | Code | `BRAND_CD`, `SRC_ID` |
| `_DT` | Date | `ORDER_DT`, `ENROLLMENT_DT` |
| `_TS` | Timestamp | `CDC_MODIFIED_TS_UTC` |
| `_FLG` | Flag (boolean / Y/N) | `PURGE_FLG`, `EMPLOYEE_ORDER_FLG` |
| `_AMT` | Dollar amount | `DEMAND_AMT`, `ATTRIBUTED_DEMAND_AMT` |
| `_QTY` | Unit quantity | `ORDER_QTY`, `DEMAND_QTY` |
| `_DESC` | Description | `Q_SKU_DESC`, `Q_CLS_DESC` |

**`SRC_ID` values:**

| Value | Region |
|-------|--------|
| `100` | North America (NA) |
| `200` | Europe (EU) |
| `0` | Other / Unclassified |

---

## "Where Does X Live?" Quick Reference

| I'm looking for… | Database | Schema | Prefix / pattern |
|---|---|---|---|
| Order data (blended D2C + retail) | EDW_PROD | URBN | `DW_BLND_ORDER_*` |
| Customer identity / CDI | EDW_PROD | URBN | `DW_CDI_*` |
| Loyalty enrolments | EDW_PROD | URBN | `Q_QL_CDI_LOYALTY_V` |
| Email opt-in status | EDW_PROD | URBN | `Q_QL_ELS_V` |
| Email send/open/click data | EDW_PROD | URBN | `DW_EMAIL_*` |
| SMS data (pre-Jan 2026) | EDW_PROD | URBN | `DW_SMS_ACTIVITY` |
| Push notifications | EDW_PROD | URBN | `DW_PUSH_MOBILE` |
| Product / SKU data | EDW_PROD | URBN | `DW_PRD_*` |
| Inventory | EDW_PROD | URBN | `DW_INV_*` |
| Retail sales (IP-sourced) | EDW_PROD | URBN | `DW_SLS_TXN_*` or `Q_QF_SLS_*` |
| D2C digital orders (Sterling) | EDW_PROD | URBN | `DW_D2C_TXN_*` |
| Web / GA4 analytics | EDW_PROD | URBN | `DW_WA_*` |
| MTA attribution (current) | EDW_PROD | ADVA | `MTA_TOTAL_POINTS_*_V` |
| AN-specific MTA rollup | EDW_PROD | URBN | `AN_MTA_ROLLUP_BASE_DTB` |
| CLV / RFM predictions | EDW_PROD | ADVA | `AA_CLV_FINAL_PREDICTIONS*` |
| RFM history | EDW_PROD | ADVA | `DW_RFM_HISTORY` (key: `CLOUD_IID`) |
| Price sensitivity | EDW_PROD | DATASCI | `AA_CUSTOMER_PRICE_SENSITIVITY_*` |
| Rockerbox log-level (AN) | EDW_ODS_PROD | URBN | `RBX_AN_LOG_LVL_PRCHS` |
| Innovid impression logs | EDW_ODS_PROD | URBN | `FT_IMPRESSIONS` |
| TTD impressions | `THE_TRADE_DESK.REDS.IMPRESSIONS` (data share) | — | — |
| EU spend data (Funnel) | `FUNNEL_ANTHROPOLOGIE_EU.FUNNEL__OLFS6ZBWHZRUFMJO5ZS` | — | `ANEU_DAILY_FUNNEL_DATA` |
| Salesforce Contact table | EDW_ODS_PROD | SFSC | `CONTACT` |
| Fiscal calendar | EDW_PROD | URBN | `DW_CALENDAR_HIERARCHY` |
| Store hierarchy | EDW_PROD | URBN | `DW_LOC_STR`, `Q_QL_MKT_STORE_V` |
| Promo/event data by channel | EDW_PROD | URBN | `Q_QL_LOC_CHN_USERDATA_V` |
| Your own working tables | EDW_SANDBOX_PROD | URBN | Whatever you name them |

---

## Deprecated Tables — How to Spot Them

Deprecated tables are not deleted — they stay in place to avoid breaking existing queries.

Signs a table is deprecated:
- **In Atlan**: Certificate status shows `Deprecated` rather than `Verified`. Description usually names the replacement.
- **In table names**: Suffixed with a date, system version, or legacy indicator.

Common deprecated patterns:

| Pattern | What it means |
|---------|--------------|
| `_UA360` suffix | Universal Analytics 360 data — superseded by GA4 (Feb 2024) |
| Tables in `ARCHIVE` schema | Preserved for YoY history only, not actively updated |
| `DW_MTA_TOTAL_POINTS_ATTRIBUTED_UA360` | Legacy MTA pre-GA4 cutover |
| SessionM-era loyalty tables | SessionM removed FY26 for UO — historical data only |

**Rule of thumb**: If a table isn't in Atlan as `Verified`, check the description for the recommended replacement before querying. If unsure, post in #edw-support-snowflake.

---

## Roles Reference

| Role | Access |
|------|--------|
| `RO_ROLE_PROD` | Standard read access to `EDW_PROD`, `EDW_ODS_PROD`, `EDW_DATA_VAULT_PROD`. PII fields masked. |
| `PII_ROLE_PROD` | Adds unmasked PII (names, emails, addresses). Request via Jira or #edw-support-snowflake with a specific use case. |
| `BI_ROLE_PROD` | Write access to specific schemas. Needed for creating tables. Align with Tim Harris / Data Engineering on schema placement before requesting. |
| `QA_ROLE_PROD` | Access to sandbox Dynamic Tables (e.g. RBX V3 UAT view). |
