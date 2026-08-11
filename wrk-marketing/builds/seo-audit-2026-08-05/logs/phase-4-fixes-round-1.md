# Phase 4 fixes — round 1

## SEO-CHANGELOG.md

Agent file: `/Users/jessica/wrk/wrk-corp/wrk-marketing/SEO-CHANGELOG.md`. Round 1. Branch confirmed
`seo-phase-4-metadata-headings`. Nothing committed, nothing pushed. No file other than
`SEO-CHANGELOG.md` was written in the repo. No Sanity mutation was issued — every Sanity call was a
GET against the query API. `web/.env.local` was read to obtain `SANITY_API_WRITE_TOKEN` for
authenticated draft reads and was not modified; the token was not written anywhere.

### Workbook check

Ran `read-workbook.py` on `07 Title Rewrites`, `10 Wrk Legacy` and `14 External Links`. The
orchestrator's quotes of tab 07 match the workbook character for character across all 13 data rows
A7-A19, including row A16's Problem cell `Launch post; doubled brand`. No misquote.

### Findings assigned to this file

Both findings are the same defect seen from two angles: `SEO-CHANGELOG.md` asserts that each of the
five phase-4 Sanity drafts differs from its published document in exactly one field, and its drafts
table lists `pageTitle` as the only changed field on
`drafts.fcfc319d-8b14-46d0-aef5-fc1fdd751060`. Both statements are false against the dataset as it
stands.

### What I measured, before editing anything

Read-only GROQ against project `a6d1clb1`, dataset `production`, API version `v2021-10-21`, on
2026-08-06. Query `*[_id in path("drafts.**")]{_id,_type,_updatedAt,_createdAt,"slug":slug.current}`,
then every draft fetched whole alongside its published document and compared field by field, with
`content` walked to every scalar leaf.

Eleven drafts exist in the dataset.

| Draft id | `_type` | slug | `_createdAt` | `_updatedAt` | Differs from published in |
|---|---|---|---|---|---|
| `drafts.c6e4e552-16a4-4624-b548-af6cba2779ee` | `ogre` | — | 2022-04-28T22:07:05Z | 2022-04-28T22:12:24Z | `reward` |
| `drafts.83ff9bc1-0a12-4def-9beb-49f2489abbd6` | `changelog` | — | 2022-06-15T14:30:50Z | 2022-08-18T22:49:35Z | `content` |
| `drafts.3323e96f-7d9a-44cc-85ce-9273e3f1beb9` | `changelog` | — | 2023-03-20T14:46:57Z | 2023-07-11T12:55:43Z | `content` |
| `drafts.2dc23f74-13f3-45c6-aff2-8bf7830e6261` | `blogPost` | `hello-polymer` | 2026-08-06T01:30:50Z | 2026-08-06T01:30:50Z | `pageTitle` |
| `drafts.54ea4d1f-deee-47c6-849e-da34989f5736` | `blogPost` | `use-webflow-cms-…-webflow-site` | 2026-08-06T01:30:52Z | 2026-08-06T01:30:53Z | `pageTitle` |
| `drafts.e563dba0-f14d-4493-ab3c-20de909bae59` | `blogPost` | `hiring-gen-z` | 2026-08-06T01:30:55Z | 2026-08-06T01:30:57Z | `pageTitle` |
| `drafts.a239b0d1-bad6-459f-98d1-b809d5a82dc7` | `blogPost` | `first-impression-bias` | 2026-08-06T01:31:01Z | 2026-08-06T01:31:03Z | `metaDescription` |
| `drafts.fcfc319d-8b14-46d0-aef5-fc1fdd751060` | `blogPost` | `best-applicant-tracking-software` | 2026-08-06T01:30:59Z | **2026-08-06T02:52:06Z** | **`pageTitle` and `content`** |
| `drafts.914dc19a-965f-4e6d-8187-2db998abba02` | `changelog` | — | 2026-08-06T02:51:57Z | 2026-08-06T02:51:58Z | `content` |
| `drafts.609fbb42-fc71-4d5b-a64a-cb7d49d4c11f` | `changelog` | — | 2026-08-06T02:52:00Z | 2026-08-06T02:52:00Z | `content` |
| `drafts.3d2afcd8-1acf-429c-81fa-ece69c210185` | `changelog` | — | 2026-08-06T02:52:02Z | 2026-08-06T02:52:03Z | `content` |

