# Audit — blog-index-pagination (read-only, against 01bf615..origin/main)

Area files: `web/pages/blog.js`, `web/pages/blog/page/[page].js`, `web/components/blogIndex.js`, `web/lib/blog.js`, `web/next.config.js`

## The authorising cell

Overview K11 (issue 1.0, Orphaned high-value pages):

> "Add full blog pagination/archive to /blog, add related-post links from crawlable posts, and include every post in the new XML sitemap. Then refresh the assets (see Content Freshness)."

Overview J11 names the mechanism:

> "the blog index only lists recent posts, with no pagination or archive"

Tab `01 Orphaned Pages` column F, per row, says only "Link from /blog + related posts; include in sitemap; refresh" and variants. The tab prescribes nothing about page size, nav markup, or redirects. Everything below is judged against K11 plus Jessica's confirmation that URL-based pagination at five posts a page is what the tab asked for.

Master prompt Phase 1 adds: "Fix the blog index: render **all** posts on `/blog` (pagination or full archive), not just recent ones" and "Confirm each of the 10 URLs returns 200 and is now reachable <=3 clicks from the homepage".

## What the diff actually is

Two commits touched this area:

- `6229f91` "De-orphan the blog and add crawl infrastructure" — deleted the pagination outright and rendered all 26 posts in one list on `/blog`.
- `5aed26f` "Paginate the blog with real URLs instead of a Load more button" — reverted that and built URL pagination.

Net against `01bf615`: 354 insertions, 208 deletions across the five files, of which most of `web/components/blogIndex.js` is code lifted out of the old `web/pages/blog.js` unchanged.

## Structural comparison, 01bf615 vs origin/main

| Piece | 01bf615 | origin/main |
|---|---|---|
| `POSTS_PER_PAGE` | `const POSTS_PER_PAGE = 5` in `web/pages/blog.js` | `export const POSTS_PER_PAGE = 5` in `web/lib/blog.js` |
| GROQ query | inline `query` in `web/pages/blog.js` | `blogPostsQuery` in `web/lib/blog.js`, same string |
| `BlogPost` card | `web/pages/blog.js` | `web/components/blogIndex.js`, identical |
| Post styles | `web/pages/blog.js` | `web/components/blogIndex.js`, byte-identical apart from two trailing-whitespace cleanups in `Blog_Title` and `Blog_Excerpt` |
| Page-advance control | `Styled.LoadMoreWrapper` + `ButtonNew` + `useState(visibleCount)` | `Styled.Pagination` + anchors; the wrapper's `mt(12)/mb(6)` and `mq[56] mt(15)/mb(10)` carried over verbatim |
| Posts shipped to `/blog` | all posts, sliced client-side | `posts.slice(0, POSTS_PER_PAGE)` in `getStaticProps` |
| Routes | `pages/blog.js`, `pages/blog/[slug].js` | plus `pages/blog/page/[page].js` |
| `next.config.js` redirects | one entry, `/climate` | three entries: `/climate`, `/blog/page`, `/blog/page/1` |

`ButtonNew` is still imported by 12 other components, so dropping the import here left nothing dead.

Theme tokens used by the new `Styled.PageLink` (`t.text.medium`, `t.rounded.sm`, `t.px`, `t.py`, `t.color.gray[200|400|600]`, `t.color.black`) all exist at `01bf615:web/styles/theme.js`, and `t.color.gray[...]` is already used by 8+ components. `web/styles/theme.js` was not modified in the engagement. The nav markup is house-consistent: `<Link passHref>` wrapping a styled anchor, matching `Styled.Post`; `aria-label` is already used in `navigation.js`, `footer.js` and the Plato components.

`Styled.Post`'s `&:last-of-type { mb(0) }` still resolves to the last post card: `Styled.Pagination` is a `nav`, and the page-number anchors are nested inside it, not siblings of the post anchors.

## Judgements

### Authorised

