# EDW Reference

Reference documentation for the URBN Enterprise Data Warehouse (Snowflake) — schema conventions, table prefixes, customer identity resolution, MTA/attribution, and channel outbound data.

## What this is

This started as internal reference material (`urbn-an-data-analyst` skill docs) used to give context before writing SQL against `EDW_PROD` / `EDW_ODS_PROD` — things like which table to use for a given metric, how IID/CDI/UID2 identity resolution works, and MTA/Rockerbox migration context. It's included here so the whole team has a shared, versioned source of truth instead of it living only in one person's tooling.

## Files

| File | Covers |
|------|--------|
| `SKILL.md` | Top-level orientation: when to use which reference doc, general query patterns |
| `references/db-structure.md` | Database/schema layout, table prefix conventions |
| `references/customer-identity.md` | IID/CDI, identity bridges, UID2 resolution |
| `references/channel-outbound.md` | Cross-channel outbound send data (email, SMS, push) for MMM/campaign analysis |
| `references/mta-attribution.md` | MTA tables, Rockerbox migration context, attribution field conventions |

## Keeping this current

This content will drift out of date as schemas change (e.g. the ongoing Rockerbox MTA migration). Treat it the same as any other file in this repo:

- If you catch something stale while writing a query, fix it in the same PR and note what changed.
- If a table gets deprecated or renamed, update the relevant reference doc — don't just fix your own query and leave the doc wrong for the next person.
- Anything not touched in 6+ months should get a sanity-check pass, same as the rule in the root `README.md`.

## Relationship to query files elsewhere in the repo

When a query in `marketing/`, `customer/`, or `digital/` relies on a non-obvious identity resolution pattern or table convention, its header's "Related doc" field should point here rather than re-explaining the convention inline.
