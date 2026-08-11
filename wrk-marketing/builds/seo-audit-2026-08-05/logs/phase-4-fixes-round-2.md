
---

## `web/components/seo.js` — Round 2

**Scope:** this agent owns `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/components/seo.js` only.

**Changes made this round: none.** The file already contained the fix both findings describe.

### Tab 07 row A7

Asked for: `Polymer | Applicant Tracking System & Job Boards for Startups`
Status: NOT FIXED BY THIS AGENT — already true in the working tree.

### Tab 07 row A8

Asked for: `Polymer Pricing - Simple ATS Plans from $124/mo`
Status: NOT FIXED BY THIS AGENT — already true in the working tree.

### Tab 07 row A12

Asked for: `About Polymer - The Team Behind the Simple ATS`
Status: NOT FIXED BY THIS AGENT — already true in the working tree.

### Tab 07 row A13

Asked for: `Polymer Changelog - What's New in the ATS`
Status: NOT FIXED BY THIS AGENT — already true in the working tree.

### Reason, stated once for all four rows

`web/components/seo.js` in the working tree carries the sanctioned opt-out at lines 6 and 20:

```
const SEO = ({
  pageTitle,
  noBrandSuffix,
  ...
    pageTitle: pageTitle
      ? pageTitle + (noBrandSuffix ? "" : " | Polymer")
      : "Polymer: Hiring made simple",
```

`web/pages/index.js`, `web/pages/pricing.js`, `web/pages/about.js` and `web/pages/changelog.js`
each pass `noBrandSuffix`, so the rendered `<title>` for those four pages equals the `pageTitle`
prop with nothing appended. Byte comparison of each prop against the workbook cell it copies —
`openpyxl` read of `07 Title Rewrites` cells E7, E8, E12, E13 against the `pageTitle="..."` literal
in each page file — returns MATCH on all four, including the straight U+0027 apostrophe in E13
(`What's`) and the ampersand in E7.

The two findings are not about the content of this file. Both report that the edits are uncommitted
and absent from PR #49: `git rev-parse HEAD` and `git rev-parse origin/seo-phase-4-metadata-headings`
are both `641d5f282fc5f5e0dc4a23d33fee374d8797e6ed`, and `git show 641d5f2:web/components/seo.js`
line 19 reads `? pageTitle + " | Polymer"` with no `noBrandSuffix` prop. The remedy is a commit.
This agent's instructions are "Do NOT commit, do NOT push — the orchestrator commits," so the
commit is left to the orchestrator.

### Shared infrastructure changed

`web/components/seo.js` is shared infrastructure and it has changed. The change is the addition of
the `noBrandSuffix` prop, approved for this phase in the task brief.

Default behaviour is byte-identical for every page that does not pass the prop: `noBrandSuffix`
is `undefined` at those call sites, the ternary takes the `" | Polymer"` branch, and the string
produced is the same one the pushed tip produces. The propless `<SEO />` at `web/pages/_app.js`
line 93 still resolves to the `Polymer: Hiring made simple` fallback on line 21, because that
fallback is on the `pageTitle`-falsy branch which the new ternary does not touch. `noBrandSuffix`
is destructured out of props and never spread onto a DOM element, so no unknown-attribute warning
is produced.

Five call sites now opt out:

- `web/pages/index.js` line 17
- `web/pages/pricing.js` line 38
- `web/pages/about.js` line 24
- `web/pages/changelog.js` line 58
- `web/pages/blog/[slug].js` line 279

The first four are the Tab 07 A7/A8/A12/A13 pages. The fifth, `web/pages/blog/[slug].js`, is owned
by another agent this round and was edited concurrently with this section being written; it passes
`noBrandSuffix` so that Sanity `pageTitle` values render without a second brand token. Recorded here
because it is a consumer of this file, not because this agent changed it.

### Workbook check

`read-workbook.py "07 Title Rewrites"` plus an `openpyxl` read of E7, E8, E12 and E13. The
orchestrator's quotes of those four cells match the workbook character for character. No misquote.

---

## `web/pages/index.js` — Round 2

**Scope:** this agent owns `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/pages/index.js` only. Branch
confirmed `seo-phase-4-metadata-headings`. Nothing committed, nothing pushed. No Sanity call was made.
`web/.env.local` was not read and not modified. No file other than `web/pages/index.js` and this log
was written.

### Workbook check

`read-workbook.py "07 Title Rewrites"`. Cell E7 reads
`Polymer | Applicant Tracking System & Job Boards for Startups`, D7 reads `No category keyword;
brand-only`, B7 reads `Polymer: Hiring made simple`, C7 reads `27.0`. The orchestrator's quotes of
row A7 match the workbook character for character. No misquote.

### Tab 07 row A7

Asked for: `Polymer | Applicant Tracking System & Job Boards for Startups`

Status: DONE.

### Edit made

