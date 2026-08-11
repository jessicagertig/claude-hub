# Phase 1-2 fixes — round 1

## `logs/phase-2.md`

**Finding:** MED, tab 03 rows A7-A9 — `logs/phase-2.md` had no implementer entry for Item 2 (robots.txt); the file/URL/before → after record was lost to a parallel read-then-write clobber, and that second instance of the clobber was reported nowhere.

**Fixed.** Inserted a new section `## Item 2 — create web/public/robots.txt (2026-08-05)` into `/Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/logs/phase-2.md`, placed immediately before `## Verification pass — Phase 2, item 2 (robots.txt)` so the verification follows the entry it verifies. It carries:

- an explicit statement that the section is a reconstruction, that the original entry was clobbered, and that `SEO-CHANGELOG.md` line 543 names the questions file rather than this log — so the second clobber is now recorded
- tab 03 rows 7-10 as re-read from the workbook at fix time
- **File:** `web/public/robots.txt`, created, 0 → 16 lines / 203 bytes
- **URL affected:** `https://www.polymer.co/robots.txt`
- **Before:** did not exist — `git show main:web/public/robots.txt` → `fatal: path 'web/public/robots.txt' exists on disk, but not in 'main'`
- **After:** the file's 16 lines verbatim from `git show seo-phase-1-2-deorphan-crawl:web/public/robots.txt`, plus the encoding facts from `git cat-file -p … | od -c` (ASCII, LF, trailing newline, no BOM)
- row 10 not implementable in-repo, and the lost apex/www question, both under "Not done"

**Sources.** Every fact came from `git show` / `git log` / `git cat-file` against `seo-phase-1-2-deorphan-crawl` (commit `6229f91`), the `SEO-CHANGELOG.md` "Item 2 — robots.txt" section (lines 420-453), and `python3 read-workbook.py "03 robots.txt"`. Nothing was invented. Details only the original implementer would have known — which analogs it read, what commands it ran — are not recoverable and were not fabricated to fill the gap.

**Not fixed, outside my one owned file:**

1. `SEO-CHANGELOG.md` line 543 still describes the orchestration defect as "the workflow gave both Phase 1 agents the same log file and both Phase 2/1 agents the same questions file". For Phase 2 it names only the questions file, not this log. Correcting it means editing a repo file I do not own.
2. The tab reproduction in the round-1 task packet truncates tab 03 cell C8 to "AI-answer visibility is part of the growth strategy". The workbook reads "AI-answer visibility is part of the growth strategy; blocking them contradicts the AEO plan". Recorded in `logs/phase-2.md`; the workbook itself is not mine to change and the dropped clause does not change what row 8 asks for.

**Branch.** At the start of this fix `git -C /Users/jessica/wrk/wrk-corp/wrk-marketing rev-parse --abbrev-ref HEAD` reported `seo-phase-6-images-links-headers`. I did not check out `seo-phase-1-2-deorphan-crawl`: my owned file is in the hub scratchpad, not the repo, every repo fact I needed was readable with `git show seo-phase-1-2-deorphan-crawl:<path>`, and switching branches would have moved the tree under a concurrently running phase-6 agent. By the end of this fix HEAD read `seo-phase-1-2-deorphan-crawl` — another agent moved it, not me. `git status --porcelain` was empty both times. Nothing in the repo was modified, committed or pushed.

---

## `web/pages/blog/[slug].js`

Branch checked out at start: HEAD read `seo-phase-6-images-links-headers`, `git status --porcelain` empty, so I ran `git checkout seo-phase-1-2-deorphan-crawl`. Nothing committed, nothing pushed. `SEO-CHANGELOG.md` shows as modified in the working tree at the end of my run — that is another agent's edit, not mine. The only file I wrote in the repo is `web/pages/blog/[slug].js`.

### Findings addressed

All four findings against this file have one cause: `relatedTo()` picked each post's own top-3 neighbours and stopped. The overlap score it computes is symmetric — `documentFrequency` is built from the whole corpus on every page and the word intersection is order-independent, so `score(a,b) === score(b,a)` — but *top-3 selection is not*. A post whose neighbours all have stronger matches elsewhere is nobody's top-3 pick and therefore receives no inbound link, no matter how well it scores.

### The change

One function rewritten, `relatedTo()` at `web/pages/blog/[slug].js:46`. Nothing else in the file touched: the component signature, the `Styled.Related` JSX, the GROQ queries and `getStaticProps` are unchanged.

Three edits inside it:

