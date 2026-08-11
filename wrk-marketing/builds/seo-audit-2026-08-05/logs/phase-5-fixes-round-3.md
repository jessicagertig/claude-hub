# Phase 5 structured data — fixes, round 3

## web/components/softwareApplicationJsonLd.js

Four findings, all against this one file. Two fixed, two not.

### Workbook check

Ran `python3 read-workbook.py "05 Structured"`. Tab 05 cells A1, A2, A4, A6-D6 and rows A7-D13 match
the orchestrator's transcription character for character — including note A4's "$124/$233/$415 per
month tiers", C8's "offers (3 tiers from /pricing)", D8's "No aggregateRating - Polymer has no
on-site reviews; do not invent" and D9's "update if billing copy changes". No misquote.

### Ground truth read before editing

Every value written into this file came out of `web/pages/pricing.js`. Nothing was fetched, inferred
or invented.

| Property added | Source | Value |
|---|---|---|
| `Offer.availability` | `web/pages/pricing.js:81` | `"https://schema.org/InStock"` |
| annual `billingIncrement` | `web/pages/pricing.js:83` | `12` |
| monthly `billingIncrement` | `web/pages/pricing.js:84` | `1` |

### FIXED — MED, row A8: `billingDuration` alone does not separate the two rates

Asked: SoftwareApplication with offers (3 tiers from /pricing).

`web/pages/pricing.js:44-47` carries `billingIncrement` alongside `billingDuration` on each
`UnitPriceSpecification` precisely because `billingDuration` is a schema.org pending term, and its
comment says so. This file emitted `billingDuration` alone, so a consumer that skips pending terms
read two `UnitPriceSpecification` objects with identical `priceCurrency` and `unitCode: "MON"`,
prices 124 and 149, and only the free-text `name` to tell them apart.

`billingIncrement: 12` and `billingIncrement: 1` now sit beside `billingDuration: "P1Y"` and
`billingDuration: "P1M"`, matching `/pricing`. Released GoodRelations vocabulary, not pending.

### FIXED — MED, row A8: `availability` was missing