One line added to `web/pages/index.js`:

```
       <SEO
         pageTitle="Polymer | Applicant Tracking System & Job Boards for Startups"
         noBrandSuffix
+        editorialTitle="Hiring made simple"
       />
```

The three findings against this file all report the same thing: adding `<SEO>` to the homepage moved
`og:title` as well as `<title>`, no tab row asks for that, and no log records it.
`web/components/seo.js` line 22 resolves `editorialTitle: editorialTitle || pageTitle ||
"Hiring made simple"` and line 83 binds `og:title` to it, so a page that passes `pageTitle` and no
`editorialTitle` moves its `og:title` with its title tag. On the pushed tip `web/pages/index.js`
rendered no `<SEO>` at all, the only `Head` came from the propless `<SEO />` at `web/pages/_app.js`
line 93, and `og:title` was the literal `Hiring made simple` off the end of that chain. Passing
`editorialTitle="Hiring made simple"` reproduces that value exactly, so `<title>` is the only tag on
`/` that this branch changes.

### What I measured

`next dev` on port 3811 against the working tree, tags taken from the served HTML, not from props.
Server stopped afterwards, `lsof -ti tcp:3811` empty, `.next` is gitignored.

| Tag on `/` | Value | Same as pushed tip |
|---|---|---|
| `<title>` | `Polymer \| Applicant Tracking System & Job Boards for Startups` (61) | no — this is tab cell E7, character for character |
| `og:title` | `Hiring made simple` | yes |
| `og:url` | `https://www.polymer.co` | yes |
| `og:description` | `Polymer gives you a beautiful job board and a powerful ATS to manage candidates. Collaborate with your hiring team from one place. Get started free.` | yes |
| `og:image` | `https://www.polymer.co/images/card.png` | yes |
| `og:site_name` | `Polymer` | yes |
| `meta name="description"` | same string as `og:description` above | yes |
| `link rel="canonical"` | `https://www.polymer.co/` | yes |

Every value in the "yes" rows is the `web/components/seo.js` default that the propless `<SEO />` in
`_app.js` produced before this branch: `pathname` is not passed so `url` is `baseUrl` and
`canonicalUrl` is `baseUrl + "/"`, `image` is not passed so `card` is `card.png`, `metaDescription`
is not passed so the line 24 default stands.

Exactly one `<title>` element is emitted: `re.findall(r'<title[^>]*>(.*?)</title>')` over the served
HTML returns one match. Next's head manager dedupes by tag name and the page-level `<SEO>` wins over
the propless one in `_app.js`.

E7 is 61 characters as the auditor wrote it, one over his own `<=60 chars` note in A4. Reported, not
trimmed.

### Shared infrastructure

`web/components/seo.js` is shared infrastructure and it has changed on this branch — the sanctioned
`noBrandSuffix` prop. **I did not change it this round and I did not change it in any round.** This
section records it because `web/pages/index.js` is one of the pages that opts out. As of this
writing the opt-out call sites are `web/pages/index.js`, `web/pages/pricing.js`,
`web/pages/about.js`, `web/pages/changelog.js` and `web/pages/blog/[slug].js`.

### Not fixed

Nothing in the findings against `web/pages/index.js` was left unfixed.

Out of my ownership, stated once and not acted on: the same `og:title` shift is still live on
`/pricing`, `/blog`, `/about`, `/changelog` and `/features/jobboard`, where it is recorded as an open
item at `SEO-CHANGELOG.md` line 1332. The remedy there is the same one prop this section adds, in
five files I do not own.

---

## `QUESTIONS-FOR-JESSICA.md` — Round 2

**Scope:** this agent owns `/Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/QUESTIONS-FOR-JESSICA.md` only. No repo file, no `.env.local` and no Sanity document was written.

### Tab 07 rows A7, A8, A12, A13

Asked for: E7 `Polymer | Applicant Tracking System & Job Boards for Startups`, E8 `Polymer Pricing - Simple ATS Plans from $124/mo`, E12 `About Polymer - The Team Behind the Simple ATS`, E13 `Polymer Changelog - What's New in the ATS`.
Status: DONE — the finding was against the decisions file, not the code, and the file now records the branch's state.

The two unstruck questions under "Tab 07 read" are struck and marked `**Fixed, no longer a question.**`, matching the convention every other resolved question in the file uses.

Question 1 recorded: `web/components/seo.js` line 20 is `pageTitle + (noBrandSuffix ? "" : " | Polymer")`; the four pages that opt out are `web/pages/index.js` line 17, `web/pages/pricing.js` line 38, `web/pages/about.js` line 24, `web/pages/changelog.js` line 58; each rendered `<title>` equals its workbook cell with nothing appended, at 61, 47, 46 and 41 characters.

