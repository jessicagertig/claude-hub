# Phase 1-2 fixes — Round 2

## web/pages/sitemap.xml.js

Branch: `seo-phase-1-2-deorphan-crawl` (already checked out; not committed, not pushed).

### Finding (MED, tabRow n/a) — conventions

Asked: the file states in its own comment that the static routes are "written the
way the site's own SEO component declares it in `pathname`".

Status: FIXED (comment corrected; no `<loc>` changed).

### Trace

```
web/pages/sitemap.xml.js
  → web/components/footer.js:137
  → web/next.config.js:40-42
  → web/pages/industries/applicant-tracking-for-legal-services.js:90
  → web/components/seo.js:13
```

### What I verified

Grepped `pathname` across every static page. All 17 declarations checked against
`staticRoutes`:

| Page | Declared `pathname` | Sitemap entry | Match |
|---|---|---|---|
| industries/applicant-tracking-for-cryptocurrency-companies.js:90 | `applicant-tracking-for-cryptocurrency-companies` | same | yes |
| industries/applicant-tracking-for-fintech-companies.js:90 | `applicant-tracking-for-fintech-companies` | same | yes |
| industries/applicant-tracking-for-greentech-companies.js:90 | `applicant-tracking-for-greentech-companies` | same | yes |
| industries/applicant-tracking-for-healthcare-companies.js:90 | `applicant-tracking-for-healthcare-companies` | same | yes |
| **industries/applicant-tracking-for-legal-services.js:90** | **`industries/applicant-tracking-for-legal-services`** | **`applicant-tracking-for-legal-services`** | **NO** |
| industries/applicant-tracking-for-real-estate-companies.js:90 | `applicant-tracking-for-real-estate-companies` | same | yes |
| industries/applicant-tracking-for-startups.js:90 | `applicant-tracking-for-startups` | same | yes |
| features.js:409, features/jobboard.js:15, features/candidate-management-software.js:15, plato.js:20, blog.js:59, changelog.js:59, pricing.js:39, about.js:25, terms.js:11, privacy.js:62 | as listed | same | yes |
| index.js | none | `""` | yes |

The finding is accurate. `applicant-tracking-for-legal-services` is the only
route where the file's stated rule does not hold.

`web/components/seo.js:13` builds `url` as
`` `${baseUrl}/${pathname}` ``, so that page emits
`og:url = https://www.polymer.co/industries/applicant-tracking-for-legal-services`
while the sitemap `<loc>` is
`https://www.polymer.co/applicant-tracking-for-legal-services`.

`web/components/footer.js:137` links to `/applicant-tracking-for-legal-services`
— the bare form. So the sitemap `<loc>` agrees with the footer and with the six
sibling pages; the page's own `pathname` is the outlier.

### Change made

Comment only. `staticRoutes` is byte-identical.

```diff
 // Every static marketing route, written the way the site's own SEO component
-// declares it in `pathname`. The industries pages appear under their top-level
-// rewrite source (see the rewrites in next.config.js) because that is the URL
-// the footer links to. New pages need a line here.
+// declares it in `pathname` — except the industries pages, which appear under
+// their top-level rewrite source (see the rewrites in next.config.js) because
+// that is the URL footer.js links to. One of them,
+// applicant-tracking-for-legal-services, declares the `industries/`-prefixed
+// form in `pathname`, so that page's og:url does not match its <loc> here.
+// New pages need a line here.
```

Verified: `node --check` passes on the edited file.

### Why the `<loc>` was not changed instead

Changing the `<loc>` to `industries/applicant-tracking-for-legal-services` would
put a URL in the sitemap that has zero internal links pointing at it
(`footer.js:137` links to the bare form), and would make that one entry
inconsistent with its six siblings. That is a behavioral change to the shipped
sitemap, not a minimum-scope fix.

The mismatch originates in
`web/pages/industries/applicant-tracking-for-legal-services.js:90`, which I do
not own. See notFixed.

### Left for Jessica / another agent