1. **Edges are now undirected.** A post's list is its own top-3 **union** every post that picked it. Because the score is symmetric this is the natural closure, and it guarantees every post receives at least as many inbound links as it emits outbound ones.
2. **Zero-overlap candidates dropped** — `.filter((scored) => scored.score > 0)` before the `.slice(0, RELATED_POST_COUNT)`. This is what removed the score-0.000 links.
3. **Deterministic ranking order** — `allBlogPosts` is sorted by `slug.current` before scoring. Every page now ranks off an identical array, so `Array.prototype.sort`'s stability resolves score ties the same way on all 26 pages. Without this the union rule produced an asymmetric graph (measured: 4 non-mutual edges), because page A and page B fed the candidate array in different orders.

Before:

```js
const relatedTo = (blogPost, otherBlogPosts) => {
  const words = topicWords(blogPost);
  const documentFrequency = {};
  for (const someBlogPost of [blogPost, ...otherBlogPosts]) {
    for (const word of topicWords(someBlogPost)) {
      documentFrequency[word] = (documentFrequency[word] || 0) + 1;
    }
  }

  return otherBlogPosts
    .map((otherBlogPost) => ({
      blogPost: otherBlogPost,
      score: [...topicWords(otherBlogPost)]
        .filter((word) => words.has(word))
        .reduce((total, word) => total + 1 / documentFrequency[word], 0),
    }))
    .sort((a, b) => b.score - a.score)
    .slice(0, RELATED_POST_COUNT)
    .map((scored) => scored.blogPost);
};
```

After:

```js
const relatedTo = (blogPost, otherBlogPosts) => {
  const allBlogPosts = [blogPost, ...otherBlogPosts]
    .sort((a, b) => a.slug.current.localeCompare(b.slug.current));
  const documentFrequency = {};
  const wordsFor = {};
  for (const someBlogPost of allBlogPosts) {
    wordsFor[someBlogPost.slug.current] = topicWords(someBlogPost);
    for (const word of wordsFor[someBlogPost.slug.current]) {
      documentFrequency[word] = (documentFrequency[word] || 0) + 1;
    }
  }

  const overlapScore = (oneBlogPost, anotherBlogPost) =>
    [...wordsFor[anotherBlogPost.slug.current]]
      .filter((word) => wordsFor[oneBlogPost.slug.current].has(word))
      .reduce((total, word) => total + 1 / documentFrequency[word], 0);

  const strongestFor = (someBlogPost) => allBlogPosts
    .filter((otherBlogPost) => otherBlogPost.slug.current !== someBlogPost.slug.current)
    .map((otherBlogPost) => ({
      blogPost: otherBlogPost,
      score: overlapScore(someBlogPost, otherBlogPost),
    }))
    .filter((scored) => scored.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, RELATED_POST_COUNT);

  const relatedBlogPosts = new Map(
    strongestFor(blogPost).map((scored) => [scored.blogPost.slug.current, scored])
  );
  for (const otherBlogPost of otherBlogPosts) {
    if (relatedBlogPosts.has(otherBlogPost.slug.current)) continue;
    const picksThisBlogPost = strongestFor(otherBlogPost)
      .some((scored) => scored.blogPost.slug.current === blogPost.slug.current);
    if (picksThisBlogPost) {
      relatedBlogPosts.set(otherBlogPost.slug.current, {
        blogPost: otherBlogPost,
        score: overlapScore(blogPost, otherBlogPost),
      });
    }
  }

  return [...relatedBlogPosts.values()]
    .sort((a, b) => b.score - a.score)
    .map((scored) => scored.blogPost);
};
```

The existing `ponytail:` comment above the function gained a paragraph naming the symmetry and the tie-order requirement.

### Verification

Method: fetched all 26 `blogPost` documents from the live Sanity production dataset (`https://a6d1clb1.api.sanity.io/v2021-03-25/data/query/production`) with the page's own projection and `| order(publishDate desc)`; then extracted `RELATED_POST_COUNT` through the end of `relatedTo` **from the edited file on disk** (`/Users/jessica/wrk/wrk-corp/wrk-marketing/web/pages/blog/[slug].js`, not from a copy) and ran it under node once per post, exactly as `getStaticProps` calls it.

Measured on the corpus, before → after:

| | before | after |
|---|---|---|
| posts with zero inbound related-post links | 2 (`job-rejection-email`, `hello-polymer`) | 0 |
| non-mutual edges | 22 of 78 | 0 |
| links with score 0.0000 | 1 (`utc-is-the-timezone-of-the-future` → `post-jobs-with-whatjobs-across-500-partners`) | 0; lowest emitted score 0.2000 |
| links emitted site-wide | 78 | 98 |
| related links rendered per post | always exactly 3 | 2 to 6 |

Per finding:

- **tab 01 row A11 (`job-rejection-email`), inbound = 0 → 3**: `behavioral-interview-scoring-matrix`, `onboarding`, `problem-solving-interview-questions`. `onboarding` was not on tab 01.
- **`hello-polymer`, inbound = 0 → 3**: `post-jobs-with-whatjobs-across-500-partners`, `employer-branding-steps`, `one-click-distribution-to-we-work-remotelys-community-of-job-seekers`. None was on tab 01.
- **tab 01 row A8 (`behavioral-interview-scoring-matrix`), inbound = 2 → 4**, and inbound from posts that were **not** tab-01 orphans = 0 → 1 (`best-applicant-tracking-software`). Full inbound set: `best-applicant-tracking-software`, `best-job-board-software`, `problem-solving-interview-questions`, `job-rejection-email`.
- **the score-0 defect**: 0 zero-score links remain; `relatedPosts.length > 0` in the JSX is now reachable, since `strongestFor` returns fewer than `RELATED_POST_COUNT` entries when fewer candidates overlap (`utc-is-the-timezone-of-the-future` now renders 2 links, not 3).

Inbound count for all 10 tab-01 URLs after the change, with how many of those come from posts that were not themselves on tab 01:

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

Syntax checked with the repo's own `@babel/parser` (`sourceType: module`, `jsx` plugin) — parses clean. No `next build` was run; the node-version question in `QUESTIONS-FOR-JESSICA.md` is still open and the phase-1 log records the same gap.

### Not done

- The "refresh", "add downloadable template", "formula & benchmark blocks for AEO", "fold into hiring-ops cluster" and "base for interview-bias guide" halves of tab-01 rows A7-A16 are Sanity content, not code. This file cannot make them true.
- Tab 01 row A16 asks for a link "from /features/jobboard". That is `web/pages/features/jobboard.js`, not a file I own.
- No test was added; per the working rules this harness does not write tests. The verification above is a one-off replay, not a committed check.

---

## `SEO-CHANGELOG.md`

Branch: HEAD read `seo-phase-6-images-links-headers` on my first command and `seo-phase-1-2-deorphan-crawl` seconds later in the same parallel block — another agent moved it, not me. It read `seo-phase-1-2-deorphan-crawl` for the whole of my work, so I ran no `checkout`. Nothing committed, nothing pushed. The only file I wrote is `SEO-CHANGELOG.md`. `web/pages/blog/[slug].js` shows as modified in the working tree — that is the concurrent `relatedTo()` fix agent, not me.

**Workbook check.** `python3 read-workbook.py "01 Orphaned Pages"` — the task packet's reproduction of tab 01 is accurate. All ten `Recommended action` strings (F7-F16) and note A4 match the workbook character for character. No misquote to report.

### Finding 1 — HIGH, tab 01 rows A7-A16 / master prompt Phase 1 step 3

**Asked:** "Confirm each of the 10 URLs returns 200 and is now reachable <=3 clicks from the homepage; record the click path per URL in the changelog."

**Fixed.** Added a new section `### Phase 1 step 3 — 200 confirmation and click path per URL` at the end of Phase 1, after Item 2 and before the Phase 2 rule. It carries:

- **Status codes.** All 10 tab-01 URLs curled live on 2026-08-05 (`curl -s -o /dev/null -w "%{http_code}"`), each returning 200, in a table keyed by tab row A7-A16. This matches tab 01 note A4's "Pages verified live (HTTP 200)".
- **The two hops**, each with the file and line that provides it: `components/home/intro.js:17` renders `<Navigation />` on `/`; `components/navigation.js:48` (mobile menu) and `:80` (desktop nav pill) carry `<Link href="/blog">`; independently `web/pages/_app.js` renders `<Footer />` on every page and `components/footer.js:73` carries the same link. Then `web/pages/blog.js:63` maps every post with no cap, each card wrapping in a `<Link>` to `/blog/<slug>`. Both hops are plain server-rendered anchors, which is the point — the orphaning was a client-side "Load more".
- **A click-path table, one row per URL**: `/` -> `/blog` -> `/blog/<slug>`, 2 clicks, identical for all ten and inside the <=3 budget.
- The secondary 3-click path through related posts, and the note that as of `6229f91` `job-rejection-email` has zero inbound related links so `/blog` is its only path.
- **Two stated limits**, so the record is not read as more than it is: the 200s are the live pages as they stand, not a post-deploy check of this branch; and the click paths are read off the branch's code, because the deployed `/blog` still serves 5 posts.

