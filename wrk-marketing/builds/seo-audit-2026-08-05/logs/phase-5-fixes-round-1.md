# Phase 5 structured data — fixes, round 1

## web/pages/_app.js

Finding: MED, tab 05 rows A7 / A10 / A11 — "No `@id` on any node, so the site-wide
Organization cannot be referenced and every page-level block restates it ... Same entity, two
encodings, on the same page."

### Workbook check

Ran `python3 read-workbook.py "05 Structured"`. Tab 05 rows A1, A2, A4, A6-D6 and A7-D13 match
the orchestrator's transcription character for character. No misquote.

### What changed

Two edits, both inside the site-wide schema objects at the top of the file. `logo`, `name`, `url`
and `sameAs` are untouched.

1. `organizationSchema` gains `"@id": "https://www.polymer.co/#organization"`, hoisted into an
   `ORGANIZATION_ID` constant. This is the node identifier a page-level block references instead
   of restating the company.
2. `websiteSchema` gains `"@id": "https://www.polymer.co/#website"` and
   `publisher: { "@id": ORGANIZATION_ID }`, so the WebSite node points at the Organization node
   rather than the two sitting unlinked.

No property was added whose value is not already in the repo.

### Verified in real output

`next dev` on port 3999, node 20.18.1, JSON-LD extracted from the served HTML and parsed. First
run, across all six page types:

| Page | ld+json blocks | Organization `@id` | WebSite `publisher` | Organization nodes on page |
|---|---|---|---|---|
| `/` | 3 | `.../#organization` | `{"@id": ".../#organization"}` | 1 |
| `/features` | 3 | `.../#organization` | resolves | 1 |
| `/plato` | 3 | `.../#organization` | resolves | 1 |
| `/pricing` | 3 | `.../#organization` | resolves | 1 |
| `/blog/hiring-gen-z` | 4 | `.../#organization` | resolves | 3 |
| `/industries/applicant-tracking-for-startups` | 4 | `.../#organization` | resolves | 2 |

Every block parses as JSON. Block count per page is unchanged from before the edit, so no
next/head key collision was introduced. `curl` on the `logo` path returns `200 image/png`.
Confirmation run after the encoding revert below: `/` still emits 3 blocks,
`Organization @id=https://www.polymer.co/#organization`,
`logo="https://www.polymer.co/android-chrome-512x512.png"`,
`WebSite publisher={"@id":"https://www.polymer.co/#organization"}`.

### Encoding mismatch — attempted, then reverted

The finding also names the `logo` encoding split: `_app.js` wrote a plain URL string, the two
restatements wrote an `ImageObject`. I first changed `_app.js` to `ImageObject` to match. While
that was in place, `git status` showed a concurrent agent editing
`web/components/industryJsonLd.js` the other direction — its `polymerOrganization.logo` going
from `ImageObject` to the plain URL string, i.e. converging on `_app.js`'s original form. Holding
my change would have inverted the mismatch rather than closed it, so I reverted `_app.js` to the
plain URL string. The convergence target for all three copies is the string form.

### Not fixed — outside this file

The blog page still carries 3 Organization nodes and each industry page 2, because the
restatements live in files this agent does not own:

- `web/pages/blog/[slug].js` lines 34-43 — `polymerOrganization`, used as `Article.author` and
  `Article.publisher`.
- `web/components/industryJsonLd.js` lines 6-13 — `polymerOrganization`, used as
  `Service.provider`. Being edited concurrently this round, but for `logo` encoding only; the
  restatement itself remains.

Both should become `{ "@id": "https://www.polymer.co/#organization" }`. The identifier they need
now exists and is emitted on every page. Nothing in `_app.js` can collapse them.

### A7 sameAs — LinkedIn still absent, and that is correct

Row A7 asks for `sameAs (X, LinkedIn, Discord)`. The node carries X and Discord. Searched
`web/components`, `web/pages`, `web/public` and `studio` for "linkedin" and fetched
`https://www.polymer.co`: the only LinkedIn URL anywhere is
`https://help.polymer.co/en/articles/8828635-post-your-jobs-to-linkedin`, a help-center article
about the LinkedIn job-posting integration. No Polymer LinkedIn company profile URL exists in the
repo or on the live homepage. Omitted rather than invented.

### No fabrication introduced

No `aggregateRating`, `ratingValue`, `reviewCount`, `review`, `FAQPage`, `SearchAction` or
`potentialAction` in this file. No author name, no profile URL, no rating.

---

## SEO-CHANGELOG.md

Two findings, both MED, both against the changelog rather than against code: row A13's
verification not done, and the Phase 5 section stating five times that row A11 was not actioned
while the code does it.

### Workbook check

Ran `python3 read-workbook.py "05 Structured"`. Tab 05 A1, A2, A4, A6-D6 and A7-D13 match the
orchestrator's transcription character for character, including note A4's "$124/$233/$415 per
month tiers" and D13's "verify product already emits JobPosting for Google Jobs - it is Polymer's
own distribution feature". No misquote.

### A13 — the verification, done

