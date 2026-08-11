# Tab "17 Headings" — verbatim read

Source: /Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/Polymer-Technical-SEO-Audit_MakeReality.xlsx
Read via: `python3 read-workbook.py "17 Headings"` plus a direct openpyxl pass for rich-text runs,
underline, strikethrough, merged ranges and non-ASCII codepoints.

Sheet: 18 rows x 3 cols. Merged ranges: A4:C4 only. No cell comments, no hyperlinks,
no strikethrough, no underline, no rich-text runs anywhere on the tab.

## Banner / note rows

- A1: `Heading Hygiene (12 pages)` — bold, 16pt Agrandir, white on #111111
- A2: `MakeReality.io  ·  Polymer Technical SEO Audit ` — bold, 10pt Inter, white on #F35C5A.
  Contains U+00B7 MIDDLE DOT, double spaces either side of it, and one trailing space.
- A4 (merged A4:C4), the tab's own instruction note, italic 10pt Inter, colour #64748B:
  `Lowest priority. One real item: /plato - the flagship AI page - has no H1. The rest are template artifacts (ToC/CTA rendered as first H2).`
- A6/B6/C6 headers: `URL` / `Finding` / `Fix` — bold, 10pt Inter, white on #111111

## Data rows (7-18) — all identically formatted: 10pt Inter, no bold/italic/strike, no fill, top-aligned, wrap on

| Row | URL | Finding | Fix |
|---|---|---|---|
| 7 | https://www.polymer.co/plato | MISSING H1 | Add H1: 'Plato: AI candidate screening built into your ATS' |
| 8 | https://www.polymer.co/pricing | H2 'All plans include everything you need' duplicated | Fine to keep; low priority |
| 9 | https://www.polymer.co/blog/talent-acquisition | First H2 is 'Table of contents' | Make ToC a <nav>/aside, not a content heading |
| 10 | https://www.polymer.co/blog/first-impression-bias | First H2 is 'Table of contents' | Make ToC a <nav>/aside, not a content heading |
| 11 | https://www.polymer.co/blog/hiring-gen-z | First H2 is 'Table of contents' | Make ToC a <nav>/aside, not a content heading |
| 12 | https://www.polymer.co/blog/onboarding | First H2 is 'Table of contents' | Make ToC a <nav>/aside, not a content heading |
| 13 | https://www.polymer.co/blog/employer-branding-steps | First H2 is 'Table of contents' | Make ToC a <nav>/aside, not a content heading |
| 14 | https://www.polymer.co/blog/skills-mapping-for-hiring-a-complete-guide | First H2 is 'Table of contents' | Make ToC a <nav>/aside, not a content heading |
| 15 | https://www.polymer.co/blog/best-applicant-tracking-software | First H2 is 'Table of contents' | Make ToC a <nav>/aside, not a content heading |
| 16 | https://www.polymer.co/blog/one-click-distribution-to-we-work-remotelys-community-of-job-seekers | First H2 is boilerplate CTA 'Get your hiring process up and running in minutes.' | Move CTA below content headings |
| 17 | https://www.polymer.co/blog/post-jobs-with-whatjobs-across-500-partners | First H2 is boilerplate CTA 'Get your hiring process up and running in minutes.' | Move CTA below content headings |
| 18 | https://www.polymer.co/blog/post-to-we-work-remotely-6m-professionals-in-seconds | First H2 is boilerplate CTA 'Get your hiring process up and running in minutes.' | Move CTA below content headings |

## Character-level notes

Every data cell is pure ASCII. All quotes are straight apostrophes U+0027, never curly.
All hyphens are ASCII hyphen-minus, including the two in the A4 note around
`- the flagship AI page -`. No non-breaking spaces, no edge whitespace, no double
spaces in rows 6-18. The only non-ASCII character on the entire tab is the U+00B7
middle dot in the A2 banner.

`<nav>` in every C-column ToC row is literal cell text, not markup applied to the cell.

## Formatting divergence check

No row diverges. Rows 7-18 carry byte-identical font, fill, alignment and colour
settings; nothing on this tab resembles tab 07's "(keep)" marker (no strikethrough,
no italic, no fill, no colour, no rich-text run, no comment).

Row count matches the title: A1 says 12 pages, rows 7-18 are 12 rows.
