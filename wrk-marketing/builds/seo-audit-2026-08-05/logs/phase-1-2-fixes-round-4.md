# Phase 1-2 fixes — round 4

## QUESTIONS-FOR-JESSICA.md

Finding: MED, tab 03 row A10 — "Host handling" | "serve at both apex and www" | "Apex 308s to www; ensure robots.txt resolves pre-redirect too". The question was absent from `QUESTIONS-FOR-JESSICA.md` after three rounds.

Verified the tab row against the workbook with `python3 read-workbook.py "03 robots.txt"`. A10/B10/C10 read exactly as quoted in the finding.

Live checks run before writing (read-only `curl -I`):

- `https://polymer.co/robots.txt` → 308, `location: https://www.polymer.co/robots.txt`
- `https://www.polymer.co/robots.txt` → 404 (branch not deployed)
- `https://polymer.co/` → 308, `location: https://www.polymer.co/`

Repo checks: `web/public/robots.txt` exists on the branch; `web/next.config.js` carries only the `/climate` redirect and the seven industry rewrites; there is no `vercel.json` anywhere in the repo.

Change: added a new section `## Phase 2, item 2 — robots.txt` to `/Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/QUESTIONS-FOR-JESSICA.md`, immediately above the existing `## Phase 2, item 3 — llms.txt` section. It carries one question — whether `polymer.co/robots.txt` should answer 200 instead of 308 to www, and who changes the Vercel domain settings — plus the tab row quoted verbatim and the three live results above. No other file touched. Nothing committed, nothing pushed.

## Workbook misquote in the orchestrator's tab summary

The prompt's copy of tab 03 row A8 gives C8 as "AI-answer visibility is part of the growth strategy". The workbook's C8 is `AI-answer visibility is part of the growth strategy; blocking them contradicts the AEO plan`. The prompt's copy is truncated at the semicolon. A7, A9 and A10 match the workbook character for character.

## web/pages/blog/[slug].js

Four findings, all four naming a fix that "exists in the working tree,
uncommitted". I read the file before touching anything: the working tree already
carries all four changes verbatim as the findings describe them. **I made zero
edits.** What follows is the verification that the working-tree content actually
makes the rows true, and the one part I cannot resolve.

### Workbook check

`python3 read-workbook.py "01 Orphaned Pages"` — the orchestrator's tab 01 summary
matches the workbook. A11 is `https://www.polymer.co/blog/job-rejection-email`,
F11 is `Link + light refresh`, character for character. All ten rows' F-column
actions match. The summary abbreviates the A-column URLs to their paths
(`/blog/job-rejection-email` for `https://www.polymer.co/blog/job-rejection-email`);
the F-column strings, which are what the findings quote, are exact. No misquote.

### Verification method

Fetched the live production dataset and replayed both `relatedTo`
implementations over all 26 posts, one page at a time, exactly as
`getStaticProps` does:

```
curl -sG 'https://a6d1clb1.apicdn.sanity.io/v2021-03-25/data/query/production' \
  --data-urlencode 'query=*[_type == "blogPost"]{_id, editorialTitle, publishDate, metaDescription, slug} | order(publishDate desc)'
```

26 documents. `projectId` `a6d1clb1` from `web/lib/sanity.js`; dataset
`production` from `web/.env.local` (`SANITY_STUDIO_API_DATASET`), read only.
Script: `/private/tmp/claude-501/-Users-jessica-claude-hub-wrk-marketing/ae83cb44-eb97-4453-99a4-0718b5a2e1c9/scratchpad/replay.js`

Result:

```
===== COMMITTED (6229f91) =====
total links emitted: 78   outbound per page: 3-3
pages with ZERO inbound: job-rejection-email, hello-polymer

===== WORKING TREE =====
total links emitted: 98   outbound per page: 2-6
pages with ZERO inbound: none
zero-score links: 0

inbound, the 10 tab-01 orphans        committed -> working tree
  problem-solving-interview-questions      4  ->  5
  behavioral-interview-scoring-matrix      2  ->  4
  employee-turnover                        3  ->  3
  interview-feedback-examples              3  ->  4
  job-rejection-email                      0  ->  3
  a-player                                 4  ->  5
  agile-recruiting-process                 3  ->  3
  talent-acquisition-vs-recruitment        4  ->  4
  first-impression-bias                    2  ->  3
  best-job-board-software                  3  ->  4
```

