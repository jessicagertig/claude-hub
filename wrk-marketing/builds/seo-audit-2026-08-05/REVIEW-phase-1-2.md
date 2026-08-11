# Phase 1+2 review — `seo-phase-1-2-deorphan-crawl` (PR #47)

Branch tip `6229f91`, identical to `origin/seo-phase-1-2-deorphan-crawl`. Six files in the PR:
`SEO-CHANGELOG.md`, `web/pages/blog.js`, `web/pages/blog/[slug].js`, `web/pages/sitemap.xml.js`,
`web/public/llms.txt`, `web/public/robots.txt`

Tabs checked against the workbook with `read-workbook.py`: 01 Orphaned Pages, 02 XML Sitemap,
03 robots.txt, 08 llms.txt. Live corpus: Sanity `production`, projectId `a6d1clb1`, 26 `blogPost`
documents, every one carrying `slug`, `editorialTitle` and `metaDescription`.

---

## 1. Still not done, and why

### Every fix from rounds 1–4 is in the working tree and none of it is on the branch

`git status --short` in `/Users/jessica/wrk/wrk-corp/wrk-marketing` reports five modified,
uncommitted files:

```
 M SEO-CHANGELOG.md
 M web/pages/blog/[slug].js
 M web/pages/features/jobboard.js
 M web/pages/sitemap.xml.js
 M web/public/llms.txt
```

`git diff main...seo-phase-1-2-deorphan-crawl --stat` lists six files and does not include
`web/pages/features/jobboard.js` at all. The branch tip and `origin` are both `6229f91`. Every
repair listed in section 3 below exists only on Jessica's disk. Merging PR #47 as it stands ships
none of them.

The uncommitted work, verified by reading each diff:

- `web/pages/blog/[slug].js` — `relatedTo` rewritten to a symmetric graph (`strongestFor`,
  `overlapScore`, `wordsFor` cache, `Map` merge), plus `.filter((scored) => scored.score > 0)`,
  plus `<h2>Keep reading</h2>` replaced by `Styled.RelatedTitle` with `aria-label` on the aside
- `web/pages/features/jobboard.js` — a `<Section thin>` "Keep reading" block linking
  `/blog/best-job-board-software`, plus a new `getStaticProps`
- `web/pages/sitemap.xml.js` — `Cache-Control: public, s-maxage=3600, stale-while-revalidate=86400`;
  the combined object query split into `postsQuery`/`logsQuery` ordered by `publishDate`/`date`;
  `"slug": slug.current` restored to whole `slug`; a `latestUpdatedAt` helper; the header comment
  amended to record the legal-services mismatch
- `web/public/llms.txt` — the three price bullets reordered to annual-first
- `SEO-CHANGELOG.md` — 155 added lines correcting three false claims and adding four sections

I replayed both versions of `relatedTo` over the live 26-post corpus. The difference is real:

| | committed `6229f91` | working tree |
|---|---|---|
| emitted related links | 78 | 98 |
| posts with zero inbound related links | 2 (`job-rejection-email`, `hello-polymer`) | 0 |
| `job-rejection-email` inbound | 0 | 3 |
| `behavioral-interview-scoring-matrix` inbound | 2 | 4 |

Nothing on the branch is live yet. `https://www.polymer.co/robots.txt`, `/sitemap.xml` and
`/llms.txt` all return 404 today; `https://polymer.co/robots.txt` returns 308 to www.

### Tab 01 — Orphaned Pages

**Tab 01 row A16 asked for:** "Link from /features/jobboard + blog index; refresh".
**Status: NOT DONE** (blog-index half done).
**Reason:** `git show seo-phase-1-2-deorphan-crawl:web/pages/features/jobboard.js` contains zero
`/blog/` hrefs. The file is not in the PR's six-file diff. The link exists only as an uncommitted
working-tree modification.

