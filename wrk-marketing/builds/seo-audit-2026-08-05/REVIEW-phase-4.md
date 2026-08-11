# Phase 4 review — metadata and headings (PR #49, branch `seo-phase-4-metadata-headings`)

Tabs in scope: 07 Title Rewrites (13 rows), 12 Meta Rewrites (9 rows), 17 Headings (12 rows).

**Workbook check.** Tabs `07 Title Rewrites`, `12 Meta Rewrites` and `17 Headings` were re-read with
`read-workbook.py`. Every value the orchestrator quoted — sheet titles, note A4 on all three tabs, and
all 34 data rows including row A16's Problem cell `Launch post; doubled brand` and the `(keep)` values
in E14/E15 — matches the workbook character for character. No misquote.

**How this was measured.** Rendered output, not props: `next dev` (pid 93353, cwd
`/Users/jessica/wrk/wrk-corp/wrk-marketing/web`) serving the working tree on port 3000; every `<title>`,
`og:title`, `<meta name="description">`, `og:description` and full heading outline extracted from the
served HTML and compared to the workbook cell by Python string equality. Sanity project `a6d1clb1`,
dataset `production`, queried read-only for all 11 draft documents and their published counterparts.
No repo file, no `web/.env.local` and no Sanity document was modified by this review.

**State of the branch.** `git rev-parse HEAD` and `git rev-parse origin/seo-phase-4-metadata-headings`
are both `641d5f282fc5f5e0dc4a23d33fee374d8797e6ed`. `git status --short` lists seven modified,
unstaged files: `SEO-CHANGELOG.md`, `web/components/seo.js`, `web/pages/about.js`,
`web/pages/blog/[slug].js`, `web/pages/changelog.js`, `web/pages/index.js`, `web/pages/pricing.js`.
Everything below that is described as done is done in the working tree.

**Shared infrastructure changed.** `web/components/seo.js` line 20 now reads
`pageTitle + (noBrandSuffix ? "" : " | Polymer")`. The default is unchanged for every page that does
not pass the prop — measured: `/features` `Applicant Tracking Software | Job Boards | Polymer`,
`/terms` `Terms of service | Polymer`, `/privacy` `Privacy policy | Polymer`,
`/industries/applicant-tracking-for-startups` `Applicant tracking for startups | Polymer`, and the
propless `<SEO />` at `web/pages/_app.js` line 93 still resolves to `Polymer: Hiring made simple`.
Pages that opt out: `web/pages/index.js` line 17, `web/pages/pricing.js` line 38,
`web/pages/about.js` line 24, `web/pages/changelog.js` line 58, and `web/pages/blog/[slug].js` line 288
for the four slugs in `BRANDLESS_TITLE_SLUGS` — `hello-polymer`,
`use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site`, `hiring-gen-z`,
`best-applicant-tracking-software`.

---

## 1. Still not done, and why

### 1.1 A fix the record reports as applied is absent from the tree

`SEO-CHANGELOG.md` line 971 lists `M web/components/start.js` in a `git status` block, and line 981
states that in `web/components/start.js` "`Styled.Title` on line 105 became a `styled.div` where it was
a `styled.h2`, so the CTA title leaves the heading outline on all seventeen pages that render
`<Start>`".

That change is not in the tree. `web/components/start.js` line 105 reads
`Styled.Title = styled.h2((props) => {` in the working tree, at HEAD `641d5f2`, and at
`seo-phase-3-redirects-canonicals`. `git status --short` lists seven files and
`web/components/start.js` is not among them. `logs/phase-4-fixes-round-3.md` line 145 records the
revert: "the line is reverted. `web/components/start.js` is now byte-identical to
`seo-phase-3-redirects-canonicals`". Line 216 of the same log records that
`SEO-CHANGELOG.md` line 981 is now false and that its author did not correct it.
`logs/phase-4-fixes-round-2.md`, section `web/components/start.js — Round 2`, describes the same
reverted change as applied.

### 1.2 Tab 17 rows A16, A17, A18 — the CTA was not moved, and the finding is not cleared

Tab 17 rows A16-A18 asked for: Fix column C16/C17/C18, "Move CTA below content headings", against
Finding column B16/B17/B18, "First H2 is boilerplate CTA 'Get your hiring process up and running in
minutes.'"