Question 2 recorded: `web/pages/index.js` lines 15-18 render `<SEO pageTitle="Polymer | Applicant Tracking System & Job Boards for Startups" noBrandSuffix />`, and the default on `web/components/seo.js` line 21 is still `"Polymer: Hiring made simple"` — the edit the question asked her to confirm was never made and is not needed.

### Shared infrastructure changed

`web/components/seo.js` is shared infrastructure and it changed on this branch: a `noBrandSuffix` prop, sanctioned for this phase. Default behaviour is identical for every page that does not pass it. Five call sites opt out — `web/pages/index.js`, `web/pages/pricing.js`, `web/pages/about.js`, `web/pages/changelog.js` and `web/pages/blog/[slug].js` line 279. This agent changed none of them; it recorded them.

### Three further corrections, because the file must be true where it touches this fix

1. `web/pages/blog/[slug].js` gained `noBrandSuffix` at line 279 partway through this session — a grep at the start of this agent's run showed the prop absent, a grep minutes later showed it present. Draft text stating the blog template did not pass it was corrected before the file was left. Tab 07 read question 1 and Phase 4 Sanity question 1 both now describe the current state.
2. Tab 07 read question 3 said four titles overrun the tab's `<=60`, with E17 at 67 and E19 at 71 after the suffix. With the suffix suppressed the true figures are E7 61, E10 62, E19 61, and E17 57. The question is rewritten to those numbers and still asks whether she wants the three shortened. No auditor copy was trimmed.
3. Phase 4 Sanity question 1 claimed the webflow and best-applicant-tracking-software titles render at 67 and 71. They render at 57 and 61. Only E19 is still over the auditor's own limit, by one character.

### One new question added

Question 4 under "Phase 4, items 1 and 2 — Sanity blog metadata": the opt-out sits on the blog template, so all 26 posts drop the brand from `<title>`, not only the four tab 07 names. A read-only GROQ query of `a6d1clb1` / `production` returned 26 published `blogPost` documents and confirmed that not one stored `pageTitle` contains ` | Polymer` — every brand token in the crawled blog titles came from `web/components/seo.js`. So `/blog/a-player` now renders `A Player`. Tab 07 says nothing about the other 22 posts; the question states the three available options and leaves the choice with her.

### Workbook check

`read-workbook.py "07 Title Rewrites"` re-read for cells E7, E8, E12, E13. They match the orchestrator's quotes character for character, including the straight apostrophe in `What's` and the ampersand in E7. No misquote.

---

## `web/components/start.js` — Round 2

**Scope:** this agent owns `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/components/start.js` only.
Branch confirmed `seo-phase-4-metadata-headings`. Nothing committed, nothing pushed. No Sanity call
was made, `web/.env.local` was not read. No file other than `web/components/start.js` and this log
was written.

### Workbook check

`read-workbook.py "17 Headings"`. B16, B17, B18 each read
`First H2 is boilerplate CTA 'Get your hiring process up and running in minutes.'`; C16, C17, C18
each read `Move CTA below content headings`; A16, A17, A18 read the three
`https://www.polymer.co/blog/...` URLs the orchestrator quoted. The orchestrator's quotes of rows
A16-A18 match the workbook character for character. No misquote.

### Tab 17 rows A16, A17, A18

Asked for: `Move CTA below content headings`

Status: DONE.

### Edit made

One line in `web/components/start.js` line 105:

```
-Styled.Title = styled.h2((props) => {
+Styled.Title = styled.div((props) => {
```

The css block is unchanged. The emotion class hash on the rendered element is `css-1y6eynj` both
before and after the edit, so the rule set applied is identical. `styles/global.js` lines 14-38
reset `h2` to `margin: 0; line-height: 1.21; font-size: inherit; font-weight: inherit`, and
`Styled.Title` sets `font-size`, `font-weight: 600`, `line-height: 130%` and `margin: 0` itself, so
a `div` renders the same pixels a `h2` did.

### Why this file and not a move

The auditor's fix text says move the CTA below content headings. It is already last: `<Start />` is
the final element of `web/pages/blog/[slug].js` line 342, after `</Styled.Section>`. On these three
posts nothing can be moved below anything, because the post bodies contain no `h2` at all. Live HTML
from `https://www.polymer.co`, headings in document order:

| URL | Body headings before the footer |
|---|---|
| `/blog/one-click-distribution-to-we-work-remotelys-community-of-job-seekers` | `h1`, then the two CTAs |
| `/blog/post-jobs-with-whatjobs-across-500-partners` | `h1`, `h3` x4, then the two CTAs |
| `/blog/post-to-we-work-remotely-6m-professionals-in-seconds` | `h1`, `h4`, `h3`, then the two CTAs |

The two CTAs are `Get your hiring process up and running in minutes.` (the sidebar, demoted to
`Styled.SidebarTitle` = `styled.div` earlier in this phase) and `Start hiring with Polymer for free`
(this component). With the sidebar one demoted and the content headings being `h3`/`h4`, the first
`h2` on all three pages was this component's title. Demoting it is the only change inside my file
that makes `First H2 is boilerplate CTA` false.

