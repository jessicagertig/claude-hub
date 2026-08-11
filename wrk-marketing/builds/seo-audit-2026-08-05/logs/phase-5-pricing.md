# Phase 5 — /pricing: Product + 3 Offers

Owns `web/pages/pricing.js` only. Applied, not committed. Branch `seo-phase-5-structured-data`.

Tab 05 row A9: "Product + Offer x3 — Starter $124/mo, Growth $233/mo, Scale $415/mo, priceCurrency USD".

## Analogs read before writing

| File | What it establishes | Followed |
|---|---|---|
| `web/components/jsonLd.js` | The shared block component: `<JsonLd id="..." schema={...} />`, one script tag, caller-supplied unique `id` | Used it; `id="pricing-product"`, unique against the `organization` and `website` ids `_app.js` already renders |
| `web/pages/_app.js:23-44` | Schema objects are plain JS object literals declared next to the component, `"@context"`/`"@type"` quoted, every other key bare; site URL as a string literal | Same shape; `pricingSchema` is a plain literal built in the component body because it reads `prices` and `headerContent` |
| `web/components/seo.js` | The head-tag component all 22 pages render, and where the `https://www.polymer.co` literal lives (`:12`) | Left untouched; the `JsonLd` block sits directly after `<SEO />` in the page, mirroring `_app.js`'s `<SEO />` then `<JsonLd />` order |
| `web/pages/pricing.js:74, :114, :153` | How the page reads a price for display: `prices[isAnnual ? 'annual' : 'monthly'].starter` | The markup reads `prices.monthly[key]` and `prices.annual[key]` off the same object — no price literal is written a second time |
| `web/pages/pricing.js:2-8` | Import style in this file is relative (`"../components/seo"`), unlike `_app.js`'s bare `"components/seo"` | `import JsonLd from "../components/jsonLd";` |

## The change

Three edits to `web/pages/pricing.js`, +38 lines, nothing removed or restructured.

1. `import JsonLd from "../components/jsonLd";` after the `SEO` import.
2. `monthlyRate` helper + `pricingSchema` object, declared after `toggleBilling` so they can read `prices` and `headerContent`.
3. `<JsonLd id="pricing-product" schema={pricingSchema} />` immediately after the `<SEO />` element.

```js
  const monthlyRate = (name, price, billingDuration) => ({
    "@type": "UnitPriceSpecification",
    name,
    price,
    priceCurrency: "USD",
    unitCode: "MON",
    billingDuration,
  });

  const pricingSchema = {
    "@context": "https://schema.org",
    "@type": "Product",
    name: "Polymer",
    description: headerContent.description.replace("\n", " "),
    url: "https://www.polymer.co/pricing",
    offers: [
      { name: "Starter", key: "starter" },
      { name: "Growth", key: "growth" },
      { name: "Scale", key: "scale" },
    ].map(({ name, key }) => ({
      "@type": "Offer",
      name,
      priceCurrency: "USD",
      priceSpecification: [
        monthlyRate("Billed monthly", prices.monthly[key], "P1M"),
        monthlyRate("Billed annually", prices.annual[key], "P1Y"),
      ],
    })),
  };
```

## Every value traced

| Value | Source |
|---|---|
| `149 / 279 / 499` | `prices.monthly` — read from `web/pages/pricing.js:27`, not retyped |
| `124 / 233 / 415` | `prices.annual` — read from `web/pages/pricing.js:26`, not retyped |
| `"Starter" / "Growth" / "Scale"` | The `<h3>` of each card, `web/pages/pricing.js:72`, `:112`, `:151` |
| `starter / growth / scale` keys | The keys of the `prices` object itself |
| `"Polymer"` | `og:site_name`, `web/components/seo.js:77` |
| `description` | `headerContent.description`, `web/pages/pricing.js:21-22`, rendered visibly by `<Header>`; the one `\n` collapsed to a space |
| `https://www.polymer.co/pricing` | `baseUrl` + `pathname="pricing"`, `web/components/seo.js:12-13` — the same string the canonical carries |
| `"USD"` | `web/pages/terms.js:173-175`, the only USD declaration on the site (the page prints a bare `$`) |

## Representing two billing periods

The page has two real prices per plan and shows one at a time. The markup carries both, as two `UnitPriceSpecification` entries in `Offer.priceSpecification`:

- `{ name: "Billed monthly", price: 149, unitCode: "MON", billingDuration: "P1M" }`
- `{ name: "Billed annually", price: 124, unitCode: "MON", billingDuration: "P1Y" }`

`unitCode: "MON"` is the UN/CEFACT Common Code for month, and it is on **both**, because both figures are per-month — `web/pages/pricing.js:74-76` renders every number followed by `/month`, and no yearly total exists anywhere on the site. `billingDuration` is the only property separating them: `P1Y` says the $124 rate holds on a one-year term, `P1M` says $149 is the month-to-month rate. Nothing in the block asserts that $124 is available month to month.

