# Phase 4 fixes — Round 3

## web/pages/pricing.js

**Finding:** MED — Tab 07 rows A8, A10, A11, A12, A13. `web/components/seo.js` line 22 resolves
`editorialTitle: editorialTitle || pageTitle` and line 83 binds `og:title` to it, so `/pricing`,
which passes no `editorialTitle`, moved its `og:title` along with its title tag. Tab 07 prescribes
nothing about `og:title`.

**Scope:** this section covers `/pricing` only. The other four pages named in the finding
(`/features/jobboard`, `/blog`, `/about`, `/changelog`) are other agents' files.

**Change:** one prop added to the `SEO` call in `web/pages/pricing.js`.

```
        pageTitle="Polymer Pricing - Simple ATS Plans from $124/mo"
        noBrandSuffix
+       editorialTitle={headerContent.title}
        metaDescription="Transparent pricing for job board and applicant tracking software. Start your free trial and publish jobs in minutes. Sign up today."
```

`headerContent.title` is `"Pricing"` — the exact expression that was passed as `pageTitle` before
Phase 4 (`pageTitle={headerContent.title}`), so `og:title` returns to its pre-Phase-4 value. This is
the same remedy `web/pages/index.js` line 18 already applies.

**Shared infrastructure:** none changed in this round. `web/components/seo.js` was not touched here;
the `noBrandSuffix` prop it already carries was added in an earlier round.

**Measured on the running dev server, `curl -s http://localhost:3000/pricing`:**

```
<title>Polymer Pricing - Simple ATS Plans from $124/mo</title>
<meta property="og:title" content="Pricing"/>
<meta name="description" content="Transparent pricing for job board and applicant tracking software. Start your free trial and publish jobs in minutes. Sign up today."/>
```

Tab 07 row A8 asked for: "Polymer Pricing - Simple ATS Plans from $124/mo"
Status: DONE. Rendered `<title>` matches character for character; `og:title` is `Pricing`, its
pre-Phase-4 value.

**Workbook check:** `python3 read-workbook.py "07 Title Rewrites"` — row A8 reads
`A8: https://www.polymer.co/pricing`, `B8: Pricing | Polymer`, `C8: 17.0`,
`D8: Stub; no category or value prop`, `E8: Polymer Pricing - Simple ATS Plans from $124/mo`.
The task's quotation of row A8 matches the workbook.

---

## web/components/seo.js

**Findings assigned:** two MED findings, both naming Tab 07 rows A7, A8, A12, A13 (the second also
naming Tab 17 rows A16-A18), both with the same reason: the titles render correctly in the working
tree and PR #49 does not contain them, because eight files including this one are uncommitted
working-tree modifications.

**Change made: none. This file is already in the state both findings require.**

`git diff web/components/seo.js` on the working tree:

```
 const SEO = ({
   pageTitle,
+  noBrandSuffix,
   editorialTitle,
...
   let seo = {
     pageTitle: pageTitle
-      ? pageTitle + " | Polymer"
+      ? pageTitle + (noBrandSuffix ? "" : " | Polymer")
       : "Polymer: Hiring made simple",
```

The findings' own text confirms this: "These four rows are correct in the working tree." The
remaining action they name is "committing the working tree." My instructions are `Do NOT commit, do
NOT push — the orchestrator commits`, and the seven other uncommitted files are not mine to touch.
Both findings therefore go to notFixed, with committing as the reason.

**Shared infrastructure:** `web/components/seo.js` is shared infrastructure and it changed — one
added prop `noBrandSuffix`, one ternary. That change was made in an earlier round; this round added
nothing. Five call sites opt out, from `git grep -n noBrandSuffix -- web/`:

```
web/pages/about.js:24
web/pages/blog/[slug].js:279
web/pages/changelog.js:58
web/pages/index.js:17
web/pages/pricing.js:38
```

**Default behaviour verified unchanged by measurement.** `next dev` was already running on port 3000
out of `/Users/jessica/wrk/wrk-corp/wrk-marketing/web` (pid 93353), serving the working tree. Pages
that do not pass `noBrandSuffix` still render the suffix:

```
/404                                       Page not found | Polymer
/features                                  Applicant Tracking Software | Job Boards | Polymer
/features/candidate-management-software    Candidate Management Software | Polymer
/applicant-tracking-for-startups           Applicant tracking for startups | Polymer
/applicant-tracking-for-fintech-companies  Applicant tracking for fintech companies | Polymer
/terms                                     Terms of service | Polymer
/privacy                                   Privacy policy | Polymer
```