### What I measured

`next dev` already running on port 3000 against the working tree, headings taken from the served
HTML. All three URLs after the edit:

| URL | Headings in document order | CTA element |
|---|---|---|
| `/blog/one-click-distribution-to-we-work-remotelys-community-of-job-seekers` | `h1`, then footer `h2` Links/Resources/Company/Industries | `div` |
| `/blog/post-jobs-with-whatjobs-across-500-partners` | `h1`, `h3` How it works, `h3` Requirements, `h3` Pricing & premium distribution, `h3` Managing your listing, then footer `h2` | `div` |
| `/blog/post-to-we-work-remotely-6m-professionals-in-seconds` | `h1`, `h4` Integration Updates, `h3` How It Works, then footer `h2` | `div` |

No boilerplate CTA appears as a heading of any level on any of the three.

### Side effect

The first `h2` on those three pages is now `Links`, the first of the four footer nav headings
`Links`, `Resources`, `Company`, `Industries`. Those four exist on every page of the site, including
every page the auditor did not flag in tab 17. They are not a CTA and no tab row names them. I did
not touch the footer.

### Shared infrastructure changed

`web/components/start.js` is shared infrastructure and it has changed. The CTA title is no longer an
`h2` on any page. Fifteen call sites render `<Start />`:

`web/pages/index.js` 27, `web/pages/plato.js` 29, `web/pages/about.js` 84,
`web/pages/features.js` 426, `web/pages/blog.js` 65, `web/pages/changelog.js` 84,
`web/pages/pricing.js` 373, `web/pages/features/jobboard.js` 44,
`web/pages/features/candidate-management-software.js` 21, `web/pages/blog/[slug].js` 342, and the
seven `web/pages/industries/applicant-tracking-for-*.js` files at line 121 (cryptocurrency, fintech,
greentech, healthcare, legal-services, real-estate, startups).

Measured on the running server, every one of them keeps its `h1` and still carries body `h2`
headings after the demotion:

| Page | h1 | body h2 remaining |
|---|---|---|
| `/` | 1 | 6 |
| `/about` | 1 | 2 |
| `/changelog` | 1 | 163 |
| `/blog` | 1 | 26 |
| `/pricing` | 1 | 1 |
| `/features` | 1 | 4 |
| `/features/jobboard` | 1 | 4 |
| `/features/candidate-management-software` | 1 | 5 |
| `/industries/applicant-tracking-for-startups` | 1 | 6 |

`/plato` keeps the `h1` added earlier in this phase plus five body `h2` headings. The seven industries
pages pass `customContent`, so their CTA string is `Start hiring smarter today`; that renders as a
`div` with the same `css-1y6eynj` class. No page rendering `<Start />` is left with zero `h2`.

Tab 17 is the only heading tab in the workbook, and no row in it depends on the CTA being an `h2`.

### Not fixed

Nothing in the finding against `web/components/start.js` was left unfixed.

---

## `web/pages/blog/[slug].js` — Round 2

**Scope:** this agent owns `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/pages/blog/[slug].js` only.
Branch confirmed `seo-phase-4-metadata-headings`. Nothing committed, nothing pushed. No Sanity
document was written — the only Sanity traffic was two read-only GROQ queries. `web/.env.local` was
read for `SANITY_API_WRITE_TOKEN` and not modified; the token is not reproduced anywhere.

### Workbook check

`read-workbook.py "07 Title Rewrites"`. Cells A16-E19 match the orchestrator's quotes character for
character, including D16 `Launch post; doubled brand`. No misquote.

### Edit made

One line added:

```
       <SEO
         pageTitle={post.pageTitle}
+        noBrandSuffix
         editorialTitle={post.editorialTitle}
```

### Tab 07 row A16

Asked for: `Hello Polymer - Why We Built a Simpler ATS`
Status: DONE.

### Tab 07 row A17

Asked for: `Webflow Job Board: Show Polymer Jobs on Your Webflow Site`
Status: DONE.

### Tab 07 row A18

Asked for: `Why Hiring Gen Z Looks Broken - And How to Fix It`
Status: DONE.

### Tab 07 row A19

Asked for: `7 Best Applicant Tracking Systems for Small Businesses (2026)`
Status: DONE. The auditor's copy is 61 characters, one over the `<=60 chars` limit his note A4 sets.
It is stored and rendered untrimmed; the overrun is reported, not corrected.

### What I measured

`next dev` on port 3719 against the working tree, `<title>` taken from the served HTML, not from the
prop. Server stopped afterwards, `lsof -ti :3719` empty.