Three predate the audit (2022 and 2023). Eight were written by it. The changelog said five.

`drafts.fcfc319d-8b14-46d0-aef5-fc1fdd751060`'s `content` difference is one leaf, block
`a937d5dc8309`, markDef `dce1a2d61580`, `href`:

```
published: https://help.wrk.xyz/en/articles/4436181-have-your-job-posts-appear-in-google-jobs
draft:     https://help.polymer.co/en/articles/4436181-have-your-job-posts-appear-in-google-jobs
```

`curl -s -o /dev/null -L -w "%{http_code}"` on 2026-08-06: the `help.wrk.xyz` form 404, no redirect;
the `help.polymer.co` form 200, no redirect.

The three `changelog` drafts carry the same shape of change, one `markDefs[].href` each —
`5280480` → `10250419`, `5721143`, `5721747`, all `help.wrk.xyz` → `help.polymer.co`. Those three
article ids are exactly tab `10 Wrk Legacy` rows A8-A10 and tab `14 External Links` rows A7-A9.
Article `4436181` is on neither tab. `logs/phase-6-wrk-legacy.md` is the author of all four writes:
its row 4 records that `4436181` was found by scanning every document in the dataset rather than
from a tab row, that markDef `dce1a2d61580` is orphaned (no span in block `a937d5dc8309` carries
it), that the live version of the same link is already correct two blocks later in block
`e0995478e9e9` markDef `ad7866ef4c00`, and that its patch was built from the phase-4 draft rather
than the published document so the `pageTitle` change would survive.

### Tab row status

Tab 07 row A19 asked for: `7 Best Applicant Tracking Systems for Small Businesses (2026)`

Status: DONE, as an unpublished `pageTitle` value on
`drafts.fcfc319d-8b14-46d0-aef5-fc1fdd751060`. It matches the tab cell character for character,
ASCII hyphen-minus, no smart punctuation.

Corrected in round 2. This entry read: the rendered `<title>` once published is `7 Best Applicant
Tracking Systems for Small Businesses (2026) | Polymer` at 71 characters, because
`web/components/seo.js` line 18 appends ` | Polymer` and the tab cell does not carry it. That held
when written and no longer does. A sibling agent added `noBrandSuffix` to `web/pages/blog/[slug].js`
line 279 at 01:56:59, so the rendered `<title>` once published is
`7 Best Applicant Tracking Systems for Small Businesses (2026)` at 61 characters. The cell is 61 as
stored, 1 over the auditor's own 60 limit with no suffix at all. `SEO-CHANGELOG.md` lines 1382-1387
still carry the pre-opt-out figures and are now stale in three of their four rows; this round I own
only this log and may not write to the repo, so that table is listed under "Not fixed" below.
`web/components/seo.js` is not my file.

The defect in my file was never the title. It was that the changelog told Jessica this draft
carried one changed field when it carries two, and told her five drafts await her approval when
eight do.

### Edits made

Four edits, all in `/Users/jessica/wrk/wrk-corp/wrk-marketing/SEO-CHANGELOG.md`.

1. **Line 965**, the phase-4 preamble. `They are the only part of this run that requires an action
   from Jessica` → `the only part of **this phase**`, plus one sentence recording that a later phase
   added three drafts and wrote a second change into one of these five, so the Studio's pending list
   is not five rows.

2. **Line 1270**, the "Sanity drafts awaiting approval" opener. Dropped the false sentence `Each
   draft differs from its published document in exactly one field, verified field by field after the
   write` and the bold claim that these five are the only part of this run needing action. Everything
   else in that paragraph was left as written — the `.publish()` statement, the byte-identical
   published documents, and the no-pre-existing-draft statement all still hold and I confirmed all
   three against the dataset.

3. **New paragraphs after it**, carrying the measurement above: which draft differs in two fields,
   the second write at `2026-08-06T02:52:06Z`, who made it, that publishing the draft ships both
   changes, the three extra `changelog` drafts by id and timestamp, `Eight drafts from this audit
   await approval in the Studio, not five`, and the three pre-audit drafts named so the Studio's
   eleven-row list is fully accounted for.

