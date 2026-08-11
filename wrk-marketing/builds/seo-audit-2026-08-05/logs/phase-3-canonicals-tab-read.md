# Phase 3 — read "04 Canonicals" tab (read-only item)

No log filename was given in my task; existing logs are `phase-1.md` and `phase-2.md`, so I created this
distinctly-named file rather than appending to another agent's log.

## Tab rows read
`04 Canonicals`, all 47 rows x 4 cols. Rows read: A1, A2, A4 (merged A4:D4), header row 6 (A6-D6),
and every data row 7-47 (columns A-D). Cross-checked row count against `01 Orphaned Pages` rows 7-16.

## Files touched
None. This item is read-only reporting; no repo file was edited.

## Formatting scan
Compared per-cell font/fill/alignment/border signatures for every cell A7:D47. All 41 data rows are
byte-identical in formatting (Inter 10pt, not bold, not italic, no fill, wrap on, vertical top,
single thin FFE2E8F0 bottom border). Row heights all 15.75. No conditional formatting, no hyperlinks,
no merged cells outside A4:D4. Freeze panes A7, autofilter $A$6:$D$47. **No formatting outliers.**

## Content observations (not formatting)
- Rows 7-37 = the 31 crawled 2xx pages. Row 38 = the backlinked parameter URL. Rows 39-47 = 9 orphans.
  41 total, matching the A4 note "Every crawled 2xx page (31) plus the orphaned set and the backlinked
  parameter URL."
- Row 38 is the only row where the "Canonical to set" value differs from the "URL" value:
  URL `https://www.polymer.co/?partner_source=whatjobs (parameter URL, 243 backlinks)` ->
  canonical `https://www.polymer.co/`. Its Note also differs: "Canonical consolidates the partner-parameter
  link equity to the homepage". Note that the A38 cell text carries the parenthetical
  " (parameter URL, 243 backlinks)" INSIDE the URL string — it is annotation, not part of the URL.
- Rows 39-47 carry the Note "Also canonicalize the 10 orphaned posts when re-linked" but there are only
  9 such rows. Cross-checked `01 Orphaned Pages` (10 URLs, rows 7-16): the 10th orphan,
  `https://www.polymer.co/blog/first-impression-bias`, appears in tab 04 at row 29 inside the main
  crawled block, because tab 01 row 15 records it as "crawlable only via one deep path (depth 4)".
  So all 10 orphans are covered; there is no missing row.
- Every Note in rows 7-37 reads "Self-referencing canonical via Next.js metadata" — the audit assumes the
  App Router Metadata API (`metadata.alternates.canonical`), which does not exist in this Pages Router
  repo. The canonical VALUES in column C are unaffected; only the delivery mechanism named in the Note is.
  Already covered by the task context, so no question was filed.

## Could not do
Nothing.