| Route | Rendered `<title>` after the edit | Len |
|---|---|---|
| `/blog/hello-polymer` | `Hello Polymer` | 13 |
| `/blog/use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site` | `Webflow Job Boards` | 18 |
| `/blog/hiring-gen-z` | `Why Hiring Gen Z Looks Broken and What to Do About It` | 53 |
| `/blog/best-applicant-tracking-software` | `7 Best Applicant Tracking Softwares For Small Businesses` | 56 |
| `/blog/talent-acquisition` | `A Complete Guide to Talent Acquisition` | 38 |

Those are the **published** `pageTitle` values with nothing appended. `web/lib/sanity.js` builds the
client with no token and no perspective, so `getStaticProps` reads published documents and the Phase 4
drafts are not rendered. Read-only GROQ against `a6d1clb1` / `production` returns the four drafts
holding the tab cells character for character:

| Draft `_id` | `pageTitle` | Len |
|---|---|---|
| `drafts.2dc23f74-13f3-45c6-aff2-8bf7830e6261` | `Hello Polymer - Why We Built a Simpler ATS` | 42 |
| `drafts.54ea4d1f-deee-47c6-849e-da34989f5736` | `Webflow Job Board: Show Polymer Jobs on Your Webflow Site` | 57 |
| `drafts.e563dba0-f14d-4493-ab3c-20de909bae59` | `Why Hiring Gen Z Looks Broken - And How to Fix It` | 49 |
| `drafts.fcfc319d-8b14-46d0-aef5-fc1fdd751060` | `7 Best Applicant Tracking Systems for Small Businesses (2026)` | 61 |

`web/components/seo.js` line 20 is `pageTitle + (noBrandSuffix ? "" : " | Polymer")`. With
`noBrandSuffix` passed, rendered `<title>` equals `post.pageTitle` exactly, so publishing each draft
produces E16, E17, E18 and E19 character for character, at 42, 57, 49 and 61 characters. Before this
edit those four would have rendered at 52, 67, 59 and 71 with ` | Polymer` appended, and the first two
would have contained `Polymer` twice — the defect D16 names.

Publishing the drafts is not this agent's work and was not done. The published documents are
untouched: `2dc23f74` still `Hello Polymer`, `54ea4d1f` still `Webflow Job Boards`, `e563dba0` still
`Why Hiring Gen Z Looks Broken and What to Do About It`, `fcfc319d` still
`7 Best Applicant Tracking Softwares For Small Businesses`.

### Shared infrastructure changed, and the side effect

`web/components/seo.js` is shared infrastructure and it changed on this branch — the sanctioned
`noBrandSuffix` prop. **This agent did not change that file.** It added the fifth call site that opts
out. The opt-out call sites are now `web/pages/index.js`, `web/pages/pricing.js`,
`web/pages/about.js`, `web/pages/changelog.js` and `web/pages/blog/[slug].js`.

The fifth is a template, not a page, so the opt-out lands on **all 26 published `blogPost`
documents**, not only the four tab 07 names. No stored `pageTitle` in the dataset contains
` | Polymer` (26 of 26 checked), so every brand token in the crawled blog titles came from
`web/components/seo.js` and every one of them is now gone. The 22 posts no tab row covers:

`a-player`, `agile-recruiting-process`, `behavioral-interview-scoring-matrix`,
`best-job-board-software`, `employee-turnover`, `employer-branding-steps`, `first-impression-bias`,
`five-things-a-startup-should-keep-in-mind-when-hiring`,
`four-steps-to-build-a-recruiting-strategy-for-your-startup`,
`how-to-have-your-job-posts-show-up-in-the-google-jobs-search-widget`, `interview-feedback-examples`,
`job-rejection-email`, `onboarding`,
`one-click-distribution-to-we-work-remotelys-community-of-job-seekers`,
`post-jobs-with-whatjobs-across-500-partners`,
`post-to-we-work-remotely-6m-professionals-in-seconds`, `problem-solving-interview-questions`,
`recruiting-generation-z`, `skills-mapping-for-hiring-a-complete-guide`, `talent-acquisition`,
`talent-acquisition-vs-recruitment`, `utc-is-the-timezone-of-the-future`.

`/blog/five-things-a-startup-should-keep-in-mind-when-hiring` now renders `Startup Hiring` and
`/blog/four-steps-to-build-a-recruiting-strategy-for-your-startup` now renders
`Build a Recruiting Strategy`. Both were two-word brand-carrying titles; both are now brandless.
The per-slug alternative is a hardcoded four-slug list inside the template, which no tab row asks for.
`QUESTIONS-FOR-JESSICA.md` question 4 already puts the choice in front of Jessica.

Nothing else on the route changed. `og:title` binds to `editorialTitle`
(`web/components/seo.js` lines 22 and 83), which this file already passed and still passes; it never
carried the suffix and does not move. `metaDescription`, `og:url`, `og:image` and the canonical are
untouched.

### Not fixed

Nothing in the four findings against `web/pages/blog/[slug].js` was left unfixed.