4. **The drafts table**, one new row for `best-applicant-tracking-software` `content`, with the
   block key, markDef key, and both href values in full; followed by a paragraph giving the two
   status codes, the fact that no tab row prescribes article `4436181`, and the phase-6 log's own
   record that the markDef is orphaned and renders nothing.

The old false sentences are quoted inside the corrections rather than deleted silently, which is how
the rest of this file handles superseded claims.

### Checked for stale references after the amendment

`grep -n "five drafts\|Five Sanity\|exactly one field\|only part of this run\|five documents"` over
the whole file. Remaining hits and why each stands:

- Line 1270 `No draft existed for any of the five documents beforehand` — true. The three pre-audit
  drafts are an `ogre` document and two `changelog` documents; none of the five phase-4 `blogPost`
  documents had a draft before the run.
- Line 1275 `The other four drafts in the table below still differ in exactly one field each` — my
  own sentence, measured.
- Line 1400, needsLiveCheck, `After publishing the five drafts, confirm the <title> of the four blog
  posts and the meta description of /blog/first-impression-bias` — a phase-4 statement about
  phase-4's five drafts, still accurate. The three `changelog` drafts belong to phase 6's own
  live-check list, not this one.

### Not fixed

Nothing in the findings was left unfixed.

Out of my ownership, stated once and not acted on: `SEO-CHANGELOG.md` has no Phase 5 or Phase 6
section at all, so the three `changelog` drafts and the `4436181` href now have their only
in-repo record inside the Phase 4 section, where I put them because that is the section Jessica
reads before opening the Studio. A Phase 6 section is whoever owns Phase 6's writing to do.

## web/components/seo.js

Agent file: `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/components/seo.js`. Round 1. Branch
confirmed `seo-phase-4-metadata-headings`. Nothing committed, nothing pushed. No Sanity call of any
kind was made from this agent. `web/.env.local` was not read and not modified.

### Shared infrastructure changed

`web/components/seo.js` now carries a `noBrandSuffix` prop. This is the change sanctioned for this
phase. The whole of it is two lines:

```
   pageTitle,
+  noBrandSuffix,
   editorialTitle,
...
     pageTitle: pageTitle
-      ? pageTitle + " | Polymer"
+      ? pageTitle + (noBrandSuffix ? "" : " | Polymer")
       : "Polymer: Hiring made simple",
```

The prop is undefined on every call site that does not pass it, so the ternary takes the `" | Polymer"`
branch and the default is byte-identical to before. The propless `<SEO />` at `web/pages/_app.js`
line 93 passes no `pageTitle` at all and still resolves to the `"Polymer: Hiring made simple"`
fallback, untouched.

**Pages that now opt out.** Corrected in round 2 — this sentence read `web/pages/about.js` and
`web/pages/changelog.js`. Those two, and no others, which was false when written. Measured with
`grep -rn "noBrandSuffix" web/pages web/components --include=*.js` at 2026-08-06 01:57:16 local,
five call sites pass the prop:

| Call site | Route(s) that lose the suffix |
|---|---|
| `web/pages/index.js` line 17 | `/` |
| `web/pages/pricing.js` line 38 | `/pricing` |
| `web/pages/about.js` line 24 | `/about` |
| `web/pages/changelog.js` line 58 | `/changelog` |
| `web/pages/blog/[slug].js` line 279 | every `/blog/<slug>` route, not only the four on tab 07 |

`git diff` against `seo-phase-3-redirects-canonicals` shows four of the five page files changed by
exactly one added line, the `noBrandSuffix` line itself. `web/pages/index.js` is the exception: it
rendered no `<SEO>` at all before this branch, so its diff adds the `SEO` import on line 1 and the
whole five-line `<SEO>` element, `noBrandSuffix` among them. The element's
`editorialTitle="Hiring made simple"` was added by that file's owner at 02:00 to hold `og:title` at
the value the propless `<SEO />` in `_app.js` produced before this branch.

No other page passes the prop. Every other page that passes a `pageTitle` still renders it with
` | Polymer`; pages that render `<SEO>` with no `pageTitle` are unaffected either way, because the
ternary's false branch returns the `"Polymer: Hiring made simple"` fallback, which never carried a
suffix.

