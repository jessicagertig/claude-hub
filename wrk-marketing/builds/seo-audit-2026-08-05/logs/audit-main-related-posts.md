# Audit — related-posts module, `web/pages/blog/[slug].js`

Read-only audit against `01bf615` ("Merge pull request #46 from wrk-corp/plato-landing-page").
Two commits touch this file between `01bf615` and `origin/main`:

- `6229f91` "De-orphan the blog and add crawl infrastructure" — +123 lines. Original module: top-N rarity-weighted scorer, `<h2>Keep reading</h2>`.
- `05eed5c` "Close the gaps the phase 1+2 review found" — +83/-26 within the module. Added reciprocity, determinism sort, `wordsFor` memo, null-prototype guards, `|| ""` guards, the `score > 0` filter, and the `<h2>` → `<Styled.RelatedTitle>` div demotion.

Net for the file: 164 insertions, 2 deletions. No later commit touches it.

## The authorising cells, quoted

**Overview K11** (row 1.0, Orphaned high-value pages):

> Add full blog pagination/archive to /blog, add related-post links from crawlable posts, and include every post in the new XML sitemap. Then refresh the assets (see Content Freshness).

**Tab `01 Orphaned Pages`**, the only detail tab in scope. Column F, per row:

- F7 `problem-solving-interview-questions`: "Link from /blog + related posts; include in sitemap; refresh"
- F8: "Link + refresh + add downloadable template"
- F9: "Link + refresh; formula & benchmark blocks for AEO"
- F10: "Link + refresh"
- F11 `job-rejection-email`: "Link + light refresh"
- F12: "Link; fold into hiring-ops cluster"
- F13: "Link + refresh"
- F14: "Link + refresh - page-2 -> page-1 candidate"
- F15: "Strengthen internal links; base for interview-bias guide"
- F16: "Link from /features/jobboard + blog index; refresh"

F7 is the only row naming "related posts". No row names a ranking method, a count, a heading level, or a visual treatment.

**Master prompt, Phase 1 step 2** — the only place in any of the three sources that specifies the module:

> Add a related-posts module to the blog post template (3 links minimum, topically matched).

**Master prompt, Phase 1 step 3:**

> Confirm each of the 10 URLs returns 200 and is now reachable ≤3 clicks from the homepage; record the click path per URL in the changelog.

Step 3 is a verification requirement. It is satisfied through `/blog` and its pagination anchors, not through related posts — `SEO-CHANGELOG.md` line 512 states this outright: "The 3-click path in the table does not depend on any of it — it runs through the pagination anchors, which reach all 26 posts regardless of how related posts are chosen."

So the full authorisation for this module is: a module, on the post template, at least 3 links, topically matched. Everything below is measured against that.

## Inventory of the module on `origin/main`

| Lines | Piece | Verdict |
|---|---|---|
| 27 | `RELATED_POST_COUNT = 3` | authorised — "3 links minimum" |
| 29-34 | `STOP_WORDS` (45 words) | exceeds |
| 36-38 | comment on the `\|\| ""` guards | exceeds |
| 39-44 | `topicWords` | authorised in principle — "topically matched" |
| 40 | `\|\| ""` guards | exceeds |
| 46-48 | `ponytail:` comment on the scorer | authorised (documents the deviation from a real taxonomy) |
| 49-54 | comment on reciprocity and the slug sort | exceeds |
| 56-57 | slug sort for cross-page determinism | exceeds (support for reciprocity) |
| 58-59 | comment on the null-prototype guards | exceeds |
| 60-61 | `Object.create(null)` × 2 | exceeds |
| 62-67 | `documentFrequency` + `wordsFor` build loop | rarity weighting exceeds; `wordsFor` memo is reciprocity support |
| 69-72 | `overlapScore` extracted as a named helper | exceeds (extraction forced by reciprocity) |
| 74-82 | `strongestFor` | the top-N half — authorised |
| 80 | `.filter((scored) => scored.score > 0)` | exceeds, and undershoots "3 links minimum" |
| 84-101 | reciprocity: Map seed, inbound loop, final re-sort | **exceeds — the largest single excess** |
| 226 | `({ post, relatedPosts })` | authorised |
| 324-332, 334-338 | "Keep reading" markup | authorised |
| 325-326 | `aria-label` + `<h2>` → div demotion | **unauthorised** |
| 333 | `<p>{relatedPost.metaDescription}</p>` excerpt | exceeds — visible design, Jessica's |
| 368-376 | second GROQ fetch of sibling posts | authorised by necessity |
| 372 | `publishDate` in the projection | dead — ships unrendered into `__NEXT_DATA__` |
| 375 | `\| order(publishDate desc)` | effectively dead after `05eed5c` |
| 379 | `relatedPosts: relatedTo(post, otherBlogPosts)` | authorised |
| 802-814 | `Styled.RelatedTitle` | styling — Jessica's, stays |
| 815-857 | `Styled.Related` | styling — Jessica's, stays |