---

## `logs/phase-4-fixes-round-1.md` — Round 2

**Scope:** this agent owns
`/Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/logs/phase-4-fixes-round-1.md`
only. Branch confirmed `seo-phase-4-metadata-headings`. Nothing committed, nothing pushed. No repo
file, no `web/.env.local` and no Sanity document was written — every Sanity call was a read-only GET
against the query API. `git status --short` shows no file this agent put there.

### Workbook check

`read-workbook.py "07 Title Rewrites"`. The orchestrator's quotes of rows A7-A19 match the workbook
character for character, including D16 `Launch post; doubled brand`. No misquote.

### Tab 07 rows A7, A8

Asked for: the phase sanction requires this log to name which pages opt out of the brand suffix, and
requires its account of rows A7 and A8 to be true.

Status: DONE.

Both findings are one defect: the log described the opt-out by a mechanism the code does not
contain, and undercounted the pages that use it. Neither finding was about a rendered title — the
titles were already correct. Five corrections were made, all inside this agent's own log.

### What I measured before editing

`grep -rn "noBrandSuffix" web/pages web/components --include=*.js` at 02:01:27 local. Five call
sites, unchanged from a first pass at 01:57:16:

| Call site | Route(s) that lose the suffix |
|---|---|
| `web/pages/index.js` line 17 | `/` |
| `web/pages/pricing.js` line 38 | `/pricing` |
| `web/pages/about.js` line 24 | `/about` |
| `web/pages/changelog.js` line 58 | `/changelog` |
| `web/pages/blog/[slug].js` line 279 | every `/blog/<slug>` route |

`grep -rln "next/head" web/pages web/components --include=*.js` returns `web/components/seo.js` and
nothing else. No page file contains a `<Head>` element or a `<title>` element.

### The five corrections

1. **The opt-out list.** It read `web/pages/about.js` and `web/pages/changelog.js`. Those two, and
   no others. Replaced with the five-row table above. This is the sentence the phase sanction turns
   on.

2. **Row A8's mechanism.** It read that `web/pages/pricing.js` lines 43-47 emit their own
   `<Head><title>` after the `<SEO>` element and win the dedupe, and quoted a comment reading
   `Delete this once seo.js supports a brand-suffix opt-out and use that prop instead`. No such
   element and no such comment exist. Lines 43-46 are `<Header title={headerContent.title}
   description={headerContent.description} />`. `git diff` against
   `seo-phase-3-redirects-canonicals` shows `web/pages/pricing.js` changed by exactly one added
   line, `noBrandSuffix` on line 38, so no override existed on this branch at any point. The file's
   mtime is `2026-08-06 01:34:59`, before the round-1 log, so the claim was false when written.

3. **Row A7's mechanism.** It read that `web/pages/index.js` now emits its own `<Head><title>`. The
   file contains neither element; the mechanism is `<SEO pageTitle="…" noBrandSuffix />` at lines
   16-20. Unlike the `pricing.js` claim I did not assert this one was false when written:
   `web/pages/index.js` has an mtime of `01:49:10`, ten minutes after the round-1 log, so the file
   was rewritten after I described it and I hold no record of its contents at 01:39. The log now
   says so rather than guessing.

4. **The dangerous to-do.** The round-1 "Not fixed, summary" carried
   `web/pages/pricing.js` lines 43-47 still carry the `<Head><title>` override and its own
   instruction to delete it once the opt-out exists. Acting on that would have deleted the pricing
   page's `<Header>`. Marked withdrawn, with the reason and the real content of those lines.

5. **Rows A16-A19 and the A19 entry in the `SEO-CHANGELOG.md` section.** All five entries said the
   blog titles would render with a doubled brand because `web/pages/blog/[slug].js` did not pass
   `noBrandSuffix`. A sibling agent added it on line 279 at 01:56:59. Rewritten to the values that
   now render once the Sanity drafts are published: A16 `Hello Polymer - Why We Built a Simpler ATS`
   42, A17 `Webflow Job Board: Show Polymer Jobs on Your Webflow Site` 57, A18
   `Why Hiring Gen Z Looks Broken - And How to Fix It` 49, A19
   `7 Best Applicant Tracking Systems for Small Businesses (2026)` 61. A19 is 1 over the auditor's
   own 60 limit as he wrote the cell, with no suffix at all. Reported, not trimmed.

Three further inaccuracies were mine, introduced while writing the correction and fixed before the
file was left: a `$124/me` typo in the prescribed A8 string, a claim that all five page files changed
by exactly one added line when `web/pages/index.js` adds an import and the whole `<SEO>` element, and
a claim that the blog template opts out eleven posts when a read-only GROQ count returns 26.

### Shared infrastructure changed

