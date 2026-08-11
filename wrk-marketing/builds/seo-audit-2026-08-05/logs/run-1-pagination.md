# Run 1 — URL-based blog pagination

Branch `seo-phase-1-2-deorphan-crawl`, repo `/Users/jessica/wrk/wrk-corp/wrk-marketing`. Nothing committed, nothing pushed.

## What shipped

`/blog` is page one and still holds the first five posts. Pages two and up are their own routes at `/blog/page/2` … `/blog/page/6`, statically generated, five posts each, with previous / next / numbered anchors in the HTML. 26 posts, 6 pages.

## Route shape and why

`/blog/page/2`, from `web/pages/blog/page/[page].js`.

`/blog/2` was not available. `web/pages/blog/[slug].js` already owns every single-segment URL under `/blog`, and Next cannot hold two dynamic files at one level — `/blog/2` and a post slugged `2` would be the same route. A `page` segment moves pagination to a depth `[slug].js` cannot reach, so the two never compete.

The name matches how the repo already builds URLs: directories are named for the literal segment they serve (`web/pages/features/jobboard.js` → `/features/jobboard`, `web/pages/industries/…`), and bracket files carry the variable part (`[slug].js`). `web/pages/blog/page/[page].js` is that same pair. It is also the shape crawlers see on most blog platforms, so it needs no explaining to Google.

`/blog` keeps its backlinks, its `navigation.js` and `footer.js` links, and its title `Blog | Polymer` unchanged.

## Files

| File | Change |
|---|---|
| `web/lib/blog.js` | New. `POSTS_PER_PAGE = 5`, `blogPostsQuery`, `blogPageCount`, `blogPageNumbers`, `blogPagePathname` |
| `web/components/blogIndex.js` | New. The `BlogPost` card, the `Pagination` nav, and the `Styled` block moved out of `blog.js` |
| `web/pages/blog.js` | Page one — SEO plus `<BlogIndex page={1}>`, slices the first five posts |
| `web/pages/blog/page/[page].js` | New. Pages two and up |
| `web/pages/sitemap.xml.js` | Emits `/blog/page/2` … `/blog/page/6` |
| `web/next.config.js` | Two redirects to `/blog` |

Two pages have to render the same list, so the card and its styling moved to `web/components/blogIndex.js` — a move, not a rewrite. Every `label:` is unchanged (`Blog_Post`, `Blog_Title`, …) so the move reads as a move in review. Importing `pages/blog.js` from the other page file would have avoided the new file but Next treats that as a page importing a page and objects to the `getStaticProps` export coming with it.

`web/lib/blog.js` exists because four places have to agree that page one is `/blog` and that a page holds five posts: both page files, the pagination nav, and the sitemap. It has no React imports, which keeps `sitemap.xml.js` free of the emotion and `next/image` graph.

## Pagination controls

Real anchors. `<Link passHref>` wrapping a `styled.a`, the same idiom `blog.js` already uses for the post cards. No click handler anywhere in the file. Previous carries `rel="prev"`, next carries `rel="next"`, the current number carries `aria-current="page"` and is styled off `&[aria-current="page"]` rather than a prop, so one emotion class serves every link.

`Styled.Pagination` takes the spacing the deleted `Styled.LoadMoreWrapper` had — `t.mt(12), t.mb(6)`, centered flex, and `t.mt(15), t.mb(10)` at `t.mq[56]`. `Styled.PageLink` is new. `Styled.Post`'s `&:last-of-type { mb(0) }` still lands on the last post, since the nav is a `<nav>` and not an `<a>`, so the gap below the list is unchanged.

Every page number is listed, no ellipsis. Marked with a `ponytail:` comment naming the ceiling — it reads fine to roughly fifteen pages, which at five posts a page is 75 posts away.

## Edge cases

| URL | Result | Mechanism |
|---|---|---|
| `/blog/page` | 308 → `/blog` | `next.config.js` redirect |
| `/blog/page/1` | 308 → `/blog` | `next.config.js` redirect |
| `/blog/page/7`, `/blog/page/99` | 404 | not in `getStaticPaths`, `fallback: false` |
| `/blog/page/latest`, `/blog/page/2.5`, `/blog/page/-1` | 404 | same |

`/blog/page` with no number was the one worth reading rather than guessing. `web/pages/blog/page/[page].js` does not create a route for `/blog/page` — Next needs an `index.js` in that directory for that, and there is none. So the URL is two segments, `blog` and `page`, and the only file that can match it is `web/pages/blog/[slug].js`, which would read `page` as a post slug. Under `fallback: false` that 404s today, but only because no Sanity document happens to be slugged `page` — the behaviour would depend on CMS content, which is not a thing to leave loose. The redirect settles it: redirects run before filesystem routing, so `/blog/page` never reaches `[slug].js` at all.

`/blog/page/1` redirects rather than 404s for the same reason it isn't in `getStaticPaths` — one first page, no duplicate of `/blog`, and any stray link to the numbered form consolidates onto the URL that holds the backlinks. Both are `permanent: true` (308); the existing `/climate` entry is `permanent: false` and was left alone.