**Tab 01 rows A7, A8, A9, A10, A13, A14, A16 asked for:** "refresh". **Row A11 asked for:**
"light refresh".
**Status: NOT DONE.**
**Reason:** Post bodies are Portable Text in Sanity `blogPost` documents; the branch changes no
Sanity content. Every one of the ten documents carries its original `_updatedAt`, from
2022-08-09 to 2023-08-08. The committed `SEO-CHANGELOG.md` uses the word "refresh" once, inside a
quoted verifier finding about row A16, and lists the refresh deferral in neither its "Open items"
nor its "Not repaired, raised with Jessica instead" section.

**Tab 01 row A8 asked for:** "add downloadable template".
**Status: NOT DONE.**
**Reason:** The branch adds two files under `web/public`: `robots.txt` and `llms.txt`. No asset, no
link to an asset, no code path for one.

**Tab 01 row A9 asked for:** "formula & benchmark blocks for AEO".
**Status: NOT DONE.**
**Reason:** The `employee-turnover` document's content array is unchanged, and
`studio/schemas/blogPost.js` block types remain `block`, `toc`, `image`, `quote`, `table`, `youtube`.

**Tab 01 row A12 asked for:** "fold into hiring-ops cluster".
**Status: NOT DONE.**
**Reason:** `studio/schemas/blogPost.js` has no tag, category or reference field and the branch adds
none. No hub or cluster page exists under `web/pages`. The related-posts module ranks by title and
meta-description word overlap.

**Tab 01 row A15 asked for:** "base for interview-bias guide".
**Status: NOT DONE** (internal-links half done).
**Reason:** No such route exists under `web/pages` and no such `blogPost` document exists in the
production dataset, which holds the same 26 documents it held before.

**Tab 01 row A11 asked for:** "Link".
**Status: NOT DONE on the branch.**
**Reason:** On `6229f91`, `/blog/job-rejection-email` receives zero inbound related-post links,
confirmed by replay over the live corpus. Its only internal link is the `/blog` index card. The
symmetric rewrite that raises it to 3 is uncommitted.

**Master prompt Phase 1 step 3 asked for:** "Confirm each of the 10 URLs returns 200 and is now
reachable ≤3 clicks from the homepage; record the click path per URL in the changelog".
**Status: NOT DONE.**
**Reason:** `git show seo-phase-1-2-deorphan-crawl:SEO-CHANGELOG.md | grep -i "click path"` returns
nothing. The section exists only in the uncommitted working-tree copy.

### Tab 02 — XML Sitemap

**Tab 02 row A9 asked for:** "Submit sitemap; monitor Index Coverage for the 10 currently-orphaned
posts".
**Status: NOT DONE.**
**Reason:** Both actions happen in Google Search Console, outside the repository. Nothing on the
branch performs or schedules either. It appears once in `SEO-CHANGELOG.md` under "needsLiveCheck
still unconfirmed" and is not in `QUESTIONS-FOR-JESSICA.md` — grep for "Search Console" returns 0.

**Tab 02 row A7 asked for:** "emitting all marketing routes + every Sanity blog post with
lastModified from CMS timestamps".
**Status: DEFECT.**
**Reason:** `web/pages/sitemap.xml.js` reads Sanity per request through `getServerSideProps`, while
`web/pages/blog/[slug].js` uses `getStaticPaths` with `fallback: false` and the string `revalidate`
occurs nowhere under `web/`. A `blogPost` published after the last deploy is emitted in
`/sitemap.xml` while `/blog/<slug>` returns 404 until a rebuild. The same split lets `<lastmod>` on
`/blog` and `/changelog` report a date newer than the deployed HTML. All 26 current posts are in the
built set, so no emitted URL 404s today. Whether Sanity fires a Vercel deploy on publish is not
determinable from the repo: no `vercel.json` under `web/`, no `.vercel` directory. The working-tree
`Cache-Control` header does not change this.