### Finding 1 / finding 3 — tab 01 row A11, job-rejection-email inbound links

Both findings are the same row. The working tree's `relatedTo` seeds the result
Map with the post's own top 3 (`strongestFor(blogPost)`), then walks every other
post and adds any that picked this post in *its* top 3. The score is symmetric,
so the graph is undirected. `job-rejection-email` goes 0 -> 3 inbound.
`hello-polymer`, the other zero, is also covered — no page in the blog now
receives zero inbound related-post links.

### Finding 2 — zero-score links

`.filter((scored) => scored.score > 0)` sits inside `strongestFor`, before the
`.slice(0, RELATED_POST_COUNT)`, so it gates both the outbound top-3 and the
reciprocal pass. Replayed: **0 zero-score links** in the working-tree graph,
against 1 on the committed version. The named case is gone:

```
committed  /blog/utc-is-the-timezone-of-the-future -> hiring-gen-z, interview-feedback-examples, post-jobs-with-whatjobs-across-500-partners
working    /blog/utc-is-the-timezone-of-the-future -> hiring-gen-z, interview-feedback-examples
```

Side effect worth naming: `utc-is-the-timezone-of-the-future` now renders 2
related links instead of 3. It is the only page below 3 outbound. Its third slot
was the score-0 link.

### Finding 4 — the boilerplate `<h2>Keep reading</h2>`

Working tree lines 320-321:

```jsx
<Styled.Related aria-label="Keep reading">
  <Styled.RelatedTitle>Keep reading</Styled.RelatedTitle>
```

`Styled.RelatedTitle` is a `styled.div` at line 797 carrying the `t.text.bold`,
`t.text.xl` and `t.mq[56] { t.text.xxl }` rules that were on the `h2` selector
inside `Styled.Related`; those rules are removed from `Styled.Related`. Rendered
appearance is unchanged; the H2 is off all 26 posts' heading outlines. This is
the same form committed on `seo-phase-4-metadata-headings`.

### Verification

- `./node_modules/.bin/eslint "pages/blog/[slug].js"` from `web/` — exit 0, no
  findings. Config is `next/core-web-vitals`, which parses the JSX.
- No `next build`: it writes `.next/` into the source repo and rebuilds every
  Sanity post. The lint parse plus the replay above cover the change.

### Not fixed

1. **None of this is on the branch.** Every one of the four findings' residual is
   that the rewrite is an uncommitted working-tree modification and PR #47's diff
   does not contain it. My task says "Do NOT commit, do NOT push," so I cannot
   resolve it, and neither could rounds 2 or 3, which filed the same escalation.
   `web/pages/blog/[slug].js` is still `M` alongside `SEO-CHANGELOG.md`,
   `web/pages/features/jobboard.js` and `web/pages/sitemap.xml.js`. Whoever
   commits the branch has to include all four.
2. **SEO-CHANGELOG.md still describes the old markup.** Finding 4 notes the
   changelog shows `<h2>Keep reading</h2>` at line 210 and explains the wording as
   a heading at line 226, and does not record the heading-outline effect. Finding 1
   notes its inbound table at line 317 lists `job-rejection-email` as 0, which the
   replay above now contradicts. That file is not mine — I own only
   `web/pages/blog/[slug].js` — so both are untouched and stale.

## /Users/jessica/wrk/wrk-corp/wrk-marketing — branch state

Finding: MED, tabRow `n/a`. Four files carry uncommitted edits that PR #47 does
not contain.

### Confirmed the finding

```
git rev-parse HEAD                                  6229f913a61822e8b510bf95fd93db8ba78da38f
git rev-parse origin/seo-phase-1-2-deorphan-crawl   6229f913a61822e8b510bf95fd93db8ba78da38f
```

Local `HEAD`, the remote branch tip and the PR head are the same commit, so PR
#47 is exactly `6229f91`. `git show --name-status 6229f91` lists six files:
`SEO-CHANGELOG.md` (A), `web/pages/blog.js` (M), `web/pages/blog/[slug].js` (M),
`web/pages/sitemap.xml.js` (A), `web/public/llms.txt` (A), `web/public/robots.txt`
(A). The rounds 1-3 fixes are all working-tree only.