Same finding's second half. `web/pages/pricing.js:81` sets `availability:
"https://schema.org/InStock"` on each of the same three Offers; this file set it on none.
`availability: "https://schema.org/InStock"` added to each Offer.

### FIXED — MED, rows A8 and A9: the parity claim in the comment

Asked: the two blocks' comments each assert the offers read the same way wherever emitted; the
rendered output did not support it.

With `availability` and `billingIncrement` added, the three Offers this file emits and the three
`web/pages/pricing.js` emits now carry the same property set — `@type`, `name`, `price`,
`priceCurrency`, `url`, `availability`, `priceSpecification` — with the same two
`UnitPriceSpecification` entries, annual first. The claim holds as written. The comment at lines
14-16 now names what parity means rather than asserting it: "in the shape the /pricing Product block
uses — same `availability`, same `billingIncrement`", and states why `billingIncrement` is there.

The reciprocal claim in `web/pages/pricing.js:62-63` becomes true by the same change. That file was
not edited.

### NOT FIXED — MED, rows A8 / D9: `PLANS` is a hand-copy of `prices`, not a read of it

Asked: offers (3 tiers from /pricing); cell D9 "update if billing copy changes".

Reported twice, by two angles, with the same named fix: move `prices` to module scope in
`web/pages/pricing.js`, export it, and import it here.

Not done. That fix edits `web/pages/pricing.js`, and this agent owns
`web/components/softwareApplicationJsonLd.js` only. `prices` is declared inside the `Pricing`
component body at `web/pages/pricing.js:26-29` and is not exported, so no edit confined to this file
can read it — an import statement here fails without the corresponding export there. A new shared
module under `web/lib/` has the same problem: it removes the duplication only once `pricing.js`
imports from it too.

Unchanged consequence, still stated in the file's own comment at lines 6-10: a rate change edits four
places — `prices` at `web/pages/pricing.js:27-28`, `PLANS` here, the literal `$124` in that page's
`pageTitle` at `web/pages/pricing.js:92`, and the six figures at `web/public/llms.txt:17-19`. Nothing
fails if one is missed; this block goes stale silently on `/`, `/features` and `/plato`.
`web/public/llms.txt` is a static file and cannot import JavaScript, so it stays a hand-copy under
any version of the fix.

### Fabrication check

No property was added whose value does not exist in this repo. `availability`, `billingIncrement: 12`
and `billingIncrement: 1` are all read out of `web/pages/pricing.js`. No `aggregateRating`,
`ratingValue`, `reviewCount` or `review` was added; none is present. No `FAQPage`. The six price
figures are untouched.

## QUESTIONS-FOR-JESSICA.md

Two findings, both fixed. The artifact Jessica reads had fallen behind the code and behind
`SEO-CHANGELOG.md`; nothing in the working tree changed.

### Workbook check

Ran `python3 read-workbook.py "05 Structured"` independently. Cells A1, A2, A4, A6-D6 and rows
A7-D13 match the orchestrator's transcription character for character — including note A4's
"$124/$233/$415 per month tiers", C7's "name, url, logo, sameAs (X, LinkedIn, Discord)", D8's "No
aggregateRating - Polymer has no on-site reviews; do not invent" and D13's JobPosting wording. No
misquote.

### FIXED — HIGH, row A7: the file said `sameAs` carries two entries; it carries three

Asked: `sameAs (X, LinkedIn, Discord)`.

`web/pages/_app.js:41-45` carries all three:

    sameAs: [
      "https://twitter.com/withPolymer",
      "https://www.linkedin.com/company/withpolymer",
      "https://discord.gg/MgQxHMYZFN",
    ],

Round 2 added the LinkedIn URL and corrected the three restatements of the gap inside
`SEO-CHANGELOG.md` (lines 1568, 2048, 2136), but its scope line reads "Only SEO-CHANGELOG.md
touched" — the questions file was never opened. Two entries in it still described the two-entry
state:

- line 126, "Phase 5, item 0" question 1 — "There is no LinkedIn URL anywhere on the site, so
  `sameAs` can only carry two links."
- line 146, "Phase 5, foundation" question 2 — "`sameAs` ships with two entries, not the three the
  tab asks for … when you have the company-page URL it is one array element in `web/pages/_app.js`."

Reading either, Jessica would have supplied a URL already in the markup.

Line 146 is struck through and marked "Fixed, no longer a question," now naming all three entries.
Line 126 is marked **half-settled**, not fixed: its LinkedIn half is closed, and its second half —
whether a Discord *invite* link is acceptable as a `sameAs`, since Google may not resolve an invite
as an entity reference — was never answered and is now labelled "Still open," with the note that it
shipped regardless because cell C7 names Discord.

Both entries keep the record of where the value came from, because that is the no-fabrication
audit trail: the URL exists nowhere in this repo and on no page of the site. It was taken off the
live LinkedIn page, verified 2026-08-06 — `200`, `<title>Polymer | LinkedIn</title>`, body names
`polymer.co`. Both now end by asking Jessica to say if it is the wrong profile, which is the only
question left on the property.

### FIXED — MED, row A8: the file predicted "not eligible"; the test says eligible

Asked: "No aggregateRating - Polymer has no on-site reviews; do not invent."

No rating is emitted — verified independently by grep across `web/pages`, `web/components` and
`web/public`: no `aggregateRating`, `ratingValue`, `reviewCount` or `review` anywhere. The row is
obeyed. The defect was in the record of why.

Line 166 read "These blocks will show as 'not eligible' in Google's Rich Results Test, and that is
correct. Google's SoftwareApplication rich result requires `name`, `offers` and *either*
`aggregateRating` or `review`." That was a prediction, and the test was later run:
`SEO-CHANGELOG.md:2052`, `:2181` and `:2226` all record the SoftwareApplication block as **1 valid
item detected**, eligible, with `Missing field "aggregateRating" (optional)` as a non-critical
issue, and the `/pricing` `Product` block as likewise valid and eligible with `review` and
`aggregateRating` both optional. The changelog states the correction was made; the questions file was
not touched, so the two records disagreed.

Line 166 is struck through, the wrong requirement is quoted as the thing that was wrong rather than
deleted, and the correction cites the run: Rich Results Test, 2026-08-06, code-snippet mode, result
id `4AoIBbNXQYpnwZ2WqfrcRQ`. The instruction the flag existed to carry is restated unchanged — no
rating is emitted and none must be invented — because that was the entry's purpose and it survives
the correction.

### Fabrication check

Nothing was invented. Every value written into the file is either read out of the working tree
(`web/pages/_app.js:41-45`) or quoted from `SEO-CHANGELOG.md`, which recorded the live LinkedIn fetch
and the Rich Results Test run. No property, URL, name or figure was added to any code file — this
agent edited one file, `QUESTIONS-FOR-JESSICA.md`, and made no source-repo change. The six price
figures, all three blocks and every schema property are untouched.

### Checked and left alone

Grepped the whole questions file for `linkedin`, "two entries", "two links", "two profiles", "not
eligible", `aggregateRating` and "rich result" to catch further restatements of either claim. The
three remaining hits are unrelated: line 156 is `eligibleDuration` in the free-trial entry, line 200
is a LinkedIn Insight tag inside the GTM question, line 216 is a `?source=linkedin` query string in a
legacy `wrk.xyz` URL. No other entry in the file describes either the two-entry `sameAs` or the
eligibility prediction.

## web/pages/pricing.js

Three findings against this file. One fixed, one already true in the file before this round, one that
cannot be finished inside this file.

### Workbook check

Ran `python3 read-workbook.py "05 Structured"`. Tab 05 cells A1, A2, A4, A6-D6 and rows A7-D13 match
the orchestrator's transcription character for character — including note A4's "Never fabricate
review/rating values; offers come from the live pricing page ($124/$233/$415 per month tiers)", C9's
"Starter $124/mo, Growth $233/mo, Scale $415/mo, priceCurrency USD" and D9's "Values verified on live
pricing page 2026-08-03; update if billing copy changes". No misquote.

### FIXED — MED, row A9: `billingIncrement` stated a term the page does not state

Asked: note A4 — never fabricate; a property with no real value must be omitted.

`billingIncrement` is "the quantity of `unitCode` units billed per charge". The page has a
Monthly/Annual toggle, a "2 months free!" badge and a per-month figure for each rate. It states the
billing *term*; it never states how many months go on one charge. `12` and `1` were derived from the
badge and from 124 x 12, not read off anything the page says. SEO-CHANGELOG.md:2058 had already
recorded exactly that: "Ambiguous here (1 month of usage, or 12 months charged at once)... a guessed
value would be a claim the page does not make."

Removed: the fourth parameter of `monthlyRate` and the `12` / `1` arguments at both call sites.
`billingDuration: "P1Y"` / `"P1M"` still separates the two `UnitPriceSpecification` entries, and that
one *is* stated — the toggle names the term.

Before:

```js
  const monthlyRate = (name, price, billingDuration, billingIncrement) => ({
    "@type": "UnitPriceSpecification",
    name,
    price,
    priceCurrency: "USD",
    unitCode: "MON",
    billingDuration,
    billingIncrement,
  });
