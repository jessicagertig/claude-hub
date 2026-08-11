# Phase 5 — SoftwareApplication on `/`, `/features`, `/plato` (tab 05 row A8)

Branch `seo-phase-5-structured-data`. Nothing committed, nothing pushed, no branch created.

## What shipped

One new component, `web/components/softwareApplicationJsonLd.js`, rendering the shared
`web/components/jsonLd.js` with `id="software-application"`. Each of the three pages I own
gained exactly two lines — an import and a self-closing tag.

| File | Change |
|---|---|
| `web/components/softwareApplicationJsonLd.js` | new, 60 lines |
| `web/pages/index.js` | `+import`, `+<SoftwareApplicationJsonLd />` as the first child of the fragment |
| `web/pages/features.js` | `+import`, `+<SoftwareApplicationJsonLd />` after `<SEO>` |
| `web/pages/plato.js` | `+import`, `+<SoftwareApplicationJsonLd />` after `<SEO>` |

No `<SEO>` was added to `web/pages/index.js` — that stays the open question it was.

## Analogs read before writing

Four files, all in this repo, all rendering something into `next/head` or composing a small
prop-less component:

1. `web/components/jsonLd.js` — the shared block the foundation item built. Read in full before
   writing anything, per the task. It takes `{ id, schema }`, keys the `<script>` on `id`, and
   escapes `<`. I use it as-is and hand it a unique `id`; `"organization"` and `"website"` were
   already taken by `web/pages/_app.js`.
2. `web/components/seo.js` — the only other `next/head` component. Took from it: `import React`
   at the top, a plain object of content assembled above the JSX, `let baseUrl =
   "https://www.polymer.co"` (mine is `const BASE_URL`, matching `web/pages/_app.js:23` and
   `web/pages/sitemap.xml.js:3`), and default export at the bottom.
3. `web/pages/_app.js:23-44` — `organizationSchema` and `websiteSchema`, the two existing
   schema literals. Took the shape exactly: a `const <name>Schema = {}` with `"@context"` and
   `"@type"` first, a comment above naming where each value came from and what was left out and
   why. Mine is the third in that series.
4. `web/components/start.js` — a prop-light presentational component with its default content in
   a `const` above the component (`defaultContent`). Confirms that a hardcoded content object
   living beside the component is the house pattern here, not a separate data module.

Structural check against the analogs: `import React` first — SAME. Content object above the
component — SAME. Arrow function plus `export default` at the bottom — SAME as `jsonLd.js` and
`seo.js` (`start.js` uses `export default function`; I followed `jsonLd.js`, the nearer analog).
Sibling import written `./jsonLd` — SAME as `start.js`'s `./button-new`. No `Styled = {}` object —
DIFFERENT, and correct: this component renders no DOM, exactly like `seo.js` and `jsonLd.js`,
neither of which has one.

Why a component and not three copies of the literal, or a `web/lib/` module: three copies of a
price table is the failure mode where one gets updated and two rot. `web/lib/` holds integration
modules (`posthog.js`, `sanity.js`), not content. `web/components/` holds exactly this kind of
small composed component, and the new file sits next to `jsonLd.js` where the next person looking
for JSON-LD will find it. Filename is camelCase after `jsonLd.js` and `web/components/plato/platoHero.js`
(the directory mixes camelCase and kebab-case; the JSON-LD sibling settles it).

## The emitted block

```json
{
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": "Polymer",
  "url": "https://www.polymer.co",
  "applicationCategory": "BusinessApplication",
  "operatingSystem": "Web",
  "description": "Polymer gives you a beautiful job board and a powerful ATS to manage candidates. Collaborate with your hiring team from one place. Get started free.",
  "offers": [
    {
      "@type": "Offer",
      "name": "Starter",
      "price": 149,
      "priceCurrency": "USD",
      "url": "https://www.polymer.co/pricing",
      "priceSpecification": [
        { "@type": "UnitPriceSpecification", "name": "Billed monthly",  "price": 149, "priceCurrency": "USD", "unitCode": "MON", "billingDuration": "P1M" },
        { "@type": "UnitPriceSpecification", "name": "Billed annually", "price": 124, "priceCurrency": "USD", "unitCode": "MON", "billingDuration": "P1Y" }
      ]
    },
    { "…Growth": "279 / 233" },
    { "…Scale":  "499 / 415" }
  ]
}
```

Every value traced:

| Property | Value | Source |
|---|---|---|
| `name` | `Polymer` | `og:site_name` at `web/components/seo.js:77`; matches `organizationSchema.name` in `web/pages/_app.js:32` |
| `url` | `https://www.polymer.co` | `web/components/seo.js:12` |
| `applicationCategory` | `BusinessApplication` | tab 05 row A8, verbatim |
| `operatingSystem` | `Web` | tab 05 row A8, verbatim |
| `description` | site default meta description | `web/components/seo.js:22-23`, verbatim. This is also the description the homepage actually renders, since `web/pages/index.js` passes no props and falls through to the prop-less `<SEO />` at `web/pages/_app.js:117` |
| offer names | `Starter`, `Growth`, `Scale` | `web/pages/pricing.js:72`, `:112`, `:151` |
| monthly prices | `149`, `279`, `499` | `web/pages/pricing.js:27` |
| annual prices | `124`, `233`, `415` | `web/pages/pricing.js:26` |
| `priceCurrency` | `USD` | `web/pages/terms.js:173-175` — the pricing page itself prints a bare `$` and never names a currency |
| offer `url` | `https://www.polymer.co/pricing` | the page those figures are published on |

## The price decision, and why