### The count moved while I worked

`git status --porcelain` at the start of this session returned four modified
files. Re-run after my first edit it returned five — `web/public/llms.txt` had
been modified by a concurrent round-4 agent, reordering the three `## Pricing`
plan bullets to lead with the annual figure (`Starter, $124/month billed annually
or $149/month billed monthly`; the committed version leads with the monthly
figure). Same figures, same plan limits. I wrote the record as a snapshot rather
than a closed count because of this.

### Changes made — `SEO-CHANGELOG.md` only

Two edits, both to the repo's own record of the branch state. No code file
touched.

1. **Top-of-file working-tree block.** The file already carried a paragraph
   beginning "**This file is ahead of `6229f91`.**" naming only
   `SEO-CHANGELOG.md`'s own divergences. Added a block above it that names every
   file with uncommitted edits and what each carries, states that `HEAD`,
   `origin/seo-phase-1-2-deorphan-crawl` and the PR head are all `6229f91`, and
   states that concurrent agents were still writing so the list is a snapshot.
   `web/pages/sitemap.xml.js` had no working-tree record anywhere in the file
   before this.

2. **Sitemap section note.** `SEO-CHANGELOG.md` line 484, immediately after the
   `web/pages/sitemap.xml.js` "After:" code block, which reproduces the committed
   source. Added a note that the block is `6229f91` and the working tree has
   changed it, naming the five differences: the one combined query split into
   `postsQuery` and `logsQuery` fetched with two `sanity.fetch` calls; both
   ordered by `publishDate` / `date` rather than `_updatedAt`, with a new
   `latestUpdatedAt()` picking the newest `_updatedAt` across the documents for
   the `/blog` and `/changelog` `<lastmod>`; `postsQuery` projecting `slug` whole
   rather than aliasing `"slug": slug.current`, so the entry reads
   `post.slug.current`; the added `Cache-Control: public, s-maxage=3600,
   stale-while-revalidate=86400`; and the expanded `staticRoutes` comment naming
   `applicant-tracking-for-legal-services`.

   The same note records two statements under Open items that are now stale
   against the working tree and were left standing because this file preserves
   verifier text verbatim: "Optional chaining is still used at
   `pages/sitemap.xml.js:48`" (Phase 1, item 2, finding 4 — the file no longer
   uses `?.` anywhere) and "a top-level object projection wrapping two queries
   (one fetch beats two)" (Phase 2, item 1, finding 4 — it is now two fetches).
   Both are true of `6229f91`.

### Checked and deliberately left alone

- **The `<h2>Keep reading</h2>` at `SEO-CHANGELOG.md` line 210 and the inbound
  table listing `job-rejection-email` as 0.** The `[slug].js` round-4 agent
  flagged both as stale. They sit inside "Change 3", the before/after record of
  `6229f91`, and inside a section headed "**These counts describe `6229f91`
  only.**" Both are accurate as records of that commit, and the new top block
  names the `h2` → `Styled.RelatedTitle` change and the `relatedTo()` rewrite. No
  change.
- **The llms.txt "After:" block.** It reproduces the committed file, which the
  concurrent agent has since reordered. That file and its section belong to the
  tab-08 agent, which was still writing. Named in the top block, not rewritten
  here.

### Not fixed

1. **The files are still not in PR #47.** That is the finding's actual defect.
   Making it true requires a commit and a push; the task says "Do NOT commit, do
   NOT push," and per the standing rule PRs and pushes are Jessica's. Rounds 2, 3
   and the round-4 `[slug].js` agent filed the same escalation. Nothing I write
   into an uncommitted `SEO-CHANGELOG.md` can appear in the PR diff either — the
   changelog edits above make the repo's own record complete for whoever commits
   the branch, they do not put the work in the PR. Whoever commits has to include
   every file `git status --porcelain` shows, and the set was still growing at
   23:56.

## web/pages/sitemap.xml.js