...
        monthlyRate("Billed annually", prices.annual[key], "P1Y", 12),
        monthlyRate("Billed monthly", prices.monthly[key], "P1M", 1),
```

After:

```js
  const monthlyRate = (name, price, billingDuration) => ({
    "@type": "UnitPriceSpecification",
    name,
    price,
    priceCurrency: "USD",
    unitCode: "MON",
    billingDuration,
  });
...
        monthlyRate("Billed annually", prices.annual[key], "P1Y"),
        monthlyRate("Billed monthly", prices.monthly[key], "P1M"),
```

The comment above `monthlyRate` was rewritten to state the omission and its reason instead of
justifying the value. Parsed the edited file with `@babel/parser` (`sourceType: module`, `jsx`
plugin): parses.

### ALREADY TRUE — MED, rows A9 and A8: annual-first figures exist only in the working tree

Asked: /pricing carries Product + Offer x3 stating Starter $124/mo, Growth $233/mo, Scale $415/mo,
priceCurrency USD.

The finding is accurate about `HEAD`. `git show HEAD:web/pages/pricing.js` has no `price` on the
Offer at any level and lists `monthlyRate("Billed monthly", ...)` first. The working tree has
`price: prices.annual[key]` and "Billed annually" first. Nothing in this file needs to change — the
gap is that the change is uncommitted, and this agent is instructed not to commit. The orchestrator's
commit closes it.

### NOT FIXED HERE — MED, rows A8 and A9: the two blocks' Offers no longer carry the same properties

Asked: row A8 offers are the 3 tiers from /pricing; row A9 /pricing Product + Offer x3.

The finding as written says `web/components/softwareApplicationJsonLd.js` emits no `availability` and
no `billingIncrement`. That is no longer true of the working tree: the agent that owned that file this
round added both, at 04:02, sourcing them from `web/pages/pricing.js:81` and `:83-84` — its log
section above records that, and its comment at line 16 now reads "same `availability`, same
`billingIncrement`".

Deleting `billingIncrement` from this file re-opens the mismatch in the other direction, and leaves
that comment describing a property `/pricing` no longer emits. Both cannot be resolved from inside
`web/pages/pricing.js`.

The two findings point opposite ways, and note A4 is the one that decides it: a value the record
itself calls a guess is omitted, not propagated. So the deletion stands here, and
`web/components/softwareApplicationJsonLd.js` needs the same deletion — `billingIncrement: 12` at
line 55, `billingIncrement: 1` at line 64, and the two comment clauses at lines 16 and 19-21 — for the
two blocks to match again. Not this agent's file.

`availability` is not part of this: both blocks emit `availability: "https://schema.org/InStock"`, the
plans are on sale, and Google lists it for Product. The parity clause in this file's comment at the
old lines 62-63 was removed rather than re-stated — it has gone stale twice in three rounds, and the
`url` / `availability` sentence it was attached to stands on its own.

### Fabrication check

Nothing was added to this file. One property was removed. The three figures are still
`prices.annual[key]` and `prices.monthly[key]`, read out of the `prices` object the cards render
from, so they cannot drift from the page. No `aggregateRating`, `ratingValue`, `reviewCount`,
`review`, `FAQPage` or `potentialAction` is present.

## web/components/industryJsonLd.js

Four findings, all four the same defect stated by four angles: `Service.provider` inlined a second
Organization object instead of referencing the site-wide node. Fixed. Nothing not fixed.

### Workbook check

Ran `python3 read-workbook.py "05 Structured"`. Cells A1, A2, A4, A6-D6 and rows A7-D13 match the
orchestrator's transcription character for character — including row A11's "Industry ATS pages (7)" /
"Service or WebPage + BreadcrumbList" / "name, description, provider" / "Keep light; breadcrumbs
matter most", and note A4's "Never fabricate review/rating values". No misquote.

### FIXED — MED, row A11: `provider` restated the company instead of referencing it

Asked: Industry ATS pages (7), Service or WebPage + BreadcrumbList, required properties name,
description, provider. Row A7's note: emit Organization once in the root layout.

`provider` was present, so row A11's property list was satisfied. The defect was that it carried a
second Organization object with no `@id` and the same `name`, `url` and `logo` as the node
`web/pages/_app.js:34-46` already emits on every page — so each of the seven industry pages stated
Polymer twice, once identified and once anonymous, and a consumer merging the page's blocks read two
distinct entities.

`web/pages/blog/[slug].js:37` and `:267-268` were changed earlier in this same working tree from
exactly this inline object to a local `ORGANIZATION_ID` constant plus `{ "@id": ORGANIZATION_ID }`.
This file is now the same shape, so the branch does it one way.

Before:

```js
// Same name, url and logo as the site-wide Organization in pages/_app.js.
const polymerOrganization = {
  "@type": "Organization",
  name: "Polymer",
  url: BASE_URL,
  logo: {
    "@type": "ImageObject",
    url: `${BASE_URL}/android-chrome-512x512.png`,
  },
};
...
          provider: polymerOrganization,
