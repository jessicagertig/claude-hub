# Phase 3, item 1 — self-referencing canonicals

Agent: phase-3-canonicals. Files owned: `web/components/seo.js` ONLY.
Branch: `seo-phase-3-redirects-canonicals` (already checked out; no branch/commit/push performed).

---

## Tab rows read

Tab **04 Canonicals**, all 41 data rows (rows 7–47) plus the tab's own instruction note at A4:

> "Every crawled 2xx page (31) plus the orphaned set and the backlinked parameter URL. Canonical column = the exact value to emit."

Every row was read and compared against the value `web/components/seo.js` computes for that URL. The row-by-row comparison is below.

---

## Files read before writing (analog pass)

`components/seo.js` is the **only** `next/head` consumer in the repo — `grep -rn "next/head" pages/ components/ lib/` returns exactly one hit. So the analogs for "emit a head tag" are the tags already inside that file, plus the call sites.

Chain traced:

```
web/components/seo.js
  → web/pages/_app.js                (renders <SEO /> with NO props, line 93)
  → web/pages/index.js               (no SEO at all — 25 lines, homepage relies on _app's)
  → web/pages/blog/[slug].js         (pathname={`blog/${post.slug.current}`}, line 246)
  → web/pages/industries/applicant-tracking-for-startups.js         (pathname="applicant-tracking-for-startups")
  → web/pages/industries/applicant-tracking-for-legal-services.js   (pathname="industries/applicant-tracking-for-legal-services")
  → web/pages/404.js                 (pathname="404")
  → web/next.config.js               (7 rewrites, short form → /industries/* form)
  → node_modules/next/dist/shared/lib/head.js        (unique() dedupe filter, reduceComponents)
  → node_modules/next/dist/shared/lib/side-effect.js (mountedInstances Set ordering)
```

All 20 `<SEO>` call sites enumerated via `grep -rn "pathname" pages/ components/`.

**Analog for the tag itself:** the file's existing keyed head tags — `<meta property="og:url" content={seo.url} key="ogurl" />` (line 74), `key="ogimage"`, `key="ogtitle"`, `key="ogdesc"`, `key="twcard"`, `key="twhandle"`. Same shape, same `seo.*` value source, same `key` idiom. The canonical is written to match these exactly.

---

## Change made

**File:** `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/components/seo.js`

One line added. Nothing else in the file touched.

Before (lines 55–58):

```jsx
      <meta charSet="utf-8" />
      <meta name="description" content={seo.metaDescription}></meta>
      <title>{seo.pageTitle}</title>

```

After (lines 55–59):

```jsx
      <meta charSet="utf-8" />
      <meta name="description" content={seo.metaDescription}></meta>
      <title>{seo.pageTitle}</title>
      <link rel="canonical" href={seo.url} key="canonical" />

```

Verbatim diff:

```
@@ -55,6 +55,7 @@ const SEO = ({
       <meta charSet="utf-8" />
       <meta name="description" content={seo.metaDescription}></meta>
       <title>{seo.pageTitle}</title>
+      <link rel="canonical" href={seo.url} key="canonical" />
 
       <meta
         name="google-site-verification"
```

`./node_modules/.bin/eslint components/seo.js` → exit 0, no errors.

### Why `href={seo.url}` and not a new computation

`seo.url` is the value the component already computes at line 13 (`pathname ? ${baseUrl}/${pathname} : baseUrl`) and already emits as `og:url`. Reusing it means the canonical and `og:url` can never drift apart, and it introduces zero new behaviour — the value was already being emitted on every page, just not as a canonical. No new prop, no new helper, no per-page edits.

### Why `key="canonical"` is load-bearing, not decoration

`web/pages/_app.js` line 93 renders `<SEO />` with **no props** on every single page, and then `<Component {...pageProps} />` at line 218 renders the page's own `<SEO pathname="..." />`. Two `SEO` instances mount per page, so two `<Head>` instances contribute tags.

`next/head`'s `unique()` filter (`node_modules/next/dist/shared/lib/head.js`) has a `switch (h.type)` with cases for `title`, `base` and `meta` only. **`link` is not in that switch.** Link tags are deduped *solely* by the `key` branch above the switch:

```js
if (h.key && typeof h.key !== 'number' && h.key.indexOf('$') > 0) {
    hasKey = true;
    const key = h.key.slice(h.key.indexOf('$') + 1);
    if (keys.has(key)) { isUnique = false; } else { keys.add(key); }
}
```

Without a `key`, both canonicals would render on every page: `https://www.polymer.co` from `_app.js`'s prop-less instance *and* the page's own. Two canonical links is worse than none — Google discards both.