Two findings, both MED, both naming the same residual as the other round-4
agents: the fix "exists only in the uncommitted working tree". I read the file
before touching anything. **I made zero edits.** What follows is the
verification that the working-tree content makes tab 02 true, and the two parts
I cannot resolve.

### Workbook check

`python3 read-workbook.py "02 XML Sitemap"` — the orchestrator's tab 02 summary
matches the workbook on A4, A7/B7/C7, A8/B8/C8, A9/B9/C9 and A10/C10, character
for character. One misquote: the prompt gives B10 as `separate host`; the
workbook's B10 is `customer job boards, separate host`. C10, which is the cell
the row's action lives in, is exact. No effect on any fix.

### State verified before deciding

- `git branch --show-current` → `seo-phase-1-2-deorphan-crawl`. The branch IS
  checked out, contrary to the review brief. Finding 1 is correct on this.
- `git status --short` → `M SEO-CHANGELOG.md`, `M web/pages/blog/[slug].js`,
  `M web/pages/features/jobboard.js`, `M web/pages/sitemap.xml.js`. Same four
  files the other round-4 agents report.
- The working tree already carries every change finding 1 enumerates: the
  `Cache-Control` header, the split `postsQuery`/`logsQuery`, `latestUpdatedAt`,
  the `slug` projection with `post.slug.current` at the call site, and the
  rewritten header comment.

### The header comment is accurate

`grep -rn "pathname" pages/industries/` — six of the seven industries pages
declare the top-level form; `applicant-tracking-for-legal-services.js:90`
declares `pathname="industries/applicant-tracking-for-legal-services"`. The
comment's claim is true. It says the mismatch is on **og:url**, not canonical,
which is also true: `components/seo.js` emits `<meta property="og:url">` and no
`<link rel="canonical">` at all.

### `latestUpdatedAt` is load-bearing

The committed query ordered by `_updatedAt desc`, so `posts[0]._updatedAt` was
the max. The working tree orders by `publishDate desc` to match the rest of the
site, which is a different order. Replayed against the live dataset:

```
first row _updatedAt : 2022-08-30T14:14:17Z
max  _updatedAt      : 2026-05-21T19:43:53Z
```

Without the helper the `/blog` lastmod would be 2022. Both versions are correct
by different routes; the helper is not redundant.

### Output replay

Replayed the working-tree module against the live production dataset
(`projectId` `a6d1clb1` from `web/lib/sanity.js`, dataset `production`,
read-only GET). Script:
`/private/tmp/claude-501/-Users-jessica-claude-hub-wrk-marketing/ae83cb44-eb97-4453-99a4-0718b5a2e1c9/scratchpad/sitemap-replay.mjs`

```
static routes: 18  posts: 26  changelog docs: 85  total <url>: 44
bytes: 5179
non-https/non-www locs: 0
forbidden hosts (app./developer./jobs.): 0
duplicate locs: 0
lastmod count: 28
```

Tab 02 row A7 (all marketing routes + every Sanity blog post with lastModified
from CMS timestamps) and row A8 (www host only, absolute HTTPS, excluding
`app.polymer.co` and `developer.polymer.co`) both hold. Row A10
(`jobs.polymer.co` out of scope) holds — no such loc is emitted. Row A9 is
Search Console, outside the repo.

`./node_modules/.bin/eslint pages/sitemap.xml.js` from `web/` — exit 0.
No `next build`: it writes `.next/` into the source repo.

### Not fixed

1. **Finding 1 — the changes are uncommitted.** Resolving it means committing.
   My task says "Do NOT commit, do NOT push." Rounds 2 and 3 filed the same
   escalation. Whoever commits the branch has to include all four modified files.

2. **Finding 2 — `getServerSideProps` cannot become `getStaticProps`.** In
   Pages Router `getStaticProps` has no `res` object and its return value feeds
   a React component that Next wraps in the `_document.js` HTML shell, so it
   cannot emit an XML body. The only build-time mechanism that produces XML is
   a postbuild script writing `web/public/sitemap.xml`, which needs a new script
   file and a `package.json` change — both outside the one file I own. The
   `Cache-Control` half of the finding is already satisfied on disk
   (`public, s-maxage=3600, stale-while-revalidate=86400`, line 72); there is no
   `vercel.json` and no `headers()` in `next.config.js`, so the route is the
   only place that header can come from.