## Titles and canonicals

Page two's title is `Blog — Page 2 | Polymer`. `web/components/seo.js` appends `" | Polymer"` to whatever `pageTitle` it is given, so the page number goes in `pageTitle` and the suffix stays. `/blog` still renders `Blog | Polymer`, byte for byte what it rendered before.

**One thing to flag.** The instruction referred to a `noBrandSuffix` prop on `<SEO>` and to `pathname` emitting the canonical. Neither is true of `web/components/seo.js` on this branch: it has no `noBrandSuffix` parameter and it emits no `<link rel="canonical">` at all — `pathname` drives `og:url` and nothing else. Both do exist in the compiled `web/.next` output sitting in the working directory, which was built from a later branch, most likely `seo-phase-3-redirects-canonicals`. I set `pathname` to each page's own URL, which is the correct input either way: `og:url` is right today, and the canonical will be right the moment phase 3's tag lands. I did not add `noBrandSuffix` or a canonical tag to `seo.js` — that is phase 3's file, and inventing it here would collide.

Each page's `pathname` is its own URL, not `/blog`. Canonicalling page two to `/blog` would de-index pages two through six and re-orphan the 21 posts this change exists to reach.

Descriptions are distinct too: pages two and up open with `Page N of 6 of the Polymer talent and hiring blog.` before the shared copy.

## Verification

`next build` on Node 16.20.2 and `next start` on port 3987, then curl. Node 20 cannot build this repo — `pages/about.js` fails on Next 12.1.0's squoosh wasm loader under undici. Pre-existing and unrelated; `.nvmrc` says `18.x` while `web/package.json` `engines` says `22.x`, which is worth a look sometime but not here.

- Build emitted `/blog/page/[page]` with 5 paths: `2`, `3`, `4`, `5`, `6`. No `1`.
- Served HTML for `/blog/page/2` contains five post `href`s and eight pagination anchors, with no JavaScript executed — that is the SSG output, which is exactly what a crawler with JS off receives.
- Union of post links across the six pages: **26 unique**, matching the 26 in the sitemap. Per page: 5, 5, 5, 5, 5, 1.
- All four URLs the audit names are linked: `problem-solving-interview-questions`, `behavioral-interview-scoring-matrix`, `employee-turnover`, `best-job-board-software`.
- `sitemap.xml`: 49 `<loc>` entries — 18 static routes, 5 blog pages, 26 posts. `/blog/page/1` absent.
- Every edge-case URL in the table above returns the status shown.

No tests written, no spec written. `web/.next` is gitignored, so the build left the tree carrying only the six files above.

## Round 1 review — fix applied

One MED finding, one file: `web/components/blogIndex.js`.

`Styled.PageLink` set `color: ${t.color.gray[600]}` as a plain declaration. `web/styles/global.js` lines 41-48 declare `a, a:link, a:visited, a:hover, a:active { text-decoration: none; color: inherit; }`, and `a:link` at (0,1,1) outranks the emotion class at (0,1,0) — so every page number rendered inherited black, and `&:hover { color: black }` changed nothing visible because it was already black.

Fixed by moving the declaration into a `&:visited, &:link` block, which is the pattern `Styled.ImageCredit` already uses at `web/pages/blog/[slug].js:495-497` for the same collision:

```
    &:visited,
    &:link {
      color: ${t.color.gray[600]};
    }
```

Placed above `&:hover` and `&[aria-current="page"]`. All three selectors are (0,2,0), so source order decides and the later two keep their black. The `!important` form used at `web/pages/changelog.js:186` and `web/pages/blog/[slug].js:715` would also have worked; the `&:link` form is the one from the blog files and does not need `!important` on the hover and current-page rules to stay ahead of it.

Nothing else touched. Still nothing committed, nothing pushed.

---

## Round 1 fix pass — `web/pages/sitemap.xml.js`

Finding: MED, "does the sitemap list every page URL and every post URL, and do those URLs match the routes that actually exist?", status DONE INCOMPLETELY.

**No code change. The file is correct; the gap the finding names cannot be closed from inside it.**

The sitemap builds its blog page URLs with

```js
blogPageNumbers(blogPageCount(posts.length)).slice(1).map(blogPagePathname)
```

and `getStaticPaths` in `web/pages/blog/page/[page].js` builds its paths with

```js
blogPageNumbers(blogPageCount(posts.length)).slice(1)
```

Same functions from `web/lib/blog.js`, same `posts.length`, same `.slice(1)`. Checked across post counts: 0/1/5 → no page URLs, 26 and 30 → `blog/page/2..6`, 31 → `blog/page/2..7`. The two sets are equal for every possible input, so they can diverge only when the two fetches see *different* Sanity data — the sitemap's `getServerSideProps` reads at request time, `getStaticPaths` read at build time. That is the whole of the finding, and it is a property of *when* each file runs, not of what either computes.

Both levers that close it are outside the one file I own:

