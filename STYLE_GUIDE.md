# SQL Style Guide

House style for this repo. The goal is that any analyst can open any query cold and understand it in under a minute — consistency matters more than any individual preference.

## Structure

- **CTE-based, not deeply nested subqueries.** Break logic into named steps. If you can't describe what a CTE does in one sentence, split it further.
- **One canonical CTE per identity resolution step.** Don't inline an IID/UID2/email resolution join into a larger CTE — pull it out so it's obviously reusable and auditable.
- **Diagnostic query before production query, when a metric is contested or new.** If you're building something where the number could be challenged (attribution totals, a new cohort definition, a reconciliation), commit the diagnostic query that validates row counts / dedup logic alongside the final query. This preserves the "why we trust this number" trail — don't make the next person re-derive your confidence from scratch.
- **CTAS/temp tables** for anything reused across multiple downstream queries in the same analysis — don't copy-paste the same CTE into five files.

## Filters

- **Spell out filters explicitly** in the query rather than relying on a view's default scope. E.g. `BRAND_CD = 'AN'`, `PURCHASE_CHANNEL = 'DIRECT'` — even if a view technically pre-filters, state it so the query is self-contained and portable to other brands/channels later.
- **Comment any non-obvious filter or exclusion** inline — e.g. why Rakuten Rewards is excluded from a channel comp, or why a particular campaign string is filtered out.

## Naming

- Use `snake_case` for CTEs and aliases.
- Name CTEs for what they contain, not how they were built (`customer_rfm_snapshot`, not `cte1` or `joined_data`).
- Alias tables with short, consistent abbreviations across the repo where possible (e.g. `oh` for order header, `xref` for identity crosswalks) — check `shared/` for existing conventions before inventing a new one.

## Dates & windows

- Default to explicit date parameters at the top of the query (as variables/CTEs), not hardcoded mid-query, so the window is obvious and easy to shift.
- State the timezone/week-start convention if it matters (e.g. Sun–Sat rolling windows for MTA channel dashboards).

## Comments

- Header block (see `_templates/query_template.sql`) is required on every file.
- Inline comments for: any assumption, any known data-quality caveat, any place where "the obvious query" would be wrong (e.g. CVR denominator effects, fractional order handling).

## What NOT to do

- Don't inherit filters silently from a view and leave them undocumented.
- Don't leave commented-out old logic in a committed file — if it's worth keeping, it belongs in `archive/` or git history, not as dead code inline.
- Don't hardcode a table name from a system that's mid-migration (e.g. legacy MTA vs. Rockerbox) without a comment flagging which system it targets and why.
