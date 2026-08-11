# Phase 5 structured data — fixes, round 2

## QUESTIONS-FOR-JESSICA.md

Finding: MED, tab 05 rows A8 and A9 — "The round-1 fix changed the code and left the artifact
Jessica reads stating the pre-fix figures."

### Workbook check

Ran `python3 read-workbook.py "05 Structured"`. Tab 05 rows A1, A2, A4, A6-D6 and A7-D13 match the
orchestrator's transcription character for character, including note A4's "$124/$233/$415 per month
tiers" and C9's "Starter $124/mo, Growth $233/mo, Scale $415/mo, priceCurrency USD". No misquote.

### Ground truth read before editing

| Fact | Source | Value |
|---|---|---|
| Annual tiers | `web/pages/pricing.js:27` | `annual: { starter: 124, growth: 233, scale: 415 }` |
| Monthly tiers | `web/pages/pricing.js:28` | `monthly: { starter: 149, growth: 279, scale: 499 }` |
| Toggle default | `web/pages/pricing.js:18` | `useState(true)` for `isAnnual` — first paint is the annual figures |
| `/pricing` `Offer.price` | `web/pages/pricing.js:78` | `price: prices.annual[key]` |
| `/pricing` spec order | `web/pages/pricing.js:83-84` | `"Billed annually"` P1Y first, `"Billed monthly"` P1M second |
| SoftwareApplication `Offer.price` | `web/components/softwareApplicationJsonLd.js:38` | `price: annual` |
| SoftwareApplication spec order | `web/components/softwareApplicationJsonLd.js:44,52` | `"Billed annually"` P1Y first, `"Billed monthly"` P1M second |
| `llms.txt` lead figure | `web/public/llms.txt:17` | "Starter, $124/month billed annually or $149/month billed monthly" |
| `/pricing` title | `web/pages/pricing.js` `pageTitle` | `Polymer Pricing - Simple ATS Plans from $124/mo` |

Both blocks lead with the annual figure. The artifact said otherwise in three places.

### What changed — four passages, one file

The file's own convention for a resolved question is a strikethrough on the question sentence plus
bold **Fixed, no longer a question.** (lines 30, 55, 57, 65, 67, 91, 118). All three resolved items
now carry it.

1. **Line 152**, "Phase 5, /pricing — Product + 3 Offers (applied)" question 1. Was: "The offers
   carry no single headline `Offer.price`" and "Say if you would rather have a headline `price` as
   well, and which of the two numbers it should be." Now struck through and marked fixed, recording
   `price: prices.annual[key]` and the four independent places the site already states $124 first
   (tab row A9, the toggle default, the page title, `llms.txt`). Ends "Nothing needed from you."
2. **Line 162**, "Phase 5, SoftwareApplication" question 1. Was: "`Offer.price` is the
   monthly-billing rate ($149 / $279 / $499)" and "Say if you want `price` to carry $124 instead."
   Now struck through and marked fixed, recording `price: annual` at line 38.
3. **Line 164**, "Phase 5, SoftwareApplication" question 2. Was: "My offers keep a headline
   `Offer.price`; the `/pricing` `Product` block deliberately does not." Now struck through and
   marked fixed — both blocks carry the headline `price`, both carry the same figure, so the
   difference the question described is gone. It also records the one asymmetry that is left and
   is not about price: `pricing.js` gained `billingIncrement` (12 and 1) on its specs and
   `availability` on each offer during this round; `softwareApplicationJsonLd.js` has neither.
   Recorded rather than closed silently, because the question is specifically about the two blocks
   describing the same plans differently. No figure differs.
