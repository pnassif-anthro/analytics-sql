# URBN Glossary

Terms and abbreviations used across EDW, ordered alphabetically within sections. Search this when you encounter something unfamiliar in a request.

## Business terms

**Attributed Demand** — Order demand $ credited to a specific marketing touchpoint. `ORDER_DEMAND_AMT × ATTRIBUTION_SHARE`. Primary MTA metric.

**BOP / EOP** — Beginning of Period / End of Period. Inventory terms.

**Brand** — URBN brands: AN (Anthropologie), UO (Urban Outfitters), FP (Free People), TR (Terrain), Nuuly. Always identified by `BRAND_CD`.

**CDI** — Customer Data Integration. Merkle's process resolving customer identity into single IID. Runs nightly + monthly NCOA/Rekey.

**CLV** — Customer Lifetime Value. **Predictive model** forecasting next-12-month spend and retention probability. `EDW_PROD.ADVA.AA_CLV_FINAL_PREDICTIONS_MAX_ANCHOR_DT`. Updated weekly Mondays. Not historical revenue.

**CPA** — Cost Per Acquisition. `Paid Spend / Attributed Conversions`.

**D2C** — Direct-to-Consumer. Online/app orders via URBN sites/apps. Processed by Sterling OMS. Contrast with Retail.

**Demand** — Order placed, regardless of fulfillment. **Marketing-facing metric.** Contrast with Sales.

**Demand Lapsed** — RFM label. Customer ordered in last 12 months but returned everything (net spend = 0).

**EU / NA** — Europe (`SRC_ID = 200`) / North America (`SRC_ID = 100`).

**Formulated IID** — Email-only identity match, lower confidence. Starts with `1`. Promotes to Sustained on first full order.

**HID** — Household Identifier. Multiple IIDs at same address.

**IID** — Individual Identifier. **Primary customer key everywhere in EDW.** Always `COUNT(DISTINCT IID)`. Always filter `IID <> '-1'`.

**Long SKU** — 14-char full SKU (`[brand]_[ISKU]`). Internal EDW format.

**MTA** — Multi-Touch Attribution. Distributes fractional demand credit across pre-purchase touchpoints. Two systems: legacy in-house + Rockerbox.

**NAR** — New / Active / Reactivated customer status. Per order: New = no prior purchase at brand; Active = ordered within 365 days; Reactivated = lapsed >365 days then returned. Field: `NAR_BRAND_D` on MTA view. Values prefixed `'1. NEW'`, `'2. ACTIVE'`, `'3. REACTIVATED'`.

**NCOA** — National Change of Address. Merkle process updating customer addresses + refreshing CDI linkage. CDI/MTA pause during NCOA window.

**OTB** — Open-to-Buy. Merch budget concept — planned inventory available to purchase.

**PII** — Personally Identifiable Information. Masked under `RO_ROLE_PROD`. Request `PII_ROLE_PROD` only when truly needed.

**Purge Flag (`PURGE_FLG`)** — On `DW_PRD_SKU`. `'Y'` = class/vendor/style/colour/size combo retired and reused. **Always filter `PURGE_FLG = 'N'`** to avoid duplicates.

**Reclass** — SKU moved from one merchandise class to another. New SKU created; old points to new via `FINALRECLASSSKU`.

**RID** — Residence Identifier. Multiple HIDs at one physical address.

**RFM** — Recency, Frequency, Monetary. Customer segmentation over past 12 months. **Backward-looking** (vs. CLV which is forward-looking). 5 scores per dimension, ~12 named labels.

**ROAS** — Return on Ad Spend. `Attributed Demand / Paid Spend`.

**Sales** — Fulfilled and paid revenue. Used by product, finance, merch. Contrast with Demand.

**Sell-Through** — `units_sold / (BOP_on_hand + units_received)`. Calculated, not a raw EDW table.

**Short SKU** — 8-digit identifier used at POS, on receipts. Also `DIRECTSELLINGNUMBER` in `DW_PRD_SKU`.

**SKU** — Stock Keeping Unit. Most granular product unit (one style, one colour, one size).

**Sustained IID** — Name + address resolved match, high confidence. Starts with `0`.

## Technical abbreviations