Vocabulary verified against https://schema.org/UnitPriceSpecification before use — it defines `billingDuration` (Duration | Number | QuantitativeValue), `billingIncrement`, `billingStart`, `referenceQuantity`, `unitCode`, `unitText`, `priceType`, and inherits `price` and `priceCurrency` from `PriceSpecification`.

Deliberately not emitted:

- **A bare `Offer.price`.** Either number in that slot reads as *the* price of the plan. Both rates live in `priceSpecification` instead, each labelled. This diverges from what question 8 of "Phase 5, item 0" anticipated (`Offer.price` carrying the annual monthly-equivalent) — raised for Jessica.
- **`billingIncrement`.** Its meaning here is ambiguous (1 month of usage, or 12 months charged at once), and `billingDuration` plus `unitCode` already carry the distinction. A guessed value would be a claim the page does not make.
- **`referenceQuantity`.** `unitCode: "MON"` on the specification already says "per month"; the nested `QuantitativeValue` would restate it.
- **`availability`, `brand`, `seller`, `itemOffered`.** Not required by the tab and adding nothing the `Product` wrapper does not already say.

## The 14-day free trial: omitted, no vocabulary exists

`web/pages/pricing.js:194` reads "You'll have unlimited time to explore Polymer and a 14-day free trial when you publish your first job." It is **not** in the markup.

Checked https://schema.org/Offer: no property has "trial" in its name or description. The closest, `eligibleDuration`, is defined as "The duration for which the given offer is valid" — how long the offer stands, not how long a trial runs. Using it for a trial length would be bending a property to mean something it does not, so the trial is omitted rather than misrepresented.

It does survive incidentally in `Product.description`, which is the page's own header copy: "…Start your free trial and publish jobs in minutes."

## FAQPage: not emitted

The facts survey found no visible FAQ on any page of the site — zero matches for `faq`, `frequently asked`, `accordion`, `<details>`, `<summary>` in `web/pages`, `web/components` or `studio`.

Read `/pricing` directly to confirm. The one question-shaped element is the CTA banner at `web/pages/pricing.js:202-203`: an `<h3>` reading "Need more jobs or custom solutions?" with a paragraph beneath it and a "Contact Us" button. It is a sales banner, not an FAQ section — one question, no Q&A set, and the paragraph is a pitch rather than an answer. No `FAQPage`. Raised for Jessica so the judgement is visible rather than silent.

## Never emitted

No `aggregateRating`, `ratingValue`, `reviewCount` or `review` — Polymer has no on-site reviews, and inventing them is both fabrication and a Google policy violation.

## Verified rendering

`./node_modules/.bin/next dev -p 3117` in `web/`, `curl http://localhost:3117/pricing`. Server stopped afterwards, port 3117 confirmed free again. Three `application/ld+json` blocks on the page, all parsing as valid JSON: `Organization` and `WebSite` from `_app.js` (foundation item, untouched) and the `Product` below.

```json
{
  "@context": "https://schema.org",
  "@type": "Product",
  "name": "Polymer",
  "description": "Simple, transparent pricing that scales with your hiring needs. Start your free trial and publish jobs in minutes.",
  "url": "https://www.polymer.co/pricing",
  "offers": [
    {
      "@type": "Offer",
      "name": "Starter",
      "priceCurrency": "USD",
      "priceSpecification": [
        { "@type": "UnitPriceSpecification", "name": "Billed monthly", "price": 149, "priceCurrency": "USD", "unitCode": "MON", "billingDuration": "P1M" },
        { "@type": "UnitPriceSpecification", "name": "Billed annually", "price": 124, "priceCurrency": "USD", "unitCode": "MON", "billingDuration": "P1Y" }
      ]
    },
    {
      "@type": "Offer",
      "name": "Growth",
      "priceCurrency": "USD",
      "priceSpecification": [
        { "@type": "UnitPriceSpecification", "name": "Billed monthly", "price": 279, "priceCurrency": "USD", "unitCode": "MON", "billingDuration": "P1M" },
        { "@type": "UnitPriceSpecification", "name": "Billed annually", "price": 233, "priceCurrency": "USD", "unitCode": "MON", "billingDuration": "P1Y" }
      ]
    },
    {
      "@type": "Offer",
      "name": "Scale",
      "priceCurrency": "USD",
      "priceSpecification": [
        { "@type": "UnitPriceSpecification", "name": "Billed monthly", "price": 499, "priceCurrency": "USD", "unitCode": "MON", "billingDuration": "P1M" },
        { "@type": "UnitPriceSpecification", "name": "Billed annually", "price": 415, "priceCurrency": "USD", "unitCode": "MON", "billingDuration": "P1Y" }
      ]
    }
  ]
}
```

Same response's rendered HTML carries `>124<`, `>233<` and `>415<` — the annual default (`isAnnual` starts `true`), matching the `billingDuration: "P1Y"` figures. `149` is absent from first paint and appears only after the Monthly toggle, which is a client-side state change; the markup is static and carries both rates regardless.

## Not actioned here

Rows A7, A8, A10, A11, A12 and A13 belong to other items. `web/pages/pricing.js` is the only file touched.