`/contact` returns no `<title>` because it is a 301 to `/about` from phase 3, not a page.

**Rendered titles for the four rows in the findings**, curled from the same server (`&amp;` and
`&#x27;` are HTML entity encoding; decoded lengths in parentheses):

```
/           Polymer | Applicant Tracking System &amp; Job Boards for Startups   (61)
/pricing    Polymer Pricing - Simple ATS Plans from $124/mo                     (47)
/about      About Polymer - The Team Behind the Simple ATS                      (46)
/changelog  Polymer Changelog - What&#x27;s New in the ATS                      (41)
```

Tab 07 row A7 asked for: "Polymer | Applicant Tracking System & Job Boards for Startups"
Status: DONE in the working tree, absent from PR #49.
Tab 07 row A8 asked for: "Polymer Pricing - Simple ATS Plans from $124/mo"
Status: DONE in the working tree, absent from PR #49.
Tab 07 row A12 asked for: "About Polymer - The Team Behind the Simple ATS"
Status: DONE in the working tree, absent from PR #49.
Tab 07 row A13 asked for: "Polymer Changelog - What's New in the ATS"
Status: DONE in the working tree, absent from PR #49.

The reason for all four is the same fact: `git rev-parse HEAD` is
`641d5f282fc5f5e0dc4a23d33fee374d8797e6ed`, and `git show HEAD:web/components/seo.js` line 19 reads
`? pageTitle + " | Polymer"` with no `noBrandSuffix` parameter. Committing makes the PR match the
working tree.

**Workbook check:** `python3 read-workbook.py "07 Title Rewrites"` returns
`E7: Polymer | Applicant Tracking System & Job Boards for Startups`,
`E8: Polymer Pricing - Simple ATS Plans from $124/mo`,
`E12: About Polymer - The Team Behind the Simple ATS`,
`E13: Polymer Changelog - What's New in the ATS`, and
`D16` on row A16 is not reachable from this file. Note A4 and cells A6-E14 match the task's
transcription. No misquote found.

## web/components/start.js

**Findings:** three round-3 findings, all MED, all naming the same single line — `Styled.Title` on
line 105 changed from `styled.h2` to `styled.div`, removing the string
`Start hiring with Polymer for free` from the heading outline of the 17 pages that render `<Start>`.
Tab 17 rows A16-A18 name a different string, `Get your hiring process up and running in minutes.`,
on a different component.

**Change:** the line is reverted. `web/components/start.js` is now byte-identical to
`seo-phase-3-redirects-canonicals` — `git diff seo-phase-3-redirects-canonicals -- web/components/start.js`
returns empty.

```
-Styled.Title = styled.div((props) => {
+Styled.Title = styled.h2((props) => {
```

**Why the revert does not undo tab 17 rows A16-A18.** The string those rows name lives in
`web/pages/blog/[slug].js` line 319, `Styled.SidebarTitle`, which is a `styled.div` and is not
touched here. `<Start />` is rendered at `web/pages/blog/[slug].js` line 343, after the article
content, so its title is below the content headings, which is what cell C16/C17/C18 asks for.

**Shared infrastructure:** `web/components/start.js` is rendered by 17 page templates
(`grep -rln "components/start" web/pages --include=*.js`). This round returns it to its
pre-phase-4 state; no page opts into anything.

**Styling:** unchanged. `web/styles/global.js` (untouched by this branch) resets `h1..h6` to
`margin: 0; line-height: 1.21; font-size: inherit; font-weight: inherit`, and `Styled.Title` sets
`font-size`, `font-weight`, `line-height: 130%` and `margin: 0` explicitly, so the Emotion class
wins on every one of those properties.

**Measured on the running dev server (pid 93353, port 3000), after the edit.** Each row is
`curl -s http://localhost:3000<path>` grepped for
`<h2[^>]*>Start hiring with Polymer for free</h2>` and for
`<h2[^>]*>Get your hiring process up and running in minutes\.</h2>`:

```
/                                                     200  h1=1  Start-title-as-h2=1  sidebar-CTA-as-h2=0
/plato                                                200  h1=1  Start-title-as-h2=1  sidebar-CTA-as-h2=0
/pricing                                              200  h1=1  Start-title-as-h2=1  sidebar-CTA-as-h2=0
/about                                                200  h1=1  Start-title-as-h2=1  sidebar-CTA-as-h2=0
/changelog                                            200  h1=1  Start-title-as-h2=1  sidebar-CTA-as-h2=0
/blog                                                 200  h1=1  Start-title-as-h2=1  sidebar-CTA-as-h2=0
/features                                             200  h1=1  Start-title-as-h2=1  sidebar-CTA-as-h2=0
/features/jobboard                                    200  h1=1  Start-title-as-h2=1  sidebar-CTA-as-h2=0
/industries/applicant-tracking-for-startups           200  h1=1  Start-title-as-h2=0  sidebar-CTA-as-h2=0
/blog/one-click-distribution-to-we-work-remotelys-community-of-job-seekers  200  h1=1  Start-title-as-h2=1  sidebar-CTA-as-h2=0
/blog/post-jobs-with-whatjobs-across-500-partners     200  h1=1  Start-title-as-h2=1  sidebar-CTA-as-h2=0
/blog/post-to-we-work-remotely-6m-professionals-in-seconds                  200  h1=1  Start-title-as-h2=1  sidebar-CTA-as-h2=0
```

`/industries/applicant-tracking-for-startups` reads 0 because it passes `customContent`; its Start
title is `Start hiring smarter today` and it renders as the seventh `<h2>` on the page, after six
content `<h2>`s.

Rendered `<h2>` order on `/blog/post-jobs-with-whatjobs-across-500-partners`:

```
Start hiring with Polymer for free
Links
Resources
Company
Industries
```

That post has no content `<h2>` of its own — the four trailing entries are the footer. The string
tab 17 row A17 names, `Get your hiring process up and running in minutes.`, is no longer an `<h2>`
on it.

Rendered `<h2>` order on `/blog/best-applicant-tracking-software` (tab 17 row A15), first five:

```
What is applicant tracking software (and how does it work)?
7 of the best applicant tracking software solutions for small businesses
How to choose the right ATS for your startup
Get your hiring process started with Polymer
Start hiring with Polymer for free
```

**Not fixed, not my file:** `SEO-CHANGELOG.md` line 981 describes `web/components/start.js` as
`Styled.Title` having "became a `styled.div` where it was a `styled.h2`". That sentence is now
false. `logs/phase-4-fixes-round-2.md`, section `web/components/start.js — Round 2`, records the
same reverted change. Neither file is mine this round.

**Workbook check:** `python3 read-workbook.py "17 Headings"` — rows A16-A18 read
`A16: https://www.polymer.co/blog/one-click-distribution-to-we-work-remotelys-community-of-job-seekers`,
`A17: https://www.polymer.co/blog/post-jobs-with-whatjobs-across-500-partners`,
`A18: https://www.polymer.co/blog/post-to-we-work-remotely-6m-professionals-in-seconds`, each with
`B: First H2 is boilerplate CTA 'Get your hiring process up and running in minutes.'` and
`C: Move CTA below content headings`. The task's quotation of tab 17 matches the workbook.

## web/pages/blog/[slug].js

**Shared infrastructure:** `web/components/seo.js` was NOT touched in this section. The
`noBrandSuffix` prop it already carries is unchanged. What changed is which pages opt out.

### Finding 1 — HIGH / MED, Tab 07 rows A16-A19: `noBrandSuffix` opted out all 26 blog posts

**Change:** two edits, both in `web/pages/blog/[slug].js`.

```
 const RELATED_POST_COUNT = 3;
+
+// Tab 07 rows A16-A19 rewrite these four pageTitle values to strings that carry
+// no " | Polymer". Every other post keeps the suffix components/seo.js appends.
+const BRANDLESS_TITLE_SLUGS = new Set([
+  "hello-polymer",
+  "use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site",
+  "hiring-gen-z",
+  "best-applicant-tracking-software",
+]);
```

```
         pageTitle={post.pageTitle}
-        noBrandSuffix
+        noBrandSuffix={BRANDLESS_TITLE_SLUGS.has(post.slug.current)}
```

The four slugs are exactly the four URLs in Tab 07 rows A16, A17, A18, A19. Read-only GROQ against
project `a6d1clb1`, dataset `production` confirms all four exist as published `blogPost` documents
(`2dc23f74-13f3-45c6-aff2-8bf7830e6261`, `54ea4d1f-deee-47c6-849e-da34989f5736`,
`e563dba0-f14d-4493-ab3c-20de909bae59`, `fcfc319d-8b14-46d0-aef5-fc1fdd751060`). No Sanity document
was written in this round.

**Measured on the running dev server (pid 93353), all 26 published posts fetched, all 200.**

The 22 posts with no Tab 07 row have ` | Polymer` back in the rendered `<title>`, the value
`web/components/seo.js` line 20 produced before Phase 4. Sample of the three the finding named:

```
/blog/talent-acquisition                            A Complete Guide to Talent Acquisition | Polymer
/blog/post-jobs-with-whatjobs-across-500-partners    Post Jobs with WhatJobs Across 500+ Partners | Polymer
/blog/a-player                                       How to Find and Retain A-Player Talent | Polymer
```

The four Tab 07 posts render with no suffix:

```
/blog/hello-polymer                                  Hello Polymer
/blog/use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site   Webflow Job Boards
/blog/hiring-gen-z                                   Why Hiring Gen Z Looks Broken and What to Do About It
/blog/best-applicant-tracking-software               7 Best Applicant Tracking Softwares For Small Businesses
```

Those four render the PUBLISHED `pageTitle`. Phase 4's rewrites live in the drafts, which a
read-only query returns as:

```
drafts.2dc23f74-13f3-45c6-aff2-8bf7830e6261  'Hello Polymer - Why We Built a Simpler ATS'                     42
drafts.54ea4d1f-deee-47c6-849e-da34989f5736  'Webflow Job Board: Show Polymer Jobs on Your Webflow Site'      57
drafts.e563dba0-f14d-4493-ab3c-20de909bae59  'Why Hiring Gen Z Looks Broken - And How to Fix It'              49
drafts.fcfc319d-8b14-46d0-aef5-fc1fdd751060  '7 Best Applicant Tracking Systems for Small Businesses (2026)'  61
```

All four match Tab 07 column E character for character. When those drafts publish, the rendered
`<title>` on each of the four is the Tab 07 string with nothing appended.

Row A19's prescribed string is 61 characters, one over the auditor's own "<=60 chars" limit stated
in Tab 07 note A4. Copied as written; not trimmed.

Tab 07 row A16 asked for: "Hello Polymer - Why We Built a Simpler ATS"
Tab 07 row A17 asked for: "Webflow Job Board: Show Polymer Jobs on Your Webflow Site"
Tab 07 row A18 asked for: "Why Hiring Gen Z Looks Broken - And How to Fix It"
Tab 07 row A19 asked for: "7 Best Applicant Tracking Systems for Small Businesses (2026)"
Status: DONE.

### Finding 2 — HIGH, Tab 17 rows A16, A17, A18: "Move CTA below content headings"

**Change:** none. Reason below.

The CTA already renders below every content heading on all three flagged posts, and did before this
branch. `<Styled.Sidebar>` (the CTA's container, a `styled.aside`) follows `<Styled.PageContent>`
(every content heading) inside `<Styled.Columns>`. Byte offsets of each heading and of the CTA
string in the HTML served for the three posts:

```
/blog/one-click-distribution-to-we-work-remotelys-community-of-job-seekers
  210855  <h1> One-click distribution to We Work Remotely's community of 2.5M job see
  534923  CTA "Get your hiring process up and running in minutes."
  624442  <h2> Start hiring with Polymer for free      (components/start.js)
  686182  <h2> Links                                    (footer)

/blog/post-jobs-with-whatjobs-across-500-partners
  210845  <h1> Distribute to 500+ Partner Job Boards with our WhatJobs Integration
  405322  <h3> How it works
  439396  <h3> Requirements
  440307  <h3> Pricing & premium distribution
  440975  <h3> Managing your listing
  533910  CTA "Get your hiring process up and running in minutes."
  623113  <h2> Start hiring with Polymer for free
  684853  <h2> Links

/blog/post-to-we-work-remotely-6m-professionals-in-seconds
  210893  <h1> Post Directly to We Work Remotely's 6M Professionals in Seconds
  405214  <h4> Integration Updates
  436748  <h3> How It Works
  566906  CTA "Get your hiring process up and running in minutes."
  655680  <h2> Start hiring with Polymer for free
  717420  <h2> Links
```

The CTA is already the last element before the site-wide `Start` block and the footer. There is no
content heading below it to move it under. The three posts carry zero `h2` blocks in their Sanity
content, which is why the crawl recorded the CTA as the page's first `h2` — a reorder cannot change
that outcome because there is no content `h2` to order it against.

Tab 17 rows A16, A17, A18 asked for: "Move CTA below content headings"
Status: NOT DONE. The prescribed position is the position the CTA already occupies.

The Phase 4 change to this element (`<h2>` -> `<Styled.SidebarTitle>`, a `styled.div`) was left in
place. Reverting it would restore the exact string Tab 17 column B names as the finding — "First H2
is boilerplate CTA" — without moving the CTA anywhere, because its position is already the one the
Fix column prescribes.