`web/pages/industries/applicant-tracking-for-legal-services.js:90` declares
`pathname="industries/applicant-tracking-for-legal-services"`. Its six siblings
declare the bare top-level form. Setting it to
`pathname="applicant-tracking-for-legal-services"` would make its `og:url` match
the footer link, the sitemap `<loc>`, and the six siblings. Outside my file.

Separately, both `/applicant-tracking-for-legal-services` and
`/industries/applicant-tracking-for-legal-services` return 200 for all seven
industries pages — Next.js rewrites alias the URL without removing the
destination path. Pre-existing on `main`; not introduced by this branch.

### Workbook misquote in the orchestrator's tab summary

Tab 02 row A10, `B10`. The orchestrator's summary quotes it as
`"separate host"`. `read-workbook.py "02 XML Sitemap"` returns
`B10: customer job boards, separate host`. LOW — the recommendation text in
`C10` is quoted correctly and no deliverable depends on `B10`.

## web/pages/features/jobboard.js

Branch: `seo-phase-1-2-deorphan-crawl` (already checked out; not committed, not pushed).

### Finding (HIGH, tab 01 row A16)

Asked: `Link from /features/jobboard + blog index; refresh` for
`https://www.polymer.co/blog/best-job-board-software`.

Status: FIXED for the `/features/jobboard` link half. The `refresh` half is
Sanity blog-post content, not this file — see notFixed.

### Workbook check

`read-workbook.py "01 Orphaned Pages"` — the orchestrator's brief quotes tab 01
exactly. `A16` = `https://www.polymer.co/blog/best-job-board-software`,
`F16` = `Link from /features/jobboard + blog index; refresh`. No misquote.

### Trace

```
web/pages/features/jobboard.js
  → web/components/section.js
  → web/components/looking.js:15        (house Next-12 <Link><a> idiom)
  → web/components/jobBoard/other.js    (styled/theme idiom for this page)
  → web/styles/theme.js:74-86,232-246   (every theme key used)
```

### Change made

Added a `Keep reading` block between `<Other />` and `<Start />`, wrapped in the
existing `Section` component that every other section of this page already uses.

```jsx
<Section thin>
  <Styled.Related>
    <h2>Keep reading</h2>
    <Link href="/blog/best-job-board-software">
      <a>Best Job Board Software to Improve your Hiring Process</a>
    </Link>
    <p>Today's job seekers head straight to the job boards. Transform your hiring process and tap into the best talent with our 7 best job board software platforms.</p>
  </Styled.Related>
</Section>
```

Plus the `Link` / `styled` / `css` / `Section` imports and a `Styled.Related`
emotion block. No other file touched.

### Where the copy came from — nothing invented

Both strings are read from the live page, not written by me:

| String | Source |
|---|---|
| `Best Job Board Software to Improve your Hiring Process` | `<h1>` of `https://www.polymer.co/blog/best-job-board-software` (HTTP 200) |
| `Today's job seekers head straight to the job boards…` | `<meta name="description">` of the same live page |
| `Keep reading` | already on this branch in `web/pages/blog/[slug].js`, same purpose |

### Link idiom

Used `<Link href><a>…</a></Link>` — the form in `web/components/looking.js:15`,
`navigation.js:48,80` and `footer.js:73`. Next 12.1 needs the `<a>` child for a
crawlable anchor to reach the HTML.

Note: `web/pages/blog/[slug].js` on this branch uses `<Link href={…}>{title}</Link>`
with a bare string child. Not my file, not in my findings, so not changed —
flagging it only because it is the same Next-12 `Link` API.

### Verification

`next dev` on port 3941 against the live Sanity production dataset, then curled
the page. (`next build` fails in this environment on `./images/clt.jpg` in the
untouched `pages/about.js` — a node-20/Next-12 squoosh wasm issue, unrelated.)

- `/features/jobboard` → HTTP 200
- rendered HTML contains
  `<a href="/blog/best-job-board-software">Best Job Board Software to Improve your Hiring Process</a>`
- rendered HTML contains the `Keep reading` heading and the description paragraph
- dev log clean — no error, warning, or failure lines