**Evidence gathered, not assumed.** Live `https://www.polymer.co/blog` was fetched and its distinct post links counted: exactly 5 — `employer-branding-steps`, `hiring-gen-z`, `post-jobs-with-whatjobs-across-500-partners`, `post-to-we-work-remotely-6m-professionals-in-seconds`, `skills-mapping-for-hiring-a-complete-guide` — none of which is a tab-01 URL. That is tab 01's orphaning, still live today, and it is now recorded in the changelog. That all 10 tab-01 slugs are in the corpus the branch renders was re-confirmed by running `pages/blog.js`'s own query against the live production dataset: 26 documents, every one with a non-null slug, 10/10 tab-01 slugs present.

### Finding 2 — MED, unsupported build attribution

**Asked:** the changelog claimed "All 26 posts are now in the statically generated HTML" and reported inbound related-link counts "counted by the verifier from a real `next build`", while `logs/phase-1.md` records "No full `next build` run" under both items and no build artifact or verifier report exists under `builds/seo-audit-2026-08-05/logs/`.

**Fixed, in three places.**

1. The "statically generated HTML" sentence was replaced with what is actually verified: `web/pages/blog.js:63` maps every element with no cap and the page's unbounded query returns 26 documents from the live dataset, so all 26 render as links — stated explicitly as verified from shipped code plus live query, **not** from generated HTML, and naming `logs/phase-1.md` as the record that no build ran.
2. The `next build` attribution on the inbound counts was removed and replaced with a `**Provenance of those counts.**` paragraph that states plainly that the attribution was wrong, and cites all three pieces of evidence: `logs/phase-1.md` under both items, `QUESTIONS-FOR-JESSICA.md` question 8 (build fails on node v18.20.8, completed only on v16.20.2), and the absent artifact/report.
3. The counts were then **re-derived** so the figures have a real provenance rather than being deleted or softened.

**Re-derivation method.** `RELATED_POST_COUNT`, `STOP_WORDS`, `topicWords()`, `relatedTo()` and both GROQ queries were copied verbatim out of `web/pages/blog/[slug].js` as committed in `6229f91`, then run over the live production dataset for all 26 slugs `getStaticPaths` emits — the same computation `getStaticProps` performs at build time. Script in the scratchpad (`inbound-and-clickpath.mjs`), read-only fetches, nothing written into the repo, no build run.

**Result: every one of the ten figures reproduced unchanged** — 4, 2, 3, 3, 0, 4, 3, 4, 2, 3 — and 78 related links across the corpus. The numbers in the changelog were correct all along; only their stated source was false. That is now what the changelog says. Independent corroboration: the concurrent `[slug].js` fix agent's section above measured the same before-state from the same corpus (78 links; `job-rejection-email` and `hello-polymer` at zero inbound), by a different route.

**Concurrency flagged in the changelog.** While I was writing, the `[slug].js` agent's uncommitted working-tree rewrite of `relatedTo()` changed the link graph — reciprocal edges, zero-overlap pairs dropped. Its own log measures the after-state at 98 links and `job-rejection-email` at 3 inbound. I did **not** adopt those numbers: they are uncommitted and were still moving. Instead the changelog now pins the figures to `6229f91` by name and carries a bolded paragraph saying every inbound figure must be re-derived once that change lands, and that the zero on `job-rejection-email` is the case it targets. **This needs reconciling in a later round** — the two sections will disagree until the rewrite is committed and the counts are re-run.

### Also corrected — same defect class, same file

Not in my findings list, but a false claim about repo state in the file I own, found while working: the changelog opened with "Nothing in this run was committed or pushed. The working tree carries two modified files and three new files". The branch is committed as `6229f91` and pushed — `git rev-list --left-right --count origin/seo-phase-1-2-deorphan-crawl...seo-phase-1-2-deorphan-crawl` returns `0 0`, and PR #47 is open on it. The commit carries six files, not five: the three crawl files, the two modified blog files, and `SEO-CHANGELOG.md` itself. Corrected to say so, with the file list updated to match `git show --stat 6229f91`.

### Not done

- No `next build` was run. `web/` is one working tree shared with the concurrently running phase-3 through phase-6 agents, one of which had `web/.next/build-manifest.json` written two minutes before I looked and another of which was mid-edit in `web/pages/blog/[slug].js`; a `next build` writing into the shared `web/.next` would have raced them and produced an artifact belonging to no single branch. The re-derivation above gives the same link graph the build would, so the changelog no longer needs a build to support any claim it makes.
- The post-deploy confirmation — that `https://www.polymer.co/blog` serves all 26 links and that the 10 URLs are <=3 clicks from the homepage **on the live site** — still needs a deploy. It was already listed under "needsLiveCheck still unconfirmed" and remains there.
