# Phase 3 fixes — round 3

## SEO-CHANGELOG.md

Agent owning `/Users/jessica/wrk/wrk-corp/wrk-marketing/SEO-CHANGELOG.md`. Branch `seo-phase-3-redirects-canonicals` confirmed by `git rev-parse --abbrev-ref HEAD`. Nothing committed, nothing pushed. No file other than `SEO-CHANGELOG.md` and this log was written.

### The tree moved under me mid-round

The finding I was given described a working tree that stopped existing while I was reading it. Concurrent fix agents rewrote three of the files it names between 00:52 and 00:59 on 2026-08-06. Observed directly:

| File | State at ~00:52 (what the finding describes) | State at 01:01, stable through 01:05 |
|---|---|---|
| `web/components/seo.js` | line 13 rewritten to `` `${baseUrl}/${pathname \|\| ""}` ``, so canonical **and** `og:url` both gained the homepage trailing slash | line 13 restored to the original ternary; new line 14 `` let canonicalUrl = pathname ? url : `${baseUrl}/`; ``, new `canonicalUrl` key in `seo`, line 60 `href={seo.canonicalUrl}`. Canonical gets the slash, `og:url` does not. |
| `web/next.config.js` | `destination: 'https://www.polymer.co/about'` | reverted to `destination: '/about'` (mtime 00:58); no longer modified against `4fbc64f` |
| `web/pages/404.js` | `import Head from "next/head"` plus a `<Head>` carrying `<meta name="robots" content="noindex" key="canonical" />` | reverted (mtime 00:59); no longer modified. `/404` emits `<link rel="canonical" href="https://www.polymer.co/404">` again |