**Which one wins, verified from source rather than assumed.** `reduceComponents` does:

```js
headElements.reduce(...).reduce(onlyReactElement, []).reverse().concat(defaultHead(...)).filter(unique()).reverse()
```

`headElements` comes from `headManager.mountedInstances`, a `Set` populated in constructor order on the server (`side-effect.js`, `if (isServer && this._hasHeadManager) { this.props.headManager.mountedInstances.add(this); }`) and in `componentDidMount` order on the client. `_app.js`'s `<SEO />` is an earlier sibling than `<Component />`, so it is inserted first. The `.reverse()` before `.filter(unique())` therefore puts the **page's** tags first, and first-seen wins. The page's canonical survives; `_app.js`'s prop-less one is dropped.

This is the same mechanism that already makes per-page `<title>` and `og:url` work, so the behaviour is confirmed by the site's existing output, not only by reading the library.

(`React.Children.toArray` prefixes an explicit `key="canonical"` to `.$canonical`, which is why the `indexOf('$') > 0` guard passes.)

### Not done, deliberately

The existing `<link>` tags in this file — `apple-touch-icon`, both `icon` sizes, `manifest`, `shortcut icon` — carry no `key`, so they are currently emitted **twice** on every page for the same `_app.js` double-render reason. Pre-existing, unrelated to canonicals, and fixing it is restructuring working code. Left alone. Noting it here only so it is not mistaken for something this change introduced.

---

## Row-by-row comparison: what the component computes vs what tab 04 specifies

37 of 41 rows agree exactly. The disagreements are rows 7, 23 and 38.

| Row | Tab 04 "Canonical to set" | Emitted by `seo.js` | Source of `pathname` | Match |
|---|---|---|---|---|
| 7 | `https://www.polymer.co/` | `https://www.polymer.co` | `_app.js` `<SEO />`, no prop | **CONFLICT — trailing slash** |
| 8 | `https://www.polymer.co/features` | same | `pages/features.js:409` | yes |
| 9 | `.../features/jobboard` | same | `pages/features/jobboard.js:15` | yes |
| 10 | `.../features/candidate-management-software` | same | `pages/features/candidate-management-software.js:15` | yes |
| 11 | `.../plato` | same | `pages/plato.js:20` | yes |
| 12 | `.../pricing` | same | `pages/pricing.js:39` | yes |
| 13 | `.../about` | same | `pages/about.js:25` | yes |
| 14 | `.../changelog` | same | `pages/changelog.js:59` | yes |
| 15 | `.../blog` | same | `pages/blog.js:59` | yes |
| 16 | `.../privacy` | same | `pages/privacy.js:62` | yes |
| 17 | `.../terms` | same | `pages/terms.js:11` | yes |
| 18 | `.../applicant-tracking-for-startups` | same | `industries/applicant-tracking-for-startups.js:90` | yes |
| 19 | `.../applicant-tracking-for-fintech-companies` | same | `industries/applicant-tracking-for-fintech-companies.js:90` | yes |
| 20 | `.../applicant-tracking-for-healthcare-companies` | same | `industries/applicant-tracking-for-healthcare-companies.js:90` | yes |
| 21 | `.../applicant-tracking-for-real-estate-companies` | same | `industries/applicant-tracking-for-real-estate-companies.js:90` | yes |
| 22 | `.../applicant-tracking-for-greentech-companies` | same | `industries/applicant-tracking-for-greentech-companies.js:90` | yes |
| 23 | `https://www.polymer.co/applicant-tracking-for-legal-services` | `https://www.polymer.co/industries/applicant-tracking-for-legal-services` | `industries/applicant-tracking-for-legal-services.js:90` | **CONFLICT — wrong path** |
| 24 | `.../applicant-tracking-for-cryptocurrency-companies` | same | `industries/applicant-tracking-for-cryptocurrency-companies.js:90` | yes |
| 25–37 | 13 blog post URLs | same | `pages/blog/[slug].js:246`, `` pathname={`blog/${post.slug.current}`} `` | yes |
| 38 | `https://www.polymer.co/` (for `/?partner_source=whatjobs`) | `https://www.polymer.co` | `_app.js` `<SEO />`, no prop | **query dropped correctly; same trailing-slash conflict as row 7** |
| 39–47 | 9 orphaned blog post URLs | same | `pages/blog/[slug].js:246` | yes |

Rows 25–37 and 39–47 (22 blog posts total) are all served by the single `pages/blog/[slug].js` template, so the canonical is `https://www.polymer.co/blog/<sanity slug>` by construction and matches every listed row without any per-post work.

---

## The three disagreements, recorded — not resolved