Status: NOT DONE.

Reason: no element moved. `web/pages/blog/[slug].js` line 328 renders
`<Styled.SidebarTitle>Get your hiring process up and running in minutes.</Styled.SidebarTitle>`, where
`Styled.SidebarTitle` is a `styled.div` declared at line 648; the element sits inside `Styled.Sidebar`,
which followed `Styled.PageContent` in the JSX before this branch and still does. The named string
left the heading outline; it did not move.

The finding text is not cleared either. Measured from the served HTML, the first `<h2>` in document
order on all three URLs is `Start hiring with Polymer for free`, which is
`web/components/start.js` line 105 (`Styled.Title = styled.h2`) rendered by `<Start />` at
`web/pages/blog/[slug].js` line 352:

```
/blog/one-click-distribution-to-we-work-remotelys-community-of-job-seekers
    h1  One-click distribution to We Work Remotely's community of 2.5M job seekers
    h2  Start hiring with Polymer for free
    h2  Links   h2 Resources   h2 Company   h2 Industries   (footer)
/blog/post-jobs-with-whatjobs-across-500-partners
    h1  Distribute to 500+ Partner Job Boards with our WhatJobs Integration
    h3  How it works   h3 Requirements   h3 Pricing & premium distribution   h3 Managing your listing
    h2  Start hiring with Polymer for free
/blog/post-to-we-work-remotely-6m-professionals-in-seconds
    h1  Post Directly to We Work Remotely's 6M Professionals in Seconds
    h4  Integration Updates   h3 How It Works
    h2  Start hiring with Polymer for free
```

A read-only GROQ query returns zero `content` blocks with `style == "h2"` on all three posts, so there
is no content heading on any of them to move a CTA below.

### 1.3 Tab 07 rows A7, A8, A12, A13 — correct in the working tree, absent from PR #49

Tab 07 asked for: E7 `Polymer | Applicant Tracking System & Job Boards for Startups`,
E8 `Polymer Pricing - Simple ATS Plans from $124/mo`,
E12 `About Polymer - The Team Behind the Simple ATS`,
E13 `Polymer Changelog - What's New in the ATS`.

Status: DONE INCOMPLETELY — done in the working tree, not in the pull request.

Reason: `git grep -c noBrandSuffix HEAD -- web/` returns no hits. `git show HEAD:web/components/seo.js`
line 19 reads `? pageTitle + " | Polymer"`, and `git show HEAD:web/pages/index.js` contains no `SEO`
string. PR #49 as pushed renders `/` as `Polymer: Hiring made simple` (27 characters — the string cell
B7 records as the current title and E7 replaces), `/pricing` as
`Polymer Pricing - Simple ATS Plans from $124/mo | Polymer` (57), `/about` as
`About Polymer - The Team Behind the Simple ATS | Polymer` (56) and `/changelog` as
`Polymer Changelog - What's New in the ATS | Polymer` (51). The last three carry the word Polymer
twice, which is the defect cell D16 names. Resolvable by committing the working tree.

### 1.4 Tab 07 rows A16-A19 and tab 12 row A14 — values exist only as unpublished drafts

Tab 07 asked for E16-E19 and tab 12 asked for D14. All five values are stored in Sanity drafts,
byte-identical to their workbook cells. None is live.

Reason: `web/lib/sanity.js` constructs the client with `useCdn: true` and no token, and
`getStaticProps` in `web/pages/blog/[slug].js` queries
`*[_type == "blogPost" && slug.current == $slug][0]` with no draft perspective, so only published
documents reach the page. Measured from the served HTML today: `/blog/hello-polymer` renders
`Hello Polymer` (13), `/blog/use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site`
renders `Webflow Job Boards` (18), `/blog/hiring-gen-z` renders
`Why Hiring Gen Z Looks Broken and What to Do About It` (53),
`/blog/best-applicant-tracking-software` renders
`7 Best Applicant Tracking Softwares For Small Businesses` (56), and `/blog/first-impression-bias`
renders the 162-character original description. Publishing the drafts in the Studio, then a rebuild
(`getStaticPaths` with `fallback: false`), is the outstanding step.

Side effect of the scoped opt-out, before publication: those four posts already lost their
` | Polymer` suffix, so `/blog/hello-polymer` renders at 13 characters today where the crawl recorded
23. It resolves itself the moment the drafts are published.

