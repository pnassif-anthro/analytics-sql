# Data Refresh and Maintenance

## Refresh cadences by domain

| Data area | Cadence | Notes |
|---|---|---|
| **CDI / customer identity** | Nightly | Paused once a month for NCOA + Rekey (~1 business day). Hari posts notice in `#marketingsystems_cloud_qa` |
| **MTA attribution** | Nightly **after CDI** | If CDI is paused, MTA is paused. Typically T-2 |
| **Email** (DW_EMAIL_*) | ~2 day lag from send | **Filter `Q_DT_IT` (send date), not `LOAD_DATE`** |
| **GA4 / web (DW_WA_*)** | Daily | Via Skybot ETL after BigQuery export |
| **GA4 fresh feed (`*_DAILY` tables)** | Daily, earlier | Available earlier than main summary |
| **Loyalty — Q_QL_CDI_LOYALTY_V** | Nightly via CDI | T-2 IID linkage. EU may not be available until next morning |
| **Loyalty — DW_SERVICES_SUBSCRIPTIONS** | Once daily ~6:45–7 AM EST | Same-day, A15 source, **digital-only** |
| **CLV** | Weekly Mondays | Use `_MAX_ANCHOR_DT` for current snapshot |
| **RFM** | Weekly Mondays | Quantile breakpoints recalculated weekly per brand |
| **Rockerbox log-level** | Incremental daily, 14-day lookback | `UPDATED_AT`-based |
| **Rockerbox aggregates** | Daily | |
| **RBX_MTA_POINTS_ATTRIBUTED_V3_RJ** | Daily Dynamic Table | Sandbox object |
| **FT_IMPRESSIONS (Innovid)** | Daily | |
| **TTD impressions** | T-1 per share schedule | |
| **CDC-replicated source tables (Sterling, etc.)** | Near real-time | Qlik Replicate (Attunity) |
| **Salesforce Service Cloud (FiveTran)** | Every few minutes | Raw ODS only |

## CDI maintenance — what happens

Once a month, Merkle runs NCOA (National Change of Address) + a full Rekey. This is when:

- CDI doesn't run for ~1 business day
- **MTA doesn't refresh** (depends on CDI)
- **NAR doesn't refresh** (depends on CDI)
- Interactive dashboards may look flat or stale

Hari posts an `@here` notice in `#marketingsystems_cloud_qa` ahead of time with the schedule. **Watch for this notice before investigating "missing" MTA data.**

Data catches up the next morning.

## When numbers look wrong

Order of investigation:

1. **Check `#marketingsystems_cloud_qa`** for an active CDI maintenance notice. If yes, that's it.
2. **Check the LOAD_DATE on email tables.** If filtering on `LOAD_DATE` rather than `Q_DT_IT`, recent sends will be missing.
3. **Check whether you're on `MARKETINGQA` instead of `URBN`.** Identical table names, very different completeness.
4. **Check whether the table is `_UA360`** (legacy) instead of the live GA4 table.
5. **Check whether `IID = '-1'` was excluded.** Including it can inflate or distort counts depending on the metric.
6. **Check fiscal calendar joins.** `CURRENT_YEAR_ID` filter wrong → wrong period.
7. **Check `BRAND_CD` filter.** Most tables include all brands — missing filter means cross-brand inflation.
8. If still off, post in `#marketingsystems_cloud_qa` with your query.

## Where to ask

| Question | Channel / contact |
|---|---|
| Marketing data, customer tables, MTA, GA4 | `#marketingsystems_cloud_qa` |
| Snowflake access, role issues, missing tables | `#edw-support-snowflake` |
| Microstrategy / Qlik / BI | `#edw-support-microstrategy` / `#edw-support-qlik` |
| Specific RBX questions | Rakesh Jain / Cherry Jain |
| GA4 pipeline, ETL, Skybot | Ryan Sweigart (via `#marketingsystems_cloud_qa`) |
| Table discovery, column definitions, lineage | Atlan — `urbn.atlan.com` |
| New data requests, bugs | EDW Jira project |

## Stakeholder communication

When a deliverable depends on data that may have lagged:

- State the data's anchor/cutoff date explicitly
- If MTA was used and CDI maintenance fell in the window, footnote it
- For Aug–Oct 2025 data: footnote the Salesforce migration POS gap (see `customer-identity.md`)
- For Bluecore campaigns: note that clicks aren't in EDW as of FY27 — pull from Bluecore UI if click metrics matter
- For EU brand MTA on RBX V3: state currency (GBP)