4. **Line 140**, "Phase 5, item 0" survey question 8. Not named in the finding; corrected because
   it is the question lines 152 and 162 both refer back to, and two of its statements were wrong
   against the current files. Its prediction ("`Offer.price` will therefore carry the annual
   monthly-equivalent") is now what shipped, so that is recorded with both file references. Its
   clause "with a monthly billing duration" was wrong — the annual entry's `billingDuration` is
   `P1Y`; only `unitCode` is `MON` — so a one-sentence correction was added naming the real values.
   Its closing question is kept, because whether the site leads with the annual or the monthly rate
   is hers to change, but reworded from "quote" to "lead with" and closed with "both rates are in
   the markup either way" so it no longer reads as a missing figure.

### Line numbers corrected against the files

The finding quoted `web/pages/pricing.js` line 68 and `web/components/softwareApplicationJsonLd.js`
line 33. Both had drifted — `grep -n` gives 78 and 38 respectively, and `useState(true)` is line 18,
not the `:17` the artifact carried at line 140. Every line number written into the artifact this
round was read out of the file at the time of writing, and each is paired with the code text it
points at so it stays findable if a later edit moves it again.

### No fabrication introduced

No figure was invented. Every price, property name, line number and file path written into the
artifact came from a file in this repo, read this round. No `aggregateRating`, `ratingValue`,
`reviewCount`, `review`, `FAQPage`, `SearchAction` or `potentialAction` was added anywhere. No
author name and no profile URL.

### Nothing outside my file

`git status` on `/Users/jessica/wrk/wrk-corp/wrk-marketing` before and after this round is
unchanged — the six modified files there are other agents' work this round. Every command I ran
against the repo was a read (`sed`, `grep`, `git status`). Nothing committed, nothing pushed.

## web/pages/pricing.js

Two MED findings against tab 05 row A9. Both fixed in this file. Nothing else in the repo touched.

### Finding 1 — Product has no `image`, Offers have no `availability` or `url`

Three properties added, no value invented:

- `image: "https://www.polymer.co/images/card.png"` — the default share image in
  `web/components/seo.js` (`let card = image ? ... : ${baseUrl}/images/card.png`). `/pricing`
  passes no `image` prop to `SEO`, so this exact URL is already the page's own rendered
  `og:image`. File is `web/public/images/card.png`, 1200x630 PNG, on disk since 2024-09-03;
  `curl` against `https://www.polymer.co/images/card.png` returns 200.
- `url: "https://www.polymer.co/pricing"` on each of the three Offers — the same value
  `web/components/softwareApplicationJsonLd.js` puts on its Offers, so the two blocks now emit the
  same Offer shape instead of two.
- `availability: "https://schema.org/InStock"` on each of the three Offers — the three plans are
  purchasable from this page; each card renders a "Get started free" Button to
  `https://app.polymer.co/auth-register`.

### Finding 2 — `billingDuration` is a pending term, and it was the only thing separating the two rates

`billingIncrement` added alongside `billingDuration`: `12` on "Billed annually", `1` on
"Billed monthly", in the unit `unitCode: "MON"` already names.

`https://schema.org/billingIncrement` fetched and checked: domain `UnitPriceSpecification`, range
`Number`, definition "This property specifies the minimal quantity and rounding increment that will
be the basis for the billing. The unit of measurement is specified by the unitCode property.",
derived from GoodRelations. No "pending" or "new area" notice on the page — released vocabulary,
unlike `billingDuration`. A consumer that skips pending terms now separates the two
UnitPriceSpecification objects on a released property: 12 months to a charge, or 1.

`billingDuration` kept. It is real vocabulary and states the contract term; removing it would drop
information rather than add it.

This is a restatement of what `billingDuration` already asserted, not a new claim: the toggle's
Annual position carries the badge "2 months free!" and 124 x 12 = 1488 = 149 x ~10, so the annual
tier is a 12-month term.

### Property-by-property source

| Property | Value | Source |
|---|---|---|
| `image` | `https://www.polymer.co/images/card.png` | `web/components/seo.js` default `card`; file at `web/public/images/card.png`; live 200 |
| `url` (Offer) | `https://www.polymer.co/pricing` | `web/components/softwareApplicationJsonLd.js:35` |
| `availability` | `https://schema.org/InStock` | three "Get started free" Buttons on this page |
| `billingIncrement` | `12` / `1` | `https://schema.org/billingIncrement`; annual/monthly terms in `prices` |

### Runnable check

Started `./node_modules/.bin/next dev -p 3117` (node v20.18.1) in `web/`, fetched `/pricing`,
extracted every `<script type="application/ld+json">` and `JSON.parse`d each after reversing the
`<` escaping. `/pricing` returns 200; three blocks render — `organization`, `website`,
`pricing-product` — all three parse. The `pricing-product` object carries `image`, and each of the
three Offers carries `price` (124 / 233 / 415), `priceCurrency: "USD"`, `url`, `availability` and
two UnitPriceSpecifications, annual first, with `billingIncrement` 12 then 1. Dev server stopped
afterward (`pkill`, confirmed by a 000 on the port).

### No fabrication introduced

No `aggregateRating`, `ratingValue`, `reviewCount`, `review`, `FAQPage`, `acceptedAnswer`, author
name or profile URL added. Every value written is either read out of this repo or fetched and
confirmed live. Nothing in `notFixed` — neither finding needed a value that does not exist.

### Scope

`web/pages/pricing.js` only. Finding 2 also names
`web/components/softwareApplicationJsonLd.js:36-53`, which carries the same pending-term-only
distinction; that file belongs to another agent this round. Nothing committed, nothing pushed.

## SEO-CHANGELOG.md — round 2

Branch confirmed: `git -C /Users/jessica/wrk/wrk-corp/wrk-marketing rev-parse --abbrev-ref HEAD` =
`seo-phase-5-structured-data`. Nothing committed, nothing pushed. Only `SEO-CHANGELOG.md` touched.

### Workbook check

Not re-run this round. Three round-2 agents above each ran
`python3 read-workbook.py "05 Structured"` and each recorded tab 05 A1, A2, A4, A6-D6 and A7-D13 as
matching the orchestrator's transcription character for character, including note A4's
"$124/$233/$415 per month tiers" and cell C9. No misquote to report.

### Finding — MED, tab row A9: three passages contradicted the working tree

Tab 05 row A9 asked for: Starter $124/mo, Growth $233/mo, Scale $415/mo in `Offer.price`.
Status: DONE in code before this round; the changelog said the opposite.

Verified in the served HTML first, from the dev server on :3000 that reflects the working tree:

```
/pricing  "@type":"Product" … "offers":[{"@type":"Offer","name":"Starter","price":124, …
          "priceSpecification":[{… "name":"Billed annually","price":124 …},
                                {… "name":"Billed monthly","price":149 …}]
/         "@type":"SoftwareApplication" … "offers":[{"@type":"Offer","name":"Starter","price":124, …
          "priceSpecification":[{… "name":"Billed annually","price":124 …}, {… "Billed monthly" …}]
```

Both blocks lead with 124 and list the annual spec first. `/`, `/pricing`, `/features` and `/plato`
each return zero occurrences of `aggregateRating`, `ratingValue` and `reviewCount`.

The three passages the finding named are corrected, and so is every other statement in the file that
the same change falsified — the defect was not three sentences, it was the whole price thread:

| Where | Was | Now |
|---|---|---|
| Item 2 `after:` block, `PLANS` and `offers` | `{ name: "Starter", monthly: 149, annual: 124 }`, `price: monthly`, "Billed monthly" spec first | the working tree: annual first in `PLANS`, `price: annual`, "Billed annually" spec first |
| Item 2 paragraph below that block (was line 1702) | "`Offer.price` carries the monthly-billing rate … a deviation from the figures tab 05 cell C9 names and it is open for Jessica" | `Offer.price` carries the annual rate, the figures C9 and A4 name; the monthly-rate reasoning recorded as the shipped-then-corrected state; no longer a deviation, no longer open for Jessica |
| Item 3 `after:` block, `pricingSchema.offers` | no `price` key, "Billed monthly" `monthlyRate` call first | `price: prices.annual[key]`, "Billed annually" call first |
| Item 3 paragraph below that block (was line 1822) | "There is no bare `Offer.price` at all; that is a deliberate divergence from the sibling SoftwareApplication block and is open for Jessica" | `price` is `prices.annual[key]`; the divergence is closed and both blocks state the three plans the same way |
| Item 2 verifier MED-2 | "the emitted `price` is 149 / 279 / 499 … Escalated as a question" | same text, with a bold **Fixed in the working tree, round 2** append |
| Item 2 verifier MED-3 | "The `/pricing` `Product` offers carry no `price` at any level; these … carry `price: 149/279/499`" | same text, with a bold Fixed append naming both halves |
| Item 3 verifier MED-2 | "`priceSpecification[0]` is "Billed monthly" price 149 … since no bare `offers.price` exists" | same text, with a bold Fixed append: headline price and first spec are both the figure the crawlable HTML prints |
| Item 3 verifier MED-3 | "`offers[].price` is absent … which price Google reads is undefined" | same text, with a bold Fixed append |
| "Every item returned `correct: true`. None of the findings below is resolved." | that sentence | resolutions are appended in bold to the findings they resolve, and only the `Offer.price` findings carry one — the rest stand open |
| Tab rows not actioned, row A8 (was line 2091) | "emitted with a headline `Offer.price` of 149 / 279 / 499, not the 124 / 233 / 415 cell C9 states" | emitted with a headline `Offer.price` of 124 / 233 / 415, with the previous text quoted as what it replaced |
| Tab rows not actioned, row A9 (was line 2092) | "actioned, with no bare `Offer.price` at all" | actioned, with a headline `Offer.price` of 124 / 233 / 415, previous text quoted |
| needsLiveCheck, merchant-listing warning | "since no bare `Offer.price` is emitted" | one is emitted, so the anticipated warning should not appear |
| Questions 8, 12, 16, 17 | all four still asking which figure `price` should carry, or recording that neither item used the annual one | all four marked settled in round 2, with the reason: the tab names one figure, the page paints it by default, the `pageTitle` states it and `llms.txt` leads with it |

One more, outside tab 05 but the same "one figure first everywhere" thread: the Phase 1/2 section
said `web/public/llms.txt`'s annual-first reorder was uncommitted and that "the committed version
leads with the monthly figure." `git log -- web/public/llms.txt` shows `05eed5c` on this branch and
`git show HEAD:web/public/llms.txt` leads with `$124/month billed annually`. Corrected, with a
pointer to the two places that still quote the monthly-first form so they read as intermediate
states rather than as the file.

### Recorded, not integrated — the tree moved while this ran

`git status --short` went from four modified files to six during this round, and line numbers moved
under me twice: `web/components/softwareApplicationJsonLd.js` `price: annual` was line 33 when the
finding was written and line 38 at 03:16; `web/pages/pricing.js` `price: prices.annual[key]` was 68
and is 78. Every line-number citation I wrote was replaced with the identifier and the file, so the
statements survive the next edit.

The concurrent round-2 code fixes are therefore **not** integrated into the item sections. They are
recorded in one timestamped paragraph under "The working tree is ahead of `a0235e0`", which names
each one and which statements below it makes stale:

- `_app.js` `sameAs` gaining the LinkedIn company page — stales the omitted-properties row, the row
  A7 entry and questions 1 and 10.
- `@id` on Organization and WebSite, `WebSite.publisher`, and `Article.author`/`publisher` reduced to
  `{ "@id": … }` — stales item 1's `after:` block and four unlinked-node findings.
- `Product.image`, `Offer.url`, `Offer.availability` and `billingIncrement` on `monthlyRate` — stales
  item 3's `after:` block, three omitted-properties rows and item 3 LOW-4.
- `industryJsonLd.js` `logo` moving from `ImageObject` to the plain URL string.

Not written up in full because the agents that own those files were still writing at 03:11-03:16;
a full integration written now would be stale by the time the orchestrator commits. The paragraph
points at this log for each one.

### No fabrication introduced

No value was invented. Every figure written into the changelog came from the repo, from
`git log`/`git show`, or from the dev server's served HTML quoted above. No `aggregateRating`,
`ratingValue`, `reviewCount`, `review` or `FAQPage` was added anywhere, and the LinkedIn URL two
other agents verified live is recorded as theirs, not restated as a fact this agent checked.

## SEO-CHANGELOG.md — round 2, second pass

Branch confirmed: `git -C /Users/jessica/wrk/wrk-corp/wrk-marketing rev-parse --abbrev-ref HEAD` =
`seo-phase-5-structured-data`. Nothing committed, nothing pushed. Only `SEO-CHANGELOG.md` touched.

Five findings. Two were already fixed in the file by the round-2 pass logged above before this pass
read it; three were not, and one of those three was a step nobody had run.

### Workbook check

Ran `python3 read-workbook.py "05 Structured"`. Tab 05 A1, A2, A4, A6-D6 and A7-D13 match the
orchestrator's transcription character for character, including note A4's "$124/$233/$415 per month
tiers", C7's "name, url, logo, sameAs (X, LinkedIn, Discord)" and C9's "Starter $124/mo, Growth
$233/mo, Scale $415/mo, priceCurrency USD". No misquote.

### Findings 1 and 3 — the price record — already done, not by this pass

Both named the same defect: the code carried 124 / 233 / 415 and the changelog said 149 / 279 / 499
in eleven places. Every one of those places was already corrected when this pass first read the file
(mtime 03:17:44) by the "SEO-CHANGELOG.md — round 2" pass logged above. Verified line by line:
`Offer.price` now reads as the annual figure at the item 2 `after:` block, the item 3 `after:` block,
item 2 MED-2 and MED-3, item 3 MED-2 and MED-3, tab rows A8 and A9, the merchant-listing
needsLiveCheck bullet, and questions 8, 12, 16 and 17. Nothing left to do; not re-edited.

### Finding 4 — the `@id` record — done

The round-1 `@id` change was in the code and the changelog stated its absence. It is integrated now,
in place rather than as a footnote, and the `a0235e0` form is quoted beside each `after:` block so the
record still shows what shipped and what corrected it:

| Where | Was | Now |
|---|---|---|
| Item 1 `after:` block | both schemas with no `@id`, no `publisher`, two-entry `sameAs` | `ORGANIZATION_ID`, `"@id"` on both nodes, `publisher: { "@id": ORGANIZATION_ID }`, three-entry `sameAs`, plus a before/after table for the three added lines |
| Item 1 value-trace table | five rows | seven — `sameAs[1]` LinkedIn with its live check, and an `@id` row saying plainly that the identifier is coined by this branch and sourced from nothing |
| Item 4 change-2 `after:` block | the full inline `polymerOrganization` object | `ORGANIZATION_ID`, with the `a0235e0` object quoted below it and why it went |
| Item 4 change-3 `after:` block | `author: polymerOrganization` | `author: { "@id": ORGANIZATION_ID }` |
| Item 4 value-trace table | "`polymerOrganization` — identical to the site-wide Organization" | a reference to the site-wide node, not a restatement |
| Item 1 LOW-2, item 2 MED-4, item 3 LOW-5, item 4 LOW-1 | four findings describing unlinked nodes | each carries a bold append saying exactly how far it resolves — item 4 LOW-1 fully, the other three only for Organization and WebSite |
| The "raised by verifiers, not filed" paragraph | "the absence of `@id` on every node" | names the three places that still restate or float free: `Service.provider`, `Product`, `SoftwareApplication` |
| Repairs table, `Service.provider` row | "`polymerOrganization`" | records the `ImageObject` to string `logo` change **and** that the object itself was not replaced, so each industry page still renders two Organization descriptions |
| The "not integrated below" bullet list | four bullets | split into what is integrated and what is not; only the `web/pages/pricing.js` bullet remains un-integrated |

The `sameAs` LinkedIn entry was not one of my findings, but the item 1 `after:` block I was editing
carried it too, and leaving a line I had just rewritten stating a false `sameAs` would have been
worse than the staleness. Verified before writing rather than restating another agent's check:
`https://www.linkedin.com/company/withpolymer` returns 200, `<title>Polymer | LinkedIn</title>`, and
the page body names `polymer.co`. The three places that said "no such URL exists" — the
omitted-properties row, the row A7 entry, questions 1 and 10 — now say it exists off-site and exists
nowhere in this repo, which is the honest version.

### Finding 5 — the site-wide `BreadcrumbList` omission row — done

The row named only tab 05 and gave two reasons. Corrected on both counts:

- It now names the master prompt, quoted: "Article + BreadcrumbList (blog template ...),
  **BreadcrumbList site-wide**, FAQPage only where visible FAQs exist." The property was asked for by
  name, not merely absent from a tab.
- The second reason — "any label not already written on the site would be invented" — is marked as
  not holding for `/features/jobboard` and `/features/candidate-management-software`. Their parent
  `/features` is the top-level menu label at `web/components/navigation.js:40` and `:72`, and each
  renders its own `<h1>`: `The best job boards around` (`web/components/jobBoard/intro.js:19`) and
  `Candidate management made easy` (`web/components/candidateManagement/intro.js:19`). A
  `Home -> Features -> <page>` trail on those two invents nothing. Still not emitted.
- Question 9 carries the same correction so the two do not drift apart again.

Counted rather than asserted: `grep -rn "BreadcrumbList" web/ --include=*.js` returns three hits, two
in `web/components/industryJsonLd.js` and one in `web/pages/blog/[slug].js`. 33 URLs of 22 routes.

### Finding 2 — "Validate every template's output with a schema validator before PR" — done

It had never been run. It has been now, and the changelog carries a `#### Schema validation` section
with the whole result.

**How.** `./node_modules/.bin/next dev -p 3488` (node v20.18.1) against the working tree. Fetched
`/`, `/pricing`, `/features`, `/plato`, `/blog/hiring-gen-z` and `/applicant-tracking-for-startups`,
extracted every `<script type="application/ld+json">` from the served HTML and deduplicated by
content: 8 distinct blocks over 7 `@type` values — `Organization`, `WebSite`, `SoftwareApplication`,
`Product`, `Article`, `Service`, and `BreadcrumbList` twice (the blog trail and the industry trail).
All 8 submitted as one snippet so the cross-block `@id` references resolve as they do on a real page.

**Which tool, and which one could not be used.** `https://validator.schema.org` was tried first, both
by `curl` against its `POST /validate` endpoint and in a real browser. Every request from this machine
is answered `HTTP 429` with a `302` to `https://www.google.com/sorry/index?...` — Google's
automated-traffic interstitial, which needs a human CAPTCHA solve. A backoff loop retried for 25
minutes and never got through. So the schema.org Schema Markup Validator has **not** run, and the
changelog says so: the vocabulary-level check on `Organization`, `WebSite` and `Service`, which the
Rich Results Test has no feature for, is still outstanding.

Google's Rich Results Test at `https://search.google.com/test/rich-results` was reachable and was
used in code-snippet mode. Result id `4AoIBbNXQYpnwZ2WqfrcRQ`.

**Verdict: 6 valid items detected, 0 invalid, 0 errors.** Every issue below is what the tool labels
non-critical, i.e. an optional field.

| Feature | Items | Errors | Non-critical issues |
|---|---|---|---|
| Product snippets | 1 valid | 0 | 2 — missing `review`, missing `aggregateRating` |
| Merchant listings | 1 valid | 0 | 7 — no global identifier (`gtin`, `brand`); missing `shippingDetails` x3; missing `hasMerchantReturnPolicy` x3 |
| Articles | 1 valid | 0 | 2 — invalid datetime value for `datePublished`; `datePublished` missing a timezone |
| Breadcrumbs | 2 valid | 0 | none |
| Software Apps | 1 valid | 0 | 7 — missing `aggregateRating`; invalid object type for `priceSpecification` x6 |

Four things the run settled, all recorded in the changelog:

1. **The `@id` references resolve.** Under Articles, `author` and `publisher` expand to the full
   Organization — `id https://www.polymer.co/#organization`, `name`, `url`, `logo` and all three
   `sameAs` entries — pulled out of the separate `_app.js` block. The finding-4 change is confirmed by
   the consumer, not by inspection.
2. **The "not eligible" prediction was wrong.** The changelog said in three places that the
   SoftwareApplication blocks would report NOT ELIGIBLE because Google requires `aggregateRating` or
   `review`. Google reports 1 valid item, eligible, with `aggregateRating` as an *optional* missing
   field. All three places corrected. The markup does not change and must not: no rating is invented.
3. **`datePublished` is not clean.** Item 4 LOW-2 said "Both are valid ISO 8601 and Google accepts
   date-only." Google returns two non-critical issues on that exact field. Corrected in place, with
   the reason nothing on this branch can fix it: `publishDate` is a Sanity `date` field, so a fix is a
   Studio schema change plus a time and timezone on 26 documents.
4. **`priceSpecification` is rejected by the Software Apps feature six times**, once per
   `UnitPriceSpecification` per offer, while the Product feature accepts the identical structure.
   New; filed as item 2 finding 9 so a later pass does not rediscover it. Nothing changed — dropping
   the monthly rate to satisfy one feature would remove a real price.

### No fabrication introduced

No value was invented. Every figure, property name, file path and URL written into the changelog was
read out of this repo, out of the dev server's served HTML, or off a live page fetched this round
(`https://www.linkedin.com/company/withpolymer`, 200). No `aggregateRating`, `ratingValue`,
`reviewCount`, `review`, `FAQPage`, `SearchAction` or `potentialAction` was added anywhere, and the
validator run confirms none is emitted. No author name, no profile URL beyond the verified LinkedIn
company page. Where the validator named a missing field that has no real value — `gtin`, `brand`,
`shippingDetails`, `hasMerchantReturnPolicy`, `review`, `aggregateRating` — it stays missing.

### Nothing outside my file

`git status --short` before and after: `SEO-CHANGELOG.md` plus five code files that are other agents'
work this round. Every command against the repo was a read except the edits to my own file. The dev
server on 3488 was started and stopped inside this run. Nothing committed, nothing pushed.

### Concurrency note

`SEO-CHANGELOG.md` was written by another round-2 pass at 03:17:44, after this pass's first read of
it, so the file was re-read in full before any edit and every edit was a targeted string replacement
rather than a rewrite. The code files moved twice underneath as well: `web/pages/_app.js` gained the
LinkedIn `sameAs` entry and `web/pages/pricing.js` gained `billingIncrement`, `image`, `Offer.url` and
`availability` between the first `git diff` of this run and the dev-server fetch. The snapshot the
`after:` blocks now quote is timestamped 2026-08-06 03:30 in the file itself, and the one remaining
un-integrated change (`web/pages/pricing.js`) is still listed as stale rather than silently absorbed.