3. **Side effect of the divergence, unreported until now.** Every other page is
   built at build time and `pages/blog/[slug].js` uses
   `getStaticPaths` with `fallback: false`. `studio/` has
   `sanity-plugin-vercel-deploy` installed, so content reaches the site by
   redeploying from the Studio. The sitemap does not follow that model: it
   queries Sanity per request. A blog post published in Sanity **without** a
   redeploy appears in `/sitemap.xml` within an hour and `/blog/<slug>` returns
   404, because that slug was not in the deployed build's `paths`. Submitting
   404 URLs is a Search Console coverage error. No in-file fix exists — it is
   inherent to serving the sitemap dynamically over a statically built site.
   Jessica's call whether that is acceptable or the postbuild-script route is
   worth the two extra files.

---

## `web/pages/features/jobboard.js` — round 4

Findings assigned: two HIGHs, both against tab 01 row 16
("Link from /features/jobboard + blog index; refresh"). Both say the same thing:
the "Keep reading" block linking `/blog/best-job-board-software` exists only as
an uncommitted working-tree modification, so merging PR #47 (`6229f91`) ships
none of it.

### Tab row verified against the workbook

Ran `read-workbook.py "01 Orphaned Pages"`. `A16` is
`https://www.polymer.co/blog/best-job-board-software` and `F16` is
`Link from /features/jobboard + blog index; refresh`. The orchestrator's quote
of row 16 matches the workbook. No misquote to report.

### What the working tree already had

The round-3 block was present and structurally intact. I traced every identifier
it uses rather than assume:

- `components/section.js` — `Section` accepts `thin`. Exists.
- `lib/sanity.js` — default export is a configured `@sanity/client`, `.fetch` used
  the same way `pages/blog.js` and `pages/blog/[slug].js` use it.
- `styles/theme.js` — `t.text.lg`, `t.text.semibold`, `t.text.xl`, `t.text.xxl`,
  `t.text.bold`, `t.text.sm`, `t.text.gray`, `t.text.base`, `t.color.black`,
  `t.mb`, `t.mt`, `t.mq[56]` all exist.

Trace: `pages/features/jobboard.js` → `components/section.js` → `components/container.js`;
`pages/features/jobboard.js` → `lib/sanity.js`; `pages/features/jobboard.js` → `styles/theme.js`;
`pages/_app.js` → `styles/global.js`.

I also confirmed the Sanity document the query depends on actually exists, since
the block is behind `{blogPost && ...}` and would silently render nothing if it
did not. Live query against `a6d1clb1` / `production` returns
`editorialTitle: "Best Job Board Software to Improve your Hiring Process"`.

### What I changed

One defect, in the anchor styling. `styles/global.js` lines 41-48 reset every
link:

```
  a,
  a:link,
  a:visited,
  a:hover,
  a:active {
    text-decoration: none;
    color: inherit;
  }
```

`a:link` and `a:visited` have specificity (0,1,1). The round-3 rule compiled to
`.css-hash a`, also (0,1,1) — an exact tie, resolved only by stylesheet
insertion order. The nearest analog is the identically-named `Styled.Related a`
in `pages/blog/[slug].js` (line 837), the other "Keep reading" block, and it
pins both properties with `!important`. `pages/changelog.js` line 184 does the
same. Matched that form:

```
    a {
      ${[t.text.lg, t.text.semibold]};
      display: block;
      color: ${t.color.black} !important;
      text-decoration: underline !important;
```

`t.text.black` came out of the utility array because the `!important` colour
declaration replaces it. Nothing else in the file was touched.

### Verification

Booted `next dev` on port 3111 and fetched `/features/jobboard`:

- HTTP 200, compiled with no errors.
- Rendered HTML contains
  `<a href="/blog/best-job-board-software">Best Job Board Software to Improve your Hiring Process</a>`
  — a plain crawlable `href`, which is what the de-orphaning needs.
- Emitted CSS for that anchor is
  `color:#000000!important;text-decoration:underline!important;`.

Server stopped, port 3111 free.

### Not fixed