```

After:

```js
// Service.provider below references the site-wide Organization node
// pages/_app.js emits on every page, so an industry page names the company once
// instead of restating it.
const ORGANIZATION_ID = `${BASE_URL}/#organization`;
...
          provider: { "@id": ORGANIZATION_ID },
```

`polymerOrganization` had exactly one reference — line 35 in this file. Grepped `web/pages` and
`web/components` for the identifier: no other file read it, so removing it stripped nothing else.

### Verification

Parsed with the repo's own babel (`next/babel` preset, resolved from `web/node_modules`): parses.

Rendered, not inferred. Started `next dev` on port 3991 (a free port — the pre-existing listener on
3000 was left alone), fetched all seven industry routes, parsed every `application/ld+json` block and
counted objects carrying `"@type": "Organization"`:

| Route | ld+json blocks | Organization nodes | `Service.provider` |
|---|---|---|---|
| /applicant-tracking-for-startups | 4 | 1 | `{"@id":"https://www.polymer.co/#organization"}` |
| /applicant-tracking-for-legal-services | 4 | 1 | same |
| /applicant-tracking-for-cryptocurrency-companies | 4 | 1 | same |
| /applicant-tracking-for-greentech-companies | 4 | 1 | same |
| /applicant-tracking-for-real-estate-companies | 4 | 1 | same |
| /applicant-tracking-for-fintech-companies | 4 | 1 | same |
| /applicant-tracking-for-healthcare-companies | 4 | 1 | same |

Before the edit the same count was 2. The one surviving Organization is the `_app.js` node, and it
carries `"@id": "https://www.polymer.co/#organization"` plus all three `sameAs` entries, so the
`@id` the `provider` reference points at resolves on the same page. Block count is unchanged at 4 —
organization, website, industry-service, industry-breadcrumb — so nothing was dropped or deduped by
`next/head`. Every payload parses as JSON. Dev server stopped afterward; port 3991 free, port 3000
untouched.

### Fabrication check

No value was added. One object was deleted and replaced by a reference to an `@id` that already
exists in the working tree at `web/pages/_app.js:37`. No URL, name, logo or figure was invented, and
none was fetched — the fix needed no value that was not already in the repo. No `aggregateRating`,
`ratingValue`, `reviewCount`, `review`, `FAQPage`, `Question` or `acceptedAnswer` is present in this
file; none was added. The `BreadcrumbList` block, the two-item trail and the `name`, `description`
and `url` properties are untouched.

## SEO-CHANGELOG.md — round 3

Branch confirmed: `git -C /Users/jessica/wrk/wrk-corp/wrk-marketing rev-parse --abbrev-ref HEAD` =
`seo-phase-5-structured-data`. Nothing committed, nothing pushed. Only `SEO-CHANGELOG.md` edited.

Three MED findings, all of them the same shape: the record states something about the working tree
that is not true of the working tree. All three are fixed.

### Workbook check

Ran `python3 read-workbook.py "05 Structured"`. Tab 05 cells A1, A2, A4, A6-D6 and rows A7-D13 match
the orchestrator's transcription character for character, including note A4's "$124/$233/$415 per
month tiers", C7's "name, url, logo, sameAs (X, LinkedIn, Discord)", C9's "Starter $124/mo, Growth
$233/mo, Scale $415/mo, priceCurrency USD" and D13's JobPosting wording. No misquote.

### Finding 1 — MED, row A9: the omissions table listed three emitted properties as omitted

Tab 05 row A9 asked for: Starter $124/mo, Growth $233/mo, Scale $415/mo, priceCurrency USD.
Status: DONE. The record of it was not.

Read out of the files before editing, every line number checked the same session:

| Property | File and line | Value |
|---|---|---|
| `Product.image` | `web/pages/pricing.js:70` | `"https://www.polymer.co/images/card.png"` |
| `Offer.url` | `web/pages/pricing.js:80` | `"https://www.polymer.co/pricing"` |
| `Offer.availability` | `web/pages/pricing.js:81` | `"https://schema.org/InStock"` |
| `billingIncrement` | `web/pages/pricing.js:83-84` | `12`, `1` |
| `Offer.availability` | `web/components/softwareApplicationJsonLd.js:46` | `"https://schema.org/InStock"` |
| `billingIncrement` | `web/components/softwareApplicationJsonLd.js:55,64` | `12`, `1` |

Six passages corrected, none of them by deleting the earlier wording:

| Where | Was | Now |
|---|---|---|
| Phase 5 preamble, "**Not** integrated below" heading and its one bullet | the four `pricing.js` properties listed as still making item 3's `after:` block, three omissions rows and item 3 LOW-4 stale | the heading is gone, the bullet moved into the "Integrated below, in place" list and extended to `softwareApplicationJsonLd.js`, and the section closes "Nothing in the working tree is un-integrated below as of 2026-08-06" |
| Item 2 `after:` block | Offer with no `availability`, specs with no `billingIncrement` | the file at mtime 2026-08-06 04:02:40 — `availability` on the Offer, `billingIncrement` 12 and 1 on the two specs |
| Item 2 value-trace table | 9 rows | 11 — `availability` and `billingIncrement` with their sources; the two `prices` citations corrected from `:27`/`:26` to `:28`/`:27` and marked as hand-copies, which is verifier MED-1 |
| Item 3 `after:` block | three-argument `monthlyRate`, no `Product.image`, no `Offer.url`, no `availability` | the working tree: four-argument `monthlyRate` with `billingIncrement`, `image`, `url` and `availability`, and the "+38 lines" count corrected to +49 of the file's +51 |
| Item 3 value-trace table | 7 rows | 10 — `image`, `availability` and `billingIncrement` with their sources, plus a line recording that the two `prices` citations were off by one |
| Omissions table, `billingIncrement` row and the `Offer.availability` / `seller` / `itemOffered` / `Product.brand` / `Product.image` row | both standing as omissions | `billingIncrement` struck through with how the ambiguity was resolved; the five-property row split — `seller`, `itemOffered` and `brand` keep a row as genuine omissions, `Offer.availability` and `Product.image` struck through with their sources |
| Item 3 LOW-4 | "`Product` emits no `image` and no `brand`" | same text, with a bold append: `image` is emitted at `web/pages/pricing.js:70`, `brand` is still absent and stays absent |

The strike-through-and-quote-the-old-text form is this file's own convention for a row that stops
being true — the `Organization.sameAs` LinkedIn row already uses it.

### Finding 2 — MED, master prompt: validate every template's output with a schema validator

Asked: "Validate every template's output with a schema validator before PR."
Status: DONE, except for one tool that needs a human.

`https://validator.schema.org` re-tried this round: `POST /validate` and `GET /` both answer `302`
to `https://www.google.com/sorry/index?continue=…`. Still a CAPTCHA. That tool did not run.