`web/pages/pricing.js:25-28` carries two rates per plan. `web/pages/pricing.js:17` is
`useState(true)` for `isAnnual`, so the page's first paint is the annual column — $124/$233/$415 —
and both columns render the number followed by `/month` (`:74-76`), which makes the annual figure a
monthly-equivalent, not a yearly charge. No yearly total ($1,488/$2,796/$4,980) appears anywhere on
the site.

**`Offer.price` states the monthly-billing rate: 149 / 279 / 499.** A bare `price` field reads as
*the* price of the plan, with no qualifier attached. $124 is not a price anyone can pay for one
month of Starter — it requires committing to a year, which the page marks with the "2 months free!"
badge at `:62`. Putting 124 in `price` would state a purchasable monthly price that does not exist.
That is the mistake already caught once on this engagement in `llms.txt`, and the reason the task
called it out.

**Both rates are still in the block**, as two labelled `UnitPriceSpecification` entries per offer:
`"Billed monthly"` with `billingDuration: "P1M"` and `"Billed annually"` with
`billingDuration: "P1Y"`, both `unitCode: "MON"` because both figures are per-month amounts. So the
annual rate a visitor sees by default is not hidden, it is just labelled as requiring the annual
term. `unitCode: "MON"` is the UN/CEFACT code for month and also stops a bare `149` being read as a
one-time purchase price.

That two-spec shape is not mine — it is what the `/pricing` item emitted in its `Product` block. I
checked the rendered `/pricing` HTML on the dev server mid-run, found `priceSpecification` as an
array of `"Billed monthly"` / `"Billed annually"` `UnitPriceSpecification`s with the same
`billingDuration` and `unitCode`, and changed my flat single-spec version to match it, so the same
three plans are not described two different ways on the same site.

One difference from `/pricing` remains and it is deliberate: my offers keep a headline
`Offer.price`, theirs do not. Google's SoftwareApplication documentation lists `offers.price` among
the properties it reads, and an offer with no `price` at any level gives a crawler that does not
walk into `priceSpecification` nothing at all. Since the honest monthly number is available, it goes
in `price`. Raised as question 2 below so the inconsistency is Jessica's call, not silently mine.

Price-mismatch risk is nil on my three pages: none of them displays a price, so there is no visible
figure for a crawler to disagree with. The default-annual-paint question belongs to `/pricing`.

## What was deliberately not emitted

- **`aggregateRating`, `ratingValue`, `reviewCount`, `review`** — Polymer has no on-site reviews.
  Consequence worth knowing: Google's SoftwareApplication rich result requires `name`, `offers` and
  *either* `aggregateRating` or `review`, so the Rich Results Test will report this block as valid
  structured data that is not eligible for the software rich result. That is the correct outcome and
  the only way to make it eligible would be to fabricate ratings. Noted so nobody "fixes" it later.
- **`FAQPage`** — none of the three pages has a visible Q&A. Checked the rendered markup of all
  three: `web/pages/index.js` composes `Intro`, `Brands`, `Toolkit`, `Features`, `Tailor`,
  `Integrations`, `Start`; `web/pages/features.js` is four `FeatureSection`s built from the
  `features` array at `:24-402`, every entry a statement; `web/pages/plato.js` is `PlatoHero`,
  `PlatoDescription`, `PlatoFeatures`, `PlatoFilter`, `PlatoPrivacy`, `PlatoVideo`, `Start`. No
  question-and-answer pair on any of them, consistent with the survey's finding that the site has
  no FAQ anywhere.
- **`softwareVersion`, `datePublished`, `releaseNotes`, `author`, `screenshot`, `featureList`,
  `downloadUrl`, `installUrl`** — no real value exists in the repo for any of them, and none is
  asked for by row A8. `web/pages/changelog.js` exists but is not a version number.
- **A free-trial offer** — the 14-day trial at `web/pages/pricing.js:194` is real, but schema.org
  Offer has no trial vocabulary; `eligibleDuration` means how long the offer stays valid. Same
  conclusion the `/pricing` item reached.
- **A separate `SoftwareApplication` for Plato on `/plato`** — Plato is a capability inside Polymer,
  not a separately purchasable product. Its usage is metered as "Plato AI credits" inside the same
  three plans (`web/pages/pricing.js:93`, `:133`, `:172`), so there are no Plato-specific offers to
  emit and no separate price. `/plato` describes the same application, so it carries the same entity.
- **`BreadcrumbList`** — `/`, `/features` and `/plato` all hang directly off the root, so the trail
  would be one or two items. Left where the foundation item left it.

## Verification

Local dev server, `node v18.20.8`, `node node_modules/next/dist/bin/next dev -p 3117`, started and
stopped inside this run; port 3117 is free again and the log is clean of errors. Nothing on this
branch is deployed, so production could not be checked.

Fetched `/`, `/features`, `/plato` and parsed every `<script type="application/ld+json">` out of
each response with `json.loads`:

```
=== /         === organization -> Organization   website -> WebSite   software-application -> SoftwareApplication
=== /features === organization -> Organization   website -> WebSite   software-application -> SoftwareApplication
=== /plato    === organization -> Organization   website -> WebSite   software-application -> SoftwareApplication
```

Three distinct blocks per page, all parsing as valid JSON, no key collision with the foundation
item's `"organization"` and `"website"`, and the `SoftwareApplication` payload byte-identical across
the three routes. `/pricing` was fetched read-only in the same pass to compare offer shapes; it was
not modified.

`git status` at the end of this item shows my three pages modified and one untracked component
added. `web/pages/_app.js`, `web/pages/pricing.js` and `web/pages/blog/[slug].js` are modified by
other items and were not touched here.