1. **The file is still not in PR #47.** This is the actual defect both findings
   name, and it is not resolvable from inside this file: it needs a commit and a
   push, and the task says "Do NOT commit, do NOT push." Same escalation the
   round-2, round-3 and round-4 `[slug].js` and `SEO-CHANGELOG.md` agents filed.
   Whoever commits the branch has to include every path `git status --porcelain`
   reports, not just this one.

2. **The "refresh" half of row 16.** The row asks for
   "Link from /features/jobboard + blog index; refresh". The two link halves are
   done (this file, and `pages/blog.js` rendering all 26 posts). "Refresh" means
   rewriting the body of the `best-job-board-software` post, which lives in the
   Sanity `production` dataset, not in this repo, and is editorial judgment about
   Jessica's own content. Needs Jessica.

---

## SEO-CHANGELOG.md — round 4

Three findings, all against `/Users/jessica/wrk/wrk-corp/wrk-marketing/SEO-CHANGELOG.md`. Branch `seo-phase-1-2-deorphan-crawl` already checked out. Nothing committed, nothing pushed. `git status --short` after my edits shows `M SEO-CHANGELOG.md` plus the four files other agents hold — no file outside my own was touched.

### Workbook check

Ran `read-workbook.py` for `01 Orphaned Pages`, `02 XML Sitemap`, `03 robots.txt` and `08 llms.txt`. Two truncations in the orchestrator's rendition, both already reported by other agents this round and in round 3, confirmed here independently:

- Tab 03 C8 is `AI-answer visibility is part of the growth strategy; blocking them contradicts the AEO plan`. The brief stops at "growth strategy".
- Tab 02 B10 is `customer job boards, separate host`. The brief gives only "separate host".

Everything else matches character for character, including all ten tab 01 `Recommended action` strings and every tab 08 row. The brief abbreviates tab 01's column A to paths; the workbook writes full `https://www.polymer.co/...` URLs.

### The file changed under me mid-round

My first edit failed with "File has been modified since read". A concurrent round-4 agent (the "branch state" section above) had added a working-tree file list at the top of the changelog and a note under the sitemap "After:" block. I re-read the whole file and dropped roughly two thirds of what I had drafted, because that agent had already covered it. What follows is only the gaps it left — it recorded under "Checked and deliberately left alone" that it was not touching the stale `<h2>` sample or the inbound table, which are two of the three gaps I filled.

### Change 1 — the measured effect of the `relatedTo()` rewrite

The file said the `6229f91` inbound counts "have to be re-derived once that change lands". They had been, twice. Expanded "**These counts describe `6229f91` only**" with:

- a summary table, `6229f91` vs working tree: links site-wide 78 → 98, outbound per page 3 → 2-6, posts with zero inbound 2 → 0, zero-shared-word edges 1 → 0, one-shared-word-or-fewer edges 16 of 78 → 22 of 98;
- a per-row table of inbound links to the ten tab 01 URLs, both columns, `job-rejection-email` (row A11) 0 → 3;
- which posts supply row A11's three, and row A8's shift away from drawing only from fellow orphans.

Attributed to the two replays in `logs/phase-1-2-fixes-round-3.md` and this round's `[slug].js` section, which agree on every figure. I did not re-run either; `web/pages/blog/[slug].js` has mtime 2026-08-05 23:16 and has not changed since round 3 measured it. The one metric that exists in only one log (one-shared-word edges) is round 3's.

Relabelled one row while transcribing: round 3 reports "22 of 98" for edges on *exactly* one shared word, while the changelog's existing verifier finding reports "16 of 78" for one shared word *or fewer*. Those are different measures. Since the working tree has zero zero-word edges, "or fewer" is 22 there too, so the row is labelled "one shared word or fewer" and both columns are correct under that label.

### Change 2 — the `<h2>` removal, recorded for the first time

Added the second uncommitted `[slug].js` change to the same section: `<Styled.Related>` + `<h2>Keep reading</h2>` → `<Styled.Related aria-label="Keep reading">` + `<Styled.RelatedTitle>`, with the `h2 { ... }` rules moved into a new `styled.div` carrying the same declarations, so rendered type is unchanged, and the heading-outline reason. Marked as superseding the Change 3 code sample and the heading-wording rationale beneath it rather than editing those, since they are the accurate record of `6229f91`.

