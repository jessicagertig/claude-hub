# Log — read tab "07 Title Rewrites" (read-only item)

No log filename was given in my task. Existing read logs are `tab-06-backlinked-404-read.md` and
`phase-3-canonicals-tab-read.md`, so I followed the `tab-NN-<slug>-read.md` form rather than appending
to another agent's log.

## Tab rows read

`07 Title Rewrites`, all 19 rows x 5 cols, via
`python3 /Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/read-workbook.py "07 Title Rewrites"`:

- A1 (title banner), A2 (author banner), A4 (instruction note, merged A4:E4), row 6 (header A6-E6),
  rows 7-19 (13 data rows). Rows 3 and 5 are empty spacers.

## Files touched

None edited. Files read for corroboration only:

- `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/components/seo.js` lines 1-40
- `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/pages/_app.js` (grep — line 5 imports SEO)
- `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/pages/index.js` (whole file — renders no `<SEO>`)
- grep for `pageTitle` / `<SEO` across `pages/plato.js`, `pages/pricing.js`, `pages/about.js`,
  `pages/changelog.js`, `pages/terms.js`, `pages/privacy.js`, `pages/blog.js`,
  `pages/features/jobboard.js`, `pages/blog/[slug].js`

## Before -> after

No changes made. Nothing to quote.

## Formatting scan

Per-cell signature (font b/i/strike/underline/size/name/colour, fill, horizontal + vertical alignment,
wrap, number format, all four borders) computed for every cell A7:E19 — 65 cells, **1 distinct
signature**: Inter 10pt, not bold, not italic, no strike, theme-1 colour, no fill, wrap on, vertical
top, General number format, single thin `FFE2E8F0` bottom border. Row heights all 27.75. No conditional
formatting, no hyperlinks, no cell comments, no merged cells outside A4:E4. Freeze panes A7,
autofilter `$A$6:$E$19`.

**The two `(keep)` markers are TEXT ONLY.** E14 and E15 carry the literal string `(keep)` with the same
formatting as every other cell on the tab — no strike, no italic, no fill, no colour. There is no
formatting-only `(keep)` anywhere on the tab, and no formatting outlier in any row.

Character check: every cell A1:E19 is pure ASCII except A2's `·` (U+00B7 MIDDLE DOT). All dashes in the
Suggested rewrite column are ASCII hyphen-minus `-`, not en-dashes. The apostrophe in E13
(`Polymer Changelog - What's New in the ATS`) is a straight `'` (U+0027), not a curly one. Column C
values are floats (`27.0`, `17.0`, ...) with General number format, so they display as integers.

## Content observations (reported to the parent agent)

1. **Only 3 of the 11 actionable rewrites end with ` | Polymer`** — E9, E10, E11. For those three the
   `pageTitle` prop is the value minus that suffix. The other eight (E7, E8, E12, E13, E16, E17, E18,
   E19) do NOT contain the brand suffix, so `seo.js` line 18 (`pageTitle + " | Polymer"`) will append it
   and the rendered title will differ from the auditor's copy.
2. **E7 (homepage) cannot be produced through the `pageTitle` prop at all.** It reads
   `Polymer | Applicant Tracking System & Job Boards for Startups` — brand FIRST, no trailing suffix.
   `web/pages/index.js` renders no `<SEO>`; `web/pages/_app.js` line 5 imports it and renders it with no
   props, so the homepage currently falls through to `seo.js` line 19's default string
   `"Polymer: Hiring made simple"` — which is exactly B7. Setting E7 means editing that default, not
   passing a prop.
3. **Four rows exceed the tab's own `<=60 chars` limit once `seo.js` has appended.** E7 61, E10 62,
   E17 67 (57 + 10), E19 71 (61 + 10). E19 is already 61 before the append.
4. Rows 16-19 are blog posts. `web/pages/blog/[slug].js` line 241 passes `pageTitle={post.pageTitle}`
   from the Sanity `blogPost` document, so those four are Sanity edits, not repo edits — and the append
   applies to them the same way.

Items 1-3 recorded in `QUESTIONS-FOR-JESSICA.md` under "Tab 07 read (title rewrites)". None of them
blocks a read task.

## Could not do

Nothing.