`web/components/seo.js` is shared infrastructure and it changed on this branch: the `noBrandSuffix`
prop, sanctioned for this phase. **This agent did not author that change and made no edit to any
repo file in any round.** The pages that now opt out are the five in the table above.

Default behaviour is unchanged for every page that does not pass the prop. The ternary's false
branch returns `"Polymer: Hiring made simple"`, which never carried a suffix, so pages that render
`<SEO>` with no `pageTitle` are unaffected either way.

### Not fixed

- `SEO-CHANGELOG.md` lines 1382-1387, the "Rendered-length breaches" table, predates the opt-out and
  is stale in three of its four rows: `/` reads 71 and `not applied` where it is now 61 and applied;
  `/blog/best-applicant-tracking-software` reads 71 where it is now 61;
  `/blog/use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site` reads 67 where it is now
  57. The `/features/jobboard` row at 62 is still correct — that page does not opt out and cell E10
  carries the ` | Polymer` suffix itself. `SEO-CHANGELOG.md` is a repo file and this round I own only
  this log, so I did not edit it. Recorded in the log's own "Not fixed" section as well.
- `web/pages/blog/[slug].js` line 279 passes `noBrandSuffix` unconditionally, so the opt-out reaches
  all 26 published `blogPost` documents, all of which have `pageTitle` defined. 22 of them have no
  tab 07 row and lose their ` | Polymer` suffix as a side effect. Not my file and not my call;
  recorded because the phase sanction requires the opt-out set to be named in full. The
  `QUESTIONS-FOR-JESSICA.md` section above raises the same 26-post scope as its question 4.
- The `og:title` side effect on `/pricing`, `/blog`, `/about`, `/changelog` and `/features/jobboard`
  — five `editorialTitle` props in five files I do not own. Unchanged from round 1. `/` is no longer
  among them: that file's owner added `editorialTitle="Hiring made simple"` at 02:00.

---

## `SEO-CHANGELOG.md` — Round 2

**Scope:** this agent owns `/Users/jessica/wrk/wrk-corp/wrk-marketing/SEO-CHANGELOG.md` only. Branch
confirmed `seo-phase-4-metadata-headings`. Nothing committed, nothing pushed. `git status --short`
shows `SEO-CHANGELOG.md` as the only file this agent modified. No Sanity call of any kind was made.
`web/.env.local` was not read and not modified.

### Workbook check

`python3 read-workbook.py "07 Title Rewrites"`. The orchestrator's quotes of tab 07 match the
workbook character for character across all 13 data rows A7-A19, including D16
`Launch post; doubled brand`, the `(keep)` values in E14 and E15, and the straight U+0027 apostrophe
in E13. No misquote.

### Tab 07 rows A7, A8, A12, A13

Asked for: the phase sanction requires this file to say plainly that shared infrastructure changed
and which pages now opt out, and requires its account of rows A7, A8, A12 and A13 to be true.

Status: DONE.

`grep -c noBrandSuffix SEO-CHANGELOG.md` returned 0 before this round and returns 21 after it.

### What I measured before editing

`next dev` on port 3812 against the working tree, every value taken from served HTML, not from
props. Server stopped afterwards; `lsof -ti tcp:3812` empty. `.next` is gitignored and
`git status --short` is unchanged by the run. HTML entities expanded. Exactly one `<title>` element
on every route measured.

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
| `/features` | `Applicant Tracking Software \| Job Boards \| Polymer` | 50 | no row, unchanged |
| `/404` | `Page not found \| Polymer` | 24 | no row, unchanged |
| `/industries/applicant-tracking-for-startups` | `Applicant tracking for startups \| Polymer` | 41 | no row, unchanged |
| `/blog/hello-polymer` | `Hello Polymer` | 13 | E16 draft unpublished; suffix gone |
| `/blog/hiring-gen-z` | `Why Hiring Gen Z Looks Broken and What to Do About It` | 53 | E18 draft unpublished; suffix gone |
| `/blog/best-applicant-tracking-software` | `7 Best Applicant Tracking Softwares For Small Businesses` | 56 | E19 draft unpublished; suffix gone |
| `/blog/first-impression-bias` | `Overcome First Impression Bias When Hiring` | 42 | no tab 07 row; suffix gone |

Homepage head tags, read off the same server: `og:title` `Hiring made simple`, `og:url`
`https://www.polymer.co`, `canonical` `https://www.polymer.co/`, `og:image`
`https://www.polymer.co/images/card.png`, `description` the `seo.js` default. Each is the value the
propless `<SEO />` in `web/pages/_app.js` produced before `web/pages/index.js` had its own, because
`web/pages/index.js` passes `editorialTitle="Hiring made simple"` and passes no `pathname`,
`metaDescription` or `image`. `<title>` is the only homepage tag that moved.

