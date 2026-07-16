# EDW Database Structure Reference

## The four production databases

Everything lives in one of four databases. For analyst work, **start in `EDW_PROD`**.

| Database | What it is | When to use it |
|---|---|---|
| `EDW_PROD` | Main warehouse. Transformed, analytics-ready. | Default for all reporting and analysis |
| `EDW_ODS_PROD` | Operational Data Store. Near-raw source data. | Sterling raw, GA4 raw, Rockerbox log-level, Innovid impressions |
| `EDW_DATA_VAULT_PROD` | Long-term storage, cross-references, bridges | Only when EDW team points you here for a specific join (e.g. `PRD_YFS_ITEM_XREF` Sterling↔IP bridge) |
| `EDW_SANDBOX_PROD` | Personal workspace, 30-day retention | Your own working tables — **no PII allowed** |

Dev (`*_DEV`) and UAT (`*_UAT`) variants exist but analysts almost always work in PROD.

## Schemas in EDW_PROD — what lives where

| Schema | What lives here | Who uses it |
|---|---|---|
| `URBN` | **Default. Most `DW_*` tables and all `Q_QF_`, `Q_QL_`, `Q_QA_`, `Q_QR_` views** | Everyone |
| `ADVA` | Advanced Analytics outputs — MTA, CLV, RFM, web funnel | Marketing analysts, data scientists |
| `PLAN` | Planning/allocation tables (`PLN_*`), feeds to/from o9 | Merch planning |
| `SFDC_MO` | Salesforce materialized objects, Data Cloud feeds | Marketing/Salesforce team |
| `MCRSTRTTGY` | MicroStrategy tables and views | BI |
| `EXPORT` | Outbound consumer tables (`CE_*`) to vendors and downstream | Engineering |
| `MARKETINGQA` | **GA4/MTA ETL staging — DO NOT QUERY for analysis.** Tables here are mid-pipeline | Data Engineering only |
| `ARCHIVE` | Legacy historical tables (often `_UA360` suffix). Static. | Read-only YoY reference |
| `BLUEBOAT` | BlueBoat vendor integration | BlueBoat-specific |
| `INFORMATION_SCHEMA` | Snowflake system metadata | All users (discovery) |

For 95% of analyst queries: **`EDW_PROD.URBN` and `EDW_PROD.ADVA`**.

## Schemas in EDW_ODS_PROD

ODS is raw source data before transformation. Most analysts don't touch this directly.

| Schema | What lives here |
|---|---|
| `URBN` | Almost all ODS source tables. Source system identified by table prefix (see below) |
| `INGEST` | Mid-pipeline staging. Not for direct query |
| `SFSC` | Salesforce Service Cloud raw via FiveTran (`CONTACT`, `ACCOUNT`, `SITE_ID_C`) |

## Reading a table name — prefix system

### EDW_PROD.URBN

| Prefix | Meaning | Examples |
|---|---|---|
| `DW_` | Data Warehouse — analyst-ready, cleaned, joined. **Start here.** | `DW_BLND_ORDER_HEADER`, `DW_CDI_CUSTOMER`, `DW_PRD_SKU` |
| `Q_QF_*_V` | Query Fact view — row-level fact data | `Q_QF_BLND_ORDER_HEADER_V`, `Q_QF_SLS_TXN_DTL_V` |
| `Q_QL_*_V` | Query Lookup view — dimension/reference | `Q_QL_CDI_LOYALTY_V`, `Q_QL_ELS_V` |
| `Q_QA_*_V` | Query Aggregate view — pre-rolled (often `_XTD_`, `_LY_`, `_CCY_` variants) | `Q_QA_SLS_CLS_D_V` |
| `Q_QR_*_V` | Query Report view — purpose-built for one question | `Q_QR_LOC_CMP_STR_D_V` |
| `DM_` | Data Mart — BA/BI summary tables | `DM_LOYALTY_SUMMARY` |
| `CE_` | Common Export (lives in `EXPORT` schema) | `CE_CDI_EXPORT` |

