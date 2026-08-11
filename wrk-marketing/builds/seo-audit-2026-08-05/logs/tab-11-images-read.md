# Tab "11 Images" — read-only dump

Task: read workbook tab "11 Images" (79 oversized files + the 111 images missing dimensions), return every row verbatim, flag formatting anomalies.

Command run:
`python3 /Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/read-workbook.py "11 Images"`

No files under `/Users/jessica/wrk/wrk-corp/wrk-marketing` were read, written, or modified. No binary asset touched.

## Shape

- Sheet: 85 rows x 4 cols, 323 filled cells.
- Rows 3 and 5 are empty spacers.
- Rows 1, 2, 4, 6 are the title / brand banner / instruction note / column header.
- Rows 7-85 are the 79 data rows.
- Columns: A `Image URL`, B `Size (Bytes)`, C `Size`, D `Fix batch`.

## The 111 images missing width/height are NOT enumerated anywhere in the workbook

Ran `read-workbook.py survey` across all 19 tabs. The only mention of the 111 is the prose in cell A4 of this tab: "ALL 111 images lack width/height attributes (CLS risk) - fix in the same templates." There is no per-image list, no page list, and no template list for that item — in this tab or any other. The 111 is a count only.

## Fix batch values (only two distinct values across all 79 rows)

- `Sanity: request fm=webp (or avif) + cap width at rendered size` — 71 rows.
- `next/image already optimizing; lower quality/width for marketing shots` — 8 rows (A66, A68, A69, A70, A71, A73, A76, A80).

## Anomalies flagged

1. **Eight URLs are truncated in the source spreadsheet.** The 8 `https://www.polymer.co/_next/image?url=...` rows contain a literal `...` where the encoded `/_next/static/media/` path prefix should be. They are not fetchable as written. Affected: A66 `jobdetail.f5606e05.png`, A68 `profile.5970387b.png`, A69 `billboard.602746ef.png`, A70 `jobsettings.a5f65853.png`, A71 `billboard.5d18896b.png`, A73 `plato-video-still.d3d29022.png`, A76 `chat-feature.6216d26a.png`, A80 `messages.314784b3.png`. The 71 `cdn.sanity.io` URLs are complete.
2. **A2 uses a different fill** (`FFF35C5A`, the MakeReality red) from A1 and A6:D6 (`FF111111`). A2 is the vendor brand banner, not a header.
3. **A4 is the only italic cell** (`italic, color:FF64748B`) — it is the tab's instruction note.
4. **No data row (7-85) carries any formatting.** No bold, no strike, no fill, no font color, no comment, no hyperlink. All 79 are formatted identically — no row is singled out.
5. **B column is stored as float**, not integer (`7044071.0`, not `7044071`).
6. **Row 8 is the standout data anomaly.** The source asset is `-800x600.png` yet it is requested at `w=2304` (upscaled ~2.9x) and weighs 6,625,346 bytes / 6.32 MB — the second-largest file on the sheet and by far the worst size-to-source-dimension ratio. Every other row's source is >= 1296px wide.
7. **The tab title says "over 100 kB"; C column is MiB-based.** 103151 bytes (row 85, the smallest) = 100.7 KiB, so the threshold holds, but C renders MiB ("6.72 MB" for 7,044,071 bytes = 6.717 MiB), not MB. Sizes in C are consistent with B throughout.
8. **All 71 Sanity URLs share identical query parameters**: `?w=2304&q=75&fit=clip&auto=format`. None requests `fm=webp` or `fm=avif`. All 8 next/image URLs share `&w=2304&q=75`.

## Not done

No code changes. This item was a read.