## The reciprocity block

Lines 84-101. `strongestFor(blogPost)` seeds a Map with this post's own three strongest matches; the loop then re-runs `strongestFor` for every one of the other 25 posts and adds any post whose own top three include this one. `RELATED_POST_COUNT` stops being a count and becomes a floor.

The stated motivation, from `05eed5c`'s message: "a post that was nobody's nearest neighbour received no inbound link at all. job-rejection-email had zero, which is the row tab 01 asks to link."

That reads a requirement into F11 that F11 does not carry. F11 says "Link + light refresh". The link it asks for is delivered by the blog index. Only F7 names related posts, and `problem-solving-interview-questions` already received 4 inbound related links under the plain top-N scorer (`SEO-CHANGELOG.md` line 423). The reciprocal graph is machinery for a guarantee — every post receives inbound related links — that no cell states.

Reciprocity is also what forced three other additions that would otherwise not exist:

- the slug sort at 56-57, so every page computes an identical graph (a plain top-N needs no cross-page agreement),
- the `wordsFor` memo at 61/63, because `strongestFor` now runs 26 times per page instead of once (~650 `overlapScore` calls per page rather than 25),
- `overlapScore` and `strongestFor` extracted as named helpers, because both are now called for posts other than the current one.

`relatedTo` went from 22 code lines and 3 comment lines at `6229f91` to 48 code lines and 9 comment lines.

**Removable without losing the links: yes.** Delete 84-101 and return `strongestFor(blogPost).map((scored) => scored.blogPost)`. Then 56-57, 61, 63 and the two helper extractions collapse back to the `6229f91` single chain. Every post still emits 3 topically-matched links; Phase 1 step 3 is untouched, because the ≤3-click paths run through the pagination anchors. The measured cost of removal, from `SEO-CHANGELOG.md` lines 443 and 462: emitted links 98 → 78, and `job-rejection-email` and `hello-polymer` go back to zero inbound *related* links — both still one anchor from `/blog` via `/blog/page/N`.

## The rarity weighting, `STOP_WORDS`, and the defensive guards

"Topically matched" authorises matching. It does not name inverse-document-frequency. `1 / documentFrequency[word]` at line 72, with the counting loop at 62-67, is a scoring refinement past the cell.

It is also the cheapest quality in the module and the one I would keep if only one refinement survived. `STOP_WORDS` is the one to drop first: six lines listing 45 words that the rarity weighting already suppresses on its own — a word appearing in all 26 posts contributes 1/26 to a score whether or not it is in the list. The two mechanisms do overlapping work.

`Object.create(null)` (lines 60-61, plus two comment lines) defends against a post whose title or description contains "constructor", "toString" or "valueOf". `|| ""` (line 40, plus three comment lines) defends against a post missing `editorialTitle` or `metaDescription` — and the comment above it concedes "Both fields are required in studio/schemas/blogPost.js". Both exceed the cell. Both are a handful of characters carrying five lines of prose; the prose is more of the excess than the code is.