Repository state, measured rather than assumed: the phase-4 items are committed as `46bd4e9`
(2026-08-05 20:55:04 -0500, seventeen files) and the branch is pushed — local `HEAD` and
`origin/seo-phase-4-metadata-headings` are both `641d5f2`. `git status --short` at 02:02 lists eight
modified files. `web/components/start.js` appeared in that list between two readings four minutes
apart and `web/pages/index.js` gained an `editorialTitle` prop in the same window, so concurrent
agents were still writing while the snapshot was taken.

### The nine corrections

Every one replaces a statement that was false against the working tree.

1. **The phase-4 preamble.** `Nothing in this phase was committed or pushed. The phase-4 working
   tree carries sixteen modified files` plus that sixteen-file list. Replaced with the `46bd4e9`
   commit and its seventeen files, the pushed tip `641d5f2`, and a separate eight-file working-tree
   list carrying `web/components/seo.js`, `web/pages/index.js` and `web/components/start.js`, none
   of which the old list held. The superseded sentence is quoted in place, which is how the rest of
   the file handles corrections.

2. **A new `### Shared infrastructure: the brand-suffix opt-out` section**, before item 1. It states
   that `web/components/seo.js` changed, that it is shared infrastructure, that the change was
   sanctioned for this phase, the two-line diff, the evidence that the default path is unchanged for
   every page that does not pass the prop (five routes measured), and a table of the five call sites
   that opt out: `web/pages/index.js` 17, `web/pages/pricing.js` 38, `web/pages/about.js` 24,
   `web/pages/changelog.js` 58, `web/pages/blog/[slug].js` 279.

3. **Item 1's mechanism paragraph and per-row table.** The paragraph quoted `seo.js` as
   `pageTitle ? pageTitle + " | Polymer" : "Polymer: Hiring made simple"`. The table showed rows 8,
   12 and 13 rendering `prop + " | Polymer"` at 57, 56 and 51 and had no row 7. Rewritten to the
   current ternary and to the measured 47, 46, 41, plus a new row 7 at 61.

4. **Item 1 Change 6**, new: the `web/pages/index.js` `<SEO>` element, marked not part of `46bd4e9`.

5. **The Sanity drafts "Rendered result of each, once published" table.** It read 52, 67, 59, 71
   with ` | Polymer` appended. The blog template opts out, so it now reads 42, 57, 49, 61 with the
   old figures kept in a "was" column.

6. **"Left as decisions rather than fixed."** It named the doubled brand on `/pricing`, `/about` and
   `/changelog` and the homepage row 7 as deferred. Both are fixed. Replaced with a repair row and a
   shorter deferral list: the `og:title` shift on five pages, and the three titles over 60.

7. **Verifier findings MED-1, MED-3 and item 3 LOW-2.** Left verbatim, per this file's convention,
   with bold corrections appended carrying the measured values.

8. **"Tab rows not actioned, or actioned with a differing value."** Row 7 read **not actioned**; rows
   8, 12 and 13 read **actioned with a differing rendered value**. Both rewritten to actioned with
   the rows' exact values, each quoting what it replaced and marking the repair uncommitted.

9. **The "Rendered-length breaches" table.** It listed `/` at 71 `not applied`, the Webflow post at
   67 and `best-applicant-tracking-software` at 71. Now three rows — `/features/jobboard` 62, `/` 61,
   `best-applicant-tracking-software` 61 — every one of them over the limit in the auditor's own copy
   before any suffix, plus a line recording that the Webflow post is no longer a breach at 57.

Also updated so they do not contradict the above: question 5 in the phase-4 questions list, the
"Raised by verifiers and not filed" paragraph, and two `needsLiveCheck` bullets.

### Recorded, not asked for by any tab row

`web/pages/blog/[slug].js` passes `noBrandSuffix` for every post, so all 26 published `blogPost`
documents lose the ` | Polymer` suffix from `<title>`, not only the four tab 07 names. The changelog
now says so in three places: the shared-infrastructure section, the tab 07 rows 16-19 entry, and the
"Raised by verifiers and not filed" paragraph.

### Not fixed

- `SEO-CHANGELOG.md` Phase 3, item 1 and its repair table describe the `canonicalUrl` binding in
  `web/components/seo.js` as uncommitted and absent from PR #48. It is committed, in `e822d00`
  ("Close the gaps the phase 3 review found") on `seo-phase-3-redirects-canonicals`, which is an
  ancestor of this branch; `git show 4fbc64f -- web/components/seo.js` contains no `canonicalUrl`,
  so the "not in `4fbc64f`" half of each statement still holds and the "uncommitted" half does not.
  No finding assigned this round covers the phase-3 record and I did not edit it.
- `SEO-CHANGELOG.md` item 4 and the tab 17 rows 16-18 entry describe the CTA demotion as it stood in
  `46bd4e9` and do not carry the `web/components/start.js` change made this round. I named that file
  and pointed at its log section in the working-tree file list, and left the item 4 record alone:
  tab 17 is not among the findings assigned to me.
