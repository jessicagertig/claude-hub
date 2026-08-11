# Phase 4, items 1 and 2 — code-side title and meta description rewrites

Branch: `seo-phase-4-metadata-headings` (already checked out; nothing created, committed or pushed).
Ownership: files under `web/pages/` and `web/components/` EXCEPT `web/pages/plato.js`, `web/pages/blog/[slug].js` and `web/components/seo.js`.

13 files edited, one line each. Every value copied byte-for-byte from the workbook; nothing trimmed, nothing invented.

## Item 1 — titles (tab 07)

Five rows of tab 07 map to files I own. For each, I worked out whether the cell value already carries the ` | Polymer` suffix that `web/components/seo.js` line 18 appends, and passed the cell value MINUS that suffix as the `pageTitle` prop where it does.

| Sheet row | File | Cell has suffix? | `pageTitle` prop now | Rendered `<title>` | Len |
|---|---|---|---|---|---|
| 8 | `web/pages/pricing.js` line 37 | no | `Polymer Pricing - Simple ATS Plans from $124/mo` | + ` \| Polymer` | 57 |
| 10 | `web/pages/features/jobboard.js` line 13 | YES | `Job Board Software - Branded, Instant, Free to Start` | `... Free to Start \| Polymer` | **62 — BREACH** |
| 11 | `web/pages/blog.js` line 57 | YES | `Hiring & Recruiting Blog - Guides and Templates` | `... and Templates \| Polymer` | 57 |
| 12 | `web/pages/about.js` line 23 | no | `About Polymer - The Team Behind the Simple ATS` | + ` \| Polymer` | 56 |
| 13 | `web/pages/changelog.js` line 57 | no | `Polymer Changelog - What's New in the ATS` | + ` \| Polymer` | 51 |

Only sheet row 10 breaches the tab's own `<=60 chars` limit. E10 is 62 characters as the auditor wrote it, so the breach exists in the workbook copy itself, not in anything I did — passing the 52-character prop reproduces E10 exactly and lands at 62. Reported, not trimmed (rule 4). Question appended for Jessica.

The other four render at 51-57, all inside the limit.

### The two "(keep)" rows I skipped, and how I identified them

Sheet row 14 (`https://www.polymer.co/terms`) and sheet row 15 (`https://www.polymer.co/privacy`).

Identified by the literal six-character text `(keep)` in column E — E14 and E15. NOT by formatting: the tab-07 read agent computed a per-cell formatting signature for all 65 cells in A7:E19 and found exactly one distinct signature across every one of them (Inter 10pt, no bold/italic/strike, theme-1 colour, no fill, wrap on, vertical top, General format, single thin FFE2E8F0 bottom border, row height 27.75). There is no strikethrough, no fill and no colour marking anything on that tab, so the text string is the only signal and it is the one I used. Column D corroborates both rows ("Legal page - acceptable as-is").

Consequence in code: `web/pages/terms.js` line 9 still reads `pageTitle="Terms of service"` and `web/pages/privacy.js` line 60 still reads `pageTitle="Privacy policy"`. Neither was touched for a title. `terms.js` WAS edited, but for its meta description only (tab 12 row 15) — a different field, prescribed by a different tab. The `(keep)` marker on tab 07 covers the title tag and nothing else.

### Titles NOT actioned because I do not own the file

- Sheet row 7, `/` — `web/components/seo.js` line 19 default string. Excluded from my ownership by name.
- Sheet row 9, `/plato` — `web/pages/plato.js`. Excluded from my ownership by name. (It shows as already changed in the working tree by whoever owns it.)
- Sheet rows 16-19, all four `/blog/<slug>` posts — Sanity `blogPost.pageTitle`, rendered through `web/pages/blog/[slug].js`. Not repo files, and `[slug].js` is excluded by name regardless.

### Titles left alone because the tab does not list them

Tab 07 lists 13 URLs. I did not touch `pageTitle` on any page absent from the tab — the seven industry pages, `features.js`, `features/candidate-management-software.js`, `404.js`, `privacy.js`. Their tab-12 meta descriptions were prescribed; their titles were not.

## Item 2 — meta descriptions (tab 12)

Eight rows of tab 12 map to files I own. All eight were already under 155 characters as written, and `seo.js` appends nothing to `metaDescription`, so nothing breaches.

