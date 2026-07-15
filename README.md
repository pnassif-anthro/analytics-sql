# analytics-sql

Shared repository of SQL queries and analyses for the Analytics team, spanning three verticals: **Marketing**, **Customer**, and **Digital**. Runs against the URBN Enterprise Data Warehouse (Snowflake).

The goal of this repo: when someone asks "how do we usually calculate X" or "has anyone already built a query for Y," the answer should be a `git grep` away instead of a Slack thread nobody can find six months later.

## Who this is for

Analysts on the Marketing, Customer, and Digital analytics teams querying the URBN EDW. If you're new to the warehouse, start with `shared/core-tables/` and `shared/identity-bridges/` before writing anything vertical-specific — most cross-team confusion comes from re-deriving identity resolution or order-header joins slightly differently three times.

## Folder structure

```
analytics-sql/
├── marketing/              # MTA, MMM, incrementality tests, weekly recaps, ad-hoc
├── customer/                # RFM/CLV, loyalty, identity resolution, ad-hoc
├── digital/                 # web analytics, site experience, ad-hoc
├── shared/                  # cross-vertical: identity bridges, core tables, reusable snippets
├── archive/                 # deprecated/superseded queries, kept for history
├── _templates/               # copy these when adding new files
└── .github/                  # PR template
```

Each vertical follows the same internal pattern: a few named subfolders for recurring workstreams, plus an `ad-hoc/` catch-all for one-off pulls that don't yet deserve a permanent home. If an ad-hoc query gets reused 2-3 times, promote it into a named subfolder.

## Before you write a new query

1. **Check `shared/` first.** Identity resolution (IID/CDI/UID2 bridges), core order/session tables, and common date-window or dedup patterns should be reused, not reinvented.
2. **Check the relevant vertical folder** for something close to what you need — better to fork an existing validated query than start from a blank Snowflake worksheet.
3. If nothing exists, use the template in `_templates/query_template.sql`.

## File naming

`YYYYMM_short-description.sql`, e.g. `202607_ttd_low_rfm_cohort_migration.sql`. The date prefix is the date the query was authored/last substantially revised — not the date range of the data it pulls. This keeps folders sorted chronologically and makes staleness visible at a glance.

## Every query needs a header

See `_templates/query_template.sql`. At minimum: title, vertical, author, created date, last-validated date, purpose, key tables, filters applied, and known caveats. This is non-negotiable — an undocumented query is functionally equivalent to no query, since nobody downstream can trust it without re-deriving what it does.

## SQL style

See [`STYLE_GUIDE.md`](./STYLE_GUIDE.md).

## Analyses vs. queries

- **Just a query** (weekly recap pull, ad-hoc metric check) → `.sql` file with header, that's it.
- **A real analysis** (incrementality test design, cohort migration study, measurement framework) → pair the `.sql` with a `.md` writeup in the same folder using `_templates/analysis_template.md`. The SQL is the "how," the markdown is the "why and what we found."

## Keeping things from rotting

- Anything not re-validated in **6 months** should get flagged in the next PR that touches it, or moved to `archive/`.
- `INDEX.md` (see below) tracks owner + last-validated date per file. Update it when you add or materially change a query.
- If a table name or schema changes underneath a query (this happens — see the Rockerbox MTA migration), fix the query, bump `Last validated`, and leave a one-line note in the header about what changed.

## Index

`INDEX.md` is a flat, searchable table of every query in the repo — vertical, title, owner, last validated. Regenerate or hand-update it whenever you add a file; there's a helper script at `_templates/generate_index.py` if the repo grows large enough that hand-maintenance becomes annoying.

## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md) for branch/PR conventions.
