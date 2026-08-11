# Unrequested-change audit — `seo-phase-3-redirects-canonicals`

Read-only pass, 2026-08-07. Tabs in scope: `04 Canonicals`, `06 Backlinked 404`, `16 Redirect Links`.

## Branch topology — the diff in the task prompt returns nothing

`git diff seo-phase-1-2-deorphan-crawl..seo-phase-3-redirects-canonicals` is empty. `git merge-base seo-phase-1-2-deorphan-crawl seo-phase-3-redirects-canonicals` returns `1dc4e21`, which *is* the phase-3 tip: phase-3 was merged into phase-1-2 as PR #48 (`56fea83`), so phase-3 is wholly contained in the branch the prompt names as its base.

The two branches were also cross-merged five times while both were live, so neither is a clean base for the other. Phase-3's own work is the three non-merge commits on its first-parent chain:

| Commit | Date | Subject | Parent |
|---|---|---|---|
| `4fbc64f` | Aug 5 20:22 | Add canonical tags, redirect /contact, and drop the apex hop | `6229f91` |
| `e822d00` | Aug 6 01:13 | Close the gaps the phase 3 review found | `94a8f05` |
| `499c9a3` | Aug 6 22:39 | Make the privacy policy link text match where it goes | `11506ff` |

`6229f91` ("De-orphan the blog and add crawl infrastructure") is the phase-1-2 commit phase-3 branched from, so it is the pre-engagement baseline for every file below.

The six merge commits were checked for conflict-resolution content with `git diff-tree --cc`. Two touched files (`94a8f05` → `web/pages/features/jobboard.js`, `93e0aae` → `web/next.config.js` and `web/pages/sitemap.xml.js`); in both, every hunk is one side's content preserved verbatim. No work was invented in a merge.

Complete file list, from `git show --numstat` on the three commits:

```
4fbc64f   21   0  BLOCKED.md
        233   0  SEO-CHANGELOG.md
          1   0  web/components/seo.js
          5   0  web/next.config.js
          1   1  web/pages/features/jobboard.js
          1   1  web/pages/industries/applicant-tracking-for-legal-services.js
          1   1  web/pages/plato.js
          1   1  web/pages/privacy.js
e822d00   52   0  BLOCKED.md
         58  22  SEO-CHANGELOG.md
          3   1  web/components/seo.js
          7   6  web/pages/sitemap.xml.js
499c9a3    1   1  web/pages/privacy.js
```

`web/pages/privacy.js` is a 167 KB Termly HTML blob held in one single-line template literal, so its line-level diff is unreadable. Both of its changes were resolved with a token-level `difflib` pass over the two blob revisions.

## Change-by-change

### `web/components/seo.js` — `<link rel="canonical">` (`4fbc64f`) — KEEP

Master prompt, Phase 3 item 1, verbatim: "Implement self-referencing canonicals via a `<link rel="canonical">` in `components/seo.js`, which every template already renders (tab 04 lists every URL and its exact canonical value)." The file and the mechanism are both named in the instruction.

`key="canonical"` is part of the mechanism, not an addition. `web/pages/_app.js` line 93 renders a prop-less `<SEO />` alongside each page's own, so two `Head` instances contribute tags. `next/head`'s `unique()` filter switches on `title`, `base` and `meta` only — `link` dedupes solely through the `key` branch — so without it every page emits two canonicals. The file's existing keyed tags (`ogurl`, `ogimage`, `ogtitle`, `ogdesc`, `twcard`, `twhandle`) are the house form.

### `web/components/seo.js` — `canonicalUrl` (`e822d00`) — KEEP

```js
let canonicalUrl = pathname ? url : `${baseUrl}/`; // Homepage canonical keeps the trailing slash
```

Tab 04 A4: "Canonical column = the exact value to emit." C7 is `https://www.polymer.co/` and C38 is `https://www.polymer.co/` — both carry the trailing slash. The pre-existing line 13 computes `https://www.polymer.co` for the homepage under the comment "No trailing slash allowed!", so `seo.url` alone cannot emit either cell's exact value.