Before this change the rendered page had zero `/blog/` hrefs beyond the three
`/blog` nav/footer links. `/blog/best-job-board-software` is now reachable from
`/features/jobboard`.

### notFixed

`refresh` (tab 01 row A16). The post body lives in the Sanity `blogPost`
document, not in this repo, and rewriting a listicle is editorial work on
Jessica's own content. needsJessica.

---

## `SEO-CHANGELOG.md`

Branch: `seo-phase-1-2-deorphan-crawl`, already checked out; no `checkout` run. Nothing committed, nothing pushed. The only file I wrote is `SEO-CHANGELOG.md`. `web/pages/blog/[slug].js` still shows modified in the working tree — that is the concurrent `relatedTo()` fix agent, not me.

### The finding, and what was actually on disk

Asked: three claims round 1 identified as false are still in `SEO-CHANGELOG.md` as committed in `6229f91` — line 5 ("Nothing in this run was committed or pushed... two modified files and three new files"), line 87 ("All 26 posts are now in the statically generated HTML"), line 317 ("Inbound related-links counted by the verifier from a real `next build`").

Status: the file content was already correct when I arrived. All three of round 1's corrections are present in the working tree. `git diff SEO-CHANGELOG.md` shows them. They are uncommitted, and committing is outside what I was permitted to do — see Not done.

But the premise underneath two of those corrections had gone stale, and one sentence round 1 wrote is now false.

### A real `next build` exists on disk

Round 1 wrote its corrections around the fact that no build was run, and round 1's own "Not done" explains why it declined to run one (shared `web/` working tree, concurrent phase-3-to-6 agents). Round 1 saw `web/.next/build-manifest.json` appear and dismissed the output as "belonging to no single branch".

Checked directly:

```
web/.next/BUILD_ID   W4gbUszIATiA1mb07NwFH   2026-08-05 21:51
web/pages/blog/[slug].js                     2026-08-05 22:58
```

The build predates the `[slug].js` edit by an hour, and `web/pages/blog.js` is unmodified against `6229f91`. So for the blog pages that output *is* a build of the committed code, and the uncommitted reciprocal `relatedTo()` rewrite is not in it.

What it contains:

| Measured | Command | Result |
|---|---|---|
| Built post pages | `ls web/.next/server/pages/blog/*.html \| wc -l` | 26 |
| Distinct post links on the index | `grep -o 'href="/blog/[a-z0-9-]*"' blog.html \| sort -u \| wc -l` | 26 |
| Total related links across corpus | `grep -o 'href="/blog/[a-z0-9-]*"' *.html \| wc -l` | 78 |
| Outbound per page | per-file `sort -u` count | 3 |
| Inbound, 10 tab-01 slugs, tab order | `grep -l` per slug, self excluded | 4, 2, 3, 3, 0, 4, 3, 4, 2, 3 |
| `features/jobboard.html` blog hrefs | `grep -c 'href="/blog/'` | 0 |

Every figure in the changelog reproduces exactly from generated HTML. Round 1's re-derivation against live Sanity was right, and the verifier's original numbers were right — only the stated source was ever false.

### Changes made

1. **Item 1, the "statically generated HTML" correction.** Round 1 narrowed the claim to code-plus-live-query because no build existed. Reworded "no `next build` was run in this run" to "by Phase 1 or Phase 2" (the run-scoped hedge was doing work the reader could not see), and added a sentence pointing at the build output that now confirms the original claim.

2. **"Provenance of those counts".** Round 1's sentence "The `web/.next/server/pages/blog.html` originally cited is not this branch's build" is false as of 21:51 — a file at that path exists and, for the blog output, is a build of `6229f91`. Replaced with a statement of what is actually true: the verifier had no build to count from *when it wrote the line*, so the attribution was unsupported when made.

3. **New "The build on disk" paragraph.** Records `BUILD_ID`, the timestamp, that neither Phase 1 nor Phase 2 produced it, the mtime argument for why the blog output is `6229f91`, and the reproduced counts. Followed by an explicit limit: this is not a clean build of the branch, other pages may carry concurrent phase-3-to-6 edits, nothing outside the blog output should be read off it.