### 1.5 Two records still describe the pre-round-3 state of the blog opt-out

`web/pages/blog/[slug].js` line 288 reads
`noBrandSuffix={BRANDLESS_TITLE_SLUGS.has(post.slug.current)}` against the four-slug Set declared at
lines 31-36, so 22 posts keep the suffix — measured: `/blog/talent-acquisition`
`A Complete Guide to Talent Acquisition | Polymer` (48), `/blog/onboarding`
`Onboarding Best Practices, Tips, and Templates | Polymer` (56), `/blog/a-player`
`How to Find and Retain A-Player Talent | Polymer` (48).

Six statements still say the opposite:

- `SEO-CHANGELOG.md` line 1010, table row: "`web/pages/blog/[slug].js` line 279 | all 26
  `https://www.polymer.co/blog/<slug>` pages"
- `SEO-CHANGELOG.md` line 1014: "**The blog-template opt-out reaches 22 pages no tab row covers.**"
- `SEO-CHANGELOG.md` line 1445: "That line is uncommitted and it applies to all 26 posts, not only
  these four."
- `SEO-CHANGELOG.md` line 1486 and line 1519: the same claim, twice more
- `QUESTIONS-FOR-JESSICA.md` line 97, question 4: "**The `noBrandSuffix` prop is on the blog template,
  so all 26 posts lose the brand from their `<title>`, not just the four with rewrites.**" — it then
  asks Jessica to choose between three options, one of which is the one already implemented

`SEO-CHANGELOG.md` contains zero occurrences of `BRANDLESS_TITLE_SLUGS`.

### 1.6 `og:title` moved on four pages and no tab row asks for it

`web/components/seo.js` line 22 resolves `editorialTitle: editorialTitle || pageTitle` and line 83
binds `og:title` to it. Four pages pass a rewritten `pageTitle` and no `editorialTitle`, so the
share-card headline moved with the title tag. Measured:

| URL | `og:title` before | `og:title` now |
|---|---|---|
| `/blog` | `Blog` | `Hiring & Recruiting Blog - Guides and Templates` |
| `/about` | `About us` | `About Polymer - The Team Behind the Simple ATS` |
| `/changelog` | `Changelog` | `Polymer Changelog - What's New in the ATS` |
| `/features/jobboard` | `Job Board Software` | `Job Board Software - Branded, Instant, Free to Start` |

`/pricing` and `/` are no longer affected — `web/pages/pricing.js` line 39 passes
`editorialTitle={headerContent.title}` and renders `og:title` as `Pricing`, and
`web/pages/index.js` line 18 passes `editorialTitle="Hiring made simple"`. `SEO-CHANGELOG.md` line
1403 and line 1412 both still list `/pricing` among the five pages whose `og:title` moved. Passing
the previous title as `editorialTitle` on the remaining four is the same one-line remedy already
applied twice.

### 1.7 `og:description` moved on all eight tab-12 code pages and is unrecorded

`web/components/seo.js` line 88 binds `<meta property="og:description">` to the same resolved value as
`<meta name="description">` at line 59. Measured on all eight: `og:description` equals the new
description on every one, so the social-share description on the seven industry pages dropped from
219-289 characters to 116-140 and on `/terms` from 160 to 104. `grep -c "og:description"
SEO-CHANGELOG.md` returns 0. The values are the auditor's copy character for character; only the
record is missing.

### 1.8 One live page over 155 characters carries no tab 12 row

Tab 12's own title is "Meta Description Rewrites (9 over 155 chars)". A sweep of every page under
`web/pages` and all 26 published `blogPost` documents finds a tenth:
`/blog/best-job-board-software` renders 157 characters — "Today's job seekers head straight to the job
boards. Transform your hiring process and tap into the best talent with our 7 best job board software
platforms." It is published `blogPost` `8e15bac9-7d65-4e3f-8b83-6d89b41fbdbf`, it has no draft, and
`getStaticPaths` at `web/pages/blog/[slug].js` emits a path for it. No tab row prescribes a rewrite,
so no agent can supply one without writing copy the auditor did not write. Every other rendered
description is at or under 154.

### 1.9 One question routes a repo-answerable fact to Jessica