So the check it performs was run against the same vocabulary it reads:

- `./node_modules/.bin/next dev -p 3521` (node v20.18.1) against the working tree. Fetched `/`,
  `/pricing`, `/features`, `/plato`, `/blog/hiring-gen-z`, `/applicant-tracking-for-startups`.
  20 `<script type="application/ld+json">` tags, all parse, 8 distinct blocks over 7 `@type`
  values — the same 8 the round-2 run found. Server stopped afterwards, `000` on the port.
- Vocabulary: `https://schema.org/version/latest/schemaorg-current-https.jsonld`, 1,551,177 bytes.
- Checked, on every node including nested ones: `@type` is a declared `rdfs:Class`; each property is
  a declared `rdf:Property`; the property's `schema:domainIncludes` names the node's type or a
  superclass of it. 149 properties.
- Not checked: `schema:rangeIncludes`. Value-type errors are what the Rich Results Test already
  reported on `priceSpecification` and `datePublished`, and both are already in the changelog.

**Result: 0 unknown types, 0 unknown properties, 0 domain violations.** `Organization`, `WebSite` and
`Service` — the three types the Rich Results Test has no feature for — are clean at the vocabulary
level.

Two properties carry `schema:isPartOf: https://pending.schema.org`, meaning proposed rather than
released: `billingDuration` (12 occurrences) and `provider` (1, on the seven industry pages).
`billingDuration` was already recorded as pending. `provider` was not known to be — verified twice,
in the dump and in the JSON-LD embedded in `https://schema.org/provider` itself. Nothing changed:
cell C11 names `provider` by name, so it is emitted because the tab requires it.