`.filter((scored) => scored.score > 0)` at line 80 is the one place the module does **less** than the cell asks. It drops zero-overlap links rather than padding to three, so `utc-is-the-timezone-of-the-future` renders 2 links against the master prompt's "3 links minimum". Recorded, not hidden — `SEO-CHANGELOG.md` line 466 calls it out as a deviation. It is one line and it removes genuinely arbitrary links; worth keeping and worth Jessica knowing the count floor is not held on that one post.

## The heading demotion — unauthorised

Line 325-326 on `origin/main`:

```
<Styled.Related aria-label="Keep reading">
  <Styled.RelatedTitle>Keep reading</Styled.RelatedTitle>
```

At `6229f91` it was:

```
<Styled.Related>
  <h2>Keep reading</h2>
```

At `01bf615` there was no module at all.

No cell in the workbook asks for this. Tab `17 Headings` is the nearest thing and it does not reach: it lists 12 named URLs, addresses first-H2s that are Tables of Contents or the boilerplate CTA, and its remedies are "Make ToC a `<nav>`/aside, not a content heading" and "Move CTA below content headings". The related-posts module did not exist when the crawl ran, so no tab-17 row describes it. Applied by analogy, tab 17's own remedy shape was already satisfied at `6229f91` — `Styled.Related` is `styled.aside`, and the "Keep reading" heading already sat below the article's content headings. The demotion goes past the remedy the tab prescribes for the analogous case.

`SEO-CHANGELOG.md` line 464 gives the reasoning: "a template `<h2>` appended after the article body's own PortableText `<h2>`s put a boilerplate heading into the outline of all 26 posts." Rendered type is unchanged — the same `t.text.bold`, `t.text.xl`, `line-height: 1.3` and `t.mq[56]` `t.text.xxl` rules moved from `Styled.Related`'s `h2 { }` block into the new `Styled.RelatedTitle` div. So this is a semantics change, not a styling change, and it is not covered by Jessica's reservation of the visual design. It leaves the module with no heading element, patched over by `aria-label` on the `<aside>`.

Flagging rather than proposing removal: it sits directly on the markup Jessica is re-reviewing, and the fix either way is one element name.

## Dead query residue

```
368  const otherBlogPosts = await sanity.fetch(`
369    *[_type == "blogPost" && slug.current != $slug]{
370      _id,
371      editorialTitle,
372      publishDate,
373      metaDescription,
374      slug
375    } | order(publishDate desc)
376  `, { slug });
```

The markup reads `_id`, `slug.current`, `editorialTitle` and `metaDescription` (lines 329-333). Nothing reads `publishDate`. It ships into props and `__NEXT_DATA__` for every related post on all 26 pages and is never rendered. Already recorded as LOW #6 in `SEO-CHANGELOG.md` line 794.

`| order(publishDate desc)` was load-bearing at `6229f91`, where publish order was the tie-break and the zero-overlap fallback. After `05eed5c` the function sorts `allBlogPosts` by slug at line 57, so GROQ order no longer reaches `strongestFor` at all. Its only surviving effect is as a stable-sort tie-break in the reciprocity loop's Map insertion order, for reciprocal links whose scores are exactly equal. Effectively dead; two lines, zero observable change on removal.

Both lines came in with `6229f91`; neither existed at `01bf615`.

## Bottom line

The cell authorises a related-posts module on the blog post template with at least 3 topically-matched links. That is `RELATED_POST_COUNT`, `topicWords`, the top-N half of `relatedTo`, the sibling GROQ fetch, and the "Keep reading" list — roughly 22 lines of logic plus markup and styling.

Past it: the reciprocal link graph and the three supports it dragged in (the single largest excess, ~26 lines, removable with the links intact), the IDF weighting, `STOP_WORDS`, two sets of defensive guards with five lines of comment, and an unrendered query field. Unauthorised: the `<h2>` → div heading demotion.

Nothing in the excess is load-bearing for the links or for Phase 1 step 3.