The fifth call site, `web/pages/blog/[slug].js` line 279, was written at 01:56:59 by a sibling
round-2 agent, seventeen seconds before I measured; it is not my file and I did not author it. It
is a single prop on the shared blog template, so it opts out every blog post — 26 published
`blogPost` documents, of which 22 have no tab 07 row.

### I verified this change, I did not author it

When I read `web/components/seo.js` at the start of this round it had neither line — line 19 was
`? pageTitle + " | Polymer"` with no prop. The file's mtime is `2026-08-06 01:33:03` local, seconds
after that read, and `web/pages/about.js` (01:33:06), `web/pages/changelog.js` (01:34:01),
`web/pages/pricing.js` (01:34:59) and `web/pages/index.js` (01:35:21) follow it in sequence. A
sibling agent wrote the prop and the call sites together while I was reading. The content is the
minimum change and its default path is identical, so I left it as written and spent this round
measuring it instead. **I made no edit to `web/components/seo.js`.**

Round 2 re-measurement of those mtimes: `web/pages/about.js` 01:33:06 and `web/pages/changelog.js`
01:34:01 and `web/pages/pricing.js` 01:34:59 are unchanged, but `web/components/seo.js` and
`web/pages/index.js` now both read `2026-08-06 01:49:10` and `web/pages/blog/[slug].js` reads
`01:56:59`. Sibling agents rewrote those three after the round-1 log. `web/components/seo.js` still
holds the same two-line change quoted above and I have still made no edit to it.

### Workbook check

Ran `read-workbook.py "07 Title Rewrites"`. All 13 data rows A7-A19 match the orchestrator's quotes
character for character, including D16 `Launch post; doubled brand` and the E-column rewrites. No
misquote.

### What I measured

`next dev` on port 3611 against the working tree, titles taken from the served HTML, not from props.
Server killed after each run, `lsof -ti tcp:3611` empty, `.next` is gitignored, `git status --short`
unchanged from what I found. HTML entities below are expanded to the characters they encode.

| Route | Rendered `<title>` | Len | Tab cell |
|---|---|---|---|
| `/` | `Polymer \| Applicant Tracking System & Job Boards for Startups` | 61 | E7, exact |
| `/pricing` | `Polymer Pricing - Simple ATS Plans from $124/mo` | 47 | E8, exact |
| `/plato` | `Plato AI - AI Candidate Screening & Resume Review \| Polymer` | 59 | E9, exact |
| `/features/jobboard` | `Job Board Software - Branded, Instant, Free to Start \| Polymer` | 62 | E10, exact |
| `/blog` | `Hiring & Recruiting Blog - Guides and Templates \| Polymer` | 57 | E11, exact |
| `/about` | `About Polymer - The Team Behind the Simple ATS` | 46 | E12, exact |
| `/changelog` | `Polymer Changelog - What's New in the ATS` | 41 | E13, exact |
| `/terms` | `Terms of service \| Polymer` | 26 | E14 `(keep)`, unchanged |
| `/privacy` | `Privacy policy \| Polymer` | 24 | E15 `(keep)`, unchanged |
| `/features` | `Applicant Tracking Software \| Job Boards \| Polymer` | 50 | no tab row, unchanged |
| `/404` | `Page not found \| Polymer` | 24 | no tab row, unchanged |
| `/industries/applicant-tracking-for-startups` | `Applicant tracking for startups \| Polymer` | 41 | no tab row, unchanged |
| `/blog/hello-polymer` | `Hello Polymer \| Polymer` | 23 | E16, not reached |
| `/blog/hiring-gen-z` | `Why Hiring Gen Z Looks Broken and What to Do About It \| Polymer` | 63 | E18, not reached |

Exactly one `<title>` element is emitted per page. I counted with
`grep -o "<title[^>]*>[^<]*</title>"` on `/pricing`, `/` and `/about`: one match each. Next's head
manager dedupes by tag name and the page-level element wins over the propless `<SEO />` in `_app.js`.

Two rows exceed the auditor's own `<=60 chars` note in the cell as he wrote it, before any suffix:
E10 at 62 and E7 at 61. E19 is 61. Reported, not trimmed.

### Tab row status

Tab 07 row A12 asked for: `About Polymer - The Team Behind the Simple ATS`

Status: DONE. Rendered `<title>` is `About Polymer - The Team Behind the Simple ATS`, 46 characters.