I armed a background watcher (`until` loop on the five files' mtimes, exit after 90 seconds of quiet) before writing anything, so the snapshot I recorded is a settled tree, not a mid-write one. `git status --short` at 01:01 and again at 01:05:

```
 M BLOCKED.md
 M SEO-CHANGELOG.md
 M web/components/seo.js
 M web/pages/sitemap.xml.js
```

Consequence for the finding: four of its six statements were true again by the time I could act on them. Statements 2 (`next/head` grep returns one hit), 3 (`/contact` destination is `/about`), 4 (`/404` canonical is an open LOW with no Fixed marker) and 6 (the relative destination is an unfiled deviation) all describe the current tree correctly and were left alone. Statements 1 and 5 were stale and are fixed, along with nine derived statements the same change made false.

### What was verified before writing

- `grep -rn "next/head" pages/ components/ lib/` from `web/` → one hit, `components/seo.js:2`.
- `node -e "const c=require('./next.config.js'); c.redirects().then(...)"` → `{ "source": "/contact", "destination": "/about", "statusCode": 301 }`.
- `web/pages/industries/applicant-tracking-for-legal-services.js:90` → `pathname="applicant-tracking-for-legal-services"` (tab 04 row 23 satisfied).
- `web/pages/sitemap.xml.js:44` → `<loc>${BASE_URL}/${pathname}</loc>`, no ternary, so the homepage `<loc>` is `https://www.polymer.co/`.
- `BLOCKED.md` → five `## ` entries, not the four the changelog claimed. The fifth is "Phase 3 — HSTS preload for `polymer.co`" (tab 06 row 9 note F9).
- `node_modules/next/dist/shared/lib/head.js` and `side-effect.js` read in full, to check whether the reverted `404.js` override would have worked before I recorded anything about it. `unique()` keeps one type-agnostic `keys` Set, so a `<meta key="canonical">` and a `<link key="canonical">` do collide; `_app.js` line 93 renders `<SEO />` before `<Component />`, so after `reduceComponents`' `.reverse()` the page's own tags win. The override would have suppressed the canonical. It is not on disk, so nothing was written claiming it does.

### Workbook check

Run against `read-workbook.py` for tabs `04 Canonicals`, `06 Backlinked 404`, `16 Redirect Links`. The orchestrator's rendering of all three tabs is accurate — C7 and C38 are both `https://www.polymer.co/` with the trailing slash, D38 is "Canonical consolidates the partner-parameter link equity to the homepage", A18-A24 are all the short top-level form with no `/industries/` path, and tabs 06 and 16 match cell for cell. One detail the orchestrator's summary attributes to tab 06 row A8 belongs to a different cell: the note "Canonical consolidates the partner-parameter link equity to the homepage" is tab 04 D38, and tab 06 F8 reads "Partner-attribution URL; canonical consolidates equity without breaking tracking". The orchestrator filed it under tab 04 row A38, which is where it lives. No misquote.

### Edits made

All in `/Users/jessica/wrk/wrk-corp/wrk-marketing/SEO-CHANGELOG.md`, Phase 3 section unless noted.

1. **Working-tree paragraph** — replaced the two-file sentence with the 01:01 `git status --short` block, the four files annotated, and an explicit record that `web/next.config.js` and `web/pages/404.js` each carried an edit earlier in the session and were reverted by 01:00, with their mtimes and their current on-disk values.
2. **Item 1, after the `href={seo.url}` paragraph** — new paragraph giving the three uncommitted `seo.js` lines verbatim. The paragraph above it says "the canonical cannot drift from `og:url`"; that is now false on the homepage and the new paragraph says so in those words rather than working around it.
3. **Item 1, `key="canonical"` paragraph** — "two canonicals: `https://www.polymer.co` from `_app.js`" now names both values, since `_app.js`'s prop-less `<SEO />` emits `https://www.polymer.co/` as the canonical after the repair.
4. **Item 1, row coverage** — "Rows 7, 23 and 38 do not match" was present tense about a tree where all three now match. Rewritten to past tense for what the item itself left, with a second paragraph recording all three closed and by which repair.
5. **Repairs table** — intro changed from "Two were then fixed by hand before the branch was handed over" to three, with the first two in `4fbc64f` and the third uncommitted. New row for the trailing-slash repair, carrying the exact line 14 binding, the fact that the 21 interior pages are byte-identical, and the cost: the homepage canonical and `og:url` disagree and no tab row asked for `og:url` to be left behind.
6. **"Left as decisions rather than fixed"** — the homepage trailing slash removed from the list, with a sentence saying it was removed and why.
7. **Item 1 verifier finding LOW-2** — Fixed marker appended in the file's existing verbatim-plus-marker form. It records that the finding's own premise ("not a canonical-only edit") no longer holds and that the two tags now disagree.
8. **"Tab rows not actioned, or actioned with a differing value", rows 7 and 38** — both were recorded as actioned with a differing value. Both now emit C7 / C38 character for character. Rewritten, kept under the heading because the item that owns the rows did not do it and the repair is not in `4fbc64f`.
9. **needsLiveCheck** — the two bullets quoting the homepage canonical as `https://www.polymer.co` corrected to `https://www.polymer.co/`, plus a new bullet for the canonical/`og:url` disagreement, marked as read off the source with no dev server started.
10. **QUESTIONS-FOR-JESSICA.md question 1** — marked answered by the repair, with the narrower question that survives it (whether `og:url` should follow the canonical) stated.
11. **Phase 3 `BLOCKED.md` section** — "carries three more" corrected to four, with the fifth entry named and its tab row given. Tab 06 row 9's E9 is "No action", so F9's HSTS note was not actioned by the item; that is recorded rather than papered over.
12. **Open items `BLOCKED.md` section** (Phase 1/2 area, two places) — "adds one entry for each of the three" and "the working-tree version carries all four" corrected to five.
13. **Phase 2 sitemap verifier finding LOW-2** (Phase 1/2 area) — it said the homepage `<loc>` has no trailing slash and that `loc` and canonical "should be written the same way". Both are now the trailing-slash form. Resolution appended, naming line 44 and line 14, and naming `og:url` as the one that stayed behind.

Edits 3, 6, 8, 9, 10, 11, 12 and 13 are not in the finding's list of six. Each is the same defect — a Phase 3 statement describing a tree that no longer exists — reachable from the same change, and leaving them would have left the finding half-fixed.

`git diff --stat SEO-CHANGELOG.md` → 58 insertions, 22 deletions.

### Not fixed

Nothing. Every statement the finding named is either corrected or was true of the settled tree.

### Standing risk

The tree is shared with concurrent fix agents and moved twice inside thirteen minutes. Every working-tree claim I wrote is timestamped 2026-08-06 01:01 in the file itself, and the section says in as many words that it is a snapshot rather than a closed count. If `web/components/seo.js`, `web/next.config.js` or `web/pages/404.js` is rewritten again after 01:05, edits 1, 2, 3, 5, 7, 8, 9, 10 and 13 go stale in the same way — they name line numbers and exact values in files another agent owns.