The separate binding is the minimum that satisfies C7 and C38 without disturbing anything else: `canonicalUrl` is `url` whenever `pathname` is set, so all 21 interior pages are byte-identical, and line 13 and `seo.url` are untouched, so `og:url` is unchanged on every page including the homepage. Pre-existing code was not modified.

### `web/next.config.js` — `/contact` 301 (`4fbc64f`) — KEEP

Tab 06 E7: "Restore /contact with demo/sales form; until then 301 -> /about or /pricing". The master prompt's redirect map picks `/about`. The preferred remedy (restore the page) is logged in `BLOCKED.md` per Phase 3 item 2: "otherwise ship the 301 now and log the page build in `BLOCKED.md`".

**Cross-branch note, not a removal.** Jessica has since approved `/contact` as a real page with a form emailing `contact@polymer.co`, and `JESSICA-TODO.md` lists the Postmark setup for it. A redirect shadows a page of the same path, so whichever branch lands that page has to delete this `redirects()` entry in the same change. `BLOCKED.md` already states this. The entry is not unrequested work — it is exactly what tab 06 E7 asked for — so it is not in the removal list, but it cannot ship alongside the contact page.

### `web/pages/industries/applicant-tracking-for-legal-services.js` — `pathname` correction (`4fbc64f`) — KEEP

```
-        pathname="industries/applicant-tracking-for-legal-services"
+        pathname="applicant-tracking-for-legal-services"
```

Tab 04 C23 is `https://www.polymer.co/applicant-tracking-for-legal-services`. The canonical is computed from the `pathname` prop, so without this one-word change the page emits `https://www.polymer.co/industries/applicant-tracking-for-legal-services` and C23 is not satisfied. Textbook mechanism: the thing the cell asks for does not work without it.

Corroborating: its six sibling industry pages, `web/components/footer.js` and `web/pages/sitemap.xml.js` all already used the short form. This page was the single outlier. Pre-engagement the wrong `pathname` only fed `og:url`, which is why it survived until the canonical made it load-bearing.

### `web/pages/sitemap.xml.js` — `urlEntry` and comment (`e822d00`) — KEEP

```
-    <loc>${pathname ? `${BASE_URL}/${pathname}` : BASE_URL}</loc>
+    <loc>${BASE_URL}/${pathname}</loc>
```

`staticRoutes[0]` is `""`, so this is the homepage `<loc>` and nothing else: `https://www.polymer.co` → `https://www.polymer.co/`. It exists to stop the sitemap contradicting the canonical that tab 04 C7 now requires. Tab `02 XML Sitemap` was read to check for a conflicting instruction — C7 and C8 specify scope and host ("www host only, absolute HTTPS URLs") and say nothing about the homepage's trailing slash — so nothing is overridden.

The comment rewrite in the same commit is downstream of the legal-services fix above: the old comment documented the `pathname` mismatch as a live condition ("that page's og:url does not match its `<loc>` here"), and that condition no longer exists. Leaving it would have shipped a comment that describes the repo falsely.

### `web/pages/privacy.js` — three anchor **hrefs** (`4fbc64f`) — KEEP

```
-<a href="https://polymer.co/" data-custom-class="link">
+<a href="https://www.polymer.co/" data-custom-class="link">
```

Tab 16 A8 Linked URL `https://polymer.co/`, D8 Fix "Update internal hrefs to the www URL". These are hrefs and the URL is row 8's exact string.

### `BLOCKED.md` and `SEO-CHANGELOG.md` — KEEP

Master prompt rule 3: "Log anything you cannot automate (missing CMS permissions, environment values, editorial judgment calls) in a running `BLOCKED.md` rather than improvising." Rule 4: "Keep a changelog. Append every change (file, URL affected, before → after) to `SEO-CHANGELOG.md` in the repo. The final report is built from it."

`SEO-CHANGELOG.md` already existed at `6229f91`; phase-3 appended to it. `BLOCKED.md` did not exist and was created here — rule 3 requires the file and does not name a location, and Phase 3 item 2 requires this specific entry in it. The phase-1 and phase-2 entries added in `e822d00` are also rule-3 logging.

