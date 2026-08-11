# Unrequested changes removed

Run: 2026-08-07. One agent, nine branches, sequential, in the order given.
No pushes, no merges, no branch deletions, `main` untouched.
Lint after every branch: `npx next lint --dir pages --dir components --dir lib`
on Node 16.20.2. Every branch shows only the pre-existing `pages/_app.js`
manual-stylesheet warning.

---

## seo-phase-1-2-deorphan-crawl — 0054be6

Removed the related-posts "Keep reading" demotion in `web/pages/blog/[slug].js`:
`<Styled.RelatedTitle>` back to `<h2>`, the `Styled.RelatedTitle` styled
component deleted, the `h2 { ... }` rule moved back inside `Styled.Related`, and
the `aria-label="Keep reading"` that arrived in the same 05eed5c hunk dropped
with it.

Verified: the `Styled.Related` block is byte-identical to 6229f91.

Kept, all as the finding listed: `robots.txt`, `sitemap.xml.js` and its
helpers, `llms.txt`, `llms-full.txt`, URL-based pagination and its redirects,
the related-posts module itself and its symmetric link graph, the job-board
post link, the underlined feature-description link, the tab 07 title, the www
`og:image` on `/features/jobboard`, `SEO-CHANGELOG.md`.

Uncertain, left in place: the sitemap `Cache-Control` header.

## seo-phase-3-redirects-canonicals — 655ae7b

Reverted both `og:image` hosts from www to the apex:

- `web/pages/plato.js` → `https://polymer.co/images/platocard.png`
- `web/pages/features/jobboard.js` → `https://polymer.co/images/jobboardcard.png`

Verified: `web/pages/plato.js` is now identical to `main`;
`web/pages/features/jobboard.js` differs from `main` only by the tab 07 E10
title rewrite.

Kept: the canonical link and `canonicalUrl`, the `/contact` → `/about` 301, the
legal-services `pathname` fix, the three privacy-policy `href` changes, the
sitemap homepage trailing slash, `BLOCKED.md`, the changelog entry.

Uncertain, left in place: commit 499c9a3's change to the visible link *text* of
the three privacy-policy anchors. One question settles it — did she approve the
privacy-policy link text change? Note it is absent from
`seo-phase-9-content-refresh`, whose `privacy.js` still carries 3 www hrefs and
3 apex texts.

## seo-phase-4-metadata-headings — e2d3ed0

Three removals:

1. The same related-posts demotion, same three edits. `Styled.Related` verified
   byte-identical to 6229f91.
2. `web/pages/sitemap.xml.js` back to `post._updatedAt` for a post's
   `<lastmod>`: the `updatedDate` line dropped from `postsQuery` and
   `post.updatedDate || post._updatedAt` back to `post._updatedAt`. Tab 02 C7
   says "lastModified from CMS timestamps" and `_updatedAt` is that timestamp.
3. The stray double blank line above `const STOP_WORDS`.

Left alone deliberately: `updatedDate` and `author` on
`studio/schemas/blogPost.js`, `studio/schemas/author.js`, the `updatedDate` line
in `blogPostsQuery`, the byline and the visible "Updated" line — all authorised
by tab 05 A10 and Overview K23.

Kept: every tab 07 title, the seven industry meta descriptions, the `/terms`
description, the `/plato` H1, the ToC `<nav>`, the sidebar `<h2>`,
`pageTitle.includes("Polymer")`, the phase 1-4 comment deletions.

Uncertain, left in place: the `role` field on `author.js`; the "Updated" suffix
on the blog index cards.

## seo-phase-5-structured-data — 0af2887 (unchanged)

No removals. Nothing committed. Lint clean.

## seo-phase-6-images-links-headers — 117fa32

**Applied by hand, not by merging phase 5 in.** The finding offered a merge as
the one-shot fix; the instruction for this round forbids merging, so every item
was done as an edit. The stack is left exactly as it stood.

Restored `href: "https://ca.la"` on the CALA entry in
`web/components/home/brands.js`. ca.la is alive, it appears on no tab, and it
was on `main` before this engagement. The makelog strip stays, along with its
mechanism: the `brand.href ? <Link> : <a>` branch and the `&[href]:hover`
selector.

Cleared the phase 1-4 merge lag, all of it Jessica's commit 1b6c3f0 applied
here:

- `web/components/seo.js`, `web/pages/about.js`, `web/pages/index.js`,
  `web/pages/pricing.js`, `web/pages/changelog.js`,
  `web/pages/blog/[slug].js` — `noBrandSuffix` and `BRANDLESS_TITLE_SLUGS` gone,
  `pageTitle.includes("Polymer")` back.
- `web/pages/blog/[slug].js` — sidebar CTA back to `<h2>`,
  `Styled.SidebarTitle` deleted, the `h2` rule restored inside
  `Styled.SidebarContent`. Verified byte-identical to `main`, trailing space on
  the `} ` line included.
- Comments from phases 1-4 deleted in `blogIndex.js`, `platoHero.js`,
  `lib/blog.js`, `next.config.js`, `blog/[slug].js`, `blog/page/[page].js` and
  `sitemap.xml.js`.