`QUESTIONS-FOR-JESSICA.md` line 87 asks about `/privacy`: "Its meta description was never measured
against the 155 limit by either tab. Worth a look if the crawl covered it." `web/pages/privacy.js`
line 61 passes a 139-character literal, measured at 139 on the served page. The answer is in the repo.

---

## 2. Needs Jessica

1. **Publish the five phase-4 Sanity drafts, or not** — outside the repo, a Studio action no agent may
   take. See the draft table below. Publishing `drafts.fcfc319d-8b14-46d0-aef5-fc1fdd751060` also
   ships a `content` change a later phase wrote into it; the two cannot be published separately.
   Do not click Generate on the slug field — `studio/schemas/blogPost.js` declares
   `options: { source: 'pageTitle' }` and all four title drafts change `pageTitle`.

2. **Three prescribed titles exceed the auditor's own `<=60 chars` note, in his copy rather than in
   the wiring — shorten them, and to what?** A decision. Rendered lengths: `/` 61 (cell E7 is 61),
   `/features/jobboard` 62 (cell E10 is 62), `/blog/best-applicant-tracking-software` 61 once
   published (cell E19 is 61). The copy was not trimmed.

3. **Accept the CTA demotion in place of the prescribed move on tab 17 rows A16-A18, or ask for
   something else?** A decision — the workbook is authoritative and the prescribed move cannot be
   executed as written (zero content `h2` blocks on all three posts). The related question is whether
   `web/components/start.js` should stop emitting an `<h2>`; that reaches 17 page templates and no tab
   row names it.

4. **`/blog/best-job-board-software` renders a 157-character description and tab 12 has no row for
   it — leave it, or supply copy?** A decision. No prescribed rewrite exists.

5. **Should `editorialTitle` be brought along on `hiring-gen-z` and `hello-polymer`, and with what
   copy?** A decision. `og:title` resolves to `editorialTitle` first, so those two keep sharing
   `Why Hiring Gen Z Looks Broken and What to Do About It` (the 53-character string tab 07 row A18
   replaces for length) and the bare `Hello Polymer`. The workbook prescribes no copy.

---

## 3. Fixed during review

| Tab row | Before → after |
|---|---|
| 07 A7 | `/` `Polymer: Hiring made simple` (27) → `Polymer \| Applicant Tracking System & Job Boards for Startups` (61) |
| 07 A8 | `/pricing` `Polymer Pricing - Simple ATS Plans from $124/mo \| Polymer` (57) → same string without the suffix (47) |
| 07 A12 | `/about` `About Polymer - The Team Behind the Simple ATS \| Polymer` (56) → same string without the suffix (46) |
| 07 A13 | `/changelog` `Polymer Changelog - What's New in the ATS \| Polymer` (51) → same string without the suffix (41) |
| 07 A16-A19 | `web/pages/blog/[slug].js` opted all 26 posts out of the brand suffix → scoped to the four `BRANDLESS_TITLE_SLUGS`; the 22 posts with no tab row keep ` \| Polymer` |
| 07 A8 | `/pricing` `og:title` `Polymer Pricing - Simple ATS Plans from $124/mo` → `Pricing`, via `editorialTitle={headerContent.title}` |
| 07 A7 | `/` `og:title` would have become the new title → held at `Hiring made simple`, via `editorialTitle="Hiring made simple"` |
| 17 A16-A18 | `web/components/start.js` `Styled.Title` `styled.div` (17 pages lost an `h2`) → reverted to `styled.h2`, byte-identical to the base branch |

---

## Tab 07 — all 13 rows, rendered `<title>` and length

Measured from the served HTML against the working tree. Lengths are of the decoded title text.

