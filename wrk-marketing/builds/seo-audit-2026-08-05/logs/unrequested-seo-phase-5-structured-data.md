# Unrequested-change sweep — `seo-phase-5-structured-data`

Read-only pass. No repository command that writes was run: the branch was never checked out, nothing
was committed, staged, merged or edited. Everything below came from
`git -C /Users/jessica/wrk/wrk-corp/wrk-marketing diff seo-phase-4-metadata-headings..seo-phase-5-structured-data`
and `git show <ref>:<path>`.

## Result

**Nothing to remove.** Ten changes, all traceable to a tab 05 cell or to the mechanism a cell's
outcome needs. Two items flagged uncertain and left in place.

## What the branch changes

17 files, +1103 / -8. Sixteen code files plus `SEO-CHANGELOG.md`. The eight removed lines are seven
inline `metaDescription` props on the industry pages (moved, not deleted) and one `SEO-CHANGELOG.md`
sentence rewritten with a correction.

## Tab 05 has seven template rows. Every one is accounted for, and nothing else is touched.

Read with `python3 read-workbook.py "05"`.

| Row | Cell | Where it landed |
|---|---|---|
| A7 | Site-wide · Organization + WebSite · "Emit once in root layout" | `web/pages/_app.js` |
| A8 | Homepage + /features + /plato · SoftwareApplication | `web/components/softwareApplicationJsonLd.js`, rendered from `index.js`, `features.js`, `plato.js` |
| A9 | /pricing · Product + Offer x3 | `web/pages/pricing.js` |
| A10 | Blog posts (all) · Article + BreadcrumbList | `web/pages/blog/[slug].js` |
| A11 | Industry ATS pages (7) · Service or WebPage + BreadcrumbList | `web/components/industryJsonLd.js`, rendered from the seven `web/pages/industries/*.js` |
| A12 | Comparison pages (planned /compare/*) | Nothing emitted. `web/pages/compare` does not exist. |
| A13 | jobs.polymer.co JobPosting · "Outside marketing-site scope" | Nothing emitted. |

The diff touches no template outside that list. No `FAQPage`, no `JobPosting`, no `/compare` route,
no `aggregateRating` / `ratingValue` / `reviewCount` / `review` anywhere — D8 says "No
aggregateRating - Polymer has no on-site reviews; do not invent" and the branch obeys it.

## Cell-by-cell

### Row A7 — `web/pages/_app.js`

C7 asks for "name, url, logo, sameAs (X, LinkedIn, Discord)". All four present. `logo` points at
`/android-chrome-512x512.png`, which is a real file — `git ls-tree seo-phase-5-structured-data:web/public`
lists it. The Twitter and Discord `sameAs` entries match what `web/components/footer.js:106` and
`:109` already link (`https://discord.gg/MgQxHMYZFN`, `https://twitter.com/withPolymer`). The
LinkedIn entry appears nowhere in the repo — C7 names LinkedIn by name, so it is requested; where the
URL came from is recorded in the round-3 log and in `QUESTIONS-FOR-JESSICA.md`, not something this
sweep re-litigates.

D7 says "Emit once in root layout." `_app.js` is this repo's root layout — the Pages Router wrapper
that already renders the prop-less `<SEO />` for the same reason. There is no `app/` directory.

### Row A8 — `softwareApplicationJsonLd.js` on three pages

Rendered on exactly `index.js`, `features.js` and `plato.js`. C8's five properties are all present.

`PLANS` hand-copies `prices` from `web/pages/pricing.js`. That is a mechanism, not scope creep:
`prices` is declared inside the `Pricing` component body at `web/pages/pricing.js:26-29` and is not
exported, so a component rendered on three other pages cannot read it. C8 requires the three tiers on
those pages; without a local copy there are no tiers.

### Row A9 — `web/pages/pricing.js`

C9: "Starter $124/mo, Growth $233/mo, Scale $415/mo, priceCurrency USD". Every figure in
`pricingSchema` is read out of `prices` — `annual: { starter: 124, growth: 233, scale: 415 }` — so
the markup and the cards cannot diverge. `description` is `headerContent.description`, the page's own
pre-existing header copy. `image` is `/images/card.png`, a real file.

### Row A10 — `web/pages/blog/[slug].js`

C10: "headline, datePublished, dateModified, author (add real author profiles), image". All five
present. Every field the schema reads was already in the GROQ query before this phase —
`author->{ name, photo }` at line 413, `publishDate`, `updatedDate`, `metaDescription`,
`editorialTitle`. Phase 5 added no query fields and changed no `editorialTitle`.

`dateModified: post.updatedDate || post.publishDate` uses the editorial field the page already
renders at line 334-335, not Sanity's `_updatedAt`. D10 calls `dateModified` an E-E-A-T fix.

### Row A11 — `industryJsonLd.js` on seven pages

C11: "name, description, provider". D11: "Keep light; breadcrumbs matter most." Two nodes per page,
four properties on the Service, a two-item breadcrumb trail. Light.

The `provider: { "@id": ORGANIZATION_ID }` reference rather than a second inline Organization object
follows D7 — one Organization per page, emitted from the root layout.

**The `metaDescription` hoist is a mechanism, and it changes no rendered output.** `IndustryJsonLd`
needs the same string `<SEO>` already renders. The literal moved into the `verticalData` object each
file already declares, and `<SEO>` reads it back. Comparing the removed literal against the added
`verticalData` value on each of the seven pages: identical character for character. Same props on
`<SEO>` before and after, `pathname` included.

## The two uncertains

### `billingIncrement` in `softwareApplicationJsonLd.js`

No cell names it. It sits inside a node tab 05 does authorise, and column C is headed **"Required
properties"** — a floor, not a ceiling — so an extra property inside an authorised node is not
obviously out of scope on its own.

What makes it worth surfacing is that the same engagement removed the same property from the sibling
block. `logs/phase-5-fixes-round-3.md` records the `pricing.js` agent deleting it under note A4
("Never fabricate"): "It states the billing *term*; it never states how many months go on one charge.
`12` and `1` were derived from the badge and from 124 x 12, not read off anything the page says." The
same log then names the deletion this file still needs: "`billingIncrement: 12` at line 55,
`billingIncrement: 1` at line 64, and the two comment clauses at lines 16 and 19-21."

So on the branch as it stands: `/`, `/features` and `/plato` emit `billingIncrement`; `/pricing` does
not; and the comment in `softwareApplicationJsonLd.js` asserts a parity with the `/pricing` block
("same `availability`, same `billingIncrement`") that no longer holds. Left in place — it is inside an
authorised node, and picking which of the two files is right is a schema-modelling decision, not a
scope call.

### The monthly-rate `UnitPriceSpecification`

C9 names three figures; the markup carries six. The monthly rates ($149 / $279 / $499) are real —
read out of the same `prices` object the cards render from — so note A4's no-fabrication bar is met.
And the `/mo` in C9 is exactly what `unitCode: "MON"` carries, so a `UnitPriceSpecification` is how
the cell's own wording gets expressed in JSON-LD. Reads as mechanism. Stays. Flagged only because it
puts figures in the markup that no cell names.

## Not flagged, and why

Extra schema properties inside an authorised node — `Article.description`, `Article.mainEntityOfPage`,
`Article.publisher`, `Service.url`, `Offer.url`, `Offer.availability`, `Product.image`, the `@id` on
Organization and WebSite. Column C is headed "Required properties." Required is a minimum. Treating
every optional property inside an authorised node as unrequested would strip the blocks to skeletons
and would be exactly the over-removal this round is meant not to do. Every one of these values is read
out of the repo; none is invented.

`SEO-CHANGELOG.md` grew 748 lines for a 334-line code change. Verbose, but the master prompt's rule 4
requires the changelog and says the final report is built from it. Not a candidate.