Eight files whose entire delta over phase 5 was merge lag were restored from
phase 5 wholesale and verified to diff empty against it: `platoHero.js`,
`lib/blog.js`, `blog/page/[page].js`, `about.js`, `index.js`, `pricing.js`,
`seo.js`, `sitemap.xml.js`. The other five were hand-edited so phase 6's own
work survives.

Verified after the edits: no `noBrandSuffix` or `BRANDLESS_TITLE_SLUGS` anywhere
in tracked source; `[slug].js`'s remaining delta over phase 5 is only the
`sizes` props, `noUpscaleImageBuilder` and phase 6's own comments.

Kept: `lib/sanityImage.js`, every `sizes` prop, the `imageBuilder` arguments,
the security headers, the Report-Only CSP, the `ready.js` `<Quote>` change, the
Sanity link drafts, the changelog.

Uncertain, left in place: phase 6's own ~130 lines of comments (one decision for
Jessica — 1b6c3f0 scoped itself to phases 1-4 and said so, and the
`sanityImage.js` header is the only record of why `fm=webp` is deliberately
absent); the `sizes` prop on `home/build.js`; the sixth dead help link in the
Sanity draft.

## seo-phase-7-final-report — 2624a59

`SEO-FINAL-REPORT.md` removed from the repo root and relocated unchanged to
`~/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/SEO-FINAL-REPORT.md`.
Same sha1 (`a70a172efb7f2f675bf392ffaedb152be7540e67`), 299 lines. Nothing in
the repo referenced it, and `main` has no root `.md` but `README.md`.

Kept: the CALA href restoration this branch already carried, `SEO-CHANGELOG.md`.

Uncertain, left in place: `BLOCKED.md` at the repo root.

## seo-phase-8-faq — 7070ec8

Removed the wide-table scroll CSS from `web/pages/blog/[slug].js`:
`TABLE_SCROLL_FROM_COLUMNS`, `TABLE_MIN_COLUMN_WIDTH` and their eight-line
comment, the `columns` prop on `Styled.Table`, the `scrolls` local, the
`overflow-x`/`overflow-y` split back to `overflow: hidden`, and the conditional
`min-width`.

Verified: `TableRenderer` and `Styled.Table` are both byte-identical to the
pre-engagement base 01bf615, and the file's only remaining delta over
`seo-phase-7-final-report` is the corrected `Article.author` comment, which the
finding keeps.

Kept: `web/pages/faq.js` and its FAQPage JSON-LD, the footer FAQ link, the
sitemap entry, the six industry-page copy fixes, the hosted `.xlsx`, the
`BLOCKED.md` rewrite.

Uncertain, left in place: the FAQ line in `llms.txt`; the `noBrandSuffix` prop
on `faq.js` (inert, and the edit belongs with the `seo.js` work).

## contact-page — 976a937 (unchanged)

No removals. Nothing committed. Lint clean.

Uncertain, left in place: the pricing enterprise "Contact Us" CTA retargeted
from `mailto:support@polymer.co` to `/contact`. Worth her eye either way — it
now routes enterprise leads to a different inbox.

## small-business-industry-page — 29091b6 (unchanged)

No removals. Nothing committed. Lint clean.

---

## Left for Jessica, not acted on

**The related-posts demotion survives on four branches.**
`Styled.RelatedTitle` is still present on `seo-phase-5-structured-data`,
`seo-phase-6-images-links-headers`, `seo-phase-7-final-report` and
`seo-phase-8-faq`, which all carry it from 05eed5c. It was judged unauthorised
on phases 1-2 and 4 and removed there. No agent listed it on the four downstream
branches, and this round's mandate was to carry out the findings branch by
branch, so it was not touched there. It needs the same three edits wherever the
branches are reconciled.

**The sitemap `updatedDate` preference survives downstream too**, on phases 5
through 8, for the same reason: removed on phase 4 where it was reported, still
present on every branch below it.

**The phase-3 `og:image` reverts likewise apply only to phase 3.** Phases 4
through 8 still carry `https://www.polymer.co/images/platocard.png` and
`.../jobboardcard.png`, as does `seo-phase-9-content-refresh`.

**`web/components/home/brands.js` line 24**: makelog lost
`href: "https://www.makelog.com"` and nothing restores it. The phase-6 finding
keeps the strip on the round brief's word that makelog is dead; the phase-7
agent flagged it as the same shape as the CALA href it did restore. Left as the
phase-6 finding directed.

## Notes on method

- Two worktrees (`contact-page`, `small-business-industry-page`) have no
  `node_modules`, so lint there ran through a temporary symlink to the main
  checkout's `node_modules`, removed immediately after. Both branches' `package.json`
  and `package-lock.json` are identical to `main`, so the shared tree is valid.
  Both worktrees were left clean.
- No finding's `howToRemove` mismatched the file. Every line number, every quoted
  string and every surrounding context matched what was on the branch, so nothing
  had to be skipped for mismatch.
