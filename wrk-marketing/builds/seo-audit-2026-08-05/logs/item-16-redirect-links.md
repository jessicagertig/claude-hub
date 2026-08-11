# Item 16 — "16 Redirect Links" (read-only transcription)

Log file name was not specified in my task prompt; created this one named for my item so I would not write into `phase-1.md` or `phase-2.md`, which other items own.

## Tab rows read

Command run:
`python3 /Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/read-workbook.py "16 Redirect Links"`

Sheet dimensions: A1:D9, 9 rows x 4 cols, 19 filled cells. One merged range: A4:D4.

Verbatim cell contents:

- A1: `Internal Links to Redirecting URLs`  [bold, color:FFFFFFFF, fill:FF111111]
- A2: `MakeReality.io  ·  Polymer Technical SEO Audit ` (trailing space present in the cell)  [bold, color:FFFFFFFF, fill:FFF35C5A]
- A4 (merged A4:D4): `Only two internal 3xx targets exist (apex forms of the homepage, 308 -> www). 52 external links also point at redirecting URLs - harmless, fix opportunistically during content refreshes.`  [italic, color:FF64748B]
- A6: `Linked URL` | B6: `Status` | C6: `Redirects to` | D6: `Fix`  [all bold, color:FFFFFFFF, fill:FF111111]
- A7: `https://polymer.co` | B7: `308.0` (numeric cell, 308.0) | C7: `https://www.polymer.co/` | D7: `Update internal hrefs to the www URL`
- A8: `https://polymer.co/` | B8: `308.0` (numeric cell, 308.0) | C8: `https://www.polymer.co/` | D8: `Update internal hrefs to the www URL`
- A9: `(52 external URLs)` | B9: `3xx` (string cell) | C9: `various` | D9: `Opportunistic: update to final destinations during post refreshes`

## Formatting differences between rows

No data row (7, 8, 9) carries any font/fill/strike/comment/hyperlink formatting — all three are unstyled and identical. The only cell-level difference is data type: B7 and B8 are numeric (`308.0`), B9 is the string `3xx`.

Content-level difference worth flagging: row 9 is an aggregate placeholder, not a real linked URL. `(52 external URLs)` / `various` names no specific URLs, so nothing in the workbook identifies which 52 external links redirect.

## Files touched

None. This item was transcription only; no source file was edited.

## Supporting grep (repo state, reported not acted on)

`grep` over `/Users/jessica/wrk/wrk-corp/wrk-marketing` (excluding `node_modules` and `.next`) for `https://polymer.co`:

- `web/pages/plato.js` — 1 occurrence, `https://polymer.co/images/platocard.png` (seo image prop)
- `web/pages/features/jobboard.js` — 1 occurrence, `https://polymer.co/images/jobboardcard.png` (seo image prop)
- `web/pages/privacy.js` — 6 occurrences of `https://polymer.co/` inside the pasted Termly HTML blob

I did not change any of these — those files belong to other items.

## Sanity Content Lake search (round 3, 2026-08-06)

The grep above covers only files in the checkout. Blog post and changelog bodies are Portable Text documents in the Sanity Content Lake, so an apex href authored inside one is invisible to it. That gap is now closed by a direct query, not left as a caveat.

Query run (read-only, public CDN endpoint, no token used):

`https://a6d1clb1.apicdn.sanity.io/v2021-03-25/data/query/production?query=*[_type in ["blogPost","changelog"]]`

`projectId` `a6d1clb1` from `web/lib/sanity.js` line 5; dataset `production` from `studio/sanity.json` line 8 and `studio/.env.production` line 1.

Coverage of the whole dataset, not just the two types: `array::unique(*[]._type)` returns `['author', 'blogPost', 'changelog', 'ogre', 'sanity.imageAsset']`. All 298 documents were scanned for the string `polymer.co` — 111 `blogPost` + `changelog`, 2 `author` + `ogre` (0 occurrences), 185 `sanity.imageAsset` (0 occurrences).

92 string occurrences of `polymer.co` in the 111 `blogPost` + `changelog` documents. All but three are `www.polymer.co`, `app.polymer.co`, `help.polymer.co`, `developer.polymer.co` or `support@polymer.co`. The three apex occurrences:

1. **`changelog` document `83ff9bc1-0a12-4def-9beb-49f2489abbd6` (date `2022-06-12`), path `content[1].markDefs[0].href` = `https://polymer.co/`.** This is a Portable Text `link` markDef on the span whose text is `polymer.co`, in the block beginning "We have rebranded from Wrk to Polymer and have moved to a new domain, ". `web/pages/changelog.js` line 14 queries `*[_type == "changelog"] | order(date desc)` and line 73 renders `log.content` through `PortableText`; its `components` object (lines 38-45) overrides only the `key` mark and the `image` type, so the `link` markDef falls through to the default `<a href={value.href}>` renderer.

   Confirmed live: `curl -s https://www.polymer.co/changelog | grep -o 'href="https://polymer\.co[^"]*"'` returns one hit, `href="https://polymer.co/"`.

   This is tab 16 row A8's Linked URL (`https://polymer.co/`, 308 -> `https://www.polymer.co/`), and its Fix — "Update internal hrefs to the www URL" — is NOT done. Not fixed in this round: the value lives in the live production Content Lake, not in this repo, so changing it is a mutation of published content outside the branch under review and outside this agent's single-file ownership. `web/.env.local` does hold a `SANITY_API_WRITE_TOKEN`, so the mutation is mechanically available; it was not run.

2. `blogPost` `hello-polymer` (`2dc23f74-13f3-45c6-aff2-8bf7830e6261`), path `content[10].markDefs[0].href` = `https://www.polymer.co` — www, no trailing slash. Neither tab 16 row A7 (`https://polymer.co`) nor row A8 (`https://polymer.co/`); the workbook lists no www form as a 3xx target. Recorded, not actioned.

3. The visible span TEXT `polymer.co` in both documents above. Prose, not an href.

Corrected statement of scope for rows A7 and A8: repo hrefs are www; one apex href remains in Sanity content and is live on `/changelog`.