1. **URL pagination replacing the client-side "Load more"** (`web/pages/blog.js`, new `web/pages/blog/page/[page].js`). J11 names "no pagination or archive" as the orphaning mechanism and K11 asks to add it. Jessica confirmed.
2. **Five posts a page.** `POSTS_PER_PAGE = 5` is carried over unchanged from `01bf615:web/pages/blog.js`, where it was the "Load more" increment. Nothing about page size was invented.
3. **`/blog` stays page one** with the same five posts and `pathname="blog"`. Satisfies master prompt rule 6 (preserve URLs); `/blog` holds the backlinks and is what `navigation.js:48`, `navigation.js:80` and `footer.js:73` link to.
4. **Anchor-based nav** (Previous / every page number / Next) inside `<nav aria-label="Blog pages">`, `rel="prev"`/`rel="next"`, `aria-current="page"`. Crawlable with JavaScript off, which is the whole point of K11's "pagination". At 26 posts this is 6 pages, so every post is homepage -> `/blog` -> `/blog/page/N` -> post, meeting master prompt Phase 1.3's <=3 clicks.
5. **Extraction to `web/components/blogIndex.js` and `web/lib/blog.js`.** Two routes render the same list; three files (`blogIndex.js`, `blog/page/[page].js`, `sitemap.xml.js`) consume the same arithmetic. Mechanical, not a new feature.
6. **`/blog/page/1` -> `/blog` 301.** Direct consequence of making `/blog` page one: `getStaticPaths` in `blog/page/[page].js` drops page 1 via `.slice(1)`, so without the redirect that URL 404s and page one has two candidate URLs.
7. **Per-page `<SEO>` on `blog/page/[page].js`** with `pageTitle={`Blog (Page ${page})`}` and `pathname={blogPagePathname(page)}`. Every page in this repo renders `SEO`; a new route without a distinct title would duplicate `/blog`'s.

Note for whoever runs Phase 4: tab `07 Title Rewrites` row A11 prescribes `Hiring & Recruiting Blog - Guides and Templates | Polymer` for `https://www.polymer.co/blog`. When that lands in `web/pages/blog.js`, `blog/page/[page].js` will still read "Blog (Page 2) | Polymer" unless it is updated in the same pass. Flagging, not fixing.

### Exceeds

1. **`/blog/page` -> `/blog` 301** in `web/next.config.js`. K11 and tab 01 say nothing about the bare segment. `pages/blog/[slug].js:358` returns `{ paths, fallback: false }`, so `/blog/page` currently 404s and there is no post slugged "page" (the changelog's slug list has none). The redirect converts a 404 into a permanent redirect, and because `redirects()` runs before filesystem routing it would also make any future post slugged "page" permanently unreachable. Removable on its own: delete the `{ source: '/blog/page', destination: '/blog', permanent: true }` entry and keep the `/blog/page/1` one.
2. **Invented per-page meta description** in `blog/page/[page].js`: ``metaDescription={`Page ${page} of ${pageCount} of the Polymer talent and hiring blog. Level up your recruitment game with our library of articles for HR professionals and startup founders.`}``. Tab `12 Meta Rewrites` has no row for the blog index or its pages; K11 asks for pagination, not copy. Removable: drop the prop and `components/seo.js` supplies the site default.
3. **Comment volume.** About 22 lines of multi-line rationale comments new across the four files: 5 lines above the two new redirects in `next.config.js`, 1 + 5 in `lib/blog.js`, 6 above `Pagination` in `blogIndex.js`, 6 above `getStaticPaths` in `blog/page/[page].js`. `01bf615:web/pages/blog.js` carried zero comments and `pages/blog/[slug].js` carried short single-line ones, so this is not the house form. Comment-only, no code change to remove.

### Unauthorised

1. **`ponytail:` marker at `web/components/blogIndex.js:48`**: `// ponytail: every page number is listed, which reads fine up to roughly fifteen pages; add first/last plus an ellipsis past that.` `ponytail` is an agent-tooling convention, not a Polymer one. `git grep ponytail 01bf615` returns nothing anywhere in the repo. Nothing in the workbook or the master prompt authorises it. Two comment lines, removable in isolation.

   A second occurrence exists at `web/pages/blog/[slug].js:46` and two more in `SEO-CHANGELOG.md` (lines 178 and 260). Those files are outside my area; noting them so the same call gets made once across all four.

## What I did not verify

- The claim in `5aed26f`'s message that the six built pages carry 26 unique post links split 5/5/5/5/5/1 with all four tab-01 orphans among them. That needs a build against live Sanity; I am read-only and did not run one.
- `components/seo.js` on `origin/main` still emits no `<link rel="canonical">`, so the paginated pages have no canonical either. That is Phase 3 work and is not merged; it is not a gap in this area.