4. **Verifier finding, Phase 1 item 2, MED 1** — "Counting inbound from a real `next build`". This is the same false attribution round 1 corrected at the body text, left standing here. The file's own convention (stated at "Repairs applied after the workflow": findings are "recorded as the verifiers wrote them, so the audit trail stays intact") is to annotate rather than rewrite, which is how the llms.txt HIGH already carries its "**Fixed — see...**" note. Annotated in that form.

5. **Verifier finding, Phase 1 item 1, LOW 4** — "the `web/.next/server/pages/blog.html` the implementer cited is no longer on disk". Stale for the same reason. Annotated: a file at that path exists again, from the concurrent build, carrying 26 distinct hrefs, and it is not the artifact the implementer cited.

### Checked and left alone

- `git show --name-status 6229f91` returns `A SEO-CHANGELOG.md`, `M web/pages/blog.js`, `M web/pages/blog/[slug].js`, `A web/pages/sitemap.xml.js`, `A web/public/llms.txt`, `A web/public/robots.txt` — six files, two modified and four added. Round 1's line 5 correction states exactly that. Accurate, unchanged.
- Verifier finding Phase 1 item 2 MED 3 cites "the built `features/jobboard.html` contains zero `/blog/` hrefs". Re-measured against the current build: still 0. Unchanged.
- The node-version records (verifier finding item 1 HIGH 2, question 8) say `next build` fails on v18.20.8 and builds clean on v16.20.2. A build succeeding at 21:51 does not contradict a version-specific failure. Unchanged.
- `needsLiveCheck` still lists the deployed `/blog` serving 26 links as unconfirmed. A local build is not a deploy. Unchanged.

### Not done

- **The corrections are still uncommitted.** That is the substance of the finding — the false claims live in `6229f91`, which is what PR #47 shows, and the fixes sit in the working tree. My instructions were "Do NOT commit, do NOT push", so I could not close it. Whoever commits this branch next carries round 1's corrections plus mine; until then the PR still displays all three false claims. This is the one part of the finding no edit to my file can resolve.
- No `next build` was run by me. None was needed — the artifact already on disk answered the question, and building would have raced the same concurrent agents round 1 avoided.

## web/pages/blog/[slug].js

Branch: `seo-phase-1-2-deorphan-crawl` (already checked out at start; not
committed, not pushed). The only file I wrote in the repo is
`web/pages/blog/[slug].js`. `SEO-CHANGELOG.md` also shows as modified in the
working tree — that is another agent's edit, not mine.

### Workbook check

`python3 read-workbook.py "01 Orphaned Pages"` — the orchestrator's brief quotes
tab 01 accurately. All ten `Recommended action` strings (F7-F16) and note A4
match character for character. The brief writes the URLs in column A as
`/blog/<slug>`; the workbook writes them as
`https://www.polymer.co/blog/<slug>`. Nothing else differs. No misquote to
report.

### State found at start — the six related-posts findings were already fixed on disk

Five of the seven findings against this file (`tab 01 row A11` x2, `tab 01 row
A8`, `tab 01 row A7` x2) describe the committed tip `6229f91`. The round-1 fix
agent's `relatedTo()` rewrite was present in the working tree when I started,
uncommitted, exactly as the HIGH finding says. I re-verified it rather than
trusting the round-1 log.

**Method.** Extracted `RELATED_POST_COUNT` through the end of `relatedTo` **from
the file on disk** (not a copy), imported it as a module, and ran it once per
post over all 26 `blogPost` documents fetched live from
`https://a6d1clb1.api.sanity.io/v2021-03-25/data/query/production` with the
page's own projection and `| order(publishDate desc)` — the same computation
`getStaticProps` performs at build time. Script:
`<scratchpad>/replay.mjs`. Read-only fetches, nothing written into the repo.

Measured on the working-tree file:

| | committed `6229f91` | working tree |
|---|---|---|
| links emitted site-wide | 78 | 98 |
| posts with zero inbound related links | 2 | 0 |
| non-mutual edges | 22 | 0 |
| edges with **zero** shared words | 1 | 0 |
| related links rendered per post | always exactly 3 | 2 to 6 |