| Row | URL | Rendered `<title>` now | Len | Matches cell? |
|---|---|---|---|---|
| A7 | `/` | `Polymer \| Applicant Tracking System & Job Boards for Startups` | 61 | yes (E7 is 61) |
| A8 | `/pricing` | `Polymer Pricing - Simple ATS Plans from $124/mo` | 47 | yes (E8 is 47) |
| A9 | `/plato` | `Plato AI - AI Candidate Screening & Resume Review \| Polymer` | 59 | yes (E9 is 59) |
| A10 | `/features/jobboard` | `Job Board Software - Branded, Instant, Free to Start \| Polymer` | 62 | yes (E10 is 62, two over note A4) |
| A11 | `/blog` | `Hiring & Recruiting Blog - Guides and Templates \| Polymer` | 57 | yes (E11 is 57) |
| A12 | `/about` | `About Polymer - The Team Behind the Simple ATS` | 46 | yes (E12 is 46) |
| A13 | `/changelog` | `Polymer Changelog - What's New in the ATS` | 41 | yes (E13 is 41) |
| A14 | `/terms` | `Terms of service \| Polymer` | 26 | (keep) — unchanged, equals cell B14 |
| A15 | `/privacy` | `Privacy policy \| Polymer` | 24 | (keep) — unchanged, equals cell B15 |
| A16 | `/blog/hello-polymer` | `Hello Polymer` | 13 | no — draft unpublished; renders `Hello Polymer - Why We Built a Simpler ATS` (42) on publish |
| A17 | `/blog/use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site` | `Webflow Job Boards` | 18 | no — renders `Webflow Job Board: Show Polymer Jobs on Your Webflow Site` (57) on publish |
| A18 | `/blog/hiring-gen-z` | `Why Hiring Gen Z Looks Broken and What to Do About It` | 53 | no — renders `Why Hiring Gen Z Looks Broken - And How to Fix It` (49) on publish |
| A19 | `/blog/best-applicant-tracking-software` | `7 Best Applicant Tracking Softwares For Small Businesses` | 56 | no — renders `7 Best Applicant Tracking Systems for Small Businesses (2026)` (61) on publish |

Rendered lengths over the tab's own `<=60 chars` note: `/features/jobboard` at 62 and `/` at 61 today,
`/blog/best-applicant-tracking-software` at 61 on publish. All three overruns are in the auditor's
cells as written; none was trimmed.

---

## Sanity drafts as they now stand

Project `a6d1clb1`, dataset `production`. Eleven `drafts.*` documents exist. No published document was
mutated by this audit — the newest published `_updatedAt` across all 26 `blogPost` documents is
`2026-05-21T19:43:53Z` (hiring-gen-z), and every write in this run carries a `drafts.` id.

### Phase 4's five drafts

| Draft `_id` | Slug | Fields differing from published | New value |
|---|---|---|---|
| `drafts.2dc23f74-13f3-45c6-aff2-8bf7830e6261` | `hello-polymer` | `pageTitle` | `Hello Polymer - Why We Built a Simpler ATS` (42) |
| `drafts.54ea4d1f-deee-47c6-849e-da34989f5736` | `use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site` | `pageTitle` | `Webflow Job Board: Show Polymer Jobs on Your Webflow Site` (57) |
| `drafts.e563dba0-f14d-4493-ab3c-20de909bae59` | `hiring-gen-z` | `pageTitle` | `Why Hiring Gen Z Looks Broken - And How to Fix It` (49) |
| `drafts.fcfc319d-8b14-46d0-aef5-fc1fdd751060` | `best-applicant-tracking-software` | `pageTitle` **and `content`** | `7 Best Applicant Tracking Systems for Small Businesses (2026)` (61); plus block `a937d5dc8309` markDef `dce1a2d61580` href `https://help.wrk.xyz/en/articles/4436181-…` → `https://help.polymer.co/en/articles/4436181-…` |
| `drafts.a239b0d1-bad6-459f-98d1-b809d5a82dc7` | `first-impression-bias` | `metaDescription` | `How to identify and overcome first impression bias in hiring - plus how structured scoring and anonymized review reduce it.` (123) |

All five values are byte-identical to their workbook cells (E16, E17, E18, E19, D14) — verified by
Python string equality, not by eye. `drafts.fcfc319d-…` was created at `2026-08-06T01:30:59Z` with
the other four and written a second time at `02:52:06Z` by the phase-6 legacy-domain item; its
`pageTitle` and `content` cannot be published separately.

`metaDescription` is not a meta-tag-only field: `web/pages/blog.js` line 43 renders it as the `/blog`
index card excerpt, `web/pages/blog/[slug].js` renders it under every "Keep reading" link, and line 49
builds `topicWords` from `editorialTitle` plus `metaDescription`, so publishing the
`first-impression-bias` draft changes visible copy and shifts related-post pairings across the blog.

### Other drafts in the Studio's pending list