**Tab 02 row A7 asked for:** "emitting all marketing routes".
**Status: DONE DIFFERENTLY.**
**Reason:** The sitemap emits `https://www.polymer.co/applicant-tracking-for-legal-services`, while
`web/pages/industries/applicant-tracking-for-legal-services.js` line 90 declares
`pathname="industries/applicant-tracking-for-legal-services"`, so that page's `og:url` is
`https://www.polymer.co/industries/applicant-tracking-for-legal-services`. Its six siblings declare
the short top-level form. Both URL forms return 200 because `next.config.js` uses rewrites, and
`web/components/seo.js` emits no `<link rel="canonical">`. The working-tree change amends the file's
comment; the URL and the page's `pathname` still disagree.

**Tab 02 row A7 asked for:** "with lastModified from CMS timestamps".
**Status: DONE INCOMPLETELY.**
**Reason:** 16 of the 18 static routes carry no `<lastmod>`. Only `/blog`, `/changelog` and the 26
blog posts get one.

**Tab 02 row A8 asked for:** "www host only, absolute HTTPS URLs".
**Status: DONE DIFFERENTLY.**
**Reason:** All 44 `<loc>` values are absolute `https://www.polymer.co` URLs. The homepage entry is
`https://www.polymer.co` with no trailing slash; tab 04 row 7 prescribes `https://www.polymer.co/`
with one, and `web/components/seo.js` line 12 carries the comment "No trailing slash allowed!".

### Tab 03 — robots.txt

**Tab 03 row A10 asked for:** "Host handling" | "serve at both apex and www" | "Apex 308s to www;
ensure robots.txt resolves pre-redirect too".
**Status: NOT DONE.**
**Reason:** `web/next.config.js` carries one redirect (`/climate`) and seven industry rewrites, no
host-conditional rule, no `basePath`, no `assetPrefix`. There is no `vercel.json` under `web/` — the
only one in the repo is `studio/vercel.json`. No middleware file exists. Whether
`polymer.co/robots.txt` answers 200 or 308s to www is decided by the Vercel domain configuration for
the apex, applied at the edge before the Next application runs. Confirmed live today:
`curl -sI https://polymer.co/robots.txt` returns 308 with `location: https://www.polymer.co/robots.txt`.

Rows A7, A8 and A9 are **DONE**.

### Tab 08 — llms.txt

**Tab 08 row A9 asked for:** "Starter $124/mo, Growth $233/mo, Scale $415/mo, 14-day free trial".
**Status: DONE DIFFERENTLY.**
**Reason:** `web/public/llms.txt` states two rates per plan — "Starter, $124/month billed annually or
$149/month billed monthly", and the same shape for Growth ($233/$279) and Scale ($415/$499). The tab
lists one rate per plan and does not contain $149, $279 or $499. `web/pages/pricing.js` lines 25–27
define `annual: { starter: 124, growth: 233, scale: 415 }` and
`monthly: { starter: 149, growth: 279, scale: 499 }`, with `isAnnual` defaulting to `true`. The
14-day free trial is present.

**Tab 08 row A9 asked for** (note C9): "Keep in sync with /pricing".
**Status: DONE INCOMPLETELY.**
**Reason:** The six figures and the per-plan limits are hardcoded in `web/public/llms.txt` with no
mechanism tying them to `web/pages/pricing.js`. The only guard is the sentence
"https://www.polymer.co/pricing is the source of truth" inside the file. Tab 08 note A4 states stale
pricing in llms.txt is worse than none.

**Tab 08 row A10 asked for:** "developer.polymer.co, help docs URL".
**Status: DONE DIFFERENTLY.**
**Reason:** The `## Docs & API` section carries four links, not two: `developer.polymer.co` and
`help.polymer.co/` as asked, plus `https://help.polymer.co/en/collections/2544541-quick-start-guide`
and `https://www.polymer.co/changelog`. All four match hrefs in `web/components/footer.js`.

**Tab 08 row A9 asked for** (note A4): "keep it accurate and short".
**Status: DONE DIFFERENTLY.**
**Reason:** The `## Pricing` section carries content the row does not name: per-plan published-job,
user and Plato AI credit limits; "All features are included on every plan"; "Annual billing is 2
months free"; the `support@polymer.co` escalation line; and a preamble naming `/pricing` as the
source of truth. Each traces to `web/pages/pricing.js`.

