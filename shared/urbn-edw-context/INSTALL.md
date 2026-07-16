# urbn-edw-context — Installation & usage

A Cowork skill that teaches Claude how to work with URBN's EDW the way a marketing analyst would. Built from the EDW Guide Series (Database Structure Reference, URBN Data Glossary, Marketing Analyst Guide, Guide for Marketers, Customer Data Guide, Marketing Data and MTA, Web Analytics Data Guide).

## What's in here

```
urbn-edw-context/
├── SKILL.md                              ← entry point, ~150 lines, always loaded
└── references/
    ├── database-structure.md             ← schemas, prefixes, column conventions
    ├── customer-identity.md              ← IID/CDI/HID, identifier crosswalk, Salesforce migration
    ├── loyalty-and-clv.md                ← UO/AN/FP loyalty, signup channels, CLV, RFM
    ├── email-and-sfmc.md                 ← DW_EMAIL_* tables, KPIs, gotchas
    ├── web-analytics-ga4.md              ← all 7 DW_WA_* tables, GA4 pipeline
    ├── mta-and-attribution.md            ← legacy + Rockerbox, channel taxonomy, ROAS
    ├── refresh-and-maintenance.md        ← cadences, CDI windows, troubleshooting
    └── glossary.md                       ← business terms, abbreviations, vendors
```

The main `SKILL.md` is what Claude sees first. The reference files load on demand only when Claude determines they're relevant — so the full skill is ~1,400 lines but only the ~150-line `SKILL.md` plus a small description is in context most of the time. That's progressive disclosure, the whole point of how skills work.

## Install — three options

### Option A: Personal install, fastest

Drop the whole `urbn-edw-context/` folder into:

```
~/.claude/skills/urbn-edw-context/
```

Claude Cowork picks it up automatically on next session start. No restart needed.

### Option B: Team plugin (recommended for the team)

If you're standing up a shared `urbn-analytics-plugin` for the team:

```
urbn-analytics-plugin/
├── .claude-plugin/
│   └── plugin.json
└── skills/
    └── urbn-edw-context/        ← drop the folder here
        ├── SKILL.md
        └── references/
            └── ...
```

Use the `cowork-plugin-management` plugin from `anthropics/knowledge-work-plugins` to scaffold the plugin.json. Once the plugin is in a shared location (Drive, internal git, GitHub), anyone on the team installs it once and gets the skill.

### Option C: Git repo

Same content as B, but versioned. This is the right long-term answer — pull requests, code review, history. The `urbn-analytics-skills` repo eventually holds many skills like this one.

## Validating it works

Open a fresh Cowork session in your working folder. Try a question that should trigger the skill, like:

> *"Pull weekly NAR by channel for AN for the last 13 weeks. Compare to LY. Use the right MTA view and exclude unmatched orders."*

Watch for:

- ✅ Does Claude use `EDW_PROD.ADVA.MTA_TOTAL_POINTS_ATTRIBUTED_V` (the `_V` view, not the underlying table)?
- ✅ Does it filter `IID <> '-1'`?
- ✅ Does it use `NAR_BRAND_D` field with values like `'1. NEW'`, `'2. ACTIVE'`, `'3. REACTIVATED'`?
- ✅ Does it join to `DW_CALENDAR_HIERARCHY` on `CALENDAR_DT` and use `CURRENT_YEAR_ID IN (0, -1)` for TY/LY?
- ✅ Does it use `DAY_FRACTIONAL_CUSTOMER_BRAND` for customer count, not `COUNT(DISTINCT IID)`?
- ✅ Does it set the session header (`USE ROLE`, `USE WAREHOUSE`, etc.)?

If yes to all, the skill is working. If any are missed, look at which reference file would have covered that rule and either (a) make sure the trigger description in `SKILL.md` actually matches the request, or (b) move that rule up into the main `SKILL.md` from the reference file.

## Maintenance

The EDW guides on Confluence are the source of truth. When they change (most likely areas: Rockerbox migration progress, RBX V3 sandbox graduating to PROD, new SMS vendor table replacing `DW_SMS_ACTIVITY`, the Direct/`conv_only` workaround being formalized), update the corresponding reference file. Bump a version note at the bottom of `SKILL.md` if you want to track.

Things most likely to need updating in the next 6 months:

- **October 2026 operational launch:** The RBX sandbox tables (`RBX_MTA_TOTAL_POINTS_ATTRIBUTED_V4_RJ`, `RBX_MTA_ORDER_LKUP_V1_RJ`, `RBX_MTA_TOTAL_POINTS_ATTRIBUTED_V_RJ`) **will get new production names** before then. Update `mta-and-attribution.md` and the `SKILL.md` quick reference table when EDW announces the final names.
- **URBN Tuned Model:** V4 currently runs the RBX default model. When the URBN-tuned model lands, update the "what's blocked" guidance — deep dives become unblocked. Watch for the EDW announcement.
- **NAR / fractional customer columns on the joined view:** Currently being added incrementally as they clear QA. When the joined view (`*_V_RJ`) is fully populated, remove the "skeleton" framing in `mta-and-attribution.md`.
- **MTA Roll-Up Phase 2:** Currently fully blocked pending session metric QA + brand alignment session. When that scope is decided, document the new rollup approach.
- **EDW-4508** (Direct / `conv_only` formalization in comparison views) — when the views split this out properly, update the channel section.
- **SMS** — when `DW_SMS_ACTIVITY` replacement lands, update `email-and-sfmc.md`.
- **Bluecore clicks** — when click tracking flows into EDW, remove that gotcha from `email-and-sfmc.md`.

## Pairing with other skills

This skill is the foundation. Layer additional skills on top for specific deliverables:

- `analytics-readout-format` — your team's standard report structure (headline, what changed, why, risks, next actions)
- `mmm-readout` — your existing Keen-export-to-formatted-workbook skill
- `clv-cohort-methodology` — cohort definitions, projection horizon disclosure
- `incrementality-test-design` — geo holdout / ghost ad templates

Each should reference this skill for warehouse/identity context rather than redefining it.