| Draft `_id` | Type | `_updatedAt` | Origin |
|---|---|---|---|
| `drafts.914dc19a-965f-4e6d-8187-2db998abba02` | `changelog` | `2026-08-06T02:51:58Z` | phase 6, `content` — `help.wrk.xyz` → `help.polymer.co` |
| `drafts.609fbb42-fc71-4d5b-a64a-cb7d49d4c11f` | `changelog` | `2026-08-06T02:52:00Z` | phase 6, `content` |
| `drafts.3d2afcd8-1acf-429c-81fa-ece69c210185` | `changelog` | `2026-08-06T02:52:03Z` | phase 6, `content` |
| `drafts.83ff9bc1-0a12-4def-9beb-49f2489abbd6` | `changelog` | `2022-08-18T22:49:35Z` | pre-audit |
| `drafts.3323e96f-7d9a-44cc-85ce-9273e3f1beb9` | `changelog` | `2023-07-11T12:55:43Z` | pre-audit |
| `drafts.c6e4e552-16a4-4624-b548-af6cba2779ee` | `ogre` | `2022-04-28T22:12:24Z` | pre-audit |

---

## Rows verified done and carried no finding

- **Tab 07 A9, A10, A11** — `/plato`, `/features/jobboard`, `/blog` render their cells character for
  character. **A14, A15** — `/terms` and `/privacy` untouched; `web/pages/privacy.js` is absent from
  the diff and the only change to `web/pages/terms.js` is its `metaDescription` (tab 12 row A15).
- **Tab 12 A7-A13 and A15** — all eight in-repo descriptions are byte-equal to their column-D cells:
  140, 128, 131, 124, 121, 125, 116 and 104 characters. No cell on tab 12 contains a non-ASCII
  character, so no en-dash or curly-quote drift is possible. Note A4's "fix the template once" was
  eight per-page literal edits, because no shared industry template builds a description —
  `web/components/industries/` contains no `SEO` or `metaDescription` reference, and the seven
  prescribed strings share no common stem. Every `verticalData.heroDescription` is untouched, so no
  visible hero copy moved.
- **Tab 17 A7** — `/plato` has an `<h1>`, it is the exact prescribed string, and it is the first
  heading in document order. `web/components/plato/platoHero.js` line 95 renders it; line 157's
  `Styled.Heading = styled.h1` uses the clip-rect visually-hidden recipe
  (`position:absolute; width:1px; height:1px; clip:rect(0 0 0 0)`), not `display:none`.
- **Tab 17 A8** — `/pricing` unchanged apart from `pageTitle`; the row's Fix is "Fine to keep".
- **Tab 17 A9-A15** — the first `<h2>` on all seven posts is now a content heading:
  `What is talent acquisition?`, `What is first impression bias?`, `Where they're coming from`,
  `What is onboarding?`, `How talent shops for jobs`, `What is skills mapping?`,
  `What is applicant tracking software (and how does it work)?`. The ToC label is a
  `<nav aria-label="Table of contents">` wrapping a `div` (`web/pages/blog/[slug].js` lines 259-264,
  `Styled.TableOfContents = styled.nav` at line 773).

---

## Close

**Rounds run:** 3. The loop stopped without a clean round — round 3 changed the tree (reverted
`web/components/start.js`, scoped the blog opt-out to four slugs), so convergence was not reached.

**Reviewers:** every angle returned in every round — tab-07-code, tab-07-sanity, tab-12, tab-17,
code-correctness and deferrals. No reviewer failed to return.

**Severity remaining:** no BLOCKER. One HIGH — tab 17 rows A16-A18, the CTA was not moved and the
first `<h2>` on all three URLs is still a boilerplate CTA (§1.2). Six MED — the working tree is
uncommitted and PR #49 contains none of it (§1.3), the five values that exist only as unpublished
drafts (§1.4), the `SEO-CHANGELOG.md` claim of a `start.js` change that is not in the tree (§1.1),
the six statements describing the blog opt-out as reaching all 26 posts (§1.5), `og:title` moved on
four pages (§1.6), `og:description` moved on eight pages unrecorded (§1.7). Three LOW — the
157-character description on `/blog/best-job-board-software` (§1.8), the `/privacy` question already
answerable from the repo (§1.9), and the three title overruns present in the auditor's own copy.