**Tab 08 row A12 asked for:** "llms-full.txt" | "Extended page-level summaries" | "Optional second
file".
**Status: NOT DONE.**
**Reason:** `web/public/` contains `llms.txt` and `robots.txt`. No `llms-full.txt` exists.

Rows A7, A8 and A11 are **DONE**.

### Defects outside the tab rows, still standing in PR #47

- **The committed `SEO-CHANGELOG.md` carries three false statements.** Line 5: "Nothing in this run
  was committed or pushed. The working tree carries two modified files and three new files" — the
  work is commit `6229f91`, pushed, open as PR #47, carrying six files including that changelog.
  Line 87: "All 26 posts are now in the statically generated HTML". Line 317: "Inbound related-links
  counted by the verifier from a real `next build`" — `logs/phase-1.md` records "No full `next build`
  run" under both Phase 1 items. Corrections for all three exist in the working tree only.
- **`BLOCKED.md` was never created.** Master prompt rule 3 requires items that cannot be automated —
  missing permissions, environment values, editorial judgment calls — to be logged there.
  `ls /Users/jessica/wrk/wrk-corp/wrk-marketing/BLOCKED.md` returns "No such file or directory".
  Tab 03 row A10 (Vercel setting), tab 02 row A9 (Search Console access) and the tab 01 refreshes
  (editorial judgment) are one of each of the three categories the rule names. Phase 7 step 1 builds
  the final report from `BLOCKED.md`, so it will show zero blocked items.
- **`<h2>Keep reading</h2>` on all 26 blog post pages.** The related-posts module puts a boilerplate
  label into every post's heading outline. The committed `SEO-CHANGELOG.md` does not record the side
  effect. The replacement is committed on `seo-phase-4-metadata-headings` and is uncommitted here.
- **No `Cache-Control` on `/sitemap.xml`.** The committed file sets only `Content-Type` and calls
  `res.end()` inside `getServerSideProps`, so Next.js never sets its own header. Every request
  re-queries Sanity.
- **`documentFrequency` is a bare object literal.** The topic word `constructor` resolves to
  `Object.prototype.constructor`, making `(documentFrequency[word] || 0) + 1` a string and
  `1 / documentFrequency[word]` `NaN`. `/[a-z]{3,}/g` on lowercased text makes `constructor` the only
  reachable collision. No current title or meta description contains it.
- **`topicWords` interpolates unguarded.** `${blogPost.editorialTitle} ${blogPost.metaDescription}`
  contributes the literal token `undefined` for a post missing either field, shared with every other
  post missing the same field. All 26 current documents have both.
- **`SEO-CHANGELOG.md` sits at the source-repo root.** It is a 630-line agent run log citing absolute
  local paths under `/Users/jessica/claude-hub/`. Hub `CLAUDE.md` universal rule 1 states outputs go
  in the pipeline scratchpad subdir, not into the source code.
- **`web/components/section.js` line 23 reads `${t.mq[56]} {aer`.** The stray `aer` token discards the
  first declaration of that media-query block, which is where the `thin` prop's only rule lives. This
  is pre-existing on `main` and is not changed by PR #47; the uncommitted `<Section thin>` in
  `web/pages/features/jobboard.js` is a new caller of that prop.

### Misquotes in the review brief

Three cells were abridged against the workbook. None changes what any row asks for.

- Tab 02 cell B10 reads "customer job boards, separate host"; the brief gave "separate host"
- Tab 03 cell C8 reads "AI-answer visibility is part of the growth strategy; blocking them
  contradicts the AEO plan"; the brief stopped at "growth strategy"
- Tab 01 column A holds full URLs (`https://www.polymer.co/blog/problem-solving-interview-questions`);
  the brief listed them as paths

Every other cell quoted for tabs 01, 02, 03 and 08 matches the workbook.

---

## 2. Needs Jessica

