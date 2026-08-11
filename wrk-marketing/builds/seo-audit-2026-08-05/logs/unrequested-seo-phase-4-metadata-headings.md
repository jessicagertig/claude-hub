# Unrequested-change audit: `seo-phase-4-metadata-headings`

Tabs in scope: 07 Title Rewrites, 12 Meta Rewrites, 17 Headings. Read read-only via
`git show` / `git diff` against `seo-phase-3-redirects-canonicals`. Nothing was checked out,
edited or committed.

## What the branch actually contains

`git diff seo-phase-3-redirects-canonicals..seo-phase-4-metadata-headings` understates the
branch. Four non-merge commits carry the work:

| commit | subject |
|---|---|
| `46bd4e9` | Apply the title and meta rewrites, and fix the heading outlines |
| `87ba3ae` | Close the gaps the phase 4 review found |
| `48352f8` | Add an editorial updated date and author bylines to the blog |
| `1b6c3f0` | Revert the CTA demotion, derive the brand suffix, drop the comments |

Two of `46bd4e9`'s edits were later replicated onto `seo-phase-1-2-deorphan-crawl` by
`05eed5c`, so the phase3..phase4 diff shows neither of them: the `/features/jobboard.js`
title (authorised, tab 07 E10) and the "Keep reading" heading demotion. I read all four
commits in full rather than the branch diff alone.

## Removals

### 1. "Keep reading" demoted from `<h2>` to a div — `web/pages/blog/[slug].js`

Introduced by `46bd4e9`, duplicated onto phase 1-2 by `05eed5c`. Pre-change form is
`6229f91`.

Tab 17 has 12 rows and none names the related-posts module. Its three CTA rows say, in
full:

- B16/B17/B18: "First H2 is boilerplate CTA 'Get your hiring process up and running in
  minutes.'"
- C16/C17/C18: "Move CTA below content headings"

Overview K27, which defines the terms tab 17 uses: "Give /plato an H1 ('Plato AI candidate
review' phrasing from the keyword plan); demote ToC headings to nav elements." Only the ToC.

`46bd4e9`'s own justification was "The related-posts heading added in phase 1 got the same
treatment once it turned out to be the new first H2 on three posts." That treatment was the
CTA demotion, and `1b6c3f0` has since reverted it as unauthorised — the sidebar CTA is an
`<h2>` again, and it precedes `Styled.Related` in DOM order (`Styled.Sidebar` sits inside
`Styled.Columns`; `Styled.Related` comes after `Styled.Columns`). So "Keep reading" cannot be
a first H2 on any post, and the stated reason no longer holds even on its own terms.

Mechanism test: would "Move CTA below content headings" work without demoting a different
module's heading? Yes. Not a mechanism.

The `aria-label="Keep reading"` on `Styled.Related` was added by the same edit as
compensation for the lost heading. Restoring the heading restores the pre-change form,
which had no `aria-label`.

### 2. Sitemap lastmod switched from `_updatedAt` to `updatedDate` — `web/pages/sitemap.xml.js`

Introduced by `48352f8`. Tab 02 row A7 C7 is the only cell that specifies sitemap lastmod:
"Add app/sitemap.ts emitting all marketing routes + every Sanity blog post with
lastModified from CMS timestamps". `_updatedAt` is the CMS timestamp.

The cells that authorise `updatedDate` existing at all are tab 05 row A10 ("headline,
datePublished, dateModified, author (add real author profiles), image") and Overview K23
("updated modified dates, author bylines"). Neither mentions the sitemap. Nothing about the
Article `dateModified`, the visible byline or the visible "Updated" line needs the sitemap
to change. The field keeps working; the sitemap kept working before.

Effect of leaving it in: a post whose body is edited after its `updatedDate` is set now
reports the older editorial date as `<lastmod>`, so the sitemap under-reports the change.
Same shape as the CTA finding — the cell pointed at a field, the work also rewired an
unrelated phase-2 deliverable.

### 3. Stray double blank line — `web/pages/blog/[slug].js` lines 28-29

Left behind by `1b6c3f0` when it deleted `BRANDLESS_TITLE_SLUGS`. Formatting artifact, no
cell involved.

## Uncertain, left alone

- `role` field on `studio/schemas/author.js`. Tab 05 A10 says "author (add real author
  profiles)". A profile plausibly carries a role; nothing on the site renders it (only the
  Studio preview subtitle). Reads either way, so it stays.
- "Updated {date}" on the blog index cards (`web/components/blogIndex.js`) and the
  `updatedDate` line in `blogPostsQuery` (`web/lib/blog.js`) that feeds it. Overview K23
  says "Refresh each post (... updated modified dates ...)" — each post, not the index. But
  tab 13 A4 names the defect as "no update dates or author profiles are shown anywhere on
  the blog", and the index is part of the blog. Reads either way, so it stays.

## Kept, with the authorising cell

| Change | Cell |
|---|---|
| Homepage title, `web/pages/index.js` | tab 07 E7 |
| `/pricing` title | tab 07 E8 |
| `/plato` title | tab 07 E9 |
| `/features/jobboard` title | tab 07 E10 |
| `/blog` title | tab 07 E11 |
| `/about` title | tab 07 E12 |
| `/changelog` title | tab 07 E13 |
| `/terms` title untouched | tab 07 E14 "(keep)" |
| 7 industry meta descriptions | tab 12 D7-D13 |
| `/terms` meta description | tab 12 D15 |
| `/plato` H1 | tab 17 C7; hidden treatment approved by Jessica, QUESTIONS-FOR-SHAWN.md entry 1 |
| ToC as `<nav>` | tab 17 C9-C15 |
| Sidebar CTA back to `<h2>` | Jessica, `1b6c3f0` |
| `pageTitle.includes("Polymer")` in `seo.js` | Jessica, `1b6c3f0` |
| Comments added by phases 1-4 removed | Jessica, `1b6c3f0` |
| `updatedDate` + `author` on `blogPost`, `author.js`, `schema.js` | tab 05 A10, Overview K23 |
| Byline and "Updated" line on the post header | tab 05 A10, Overview K23 |

Mechanisms kept because the authorised outcome does not render without them:
`<SEO>` added to `index.js` (the page had none and fell through to `_app.js`'s default,
which is the exact string tab 07 B7 replaces); `editorialTitle` on `index.js` and
`pricing.js` (holds `og:title` at the value it had before the title rewrite);
`Styled.TableOfContents` and its CSS (reproduces `Styled.Content`'s `h2` sizing minus
`scroll-margin-top`); `Styled.Heading` on `platoHero.js`; `Styled.Byline`; the
`author->{ name, photo }` projection in `getStaticProps`.