| Sheet row | File (line 89 unless noted) | Len |
|---|---|---|
| 7 | `web/pages/industries/applicant-tracking-for-real-estate-companies.js` | 140 |
| 8 | `web/pages/industries/applicant-tracking-for-healthcare-companies.js` | 128 |
| 9 | `web/pages/industries/applicant-tracking-for-legal-services.js` | 131 |
| 10 | `web/pages/industries/applicant-tracking-for-greentech-companies.js` | 124 |
| 11 | `web/pages/industries/applicant-tracking-for-cryptocurrency-companies.js` | 121 |
| 12 | `web/pages/industries/applicant-tracking-for-startups.js` | 125 |
| 13 | `web/pages/industries/applicant-tracking-for-fintech-companies.js` | 116 |
| 15 | `web/pages/terms.js` line 10 | 104 |

### "Fix the template once" — seven per-page edits ARE the template-level answer

The tab's own note (A4) says "The industry-page template repeats a two-sentence pattern - fix the template once." I checked how the seven pages are actually constructed before deciding, and a single shared fix is not available:

- There is no shared industry template module. `web/components/industries/` exports `IndustryHeader`, `IndustryFeatures`, `IndustryBenefits` and `IndustryIntegrations` — presentation components. None of them builds or holds a meta description.
- Each of the seven page files declares its OWN local `const verticalData` (line 17) and builds its meta description inline at line 89 as `` metaDescription={`${verticalData.heroDescription} <tail>`} ``.
- The tail sentence differs on every one of the seven — "Simple, powerful ATS built for real estate brokerages and proptech companies.", "... for healthcare and medical technology organizations.", "... built for law firms and legal departments. Start your free trial today.", "... designed for greentech and climate companies.", "... designed for cryptocurrency and blockchain companies.", "Purpose-built ATS for fast-growing startups.", "... built for growing fintech companies." Seven distinct strings in seven files. There is no single place to edit.
- The shared half, `verticalData.heroDescription`, is ALSO passed to `<IndustryHeader description={verticalData.heroDescription} />` at line 95 — it is the visible hero paragraph. Shortening it to fix the meta description would rewrite what a visitor reads on the page.

So replacing the template literal at line 89 with the plain string from tab 12 column D, in each of the seven files, is the template-level fix: it is the smallest change that reaches every instance of the repeated pattern, and it leaves the hero copy untouched. Each page keeps its `verticalData.heroDescription` exactly as it was; only the `metaDescription` prop stops deriving from it.

### Meta descriptions NOT actioned

- Sheet row 14, `/blog/first-impression-bias` — Sanity `blogPost.metaDescription`, project `a6d1clb1`, dataset `production`. Not a repo file; another agent owns Sanity.

### Copy fidelity note carried forward, not acted on

Tab 12 D12 (`/applicant-tracking-for-startups`) joins its clauses with a bare ASCII hyphen — "...decide together - without enterprise complexity or cost." That is U+002D in the workbook, not an en dash. Transcribed exactly as written per rule 4. Same shape as D14, which is not mine.

## Verification

1. All 13 edited files parse under `next/babel` — no JSX breakage from the literal apostrophe in `"Polymer Changelog - What's New in the ATS"` or the bare `&` in `"Hiring & Recruiting Blog - Guides and Templates"`. Both forms already exist in the repo: `web/pages/terms.js` line 10 carries `Polymer's` inside a double-quoted JSX attribute.
2. Every emitted `pageTitle` and `metaDescription` string literal was read back out of the parsed AST and compared byte-for-byte against the workbook cell. All 13 match exactly. Rendered title lengths recomputed from the AST values plus the ` | Polymer` append: 57, 62, 57, 56, 51.

## Files edited

```
web/pages/pricing.js
web/pages/blog.js
web/pages/about.js
web/pages/changelog.js
web/pages/terms.js
web/pages/features/jobboard.js
web/pages/industries/applicant-tracking-for-real-estate-companies.js
web/pages/industries/applicant-tracking-for-healthcare-companies.js
web/pages/industries/applicant-tracking-for-legal-services.js
web/pages/industries/applicant-tracking-for-greentech-companies.js
web/pages/industries/applicant-tracking-for-cryptocurrency-companies.js
web/pages/industries/applicant-tracking-for-startups.js
web/pages/industries/applicant-tracking-for-fintech-companies.js
```

`web/pages/plato.js` and `web/components/plato/platoHero.js` also show as modified in the working tree. Neither is mine and I did not touch them.

Nothing appended to `BLOCKED.md`; not blocked.
