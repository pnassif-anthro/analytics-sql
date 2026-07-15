# Contributing

Lightweight on purpose — this is a small analytics team, not a software release process.

## Branching

- `main` = validated, trustworthy queries only. Anything here should be safe for someone else to run and cite.
- Create a branch per query or analysis: `yourname/short-description`, e.g. `paul/ttd-rfm-migration`.
- Personal, exploratory ad-hoc work can be pushed straight to your own `ad-hoc/` file on a branch without heavy review — but still needs the header block before merging.

## Pull requests

Required for anything landing in a **named/shared folder** (i.e. not a personal ad-hoc scratch query). PR description should answer:

1. **What table(s) does this depend on?** (call out anything in `shared/` it should have reused but didn't, if applicable)
2. **Has this been run against prod and spot-checked?** How — row counts, comparison to a known dashboard number, reconciliation against a prior version?
3. **Vertical + folder** — does this belong where you put it, or should it move to `shared/` because other teams will need it too?

See `.github/PULL_REQUEST_TEMPLATE/pull_request_template.md` — GitHub will auto-populate this for you.

## Review bar

A reviewer should be able to answer "would I trust this number in front of an exec" after reading the header + skimming the CTEs. If they can't, ask for either better comments or a diagnostic query showing the validation.

## Adding a new query

1. Copy `_templates/query_template.sql` into the right vertical/subfolder.
2. Fill out the header completely — don't skip fields.
3. If it's more than a straightforward pull (i.e. an actual analysis with findings/decisions), also copy `_templates/analysis_template.md` into the same folder.
4. Add a row to `INDEX.md`.
5. Open a PR.

## Updating an existing query

- Bump `Last validated` in the header.
- If the change is because an underlying table/schema changed (e.g. an MTA platform migration), add a one-line note explaining what changed and when.
- If the query is being superseded rather than fixed, move the old version to `archive/` instead of deleting it — history has value when someone asks "why did the number change."

## Deprecating a query

Move it to `archive/<vertical>/` (mirroring its original path) rather than deleting. Add a one-line note at the top of the file: what replaced it and why.