The row asked for a verification, not a code change, and it is now done. Result: **the product
does emit JobPosting**, server-rendered, on live job-detail pages.

What was measured, read-only, 2026-08-06:

- `https://jobs.polymer.co/` 301s to `https://polymer.co/`. Tenant boards are paths on that host.
  `https://jobs.polymer.co/polymer` and `/m3` return 200 and list no open roles.
  `https://jobs.polymer.co/aboard` returns 200 and lists one, `Solution Engineer`.
- `https://jobs.polymer.co/aboard/40210` — the live job. `curl` returns 25,714 bytes containing
  exactly one `<script type="application/ld+json">`, and it is a `JobPosting`. No JavaScript
  executed, so a non-rendering crawler sees it. Re-confirmed in a real browser DOM: 1 ld+json
  block, 0 microdata elements.
- Properties emitted: `title`, `description`, `identifier` (PropertyValue, name `Polymer`),
  `datePosted`, `employmentType`, `hiringOrganization` (Organization: name, url, sameAs, logo),
  `url`, `directApply: true`, `jobLocation` (Place → PostalAddress: New York / NY / US),
  `baseSalary` (MonetaryAmount → QuantitativeValue 185000.0-225000.0 YEAR USD).
- Google's JobPosting doc, fetched: required are `datePosted`, `description`,
  `hiringOrganization`, `jobLocation`, `title` — all five present. `employmentType`, `identifier`,
  `baseSalary`, `directApply` are on its recommended list.
- Per live job, not per URL: both board index pages carry zero ld+json, and
  `https://jobs.polymer.co/m3/40813` (posting gone, renders "This job post could not be found")
  carries zero. The four `job_board_application` JS chunks contain zero occurrences of
  `JobPosting`, `ld+json` or `schema.org`, so nothing is injected client-side.
- One product-side defect found: `datePosted` is `2026-06-03 16:36:07 UTC`, which is not ISO 8601
  (Google's example is `2017-01-24T19:33:17+00:00`). `validThrough` is absent — recommended, and
  required only for postings with an expiration date. Both live in the Rails job board, not this
  repo. Recorded, not fixed.

Nothing about this row is actionable in `wrk-marketing`; the row asked to verify and the record
now carries the verification and its result.

### A11 — the five contradictions, corrected

The code has done row A11 since `a0235e0`. Six places in the changelog said otherwise:

1. "Nothing in this phase was committed or pushed. The working tree carries six modified files and
   two new ones," with an eight-file list containing no industry page. Replaced with the `a0235e0`
   record — seventeen files, +334/-7 across sixteen code files — plus the current working-tree
   snapshot (four files, concurrent fix agents mid-write).
2. "Four items ran … Row A11 … had no item and is not actioned." Now says the row was actioned
   afterwards by hand and points at the repairs section.
3. The URL/@type table listed all seven industry URLs as "Organization, WebSite". Now
   "Organization, WebSite, **Service**, **BreadcrumbList**", and the sentence about the rewrite
   twins says both forms carry the same four blocks and both name the short URL.
4. The omitted-properties table carried "`Service` / `WebPage` + `BreadcrumbList` … Not attempted."
   Row deleted — it is not an omission — with a line under the table recording the deletion.
5. "Row A11 … NOT ACTIONED" under "Tab rows not actioned". Rewritten in the phase-3/4 house form
   ("actioned, in a repair after the workflow rather than by any of the four items"), kept under
   that heading because the workflow never assigned the row.
6. Question 5, "still unanswered, and row A11 was never actioned." Now records that the question is
   still unanswered and the two-item trail shipped anyway.

Also added to the repairs section: a value-trace table for the six properties
`web/components/industryJsonLd.js` emits, matching the "every value traced" table each of the four
items already carries. One thing it records that was not previously written down — the breadcrumb
label is `verticalData.title`, the page's `<title>` text, not visible page copy: the `<h1>` on
these pages is `verticalData.heroTitle` ("Simple hiring tools for growing teams"), which names no
industry.

Verified before writing: `git log` — row A11's code is in `a0235e0`, not the working tree;
`git diff --numstat` for the file list and line counts; `grep -c "IndustryJsonLd"` returns 2 for
all seven industry pages; `web/components/industryJsonLd.js` read in full for the emitted
properties; `components/industries/industryHeader.js:15` for what the `<h1>` actually renders.

### No fabrication introduced

No value was invented. Every figure written into the changelog came from `git`, from a file in the
repo, or from a live page fetched during this round. No `aggregateRating`, `ratingValue`,
`reviewCount`, `review` or `FAQPage` was added anywhere.

### Noted, not acted on — outside my file

A web search for "jobs.polymer.co" returned `https://www.linkedin.com/company/withpolymer` as a
result titled "Polymer | LinkedIn". The `_app.js` round-1 section above records that no LinkedIn
company URL exists in the repo or on the live homepage, which is why `Organization.sameAs` carries
two entries. That search hit is not repo evidence and I did not fetch or verify it; `_app.js` is
not my file. Routing it so the A7 `sameAs` gap is decided on evidence rather than left assumed
impossible.