The changelog's "the vocabulary-level check … is still outstanding" sentence is replaced, with the
old wording quoted, and the section now closes with what is genuinely left: one person, one paste
into `https://validator.schema.org`, one CAPTCHA.

### Finding 3 — MED, master prompt: BreadcrumbList site-wide

Asked: "BreadcrumbList site-wide".
Status: DONE INCOMPLETELY, and now recorded as unfinished work rather than as an omission.

`grep -rn "BreadcrumbList" web/ --include=*.js` returns three hits — two in
`web/components/industryJsonLd.js`, one in `web/pages/blog/[slug].js:278`. 33 URLs of 22 routes.

The row sits in a table headed "Properties the tab asked for that were deliberately OMITTED because
no real value exists," and for `/features/jobboard` and `/features/candidate-management-software` a
real value does exist. Verified in the files rather than restated: `Features` is the menu text at
`web/components/navigation.js:40` (mobile) and `:72` (desktop); the two `<h1>`s are `The best job
boards around` (`web/components/jobBoard/intro.js:19`) and `Candidate management made easy`
(`web/components/candidateManagement/intro.js:19`); the three-`ListItem` shape a trail would copy is
`web/pages/blog/[slug].js:276-284`.

The row now says so in bold — for those two routes it is work not done, not a value that is
unavailable — names the two files as owned by no phase-5 item, and leaves the other 14 root-level
routes open as question 9, which is a judgement rather than a missing value.

I own `SEO-CHANGELOG.md` only, so the two pages were not edited. The row records the gap; it does
not close it.

### Nothing fabricated

No value was invented. Every figure, property name, file path and line number written into the
changelog this round was read out of a file in this repo the same session, or fetched live
(`https://schema.org/version/latest/schemaorg-current-https.jsonld`, `https://schema.org/provider`,
`https://schema.org/billingDuration`, `https://schema.org/billingIncrement`,
`https://validator.schema.org`). No `aggregateRating`, `ratingValue`, `reviewCount`, `review`,
`FAQPage`, `acceptedAnswer`, `SearchAction` or `potentialAction` was added anywhere, and the
extraction above confirms none is emitted: 8 blocks, zero occurrences of any of them.

### Nothing outside my file

`git status --short` before and after: `SEO-CHANGELOG.md` plus five code files that are other
agents' work this round. Every command against the repo was a read except the edits to my own file.
The dev server on 3521 was started and stopped inside this run; the `pkill` pattern named that port
so no other agent's process was touched. Nothing committed, nothing pushed.