- **tab 01 row A11 (`job-rejection-email`)**: inbound 0 -> 3 —
  `behavioral-interview-scoring-matrix`, `onboarding`,
  `problem-solving-interview-questions`.
- **tab 01 row A8 (`behavioral-interview-scoring-matrix`)**: inbound 2 -> 4, of
  which inbound from posts that were **not** themselves tab-01 orphans is 0 -> 1
  (`best-applicant-tracking-software`). Full inbound set:
  `best-applicant-tracking-software`, `best-job-board-software`,
  `problem-solving-interview-questions`, `job-rejection-email`.
- **tab 01 row A7 (the zero-score defect)**: the `.filter((scored) =>
  scored.score > 0)` removes it. `utc-is-the-timezone-of-the-future ->
  post-jobs-with-whatjobs-across-500-partners`, the one edge with no shared words
  at all, is gone. `utc-is-the-timezone-of-the-future` now renders 2 links, not 3.

Inbound count for all 10 tab-01 URLs, with how many come from posts that were not
themselves on tab 01:

```
problem-solving-interview-questions   in=5  from-non-orphan=2
behavioral-interview-scoring-matrix   in=4  from-non-orphan=1
employee-turnover                     in=3  from-non-orphan=2
interview-feedback-examples           in=4  from-non-orphan=4
job-rejection-email                   in=3  from-non-orphan=1
a-player                              in=5  from-non-orphan=2
agile-recruiting-process              in=3  from-non-orphan=2
talent-acquisition-vs-recruitment     in=4  from-non-orphan=3
first-impression-bias                 in=3  from-non-orphan=1
best-job-board-software               in=4  from-non-orphan=2
```

### Residual on the tab 01 row A7 finding, stated as a fact

The finding named three weak edges. One is gone (the zero-shared-word one). The
other two survive: `interview-feedback-examples -> whatjobs` (shares only
`candidates`) and `job-rejection-email -> onboarding` (shares only `templates`).
22 of the 98 edges rest on exactly one shared word. **Zero rest on none.**

I did not add a minimum-shared-word threshold. Measured what one would do
(`<scratchpad>/threshold.mjs`, same live corpus):

```
MIN shared words = 1 (current): links=98  posts with zero inbound = 0
MIN shared words = 2:           links=88  posts with zero inbound = 2  [hello-polymer, utc-is-the-timezone-of-the-future]
MIN shared words = 3:           links=56  posts with zero inbound = 5  [hiring-gen-z, job-rejection-email, hello-polymer, utc-is-the-timezone-of-the-future, five-things-a-startup-should-keep-in-mind-when-hiring]
```

A threshold of 2 re-orphans two posts; a threshold of 3 re-orphans five,
including tab 01 row A11's `job-rejection-email`. Any such number would also be
invented — nothing in the workbook or the repo prescribes one. Left at
`score > 0`.

### Change I made this round — the `Keep reading` heading

**Finding (MED, tabRow n/a — side effect of the tab 01 related-posts module).**
The module rendered `<h2>Keep reading</h2>` on all 26 blog post pages, putting a
boilerplate label into the heading outline.
`QUESTIONS-FOR-JESSICA.md` line 106 records the correction as made and
verifier-confirmed, but it is committed on `seo-phase-4-metadata-headings`
onward, not on PR #47.

Ported that correction onto this branch, **byte-identical** to the form phase-4
already committed, so the two branches carry the same text in that region:

```diff
-              <Styled.Related>
-                <h2>Keep reading</h2>
+              <Styled.Related aria-label="Keep reading">
+                <Styled.RelatedTitle>Keep reading</Styled.RelatedTitle>
```

and the matching style move — `Styled.RelatedTitle` inserted between
`Styled.ImageWrapper` and `Styled.Related`, carrying the exact declarations the
`h2 { … }` block inside `Styled.Related` used to hold:

```js
Styled.RelatedTitle = styled.div((props) => {
  const t = props.theme;
  return css`
    label: BlogPost_RelatedTitle;
    ${[t.text.bold, t.text.xl]};
    line-height: 1.3;

    ${t.mq[56]} {
      ${[t.text.xxl]};
    }
  `;
});
```