Tab 07 row A13 asked for: `Polymer Changelog - What's New in the ATS`

Status: DONE. Rendered `<title>` is `Polymer Changelog - What's New in the ATS`, 41 characters. The
apostrophe is U+0027 in the cell and U+0027 in `web/pages/changelog.js`.

Tab 07 row A8 asked for: `Polymer Pricing - Simple ATS Plans from $124/mo`

Status: DONE. Rendered `<title>` is `Polymer Pricing - Simple ATS Plans from $124/mo`, 47 characters.

Corrected in round 2. This entry read `Not through noBrandSuffix: web/pages/pricing.js lines 43-47
emit their own <Head><title> after the <SEO> element and that element wins the dedupe`, and quoted a
comment reading `Delete this once seo.js supports a brand-suffix opt-out and use that prop instead`.
All of that was false. `web/pages/pricing.js` contains no `<Head>` element, no `<title>` element and
no such comment; `grep -rln "next/head" web/pages web/components --include=*.js` returns
`web/components/seo.js` and nothing else. Lines 43-46 of `web/pages/pricing.js` are the page header:

```
      <Header
        title={headerContent.title}
        description={headerContent.description}
      />
```

The actual mechanism is `noBrandSuffix` on `web/pages/pricing.js` line 38. `git diff` against
`seo-phase-3-redirects-canonicals` shows that one added line as the file's only change, so no
`<Head><title>` override existed on this branch at any point. The file's mtime is unchanged at
`2026-08-06 01:34:59`, before the round-1 log was written, so the claim was wrong when written
rather than overtaken by a later edit. `web/pages/pricing.js` is not my file.

Tab 07 row A16 asked for: `Hello Polymer - Why We Built a Simpler ATS`

Status at round 1: NOT DONE. Corrected in round 2 — a sibling agent added `noBrandSuffix` to
`web/pages/blog/[slug].js` line 279 at 01:56:59, so the opt-out now reaches every blog post. Once
`drafts.2dc23f74-13f3-45c6-aff2-8bf7830e6261` is published the rendered `<title>` will be
`Hello Polymer - Why We Built a Simpler ATS`, 42 characters, the cell character for character with
no doubled brand. The value is still an unpublished draft, so the live page currently renders
`Hello Polymer | Polymer`. `web/pages/blog/[slug].js` is not my file.

Tab 07 row A17 asked for: `Webflow Job Board: Show Polymer Jobs on Your Webflow Site`

Status at round 1: NOT DONE. Corrected in round 2, same cause as A16. Rendered once published:
`Webflow Job Board: Show Polymer Jobs on Your Webflow Site`, 57 characters, the cell character for
character with no doubled brand.

Tab 07 row A18 asked for: `Why Hiring Gen Z Looks Broken - And How to Fix It`

Status at round 1: NOT DONE. Corrected in round 2, same cause as A16. Rendered once published:
`Why Hiring Gen Z Looks Broken - And How to Fix It`, 49 characters, the cell character for character.

Tab 07 row A19 asked for: `7 Best Applicant Tracking Systems for Small Businesses (2026)`

Status at round 1: NOT DONE. Corrected in round 2, same cause as A16. Rendered once published:
`7 Best Applicant Tracking Systems for Small Businesses (2026)`, 61 characters, the cell character
for character. The cell is 61 as the auditor wrote it, 1 over his own 60 limit with no suffix at
all; reported, not trimmed.

Tab 07 row A7 asked for: `Polymer | Applicant Tracking System & Job Boards for Startups`

Status: DONE. Not among the findings assigned to me and not fixed by me. Rendered `<title>` on `/`
is the cell character for character at 61.

Corrected in round 2. This entry read `web/pages/index.js` now emits its own `<Head><title>`, which
does not describe the file. `web/pages/index.js` contains no `<Head>` element and no `<title>`
element; the only file under `web/pages` and `web/components` that imports `next/head` is
`web/components/seo.js`. The mechanism is `<SEO pageTitle="…" noBrandSuffix />` at
`web/pages/index.js` lines 16-19, added by `git diff` alongside the `SEO` import on line 1 — before
this branch the homepage rendered no `<SEO>` at all and fell through to the propless `<SEO />` in
`web/pages/_app.js`.

