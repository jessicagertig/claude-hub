# Phase 5 review — structured data

Branch `seo-phase-5-structured-data`, PR #50. Reviewed against tab 05 rows A7-A13.

**Workbook check:** ran `python3 read-workbook.py "05 Structured"`. The orchestrator's
transcription matches the workbook character for character — title A1, note A4, headers A6-D6 and
every cell of rows A7-A13. No misquote.

**Verification method:** read all five modified files on disk, then ran `next dev` on port 3941
against the working tree and extracted every `<script type="application/ld+json">` from 20 routes.
Every block parses. Server stopped afterwards (port returns 000).

**No aggregateRating, ratingValue, reviewCount, bestRating, worstRating, review, FAQPage or
acceptedAnswer exists anywhere on this branch.** `grep -rnE` over `web/pages`, `web/components`,
`web/public` and `studio` returns three hits: two comments recording deliberate absence
(`web/pages/_app.js:48`, `web/components/softwareApplicationJsonLd.js:29`) and
`web/pages/blog/[slug].js:261` `mainEntityOfPage`, which is Article vocabulary, not FAQPage's
`mainEntity`. No FAQPage exists, and no page renders a visible Q&A set. There is no `/compare`
route.

---

## The finding that governs the rest

**Every fix from three review rounds is uncommitted.** `git status` shows five code files and
`SEO-CHANGELOG.md` modified and unstaged. PR #50 contains the pre-fix state:

| What the working tree does | What `git show HEAD` — PR #50 — does |
|---|---|
| `softwareApplicationJsonLd.js` `price: annual` → 124/233/415 | `price: monthly` → 149/279/499 |
| `softwareApplicationJsonLd.js` "Billed annually" first | "Billed monthly" first |
| `pricing.js` `price: prices.annual[key]` on each Offer | no `price` property at any level |
| `pricing.js` "Billed annually" first | "Billed monthly" first |
| `_app.js` `sameAs` carries three URLs incl. LinkedIn | two URLs, no LinkedIn |
| `_app.js` `@id` on Organization and WebSite, `publisher` ref | no `@id` anywhere |
| `blog/[slug].js` `author`/`publisher` are `@id` refs | full restated Organization object |
| `industryJsonLd.js` `provider` is an `@id` ref | full restated Organization object |

Merging PR #50 as it stands ships row A9's figures wrong, three Organization nodes on a blog post,
and `sameAs` missing LinkedIn. Everything in the sections below describes the **working tree**.

---

## 1. Still not done, and why

**Tab 05 row A10 asked for: author (add real author profiles).**
Status: DONE DIFFERENTLY.
Reason: `Article.author` is `{ "@id": "https://www.polymer.co/#organization" }` — the company, not a
person. `studio/schemas/blogPost.js` has no author field; `studio/schemas/` holds only
`blogPost.js`, `changelog.js`, `schema.js` and `youtube.js`, so there is no author document type.
No byline renders on any post. Naming a person would be fabrication. Closing the row needs a Studio
schema change plus a value on all 26 documents.

**Tab 05 row A10 asked for: datePublished.**
Status: DONE INCOMPLETELY.
Reason: rendered value is `2026-05-21` — a date with no time and no timezone offset, because
`publishDate` is a Sanity `date` field. `dateModified` renders `2026-05-21T19:43:53Z` from
`_updatedAt`. Google's Rich Results Test returns "Invalid datetime value" and "Datetime property is
missing a timezone" on `datePublished`, and those are the only two issues it reports on the branch.
The fix is `studio/schemas/blogPost.js` changing `publishDate` from `date` to `datetime` plus a time
and zone on all 26 documents. **This is not in QUESTIONS-FOR-JESSICA.md** — grep for `datePublished`
and `timezone` returns zero. It is the one item on the branch that cannot move without her and the
one item absent from the file she reads.