**1. Tab 01 rows A7–A16, the "refresh" half and the four row-specific extras**
(row A8 downloadable template, row A9 formula & benchmark blocks, row A12 hiring-ops cluster,
row A15 interview-bias guide).
**Question:** Do you want the ten posts' content work treated as a separate engagement, outside this
branch?
*A decision. The work is editorial rewriting of your own blog posts in Sanity.*

**2. Tab 01 row A16, the /features/jobboard link.**
An agent has written a "Keep reading" block onto that page in the working tree, carrying the
`best-job-board-software` title and meta description as visible marketing copy. The committed
changelog states this half was deliberately left for you because it means new copy on a live feature
page.
**Question:** Do you approve that copy on `/features/jobboard`, and where should it sit?
*A decision. Unapproved marketing copy currently sits uncommitted on your disk.*

**3. Tab 02 row A9, Search Console.**
**Question:** Who submits `/sitemap.xml` in Search Console and monitors Index Coverage for the ten
posts, once this branch is deployed?
*Outside the repo entirely. `web/components/seo.js` carries the google-site-verification token, so a
verified property exists.*

**4. Tab 03 row A10, apex host handling.**
**Question:** Should `polymer.co/robots.txt` answer 200 instead of 308ing to www — and will you make
the Vercel domain change if so?
*Outside the repo entirely. It is a Vercel dashboard setting under Project Settings → Domains. Only
the second half — a `has: [{ type: 'host', value: 'polymer.co' }]` redirect in `web/next.config.js`
excluding `/robots.txt` — lives in this repo, and it is inert until the dashboard half is set. This
question IS now filed in `QUESTIONS-FOR-JESSICA.md` under "Phase 2, item 2 — robots.txt".*

**5. Tab 02 row A7, the sitemap/build divergence.**
**Question:** Does publishing a post in Sanity Studio trigger a Vercel deploy?
*Outside the repo — a Vercel/Sanity setting. If it does not, a newly published post sits in
`/sitemap.xml` as a 404 until someone deploys. Not filed anywhere; grep of
`QUESTIONS-FOR-JESSICA.md` for "deploy hook" and "revalidat" returns 0.*

**6. Tab 02 row A7, the legal-services URL.**
**Question:** Should `web/pages/industries/applicant-tracking-for-legal-services.js` line 90 declare
`pathname="applicant-tracking-for-legal-services"`, matching its six siblings?
*A decision. It is a one-word edit, and phase 3 has since made that line the page's canonical, so it
now decides which of the two live URLs Google consolidates on.*

**7. Tab 08 row A9, the pricing figures.**
**Question:** Should `llms.txt` state both rates as it does now, or only the annual figures the tab
lists?
*A decision about what an AI assistant quotes as Polymer's price.*

**8. Tab 08 row A12, `llms-full.txt`.**
**Question:** Do you want the optional second file, and which pages should it cover?
*A decision.*

**9. Tab 01, the blog index mechanism.**
The de-orphaning was done by deleting pagination: `POSTS_PER_PAGE`, the `visibleCount` state, the
`loadMore` handler, the `ButtonNew` import and `Styled.LoadMoreWrapper` are all removed, so `/blog`
renders all 26 posts and every future post in one list.
**Question:** Keep the full archive, or reinstate a cap as server-rendered pagination
(`/blog/page/2`) above some threshold?
*A decision about your own site's reading experience.*

**10. Tab 01 rows A7–A16, the related-posts mechanism.**
The module ranks by rarity-weighted word overlap because `studio/schemas/blogPost.js` has no
taxonomy. It is lexical, so synonyms miss — "attrition" will not match "turnover".
**Question:** Does Shawn want a `tags` array or a `relatedPosts` reference field added to the
`blogPost` schema?
*A decision for Shawn. It is a Studio schema change plus back-filling 26 documents.*

**11. Build environment.**
`web/.nvmrc` says `18.x`, `web/package.json` `engines` says `22.x`, and the only version that
completed a `next build` during this run was `16.20.2`. On 18 and 22 the build fails at
`pages/about.js` with a squoosh mozjpeg wasm URL parse error. The same failure reproduces on `main`,
so this branch neither causes nor worsens it.
**Question:** Which of the three is correct, and should `.nvmrc` and `engines` be reconciled?
*A decision. It currently blocks any agent from running a production build locally without pinning 16.*