## Removals

### `web/pages/plato.js` and `web/pages/features/jobboard.js` — `og:image` host moved apex → www (`4fbc64f`)

```
-        image="https://polymer.co/images/platocard.png"
+        image="https://www.polymer.co/images/platocard.png"

-        image="https://polymer.co/images/jobboardcard.png"
+        image="https://www.polymer.co/images/jobboardcard.png"
```

No cell authorises this.

Tab 16's only two URL rows are A7 `https://polymer.co` and A8 `https://polymer.co/`. Neither `https://polymer.co/images/platocard.png` nor `https://polymer.co/images/jobboardcard.png` appears anywhere in the tab. D7 and D8 both read "Update internal hrefs to the www URL"; an `og:image` is a `content` attribute on a `<meta>`, not an href.

Tab 16's note A4 is a scoping statement, not a description: "Only two internal 3xx targets exist (apex forms of the homepage, 308 -> www). 52 external links also point at redirecting URLs - harmless, fix opportunistically during content refreshes." The tab knows other redirecting URLs exist on the site and says to leave them for content refreshes.

Overview J26 says "A handful of internal references point at https://polymer.co (apex)" and K26 says "Point internal links directly at https://www.polymer.co/... equivalents." Overview describes, detail tab specifies — where both mention a thing, the tab's string ships, and the tab's string is "hrefs" against two named URLs.

Applying the mechanism test: would the thing the cell asks for work without this? Yes. Fixing the three privacy-policy hrefs works untouched by the `og:image` props, and nothing else in phase-3 reads them. This is not a mechanism of anything asked for; it is the same action applied to two URLs the tab never named — the shape Jessica described with the CTA that moved on 26 posts rather than the 3 named.

Corroborated inside the engagement's own record. The phase-3 verifier classified it MED: "the two `og:image` changes are not workbook-driven ... it is a scope extension past the authoritative tab and is Jessica's call." `QUESTIONS-FOR-JESSICA.md` question 1 offers the revert: "Say the word and it reverts." `SEO-CHANGELOG.md` records it as "disclosed three times with an offer to revert". It is not on the approved list.

Both PNGs exist in `web/public/images/` and the same deployment serves both hosts, so reverting breaks nothing.

## Uncertain

### `web/pages/privacy.js` — three anchor **texts** (`499c9a3`)

```
-<a href="https://www.polymer.co/" data-custom-class="link">https://polymer.co/</a>
+<a href="https://www.polymer.co/" data-custom-class="link">https://www.polymer.co/</a>
```

Reads both ways, so per the rules it stays and is flagged.

Against it: tab 16 D8 says "Update internal hrefs to the www URL", and visible link text is not an href — it is wording in a legal document. `4fbc64f` deliberately did *not* make this change for that exact reason, and `SEO-CHANGELOG.md` records the restraint: "Only the `href` changed; the visible link text still reads `https://polymer.co/`, because row 8's Fix names hrefs and the text is prose in a legal document. Raised as a question rather than decided." It went to Jessica as `QUESTIONS-FOR-JESSICA.md` question 2, which closes "it is a change to the wording of a legal document, so it is yours to call." Then `499c9a3` did it a day later, and the approved list does not name it.

For it: the change exists only because the authorised href fix created a text/target disagreement, it is confined to exactly the three anchors that fix touched, and it adds nothing new — it removes an inconsistency phase-3 introduced. That is "a change that keeps an authorised change from breaking something else."

The timestamp is the reason to leave it rather than pull it: `499c9a3` is Aug 6 22:39, inside the window Jessica was reviewing and settling items with the orchestrator. If she answered question 2 that night, this is her answer and removing it re-opens a closed decision. One question settles it: did she approve the privacy-policy link text change?

Note on propagation, since it affects any removal decision later: `499c9a3` is on phases 1-2 and 4 through 8, but **not** on `seo-phase-9-content-refresh`, which merged phase-3 at an earlier point. `web/pages/privacy.js` at the phase-9 tip still carries 3 www hrefs and 3 apex texts.