**Tab 05 row A12 asked for: Article + FAQPage on comparison pages (planned /compare/*).**
Status: NOT DONE.
Reason: the pages do not exist. `web/pages/` has no `compare` directory and `web/next.config.js`
declares no `/compare` rewrite. Cell A12 says "planned". No FAQPage was emitted anywhere, which is
the required outcome — no page on the site renders visible Q&A, so an FAQPage would have been a
BLOCKER.

**Tab 05 row A13 asked for: verify the product already emits JobPosting for Google Jobs.**
Status: DONE, with a defect that has nowhere to go.
Reason: the verification was performed and passed — `https://jobs.polymer.co/aboard/40210` carries
one server-rendered `JobPosting` with all five Google-required properties. It found
`datePosted: "2026-06-03 16:36:07 UTC"`, which is not ISO 8601 (Google's example is
`2017-01-24T19:33:17+00:00`), and no `validThrough`. Both live in the Rails job board, not this
repo. **QUESTIONS-FOR-SHAWN.md contains no occurrence of `JobPosting`, `datePosted` or
`jobs.polymer.co`** — a malformed field on Polymer's own distribution feature is recorded only in a
marketing-site changelog.

**Master prompt Phase 5: "Validate every template's output with a schema validator before PR."**
Status: DONE INCOMPLETELY.
Reason: Google's Rich Results Test was run and reports on Product snippets, Merchant listings,
Articles, Breadcrumbs and Software Apps. `validator.schema.org` answered this machine with HTTP 429
and a CAPTCHA interstitial through a 25-minute backoff, so the schema.org Schema Markup Validator
never ran. A round-3 pass substituted a check of all eight blocks against schema.org's published
vocabulary dump, which covers property existence but not value ranges. `Organization`, `WebSite`
and `Service` have no Google rich-result feature and so drew no report from the tool that did run.
Completing it is one person, one paste, one CAPTCHA.

**`billingIncrement` — the two price blocks disagree, and three documents say they agree.**
Status: DEFECT.
Reason: `web/components/softwareApplicationJsonLd.js` emits `billingIncrement: 12` and
`billingIncrement: 1` on its two `UnitPriceSpecification` entries. `web/pages/pricing.js` emits
neither — its only mention is the comment at line 44 explaining the omission: "that is how many
months go on one charge, which the page never states, so a number here would be a claim the page
does not make." The same three offers therefore carry different property sets on `/pricing` than on
`/`, `/features` and `/plato`. Each file's comment asserts the opposite:
`softwareApplicationJsonLd.js:16` says "in the shape the /pricing Product block uses — same
`availability`, same `billingIncrement`". `SEO-CHANGELOG.md` states it three times — line 1738
"Matches `web/pages/pricing.js:83-84`", line 1740 "both blocks now emit the same Offer shape",
line 2073 "Both are emitted, in `web/pages/pricing.js:83-84`". File mtimes show `pricing.js`
(04:03:57) was edited after `softwareApplicationJsonLd.js` (04:02:40) and before the changelog
(04:12:36), so the removal happened and was then documented as its opposite. Two fixes are
available and one line each: delete the two `billingIncrement` lines from the component, or restore
the fourth `monthlyRate` argument in `pricing.js`.

**Tab 05 row A8 asked for: offers (3 tiers from /pricing).**
Status: DONE DIFFERENTLY.
Reason: the tiers are a hand copy, not a read. `web/components/softwareApplicationJsonLd.js:22-26`
declares `PLANS` with all six figures as literals; `prices` at `web/pages/pricing.js:26-29` is
declared inside the `Pricing` component body and is not exported, so nothing can import it. The
file's own comment counts the cost: "A rate change edits four places." Cell D9 says "update if
billing copy changes." The values agree today. Hoisting `prices` above `export default function
Pricing()` and exporting it removes one of the four.

**Master prompt Phase 5: "BreadcrumbList site-wide."**
Status: DONE INCOMPLETELY.
Reason: emitted on the 26 blog posts and the 7 industry pages, nowhere else. For
`/features/jobboard` and `/features/candidate-management-software` the stated reason — that labels
would have to be invented — does not hold: their parent `/features` is a top-level menu label in
`web/components/navigation.js` and both pages render their own titles. The remaining root-level
routes have no parent, so a trail there would invent hierarchy.

**Homepage URL is stated in two forms.**
Status: DEFECT, cosmetic.
Reason: `Organization.url`, `WebSite.url` and every BreadcrumbList Home item state
`https://www.polymer.co` with no trailing slash. `web/components/seo.js:15` emits
`https://www.polymer.co/` with one as the homepage canonical. Both resolve; nothing 404s.

---

## 2. Needs Jessica

**1. Blog post authors — a business fact plus a Studio schema change.**
Tab 05 row A10 asks for real author profiles and cell D10 ties it to E-E-A-T on tab 13. No author
data exists anywhere in the repo or the Sanity dataset. Who wrote the 26 blog posts, or should
`author` stay as Polymer the company?

**2. `datePublished` has no time or timezone — a Studio schema change.**
Google's Rich Results Test flags this and nothing else on the branch. Changing `publishDate` from
`date` to `datetime` in `studio/schemas/blogPost.js` requires a time on all 26 existing documents.
Approve the schema change, or leave the two warnings standing?

**3. The `JobPosting.datePosted` defect on jobs.polymer.co — outside this repo.**
The product emits valid JobPosting, but `datePosted` is `2026-06-03 16:36:07 UTC`, which Google
will not parse as ISO 8601, and `validThrough` is absent. Both live in inflow-ats. Should this be
routed to Shawn?

**4. The Discord `sameAs` is an invite link, not a profile page.**
Cell C7 names Discord and `https://discord.gg/MgQxHMYZFN` shipped. Google may not resolve an invite
URL as an entity reference. Leave it, or drop it?

**5. `Organization.address` — a business decision, not a missing value.**
Two locations are published: `web/pages/terms.js:278-286` gives `Curious One, Inc., 1209 Orange St.,
Wilmington, DE 19801`, a Delaware registered-agent address; `web/pages/about.js:73` says
"headquartered in Charlotte" with no street. Row A7 does not ask for `address`. Which entity and
address should the site publish, if either?

---

## 3. Fixed during review

| Tab row | Before → after |
|---|---|
| A9 | `/pricing` Offers had no `price` at any level → `price: prices.annual[key]`, 124/233/415 |
| A9 | `priceSpecification` listed "Billed monthly" first → "Billed annually" first |
| A8 | `Offer.price` was `monthly`, 149/279/499 → `annual`, 124/233/415 |
| A8 | `priceSpecification` listed "Billed monthly" first → "Billed annually" first |
| A7 | `sameAs` carried two URLs → three, adding `https://www.linkedin.com/company/withpolymer` (verified live: 200, names polymer.co) |
| A7 | Organization and WebSite had no `@id` → both carry one, `WebSite.publisher` references the Organization |
| A10 | `Article.author`/`publisher` restated a full Organization → `{ "@id": ORGANIZATION_ID }` |
| A11 | `Service.provider` restated a full Organization → `{ "@id": ORGANIZATION_ID }` |
| A7/A10 | `logo` was an ImageObject in one file, a string in two → string in all three |
| A9 | `Product` had no `image` → `https://www.polymer.co/images/card.png` (file exists) |
| A9/A8 | Offers had no `availability` → `https://schema.org/InStock` on all six |
| A9 | `billingIncrement` was a guessed value → removed from `pricing.js`; **still emitted in `softwareApplicationJsonLd.js`, see section 1** |

Measured result: a blog post, an industry page, `/pricing` and `/` each carry exactly **one**
Organization node, `https://www.polymer.co/#organization`. Before these fixes a blog post carried
three and an industry page two.

---

## Table 1 — every URL and the schema.org @type values it carries

Measured from rendered HTML, `next dev` port 3941, working tree.

| URL | @type values |
|---|---|
| `/` | Organization, WebSite, SoftwareApplication |
| `/features` | Organization, WebSite, SoftwareApplication |
| `/plato` | Organization, WebSite, SoftwareApplication |
| `/pricing` | Organization, WebSite, Product (+3 Offer, 6 UnitPriceSpecification) |
| `/about` | Organization, WebSite |
| `/blog` | Organization, WebSite |
| `/changelog` | Organization, WebSite |
| `/terms` | Organization, WebSite |
| `/privacy` | Organization, WebSite |
| `/features/jobboard` | Organization, WebSite |
| `/features/candidate-management-software` | Organization, WebSite |
| `/applicant-tracking-for-startups` | Organization, WebSite, Service, BreadcrumbList |
| `/applicant-tracking-for-fintech-companies` | Organization, WebSite, Service, BreadcrumbList |
| `/applicant-tracking-for-cryptocurrency-companies` | Organization, WebSite, Service, BreadcrumbList |
| `/applicant-tracking-for-greentech-companies` | Organization, WebSite, Service, BreadcrumbList |
| `/applicant-tracking-for-healthcare-companies` | Organization, WebSite, Service, BreadcrumbList |
| `/applicant-tracking-for-legal-services` | Organization, WebSite, Service, BreadcrumbList |
| `/applicant-tracking-for-real-estate-companies` | Organization, WebSite, Service, BreadcrumbList |
| `/blog/<slug>` — all 26 posts | Organization, WebSite, Article, BreadcrumbList |
| `/404` and any unmatched path | Organization, WebSite |
| `/sitemap.xml`, `/api/*` | none — not HTML routes |

Eight distinct block ids, all unique, no collision on any route: `organization`, `website`,
`software-application`, `pricing-product`, `article`, `breadcrumb`, `industry-service`,
`industry-breadcrumb`.

---

## Table 2 — every property tab 05 asked for that is deliberately OMITTED

This is the honest core of the phase. Each row is a property a tab row names, or a Google-required
property of a type a tab row names, that is not emitted.

| Property | Tab row | Why it is omitted | What would be needed to supply it |
|---|---|---|---|
| `Article.author` as a real author profile | A10 (C10 "add real author profiles") | No author data exists. `studio/schemas/blogPost.js` has no author field, `studio/schemas/` has no author document type, no post renders a byline. A name would be fabricated. Emitted instead: `{ "@id": ".../#organization" }` | A Studio document type or field, plus the author of each of the 26 posts. Jessica. |
| Time and timezone on `Article.datePublished` | A10 | `publishDate` is a Sanity `date` field, so no time exists to emit. Google's Rich Results Test reports "Invalid datetime value" and "missing a timezone" | `publishDate` changed from `date` to `datetime`, plus a time on 26 documents. Jessica. |
| `FAQPage`, `Question`, `acceptedAnswer` | A12 | No `/compare` route exists and no page on the site renders visible Q&A. Emitting FAQPage without a visible FAQ is a policy breach and was named a BLOCKER | The comparison pages, with visible Q&A written on them. |
| `Article` on `/compare/*` | A12 | Same — the pages do not exist | The comparison pages. |
| `JobPosting` | A13 | Product-side. `jobs.polymer.co` is served by inflow-ats; no route under `web/pages/` produces a job post. Cell D13 says "Outside marketing-site scope" | Nothing in this repo. The product already emits it; the `datePosted` format defect is in inflow-ats. |
| `SoftwareApplication.aggregateRating` | A8 | Cell D8 forbids it: "Polymer has no on-site reviews; do not invent." Consequence, measured: the block is still reported by the Rich Results Test as 1 valid item and eligible, with `aggregateRating` listed as a non-critical optional field | Real on-site reviews. Not a markup change. |
| `Product.aggregateRating`, `Product.review` | A9 | Same — no reviews exist | Real reviews. |
| `WebSite.potentialAction` / `SearchAction` | A7 (WebSite) | The site has no search route to point one at. `web/pages/` has no `search.js` | A site search feature. |
| `Organization.address` | A7 | Two locations are published and neither is unambiguous: a Delaware registered-agent address in `terms.js`, and "Charlotte" with no street in `about.js`. Not named by C7 | A decision on which entity and address to publish. Jessica. |
| `Organization.legalName`, contact | A7 | Not named by C7. Values do exist — `llms.txt:3` states "operated by Curious One, Inc." and `pricing.js` links `mailto:support@polymer.co` | A decision to add properties beyond what C7 names. |
| `BreadcrumbList` on `/features/jobboard`, `/features/candidate-management-software` | Master prompt "BreadcrumbList site-wide" | Omitted. The stated reason — labels would be invented — does not hold for these two: parent `/features` is a nav label and both render their own titles | Two `BreadcrumbList` blocks. No new data. |
| `BreadcrumbList` on root-level routes | Master prompt | Those routes hang directly off the root, so a trail would invent hierarchy | Nothing — correctly omitted. |
| `SoftwareApplication.softwareVersion`, `datePublished`, `releaseNotes`, `screenshot`, `downloadUrl`, `installUrl` | A8 | Not named by C8. No real value in the repo for most; product screenshots live in `web/images/` outside `web/public/`, so they have only webpack-hashed URLs | Real values plus a decision to exceed C8. |
| `Product.brand`, `gtin`, `shippingDetails`, `hasMerchantReturnPolicy` | A9 | Not named by C9. `brand` would restate `name: "Polymer"`; the other three are physical-goods properties — Polymer ships nothing and has no returns | Nothing. Correctly omitted. |
| `UnitPriceSpecification.billingIncrement` on `/pricing` only | A9 | Removed as a claim the page does not make. **But it is still emitted on `/`, `/features` and `/plato`** — see section 1 | Delete two lines from the component, or restore the argument in `pricing.js`. |

---

## Close

**Rounds run:** 3. Every reviewer returned in every round — no agent failed to report, so no round
was a false clean pass.

**Converged:** no. Round 3 findings drove further code changes, and those changes introduced the
`billingIncrement` divergence recorded above. A fourth round would be needed to confirm the tree is
stable.

**Severity remaining:**

- **HIGH — 1.** Every fix from three rounds is uncommitted. PR #50 ships the pre-fix state: row A9's
  Offers carry no `price`, row A8's lead with $149, `sameAs` has no LinkedIn, and blog and industry
  pages each restate the Organization. This is the only finding that changes what merging does.
- **MED — 2.** The `billingIncrement` divergence between the two price blocks, asserted as parity in
  both files' comments and three changelog passages. The `PLANS` hand-copy in
  `softwareApplicationJsonLd.js`, which cell D9's "update if billing copy changes" makes load-bearing.
- **LOW — 4.** Schema Markup Validator not run (CAPTCHA-blocked). BreadcrumbList absent from two
  `/features/*` routes whose labels exist. Homepage URL stated with and without a trailing slash.
  `SoftwareApplication` and `Product` carry no `@id`, so they are not linked to the Organization.
- **BLOCKER — 0.**

**No `aggregateRating`, `ratingValue`, `reviewCount`, `review`, `bestRating` or `worstRating` exists
anywhere on this branch. No `FAQPage` exists anywhere on this branch, and no page renders a visible
Q&A set. Nothing was fabricated: every emitted value traces to a repo file or a live resource that
was fetched.**