> **`Q_` does NOT mean Qlik.** It stands for Quantisense, the original DW vendor. Naming preserved because thousands of reports depend on it.

### EDW_PROD.ADVA

| Pattern | Examples |
|---|---|
| `AA_*` | Advanced Analytics models — `AA_CLV_FINAL_PREDICTIONS`, `AA_CUSTOMER_PRICE_SENSITIVITY_CATEGORY` |
| `DW_MTA_*` | In-house MTA tables — `DW_MTA_TOTAL_POINTS_ATTRIBUTED` |
| `MTA_*_V` | Analyst-facing MTA views — `MTA_TOTAL_POINTS_ATTRIBUTED_V`, `MTA_TOTAL_POINTS_ROLLUP_V` |
| `DW_RFM_*` | RFM history — `DW_RFM_HISTORY` (key column: `CLOUD_IID`, not `IID`) |
| `DW_WEB_*` | Web funnel — `DW_WEB_SESSION_PRODUCTS_FUNNEL_V` |

### EDW_ODS_PROD.URBN — source system prefixes

| Prefix | Source | Example |
|---|---|---|
| `SOM_STER_PRD_SCH_*` | Sterling OMS (CDC-sourced) | `SOM_STER_PRD_SCH_YFS_ORDER_HEADER` |
| `SOM_STERPRD_*` | Sterling OMS (legacy ETL) | `SOM_STERPRD_YFS_CUSTOMER` |
| `IP_*` | Island Pacific ERP | `IP_UORNIATT` |
| `POS_*` | Point of Sale (retail) | `POS_TR_RTL` |
| `A15_*` | A15 / URBN digital platform | `A15_MASTER_PRODUCT_SKU` |
| `FT_*` | Flashtalking/Innovid (ad server) | `FT_IMPRESSIONS`, `FT_MATCH_PLACEMENT` |
| `RBX_*` | Rockerbox | `RBX_AN_LOG_LVL_PRCHS`, `RBX_FP_LOG_LVL_PRCHS` |
| `GA4_*` | GA4 raw (BigQuery pipeline) | GA4 raw event tables |
| `SFMC_*` | Salesforce Marketing Cloud | `SFMC_EMAIL_SENT` |

## Column conventions

| Suffix | Type | Example |
|---|---|---|
| `_ID` | Surrogate identifier | `Q_SKU_ID`, `Q_CLS_ID` |
| `_SNUM` | Surrogate number (concatenated business key) | `Q_SKU_SNUM`, `Q_BLND_ORD_HDR_SNUM` |
| `_DNUM` | Display number (human-readable) | `Q_SKU_DNUM` |
| `_CD` | Code | `BRAND_CD`, `SRC_ID` |
| `_DT` | Date | `ORDER_DT`, `ENROLLMENT_DT` |
| `_TS` | Timestamp | `CDC_MODIFIED_TS_UTC` |
| `_FLG` | Flag (Y/N or boolean) | `PURGE_FLG`, `EMPLOYEE_ORDER_FLG` |
| `_AMT` | Dollar amount | `DEMAND_AMT`, `ATTRIBUTED_DEMAND_AMT` |
| `_QTY` | Unit quantity | `ORDER_QTY`, `DEMAND_QTY` |
| `_DESC` | Description | `Q_SKU_DESC` |

`Q_` *column prefix* (not table prefix) = EDW-derived. Example: `Q_SKU_ID` is a surrogate key generated by EDW; `Q_DT_ID` is an EDW-generated date key.

`SRC_ID`: `100` = NA, `200` = EU, `0` = other.

## Spotting deprecated tables

- Atlan certificate status = "Deprecated" (not "Verified")
- `_UA360` suffix = Universal Analytics 360 (pre-GA4, before Feb 2024)
- Tables in `ARCHIVE` schema = preserved for YoY only, not updated
- `DW_MTA_TOTAL_POINTS_ATTRIBUTED_UA360` = pre-GA4 MTA, historical only
- SessionM-era loyalty tables = removed FY26 for UO

If unsure whether a table is current, check Atlan or post in `#edw-support-snowflake`.