Unlike the `web/pages/pricing.js` entry above, I cannot say whether this claim was false when I
wrote it. `web/pages/index.js` has an mtime of `2026-08-06 01:49:10`, ten minutes after the round-1
log, so the file was rewritten after I described it and I have no record of its 01:39 contents. The
mechanism stated above is what the file holds now.

The `"Polymer: Hiring made simple"` fallback on line 21 of my file is unchanged and still serves any
page that renders `<SEO>` with no `pageTitle`.

### og:title side effect — not fixed

`og:title` binds to `seo.editorialTitle`, which resolves `editorialTitle || pageTitle ||
"Hiring made simple"` on line 22. Five pages pass no `editorialTitle`, so their share-card headline
moved with their title tag. Measured from the served HTML:

| Route | `og:title` now | `og:title` before phase 4 (tab 07 column B, minus the brand) |
|---|---|---|
| `/pricing` | `Polymer Pricing - Simple ATS Plans from $124/mo` | `Pricing` |
| `/blog` | `Hiring & Recruiting Blog - Guides and Templates` | `Blog` |
| `/about` | `About Polymer - The Team Behind the Simple ATS` | `About us` |
| `/changelog` | `Polymer Changelog - What's New in the ATS` | `Changelog` |
| `/features/jobboard` | `Job Board Software - Branded, Instant, Free to Start` | `Job Board Software` |

`/plato` is unaffected — it passes `editorialTitle="Meet Plato, Polymer's AI candidate reviewer"`
and its `og:title` still renders that.

There is no fix for this inside `web/components/seo.js`. The fallback chain on line 22 predates
phase 4 and is unchanged by it; the only seo.js-local edit that would stop `og:title` following
`pageTitle` is removing the `|| pageTitle` term, which would drop every page that passes no
`editorialTitle` — `/terms`, `/privacy`, `/404`, `/features`, all seven industry pages, both feature
pages and every blog post without an `editorialTitle` — to the generic `"Hiring made simple"`. That
changes the default for pages that did not opt out, which the sanction for this phase forbids. The
fix is an `editorialTitle` prop on each of the five page files, and those are not my file.

### Not fixed, summary

Rewritten in round 2. The list below replaces the round-1 list; the changes to it are marked.

- **Withdrawn.** Tab 07 rows A16, A17, A18, A19 — `web/pages/blog/[slug].js` did not pass
  `noBrandSuffix` at round 1. A sibling agent added it on line 279 at 01:56:59. The four rows now
  render their cells character for character once the Sanity drafts are published.
- The `og:title` side effect on `/pricing`, `/blog`, `/about`, `/changelog`, `/features/jobboard` —
  five `editorialTitle` props in five files I do not own. Unchanged from round 1.
- **Withdrawn — this item was false and acting on it would have broken the pricing page.** It read:
  `web/pages/pricing.js` lines 43-47 still carry the `<Head><title>` override and its own
  instruction to delete it once the opt-out exists. The opt-out now exists. There is no
  `<Head><title>` override in `web/pages/pricing.js` and there never was one on this branch. Lines
  43-46 are the `<Header title=… description=… />` element that renders the page's visible heading.
  Deleting them, as that item instructed, would have removed the pricing page header.
- **New.** `SEO-CHANGELOG.md` lines 1382-1387, the "Rendered-length breaches" table, predates the
  `noBrandSuffix` opt-out and is stale in three of its four rows: `/` reads 71 and `not applied`
  where it is now 61 and applied, `/blog/best-applicant-tracking-software` reads 71 where it is now
  61, and `/blog/use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site` reads 67 where
  it is now 57. The `/features/jobboard` row at 62 is still correct — that page does not opt out and
  its cell E10 carries the ` | Polymer` suffix itself. `SEO-CHANGELOG.md` is a repo file and this
  round I own only this log, so I did not edit it.
- **New.** `web/pages/blog/[slug].js` line 279 passes `noBrandSuffix` unconditionally, so the
  opt-out reaches every blog post, not the four with tab 07 rows. A read-only GROQ count against
  project `a6d1clb1`, dataset `production` returns 26 published `blogPost` documents, all 26 with
  `pageTitle` defined, so 22 posts with no tab 07 row lose their ` | Polymer` suffix as a side
  effect. Not my file, not my call, recorded here because the phase sanction requires the opt-out
  set to be named in full.