### 1. Rows 7 and 38 — homepage trailing slash

Tab 04 prescribes `https://www.polymer.co/`. The component computes `https://www.polymer.co` and line 13 carries the comment `// No trailing slash allowed!`.

I did **not** bend either side. The component keeps emitting what it already emitted for `og:url`; the tab keeps saying what it says. Filed as a question.

Facts, no recommendation: `next.config.js` does not set `trailingSlash`, so it defaults to `false`. Nothing else in the codebase emits a trailing-slash form. Changing this would mean special-casing the no-`pathname` branch of line 13, which would also change the existing `og:url` on the homepage.

### 2. Row 23 — legal services emits the `/industries/` path

`web/pages/industries/applicant-tracking-for-legal-services.js` line 90 declares:

```jsx
        pathname="industries/applicant-tracking-for-legal-services"
```

Its six sibling industry pages declare the short top-level form. `next.config.js` rewrites the short form to the `/industries/` form for all seven, so both URLs return 200 for every one of them.

I do not own that file and did not touch it.

**This change makes the mismatch materially worse than it was.** Before, the wrong `pathname` only affected `og:url`. Now it is the canonical: for the six correct pages the canonical points at the short form no matter which of the two URLs a crawler lands on, which collapses the rewrite twins onto one URL — a real gain. For legal-services it does the opposite, canonicalising both URLs onto `/industries/applicant-tracking-for-legal-services`, which is the form tab 04 does not want and the form `web/components/footer.js` and the sitemap do not use.

The one-word fix lives in a file another item owns. The phase-2 sitemap agent already filed the same mismatch as its own question 1; I have appended the canonical-specific consequence under my own heading so it is not lost if that question is answered narrowly.

### 3. `/404` gets a canonical that is not in tab 04

`web/pages/404.js` line 11 passes `pathname="404"`, so the page now emits `<link rel="canonical" href="https://www.polymer.co/404" />`. Tab 04 has no row for it. Not a tab disagreement — a side effect of the component covering all 22 templates at once. Filed as a question rather than silently special-cased, since suppressing it means either a new prop or an edit to a file I do not own.

---

## `?partner_source=whatjobs` — how the canonical is computed for a parameterised URL

Checked before deciding, as instructed. Chain: `web/pages/_app.js` → `ReferralContext` → `appendReferral` → `process.env.NEXT_PUBLIC_REFERRER_SOURCE` → `web/next.config.js` `env` block → `web/pages/index.js`.

Findings:

- `appendReferral` (`_app.js` lines 69–89) only ever **builds outbound link hrefs** — it appends `referral=`, `partner=` and captured tracking params to URLs passed into it, all of which point at `https://app.polymer.co/...`. It is never called with, and never touches, anything the `SEO` component renders.
- `NEXT_PUBLIC_REFERRER_SOURCE` is read in exactly two other places: `appendReferral` line 77, and `pages/index.js` lines 16–17 where it gates rendering of `<PartnerBrand />` and `<PartnerSetup />`. It changes what the homepage **displays**, never its URL or its head tags.
- `TRACKING_PARAM_KEYS` is `["gclid", "fbclid", "li_fat_id", "adct", "internal_ref"]` and the capture loop at lines 52–57 additionally takes anything prefixed `utm_`. **`partner_source` is neither**, so it is not even captured into `trackingParams` or localStorage.
- `router.query` is read only for the `referral` key (line 39).

Conclusion: the canonical is a pure function of the `pathname` prop. It never reads `window.location.search` or `router.query`, so a query string cannot leak into it. `https://www.polymer.co/?partner_source=whatjobs` renders `pages/index.js`, which has no page-level `<SEO>`, so `_app.js`'s prop-less instance supplies `url = baseUrl` and the canonical comes out query-free at `https://www.polymer.co`.

That is exactly what row 38 asks for — the 243 backlinks consolidate onto the homepage — subject only to the same trailing-slash question as row 7. The parameter URL stays live; nothing in this change redirects or blocks it.

---

## Anything I could not do

- **Rows 7/38 trailing slash** — deliberately not resolved. Requires Jessica's call; would alter existing `og:url` output too.
- **Row 23 legal-services path** — cannot fix, file not owned.
- **Suppressing the `/404` canonical** — cannot fix, file not owned.
- **No live render check.** I did not start a dev server, so I have not seen the emitted HTML. The single-canonical-per-page conclusion is read out of `next/head`'s source rather than observed in `view-source`. One `curl` against a running dev server on any page (grep for `rel="canonical"`, expect exactly one hit with the page's own URL) would close that out.

No blockers. `BLOCKED.md` not written.