Also recorded a master prompt deviation that was in no repo file: Phase 1 step 2 asks for "3 links minimum", and `utc-is-the-timezone-of-the-future` renders 2 because its third slot was the zero-overlap link the rewrite removes. It is not a tab 01 URL.

Consequential edit in the "Phase 1 step 3" section: it said the rewrite "targets" the row A11 zero. It closes it — all ten tab 01 rows receive 3 or more inbound in the working tree, so all ten gain the second 3-click path once the change is committed.

### Change 3 — `web/pages/features/jobboard.js` described as it now is

The file's account of that block was written when the block was round-2 work and had gone stale twice over. It said `<h2>Keep reading</h2>` and described the link text and description as hardcoded marketing copy. Round 3 replaced the `h2` with `Styled.RelatedTitle` + `aria-label` and moved both strings into a `getStaticProps` reading `editorialTitle` and `metaDescription` from Sanity behind a `{blogPost && ...}` guard. Rewrote the paragraph as a proper entry with file, URL affected, the `main` baseline of 26 lines, the current markup, and why the strings come from the CMS (`fallback: false` would turn a stale hardcoded href into a 404 internal link, and the same tab row asks for a "refresh" that would strand copied text).

Kept the flag: no new sentence was written for the feature page, but putting a blog link and a "Keep reading" heading on a live feature page is Jessica's editorial call, and the file is in neither `6229f91` nor the branch.

### Change 4 — finding 1, where this file lives

Added a "Where this file lives" section under Open items. It records that the repo root otherwise holds only `README.md`, `studio/` and `web/`; that the file is 630 lines / 42 KB as committed and is an agent run record, with line 3 citing two logs by absolute local path under `/Users/jessica/claude-hub/`; and that the repo's actual product changelog is the unrelated Sanity `changelog` document type in `studio/schemas/changelog.js`, 85 entries, rendered by `web/pages/changelog.js`.

Then both instructions, quoted: master prompt rule 4 puts this file "in the repo" and Phase 7 step 1 builds the final report from it; `~/claude-hub/CLAUDE.md` universal rule 1 sends outputs to the pipeline scratchpad, not into source code. Satisfying either breaks the other.

### Change 5 — the top-of-file gap list

The "**This file is ahead of `6229f91`**" paragraph listed one missing section. It now lists four, including the three added this round.

### Not fixed

1. **Finding 1 — the file is still at the repo root.** Making the row literally true means deleting `SEO-CHANGELOG.md` from the branch, which contradicts master prompt rule 4 ("in the repo") and removes PR #47's only account of what the branch does. Two instructions Jessica approved point opposite ways, and picking between them is hers, not mine. Recorded in the file instead, with both quoted, so the choice is visible rather than made by default. What I could fix inside the file — the false "Nothing in this run was committed or pushed", fixed in round 1 — is fixed.

2. **Findings 2 and 3 — the corrections are still uncommitted.** Both findings are written against `git show seo-phase-1-2-deorphan-crawl:SEO-CHANGELOG.md`. The click-path record (finding 2) has been in the working-tree file since round 1 and all three false statements (finding 3) were corrected in rounds 1 and 2. Nothing is missing from the file on disk; what is missing is a commit, and the task says "Do NOT commit, do NOT push." This is the fourth consecutive round to file this escalation, and it will recur verbatim in round 5 unless the branch is committed. Every agent this round reported the same thing about its own file.

3. **`BLOCKED.md` still does not exist.** Same as round 3: one owned file, and creating a second repo file is outside it. The changelog section says so in as many words.

### Note for whoever routes round 5

Five files now carry uncommitted work — `SEO-CHANGELOG.md`, `web/pages/blog/[slug].js`, `web/pages/features/jobboard.js`, `web/pages/sitemap.xml.js`, `web/public/llms.txt` — and PR #47 contains none of it. Every round-4 agent's primary "not fixed" item is that commit. Re-running the reviewers against `6229f91` will re-derive the same findings a fifth time. Two agents also edited `SEO-CHANGELOG.md` concurrently this round; if that repeats, one of them should own it.