| Abbrev | Meaning |
|---|---|
| AA | Advanced Analytics |
| ADVA | The `ADVA` schema in `EDW_PROD` — model outputs and MTA |
| BA | Business Analyst |
| BI | Business Intelligence |
| BW | TIBCO BusinessWorks |
| CDC | Change Data Capture (Qlik Replicate / Attunity) |
| CDI | Customer Data Integration |
| CE_ | Common Export table prefix |
| CRM | Customer Relationship Management |
| D2C | Direct-to-Consumer |
| DC | Distribution Centre |
| DM_ | Data Mart prefix |
| DW_ | Data Warehouse prefix |
| EDW | Enterprise Data Warehouse |
| ESB | Enterprise Service Bus (TIBCO) |
| ETL | Extract, Transform, Load |
| FiveTran | Pipeline tool ingesting Salesforce Service Cloud → Snowflake |
| GA4 | Google Analytics 4 |
| GTIN | Global Trade Item Number (barcode) |
| HID | Household Identifier |
| IID | Individual Identifier |
| IP | Island Pacific (ERP) |
| ISKU | Inventory SKU (Long SKU format) |
| MTA | Multi-Touch Attribution |
| NAR | New / Active / Reactivated |
| NCOA | National Change of Address |
| ODS | Operational Data Store |
| OMS | Order Management System (Sterling) |
| OTB | Open-to-Buy |
| PII | Personally Identifiable Information |
| PIM | Product Information Management (STEP) |
| PLM | Product Lifecycle Management |
| PO | Purchase Order |
| POS | Point of Sale |
| Q_ | Quantisense (legacy table prefix) OR derived column prefix — context-dependent |
| RBX | Rockerbox |
| RFC | Request for Change |
| RFM | Recency, Frequency, Monetary |
| RID | Residence Identifier |
| ROAS | Return on Ad Spend |
| SFD | Salesforce |
| SFMC | Salesforce Marketing Cloud |
| SFSC | Salesforce Service Cloud |
| SOM | Sterling Order Management |
| SRC_ID | Source ID column. 100 = NA, 200 = EU |
| SS | Same-Session (primary MTA window) |
| STEP | URBN's PIM system |
| TDID | Trade Desk ID |
| TTD | The Trade Desk (DSP) |
| UID2 | Unified ID 2.0 |
| VSW | Virtual Store Warehouse — non-physical location in `DW_LOC_STR` |
| YFS | Yantra Fulfillment System (Sterling's historical name) |
| 14DLC | 14-Day Last Click (legacy MTA window) |

## Systems and vendors

| Name | What it is |
|---|---|
| **A15** | URBN's ecommerce platform (web + app). Passes orders to Sterling via TIBCO |
| **Attentive** | SMS marketing vendor. ODS prefix `ATTENTIVE_*` |
| **Blue Cherry** | Wholesale OMS / ERP |
| **Bluecore** | Trigger engine for behavioural email — fires triggers, SFMC delivers. Replaced Interaction Studio FY26 |
| **Cheetah Digital** | Pre-SFMC email platform. Cutover June 30 2021 |
| **Crealytics** | Paid search agency |
| **Dynamic Yield** | On-site personalization, replaced Salesforce Interaction Studio Q1 FY27 |
| **Epsilon** | Legacy programmatic DSP |
| **FiveTran** | Pipeline tool for Salesforce Service Cloud |
| **Innovid** | Ad server (acquired Flashtalking 2025). Serves Epsilon AND TTD. EDW prefix retained as `FT_*` |
| **IBM Sterling** | OMS for D2C |
| **Island Pacific (IP)** | ERP / retail merchandising. System of record for SKUs, inventory, retail sales |
| **Merkle** | Identity resolution vendor. KL/Merkury for NA, AI for international |
| **MicroStrategy** | Enterprise BI. Reads `MCRSTRTTGY` schema |
| **MoveIt** | SFTP file transfer for vendor feeds |
| **Narvar** | Post-purchase tracking. ODS prefix `NARVAR_*` |
| **o9** | Merchandise planning. Feeds to/from `EDW_PROD.PLAN` |
| **Qlik** | Self-service BI. Reads from EDW |
| **Qlik Replicate (Attunity)** | CDC tool replicating sources → Snowflake ODS in near-real-time |
| **Rockerbox** | Third-party MTA, replacing in-house. Snowflake share materialized to `EDW_ODS_PROD.URBN.RBX_*` |
| **Salesforce** | CRM (Service Cloud), email (SFMC), CDP (Data Cloud) |
| **SessionM** | Old UO loyalty platform. **Removed FY26.** Don't use any SessionM-era tables/columns for current analysis |
| **Skybot** | URBN's ETL job scheduler |
| **Snowflake** | Data warehouse platform. Account: `urbanoutfittersinc.us-central1.gcp` |
| **STEP** | URBN's PIM system |
| **The Trade Desk (TTD)** | DSP, programmatic test partner |
| **TIBCO** | Enterprise Service Bus — routes/transforms data between systems |
| **Tradestone** | Purchase order management |
| **URBNCat** | Product catalogue / PIM integration (A15 catalogue layer) |