- `fallback: false` → `fallback: "blocking"`, or a `revalidate`, in `web/pages/blog/page/[page].js` and `web/pages/blog/[slug].js`
- a Sanity-publish → Vercel deploy hook, which is infrastructure and not in the repo

Options considered inside `sitemap.xml.js` and rejected:

- **Statically generate the sitemap** so it shares the build's snapshot — Next 12 Pages Router cannot; only `getServerSideProps` can set `Content-Type` and write the body.
- **Read `.next/prerender-manifest.json`** at request time to emit only routes the build actually produced — would work, but it is ~10 lines plus a `next dev` fallback branch, depends on Vercel's lambda file tracing shipping that manifest, and buys correctness only inside a window that self-heals on the next deploy. Over-engineering for a MED temporal edge.
- **Drop `/blog/page/N` from the sitemap** — violates Jessica's spec point 3, "Every page URL goes in the sitemap, alongside every post URL". Not on the table.

Scope note: the page-URL case is strictly narrower than the post-URL case in the same file. A new post adds a `/blog/<slug>` entry to the live sitemap immediately; it adds a `/blog/page/N` entry only when the count crosses a multiple of 5. So this adds no new class of breakage over what the file already does for posts.

**One question for Jessica, unfiled since the earlier verifier raised it (`SEO-CHANGELOG.md:694`, `:775`): does publishing in Sanity fire a Vercel deploy hook?** If yes, the divergence window is a build long and nothing here needs doing. If no, the fix is `fallback: "blocking"` on the two blog route files — one line each, and it covers post URLs and page URLs together.

Nothing edited, nothing committed, nothing pushed.

---

## Round 1 fix — SEO-CHANGELOG.md brought in line with the code

One finding, MED, one file: `/Users/jessica/wrk/wrk-corp/wrk-marketing/SEO-CHANGELOG.md`. Nothing else in the repo was touched — `git status --short` after this round shows the same six pagination entries as before plus `M SEO-CHANGELOG.md`. Nothing committed, nothing pushed.

The changelog described the one-list blog index as the shipped state. Four places named in the finding, plus six more that went stale from the same change:

| Where | Was | Now |
|---|---|---|
| Item 1 heading | "blog index renders all posts" | "blog index pagination" |
| Item 1 **Files** / **URLs affected** | one file, `/blog` plus 21 slugs | five files; adds `/blog/page/2` … `/blog/page/6` |
| Changes 1-5 (the `ButtonNew`, `POSTS_PER_PAGE`, `visibleCount`, `LoadMoreWrapper` deletions) | presented as shipped | kept verbatim under "What `6229f91` shipped — superseded", with a lead paragraph recording Jessica's 2026-08-06 decision and why the deletion was the wrong fix |
| — | — | new subsection "The 2026-08-06 shape — URL-based pagination, five posts a page": file table, route-shape reasoning, the `/blog/page` resolution, styling, edge cases, titles, per-page post table, verification |
| "`web/pages/blog.js:63` maps every element of `posts` with no cap" | present tense | scoped to `6229f91` |
| "`blog.html` carries 26 distinct `/blog/<slug>` hrefs" | present tense | that artifact is gone; the current build's `blog.html` has 5 post hrefs plus 5 page hrefs |
| Item 2 "The build on disk" | `BUILD_ID` `W4gbUszIATiA1mb07NwFH` | corrected — `bHgXp2yrP42ogOUnP1UOe`, and its 98 related edges independently confirm the working-tree column of the table above it |
| Phase 1 step 3 click paths | "two hops", 2 clicks for all ten | three hops, 3 clicks for all ten, with the page number per row |
| Sitemap item 1 | 44 URLs | 44 at `6229f91`, 49 in the working tree; the new `blogPagePathnamesAfterFirst` block added as a sixth working-tree difference |
| needsLiveCheck | "serving all 26 post links", "26-card blog index" | 5 posts plus 5 page anchors; added the redirect check and the unrendered pagination nav |
| Open question 7 | asked whether to reinstate "Load more" | struck through and answered |
| Verifier findings citing `POSTS_PER_PAGE` as deleted, and the repair-table row | left verbatim | left verbatim, each with a bold correction noting it is back in `web/lib/blog.js` |

Everything measured for this entry came off the build already on disk (`BUILD_ID` `bHgXp2yrP42ogOUnP1UOe`, `web/.next/server/pages/`), not off a claim: which posts sit on which page, the 26-unique union, the `rel="prev"` / `rel="next"` / `aria-current="page"` in `/blog/page/4`, the five `/blog/page/<n>` hrefs in `blog.html`, the 98 related edges, and the three tab-01 URLs that keep a 3-click alternate through a page-one post.

Two things deliberately not done. `QUESTIONS-FOR-JESSICA.md` still carries the same question unanswered at line 7 ("Phase 1, item 1 — blog index" question 2) — that file was outside this round's one-file permission, so the changelog names it and its line rather than editing it. And the `6229f91` before/after record was not deleted: it is what PR #47 renders and what every verifier finding below it was written against, so it was relabelled as superseded instead.