Visible copy and rendered styling are unchanged; the accessible name survives on
the `aria-label`.

I did **not** port phase-4's other two heading changes (`Styled.TableOfContents`,
`Styled.SidebarTitle`). Both `<h2>`s pre-exist on `main`, neither is a side
effect of the tab 01 module, and both are phase-4's own tab 17 scope.

**Verified.** `git diff seo-phase-4-metadata-headings <working file>` now shows
**no difference at all** in the `Styled.Related` / `Styled.RelatedTitle` /
`Keep reading` region — the port is exact. The file parses clean under the repo's
own `@babel/parser` (`sourceType: module`, `jsx` plugin). `grep -n "<h2"` on the
file returns three hits: line 246 (ToC label, pre-existing on `main`), line 265
(the content-heading renderer, which is the outline that should exist), line 313
(sidebar CTA, pre-existing on `main`). The `Keep reading` `<h2>` is gone.

No `next build` was run: `web/` is one working tree shared with the concurrently
running phase-3 through phase-6 agents, and `next build` fails in this
environment on `./images/clt.jpg` in the untouched `pages/about.js` (a
node-20/Next-12 squoosh wasm issue, unrelated to this diff).

### Not done

1. **HIGH, tab 01 row A11 — the `relatedTo()` rewrite is on no branch.** Still
   true. The content is correct in the working tree of
   `seo-phase-1-2-deorphan-crawl` and I verified it against the live corpus
   above, but my instructions for this round are explicit: do not commit, do not
   push. Only a commit makes this row true on PR #47. It needs the orchestrator
   or Jessica to commit `web/pages/blog/[slug].js` to
   `seo-phase-1-2-deorphan-crawl`. Note for whoever does: all four of
   `seo-phase-3-redirects-canonicals`, `seo-phase-4-metadata-headings`,
   `seo-phase-5-structured-data` and `seo-phase-6-images-links-headers` contain
   `6229f91`, so a new commit here lands beneath a stack that already diverged in
   this same file.
2. **The `Keep reading` side effect is still absent from `SEO-CHANGELOG.md`.**
   That file is not mine this round. Another agent is editing it in this same
   working tree.
3. **The `refresh` half of tab 01 rows A7-A16**, and every row-specific extra —
   `add downloadable template` (A8), `formula & benchmark blocks for AEO` (A9),
   `fold into hiring-ops cluster` (A12), `base for interview-bias guide` (A15).
   All are Sanity `blogPost` content, not code. This file cannot make them true.
4. **Tab 01 row A16's link "from /features/jobboard"** — that is
   `web/pages/features/jobboard.js`, done this round by another agent (see its
   section above), not by me.

### Addendum — two more stale claims, found during the same pass

`git status --short` at the end of my work showed `web/pages/features/jobboard.js` modified by a concurrent agent. The diff adds a `<Section thin>` with `<h2>Keep reading</h2>`, a `<Link href="/blog/best-job-board-software">` with the link text "Best Job Board Software to Improve your Hiring Process", a one-sentence description, and a new `Styled.Related` block. That is tab 01 row 16's `/features/jobboard` half.

It falsifies two more verification claims in my file, same defect class as the finding I was sent for:

6. **"Repairs applied after the workflow" → "Not repaired, raised with Jessica instead"** said the `/features/jobboard` half "means writing new visible marketing copy on a live feature page, which is her call, not a silent fix." That copy has now been written by an agent. Annotated with what was added, that it is uncommitted and absent from `6229f91` and PR #47, and that it needs her approval before it ships. Not reverted — reverting another agent's in-flight work is not this file's job.

7. **Verifier finding Phase 1 item 2, MED 3** said the half "is not done by anything on this branch" and cited `git status --short` showing only five files. True of `6229f91` and of the build on disk, false of the working tree. Annotated in place, verbatim text preserved.

Both annotations pin the original statement to `6229f91` rather than rewriting it, matching how round 1 handled the concurrent `relatedTo()` rewrite.
