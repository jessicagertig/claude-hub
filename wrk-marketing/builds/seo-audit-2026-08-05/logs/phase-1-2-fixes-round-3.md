# Phase 1-2 fixes — round 3

## SEO-CHANGELOG.md

Agent scope: the three round-3 findings filed against `/Users/jessica/wrk/wrk-corp/wrk-marketing/SEO-CHANGELOG.md`. Branch `seo-phase-1-2-deorphan-crawl`, already checked out. Nothing committed, nothing pushed. `git status --short` after the edits shows `M SEO-CHANGELOG.md` plus the three files other agents hold (`web/pages/blog/[slug].js`, `web/pages/features/jobboard.js`, `web/pages/sitemap.xml.js`) — no file outside my own was touched.

### State verified before editing

- `git show seo-phase-1-2-deorphan-crawl:SEO-CHANGELOG.md | sed -n '5p;87p;317p'` returns all three false statements verbatim, so the committed file (what PR #47 renders) still carries them.
- `git show seo-phase-1-2-deorphan-crawl:SEO-CHANGELOG.md | grep -i "click path\|clicks from\|Phase 1 step 3"` returns nothing.
- The working-tree file already carries all four corrections, added in rounds 1 and 2: line 5 paragraph rewritten around `6229f91`, line 90 "statically generated HTML" corrected, lines 322-328 "Provenance of those counts", and the "Phase 1 step 3 — 200 confirmation and click path per URL" section at line 334.
- `6229f91` exists, `git rev-parse HEAD origin/seo-phase-1-2-deorphan-crawl` returns the same SHA on both, and `git show --name-status 6229f91` lists exactly the six files line 5 now claims.
- `ls BLOCKED.md` → no such file. `grep -i blocked` over `phase-1.md`, `phase-2.md`, `phase-1-2-fixes-round-1.md`, `phase-1-2-fixes-round-2.md` returns nothing — no phase log ever mentions it.
- Master prompt rule 3 read in full from `master-prompt-pages-router.md` line 8. It also appears in Phase 3 step 2 ("log the page build in `BLOCKED.md`") and Phase 7 step 1 ("items in `BLOCKED.md`").

### Change 1 — finding 3 (MED), the BLOCKED.md section

Replaced the three-line `### BLOCKED.md` section. Before:

```
No blockers were logged. `/Users/jessica/wrk/wrk-corp/wrk-marketing/BLOCKED.md` does not exist, and every item returned `blocked: false`.
```

After: the rule 3 sentence quoted verbatim, then a three-row table mapping each item to the rule 3 category it falls in and to where it currently lives instead.

| Item | Category | Currently in |
|---|---|---|
| Tab 03 row A10 host handling — Vercel domain config, no `vercel.json` under `web/` | environment value | `QUESTIONS-FOR-JESSICA.md` |
| Tab 02 row A9 — Search Console submission and Index Coverage | missing permissions | "needsLiveCheck still unconfirmed" only; in no questions file and no `BLOCKED.md` |
| Tab 01 rows A7:F16 "refresh" plus A8/A9/A12/A15 extras and F16's `/features/jobboard` copy | editorial judgment call | `QUESTIONS-FOR-JESSICA.md` |

Also records the Phase 7 consequence: the final report is compiled from "items in `BLOCKED.md`", so with no file on disk it shows zero blocked items while three are open.

The `BLOCKED.md` file itself was NOT created — this round permitted one file and creating a second repo file is outside it. The section says so in as many words so it is not read as closed.

### Change 2 — findings 1 and 2 (HIGH, MED), the committed-vs-working-tree gap

Both findings' substance was already fixed in the working tree by rounds 1 and 2; the residual is that the corrections are uncommitted and PR #47 still displays the old text. Committing is out of scope for this round. Added one paragraph after the file list at the top of the changelog naming exactly what the committed copy still says wrong and what it lacks, so the gap is visible in the file rather than surviving only in a round-2 log line.

### Workbook quote check

Ran `read-workbook.py` for `01 Orphaned Pages`, `02 XML Sitemap`, `03 robots.txt`, `08 llms.txt`. Every cell the orchestrator quoted matches the workbook except two truncations:

- Tab 03 C8 is `AI-answer visibility is part of the growth strategy; blocking them contradicts the AEO plan`. The orchestrator's rendition stops at "growth strategy".
- Tab 02 B10 is `customer job boards, separate host`. The orchestrator's rendition gives only "separate host".

Neither changes what was built.

### Not fixed

- `BLOCKED.md` — outside this agent's one owned file.
- The commit that would put any of these corrections on PR #47 — committing was forbidden.
# Phase 1-2 fixes — Round 3

## web/pages/blog/[slug].js

Branch `seo-phase-1-2-deorphan-crawl` was already checked out. Not committed, not
pushed. **I wrote nothing to the repo this round.** `git status --short` shows
`SEO-CHANGELOG.md`, `web/pages/features/jobboard.js` and `web/pages/sitemap.xml.js`
also modified — other agents' edits, not mine.

### Workbook check

`python3 read-workbook.py "01 Orphaned Pages"` — the orchestrator's brief quotes
tab 01 accurately. Note A4 and the `Recommended action` strings F7-F16 match. The
brief writes column A as `/blog/<slug>`; the workbook writes
`https://www.polymer.co/blog/<slug>`. No other difference. No misquote to report.

### All four findings describe `6229f91`, not the file on disk

Every finding routed to me this round was computed against the committed tip. The
round-2 agent had already applied all of them to the working tree. `git diff --
web/pages/blog/[slug].js` shows the three changes in place:

1. `relatedTo()` builds a symmetric graph — `strongestFor()` is computed for every
   post over the same slug-sorted 26-post corpus, and a post's own top-N is unioned
   with every post that picked it.
2. `.filter((scored) => scored.score > 0)` inside `strongestFor()`.
3. `<h2>Keep reading</h2>` replaced by `<Styled.RelatedTitle>` (a `styled.div`),
   with `aria-label="Keep reading"` on the `Styled.Related` `<aside>`, and the
   `h2 { ... }` rule moved out of `Styled.Related` into `Styled.RelatedTitle`.

I re-verified rather than trusting round 2's log.

### Verification 1 — replay the on-disk function over the live corpus

Extracted lines 27-97 **from the file on disk** (`sed -n '27,97p'`) and ran
`relatedTo()` once per post over all 26 `blogPost` documents fetched read-only from
`https://a6d1clb1.apicdn.sanity.io/v2021-03-25/data/query/production` with the
page's own projection and `| order(publishDate desc)` — the same computation
`getStaticProps` performs. Scripts: `<scratchpad>/related.js`, `<scratchpad>/related2.js`.

```
links emitted site-wide      98
edges with zero shared words  0
posts with zero inbound       0
edges on exactly 1 shared word  22 of 98
outbound-count distribution   {2: 1, 3: 12, 4: 7, 5: 4, 6: 2}
```

- **tab 01 row A11 `job-rejection-email`** — inbound 0 -> 3:
  `behavioral-interview-scoring-matrix`, `onboarding`,
  `problem-solving-interview-questions`. Emits 3.
- **`hello-polymer`** — inbound 0 -> 3.
- **tab 01 row A8 `behavioral-interview-scoring-matrix`** — inbound 2 -> 4:
  `best-applicant-tracking-software`, `best-job-board-software`,
  `problem-solving-interview-questions`, `job-rejection-email`.
- **tab 01 row A7 zero-score edge** — `utc-is-the-timezone-of-the-future ->
  post-jobs-with-whatjobs-across-500-partners` (score 0.000, no shared word) is
  gone. Zero edges site-wide now rest on no shared word.

These figures reproduce round 2's independently measured numbers exactly.

### Verification 2 — the rendered pages

A `next dev` on port 3000 is serving this working tree. Fetched five pages and
parsed the `Keep reading` `<aside>`:

```
job-rejection-email                  h2 "Keep reading": absent  links: problem-solving-interview-questions, onboarding, behavioral-interview-scoring-matrix
hello-polymer                        h2 "Keep reading": absent  links: employer-branding-steps, one-click-distribution-..., post-jobs-with-whatjobs-...
behavioral-interview-scoring-matrix  h2 "Keep reading": absent  links: problem-solving-interview-questions, best-applicant-tracking-software, best-job-board-software, job-rejection-email
problem-solving-interview-questions  h2 "Keep reading": absent  links: a-player, behavioral-interview-scoring-matrix, talent-acquisition, job-rejection-email, five-things-...
utc-is-the-timezone-of-the-future    h2 "Keep reading": absent  links: hiring-gen-z, interview-feedback-examples
```

`aria-label="Keep reading"` present on all five. Rendered links match the replay
exactly. No `next build` run: `web/` is one working tree shared with the
concurrent phase-3 through phase-6 agents, and `next build` fails in this
environment on `./images/clt.jpg` in the untouched `pages/about.js` — a
squoosh-wasm issue that reproduces on `main` and is unrelated to this diff.

### Changes made

None. Editing the file would have re-applied changes already on disk.

### Not done

1. **HIGH, tab 01 row A11 — the `relatedTo()` rewrite is still on no branch.** The
   content is correct in the working tree; only a commit makes the row true on
   PR #47, and my instructions this round are explicit: do not commit, do not push.
   Needs the orchestrator or Jessica to commit `web/pages/blog/[slug].js` to
   `seo-phase-1-2-deorphan-crawl`. Same escalation as round 2's item 1.
2. **`utc-is-the-timezone-of-the-future` renders 2 related links, not 3** — below
   the master prompt's "3 links minimum, topically matched". It has exactly two
   posts with any shared topic word; a third link would have score 0.000, which is
   the defect finding 2 asks to remove. The two constraints cannot both hold for
   this post and no third topically-matched post exists to supply. Not invented.
   The post is not a tab 01 row; all ten tab 01 URLs emit and receive 3 or more.
3. **22 of 98 edges rest on exactly one shared word** (up from 16 of 78, because
   the symmetric graph emits more edges). Examples: `hiring-gen-z ->
   utc-is-the-timezone-of-the-future` on `showing`; `employer-branding-steps ->
   hello-polymer` on `works`; `post-to-we-work-remotely-... ->
   how-to-have-your-job-posts-...` on `directly`. A minimum-shared-word threshold
   would fix these and re-orphan posts: round 2 measured MIN=2 re-orphaning
   `hello-polymer` and `utc-is-the-timezone-of-the-future`, MIN=3 re-orphaning five
   including tab 01 row A11's `job-rejection-email`. Any threshold would be an
   invented number — nothing in the workbook or repo prescribes one. Left at
   `score > 0`.
4. **The `Keep reading` heading-outline side effect is still absent from
   `SEO-CHANGELOG.md`.** Not my file. `SEO-CHANGELOG.md` line 210 still shows the
   old `<h2>Keep reading</h2>` code sample and line 226 still explains the heading
   wording as a heading.
5. **`web/pages/features/jobboard.js` line 28 carries a literal
   `<h2>Keep reading</h2>`** — confirmed present, uncommitted. Not my file.
6. **The `refresh` half of tab 01 rows A7-A16** and every row-specific extra —
   `add downloadable template` (A8), `formula & benchmark blocks for AEO` (A9),
   `fold into hiring-ops cluster` (A12), `base for interview-bias guide` (A15).
   All Sanity `blogPost` content, not code. This file cannot make them true.

### Note for whoever routes round 4

Findings 1, 2 and 4 of this round are the same findings round 2 already closed on
disk. Two consecutive rounds have re-derived them because the reviewers read
`6229f91` while the fixes live in an uncommitted working tree. Committing
`web/pages/blog/[slug].js` ends the loop.

# Phase 1-2 fixes — Round 3

## web/pages/sitemap.xml.js

Branch `seo-phase-1-2-deorphan-crawl` was already checked out. Not committed, not
pushed. `git status --short` after my edits shows `SEO-CHANGELOG.md`,
`web/pages/blog/[slug].js` and `web/pages/features/jobboard.js` also modified —
other agents' files, which I did not touch.

### Workbook check

`python3 read-workbook.py "02 XML Sitemap"` — the orchestrator's brief quotes A4,
A7:C7, A8:C8, A9:C9 and A10/C10 verbatim. One truncation: B10 is `customer job
boards, separate host`; the brief gives only `separate host`. It changes nothing
about what was built. (Already reported by the `SEO-CHANGELOG.md` agent above.)

### Change 1 — finding 1 (MED), GROQ query style

Replaced the single object-projection query with two module-level queries in the
house form (`*[_type == "..."]{ one field per line } | order(<content date> desc)`,
as in `web/pages/blog.js` lines 14-21 and `web/pages/changelog.js` line 14).

Before:

```js
const query = `{
  "posts": *[_type == "blogPost"]{ "slug": slug.current, _updatedAt } | order(_updatedAt desc),
  "changelogUpdatedAt": *[_type == "changelog"] | order(_updatedAt desc)[0]._updatedAt
}`;
```

After:

```js
const postsQuery = `*[_type == "blogPost"]{
  slug,
  _updatedAt
} | order(publishDate desc)`;

const logsQuery = `*[_type == "changelog"]{
  _updatedAt
} | order(date desc)`;
```

All three flagged forms are gone: the top-level object projection, the
`"slug": slug.current` alias, and the `| order(...)[0]._updatedAt`
slice-then-attribute. Two `await sanity.fetch(...)` calls replace the one, which
is the form `web/pages/blog/[slug].js` `getStaticProps` uses (lines 359 and 363).
Result variables are named `posts` and `logs` to match `web/pages/blog.js` line 71
and `web/pages/changelog.js` line 89.

Both flagged consequences follow:

- `post.slug` is now `post.slug.current` at the URL-building call site, the same
  shape as `web/pages/blog.js` line 30 and `web/pages/blog/[slug].js` line 278.
- Ordering is `publishDate desc` / `date desc`, matching every other query.

Because `publishDate`/`date` order is not last-modified order, the two index-page
`lastmod` values can no longer be read off row `[0]`. Added:

```js
const latestUpdatedAt = (documents) =>
  documents.map((document) => document._updatedAt).sort().pop();
```

`_updatedAt` comes back Z-suffixed ISO 8601, so lexicographic max is chronological
max. This is not a cosmetic detail: the live `changelog` documents in
`| order(date desc)` come back `2022-04-30T18:43:32Z`, `2022-04-30T18:42:35Z`,
`2026-02-03T00:25:30Z` — row `[0]` would have published a 2022 `lastmod` for a page
last edited in 2026.

`web/pages/features/jobboard.js` is not affected; nothing in it reads these
queries.

### Change 2 — finding 2 (MED), partial: `Cache-Control`

Added one line:

```js
res.setHeader("Cache-Control", "public, s-maxage=3600, stale-while-revalidate=86400");
```

This closes the second half of the finding — the response previously set only
`Content-Type`, so Vercel's SSR default `no-store` applied and every crawler hit
ran both Sanity queries. It does NOT close the first half; see "Not fixed" below.

### Change 3 — finding 3 (MED), tab 02 row A8

No edit. The working-tree comment already names the mismatch, which is what round 2
added and what the finding itself records. See "Not fixed" below for why the URL
was left as is.

### Verification

1. **Both GROQ queries run against live Sanity** (read-only GET to
   `https://a6d1clb1.apicdn.sanity.io/v2021-03-25/data/query/production`, project
   `a6d1clb1`, dataset `production` from `web/.env.local`). `blogPost` returns 26
   documents with `slug` as `{_type, current}` and Z-suffixed `_updatedAt`;
   `changelog` returns 85.
2. **`latestUpdatedAt` and `urlEntry` asserted** over that live data in
   `<scratchpad>/check.mjs` — max across out-of-order timestamps, `undefined` on an
   empty array, source array not mutated, both `urlEntry` branches. Not written into
   the repo.
3. **The route served end to end.** `next dev` on port 3999 against this working
   tree, then `curl -si http://localhost:3999/sitemap.xml`:

```
HTTP/1.1 200 OK
Content-Type: text/xml
Cache-Control: public, s-maxage=3600, stale-while-revalidate=86400
```

   44 `<loc>` elements (18 static routes + 26 posts). Zero occurrences of
   `object%20Object` or `undefined`. `xmllint --noout` reports well-formed.
   `<loc>https://www.polymer.co/blog</loc>` carries `<lastmod>2026-05-21T19:43:53Z`
   and `<loc>https://www.polymer.co/changelog</loc>` carries
   `<lastmod>2026-02-03T00:47:51Z`, both the max across their documents. Blog slugs
   render as `https://www.polymer.co/blog/talent-acquisition-vs-recruitment` etc.
   Server stopped afterwards.

No `next build`: `web/` is one working tree shared with concurrent agents, and the
`pages/about.js` squoosh-wasm failure reproduces on `main` (recorded by the
`web/pages/blog/[slug].js` agent above).

### Not fixed

1. **Finding 2, first half — the route uses `getServerSideProps`, not
   `getStaticProps`.** Every other route under `web/pages/` uses
   `getStaticProps`/`getStaticPaths`. In the Pages Router a page with
   `getStaticProps` still renders through the React tree and emits HTML; there is no
   `getStaticProps` form that writes a `text/xml` body. Emitting XML from a Pages
   Router route requires `getServerSideProps` with `res.write`, or an
   `pages/api/sitemap.xml.js` route plus a rewrite in `next.config.js` — which is
   still per-request and would need a file I do not own. The Sanity queries
   therefore still run per request; the `Cache-Control` header added above limits
   that to roughly one origin hit per hour at the Vercel CDN rather than one per
   crawler hit. The mechanism itself remains a divergence from the house form.
2. **Finding 3 — the `<loc>` / `og:url` mismatch on
   `applicant-tracking-for-legal-services`.** The divergence is
   `web/pages/industries/applicant-tracking-for-legal-services.js` line 90, which
   declares `pathname="industries/applicant-tracking-for-legal-services"` while the
   other six industries pages (lines 90 of each) declare the top-level rewrite form
   and `web/components/footer.js` links to the top-level form. That file is not
   mine. Changing the sitemap `<loc>` to the `industries/`-prefixed form instead
   would put the one outlier URL in the sitemap and split it from the six siblings
   and from what the footer links — so the URL was left at the top-level form and
   the comment continues to name the mismatch. One-word fix in a file I do not own.

---

# Phase 1-2 fixes — Round 3

## web/pages/features/jobboard.js

One finding routed to this file: MED, tabRow `n/a`, angle "conventions — does the
new code match this codebase's house forms".

### State verified before editing

`git -C /Users/jessica/wrk/wrk-corp/wrk-marketing rev-parse --abbrev-ref HEAD` →
`seo-phase-1-2-deorphan-crawl`. Working tree had four modified, uncommitted files:
`SEO-CHANGELOG.md`, `web/pages/blog/[slug].js`, `web/pages/sitemap.xml.js`,
`web/pages/features/jobboard.js`. `git diff main...seo-phase-1-2-deorphan-crawl
--stat` lists six files and does not include `web/pages/features/jobboard.js`.
Both halves of the finding's factual claim confirmed.

`git show main:web/pages/features/jobboard.js` is 26 lines: `SEO`, `Intro`,
`Basics`, `Features`, `Other`, `Start`, no styled components, no data fetching.
Every line of the "Keep reading" block is round-2 work.

### Files read in full before editing

`web/pages/features/jobboard.js` → `web/components/section.js` →
`web/components/blogSection.js` → `web/styles/theme.js` → `web/pages/blog.js` →
`web/components/seo.js` → `web/pages/blog/[slug].js` → `web/pages/_app.js` →
`web/styles/global.js` → `web/pages/changelog.js` → `web/components/looking.js` →
`web/lib/sanity.js`. Plus `web/components/jobBoard/{intro,basics,features,other}.js`
for heading levels and `label:` prefixes, and `web/components/footer.js` lines
270-290 for the link-underline form.

### Change 1 — the hardcoded CMS copy

Before, the block hardcoded two strings:

    <a>Best Job Board Software to Improve your Hiring Process</a>
    <p>Today's job seekers head straight to the job boards. Transform your hiring
    process and tap into the best talent with our 7 best job board software platforms.</p>

Both are verbatim Sanity fields. Confirmed against the live page —
`curl https://www.polymer.co/blog/best-job-board-software` returns 200, its
`og:title` is `Best Job Board Software to Improve your Hiring Process` (the SEO
component maps `og:title` to `editorialTitle`) and its `meta name="description"`
is the `<p>` text character for character. Nothing was fabricated by round 2; the
strings were accurate on 2026-08-05.

They are now read from Sanity, matching the `const query` + `getStaticProps` +
`sanity.fetch` form in `web/pages/blog.js` and `web/pages/changelog.js`:

    const query = `*[_type == "blogPost" && slug.current == "best-job-board-software"][0]{
      editorialTitle,
      metaDescription,
      slug
    }`;

    export const getStaticProps = async () => {
      const blogPost = await sanity.fetch(query);

      return {
        props: { blogPost }
      };
    };

Two reasons, not one:

1. `web/pages/blog/[slug].js` `getStaticPaths` returns `{ paths, fallback: false }`.
   `/blog/best-job-board-software` exists only while the Sanity `blogPost` with
   that slug exists. A hardcoded `<Link href>` becomes a 404 internal link if the
   post is unpublished or its slug changes — the inverse of what tab 01 is for, and
   silent. The `{blogPost && ...}` guard removes the block instead.
2. Tab 01 row 16 reads "Link from /features/jobboard + blog index; refresh". The
   post is going to be refreshed. A copy-pasted `editorialTitle` and
   `metaDescription` drift from the CMS at that moment.

Query verified against the live content lake before committing to the shape:

    curl -s -G "https://a6d1clb1.apicdn.sanity.io/v2021-03-25/data/query/production" \
      --data-urlencode "query=*[_type == \"blogPost\" && slug.current == \"best-job-board-software\"][0]{editorialTitle,metaDescription,slug}"

returns `editorialTitle`, `metaDescription` and `slug.current` identical to the
strings that were hardcoded. Rendered output is unchanged.

Record naming is `blogPost` (the Sanity `_type`), matching the round-2 naming in
`web/pages/blog/[slug].js` (`blogPost`, `otherBlogPosts`, `relatedBlogPosts`).
`web/pages/blog.js` uses `post`/`posts`, which is pre-existing.

### Change 2 — the "Keep reading" block markup

`web/pages/blog/[slug].js` renders the same block as:

    <Styled.Related aria-label="Keep reading">      // styled.aside
      <Styled.RelatedTitle>Keep reading</Styled.RelatedTitle>   // styled.div

`web/pages/features/jobboard.js` rendered it as `styled.div` + a bare
`<h2>Keep reading</h2>` styled through a descendant selector, with no `aria-label`.
One block, two forms, both added in this PR. The jobboard copy now matches the
`[slug].js` form: `Styled.Related` is `styled.aside` carrying
`aria-label="Keep reading"`, and `Styled.RelatedTitle` is a `styled.div`. The
`t.mb(6)` / `t.mb(8)` that were on the `h2` moved onto `Styled.RelatedTitle`, so
the rendered spacing is unchanged.

### Checked and deliberately left alone

- **`text-decoration: underline` without `!important`.** `web/styles/global.js`
  resets `a, a:link, a:visited, a:hover, a:active { text-decoration: none; color:
  inherit; }`. `.css-hash a` and `a:link` are both specificity (0,1,1), so source
  order decides. Fetched the live `/features/jobboard` HTML: the global reset is
  emitted at byte 231 of the concatenated `<style>` tags, component styles at byte
  23248 — component rules come later and win. Confirmed live by
  `web/components/footer.js` lines 280-286, which underlines footer links with no
  `!important` and renders underlined in production. The `!important` occurrences
  in `[slug].js` and `changelog.js` sit on `p a` (0,1,2) selectors inside
  PortableText output. `web/components/looking.js` lines 60-63 is the exact same
  shape as this block — nested `a`, `display: block`, `text-decoration: underline`,
  no `!important`. No change.
- **Curly apostrophe in JSX text.** `Today's` carries U+2019 raw in the JSX. Also
  raw in `web/pages/plato.js` lines 17-18, `web/components/plato/platoDescription.js`
  line 28, `platoPrivacy.js` line 33, `platoHeroCard.js` line 53.
  `react/no-unescaped-entities` does not cover U+2019. It is now a Sanity value
  rather than a literal anyway. No change.
- **`label: JobBoard_Related`.** House form is `label: <ComponentName>_<Part>`, and
  this file's component is `Main`. `Main_Related` carries no information, and the
  convention is already loose in the codebase — `web/pages/blog/[slug].js` lines
  385 and 402 label `JobPost_Header` / `JobPost_HeaderContent` inside a component
  named `BlogPost`. Kept `JobBoard_*`, which names the page.
- **`const query` as the query variable name.** Matches `web/pages/blog.js` line 14
  and `web/pages/changelog.js` line 14 exactly.
- **`<Section thin>` wrapper.** `web/components/section.js` accepts `thin`; the
  usage matches `web/pages/changelog.js` line 62.

### Verification

- `./node_modules/.bin/eslint pages/features/jobboard.js` — exit 0, no findings.
  The config is `next/core-web-vitals`, which parses the JSX and checks `next/link`
  usage.
- GROQ query executed against the production dataset (above), returns the expected
  document and fields.
- No `next build` run: it would write `.next/` into the source repo and rebuild
  every Sanity blog post. The added code is structurally identical to
  `web/pages/blog.js` lines 14-21 and 70-76.

### Not fixed

1. **The file is still not in PR #47.** That is the finding's actual defect and it
   is not fixable from here — the task says "Do NOT commit, do NOT push."
   `web/pages/features/jobboard.js` remains an uncommitted working-tree
   modification alongside `SEO-CHANGELOG.md`, `web/pages/blog/[slug].js` and
   `web/pages/sitemap.xml.js`. Anyone reading the PR diff still sees six files and
   none of this. Whoever commits the branch has to include it.
2. **The "Keep reading" link is now conditional on the Sanity document.** Tab 01
   row 16 asks for a link from `/features/jobboard`. If the `blogPost` with slug
   `best-job-board-software` is ever removed or renamed in Sanity, the block stops
   rendering and the row silently stops being true. The alternative was a hardcoded
   link that 404s under the same conditions. The post is live today (HTTP 200) so
   the row is true today.