**12. Tab 02 row A8, the homepage URL form.**
**Question:** Should the homepage be `https://www.polymer.co` or `https://www.polymer.co/`?
*A decision. Tab 04 rows 7 and 38 prescribe the trailing slash; `web/components/seo.js` line 12
computes the no-slash form and comments "No trailing slash allowed!". Switching changes the homepage
`og:url` too, so it is not a sitemap-only edit.*

---

## 3. Fixed during review

Every line below is a working-tree change. **None of it is committed and none is in PR #47.**

| Tab row | Before → after |
|---|---|
| 01 A11 | `/blog/job-rejection-email` 0 inbound related links → 3; corpus-wide posts with zero inbound 2 → 0; emitted links 78 → 98 |
| 01 A8 | `behavioral-interview-scoring-matrix` 2 inbound related links, both from tab-01 orphans → 4 |
| 01 A7 | `utc-is-the-timezone-of-the-future` → `post-jobs-with-whatjobs-across-500-partners` at score 0.000 → link removed by `.filter((scored) => scored.score > 0)` |
| 01 A7–A16 | `relatedTo` asymmetric top-3 → symmetric graph: `wordsFor` cache, `overlapScore`, `strongestFor`, `Map` merge of every post whose own top-3 includes this one |
| 01 A7–A16 | `<h2>Keep reading</h2>` on all 26 post pages → `Styled.RelatedTitle` div plus `aria-label="Keep reading"` on the aside |
| 01 A16 | `/features/jobboard` with zero `/blog/` hrefs → a `<Section thin>` "Keep reading" block linking `/blog/best-job-board-software`, plus `getStaticProps` (copy unapproved — see section 2 item 2) |
| 02 A7 | `/sitemap.xml` with no `Cache-Control` → `public, s-maxage=3600, stale-while-revalidate=86400` |
| 02 A7 | one combined object GROQ query → separate `postsQuery`/`logsQuery` ordered by `publishDate`/`date`, matching every other query in the repo |
| 02 A7 | `"slug": slug.current` alias → whole `slug`, so `post.slug.current` reads the same shape as `blog.js` and `[slug].js` |
| 02 A7 | `lastmod` taken from the first row of an `_updatedAt desc` query → a `latestUpdatedAt` helper, since the queries now order by content date |
| 02 A7 | header comment claiming all routes match their page's `pathname` → comment naming `applicant-tracking-for-legal-services` as the exception |
| 08 A9 | `llms.txt` "Starter, $149/month billed monthly or $124/month billed annually" → "$124/month billed annually or $149/month billed monthly", matching the order `/pricing` shows by default |
| — | `SEO-CHANGELOG.md` three false claims (nothing committed / statically generated HTML / counted from a real `next build`) → corrected, with the provenance of the link counts restated |
| — | `SEO-CHANGELOG.md` missing the master prompt's Phase 1 step 3 record → "200 confirmation and click path per URL" section added |

One repair from an earlier round **is** committed in `6229f91`: `llms.txt` originally presented the
annual rate as the flat monthly price; the committed file states both rates.

One repair landed outside the repo: the tab 03 row A10 apex/www question, reported missing through
round 4, is now present in `QUESTIONS-FOR-JESSICA.md` under "Phase 2, item 2 — robots.txt".

---

Four rounds ran. Every angle — tab-01, tab-02, tab-03, tab-08, code-correctness, conventions,
deferrals — returned in all four rounds; no reviewer failed to return. The review did not converge.
Highest severity remaining is **HIGH**; there is no BLOCKER. The single most consequential item is
structural rather than any one tab row: PR #47 contains none of the fixes above, and the branch as
pushed still ships `job-rejection-email` with zero inbound related links, `/features/jobboard` with
no link to `best-job-board-software`, and a changelog stating the work was never committed.
