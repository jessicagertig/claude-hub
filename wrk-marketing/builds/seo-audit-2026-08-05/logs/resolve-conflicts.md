# Stack merge and conflict resolution, 2026-08-07

Merged each branch into the one above it, one at a time, in the prescribed order.
Every branch: merge, resolve, check all twelve invariants by reading the files,
`npx next build` on Node 16.20.2, commit, push. All twelve invariants pass on all
seven branches. All six open PRs (#50 to #55) now report MERGEABLE.

## One cross-cutting finding, applied on `seo-phase-4-metadata-headings`

`396d236` on `seo-phase-1-2-deorphan-crawl` ("Drop three related-posts and routing
changes no cell authorises") is the origin of invariants 7, 8 and 9. It is **not**
an ancestor of `seo-phase-3-redirects-canonicals`, of `origin/main`, or of anything
in the phase-3-and-up chain — the second cleanup round landed on `seo-phase-1-2`
only. So no merge in this run could have delivered those three invariants; they had
to be applied.

They were applied once, on `seo-phase-4-metadata-headings`, as commit `2f7f30e`,
and then propagated up the chain by the six merges that followed. The three files
are byte-identical to their `seo-phase-1-2-deorphan-crawl` versions:

- `web/pages/blog/[slug].js` — `relatedTo` back to the plain top-N chain. The
  slug sort, `wordsFor` memo, `overlapScore`, `strongestFor`, the `relatedBlogPosts`
  Map seed, the loop over `otherBlogPosts` and the final re-sort are all gone.
- `web/next.config.js` — bare `/blog/page` redirect removed, `/blog/page/1` kept.
- `web/pages/blog/page/[page].js` — `metaDescription` prop removed.

`seo-phase-3-redirects-canonicals` and `seo-phase-1-2-deorphan-crawl` were not
touched, per instruction. `seo-phase-3-redirects-canonicals` therefore still fails
invariants 7, 8 and 9; its PR (#48) is already merged, so it has no open PR and no
mergeability problem. Merging PR #50 upward will carry the fix down to it.

## Per branch

### 1. `seo-phase-3-redirects-canonicals` into `seo-phase-4-metadata-headings`

- Merge commit `a5ce09d`. **No conflict.**
- Follow-up commit `2f7f30e` applying invariants 7, 8, 9 (see above).
- Build clean. Pushed `7628829..2f7f30e`.
- All twelve invariants pass.

### 2. `seo-phase-4-metadata-headings` into `seo-phase-5-structured-data`

- Merge commit `33f4e6b`. **Conflicted** in `web/pages/blog/[slug].js`.
- One hunk: HEAD adds `BASE_URL` and `ORGANIZATION_ID`, the phase-4 side has
  neither. Those two constants are phase 5's own structured-data work, and no
  invariant covers them, so the target branch's side was kept. The rest of
  `relatedTo` had already auto-merged to the plain top-N form.
- Diff against the old tip is exactly the three phase-1-2 files, nothing else;
  phase 5's `JsonLd`, `articleSchema` and `breadcrumbSchema` are intact.
- Build clean. Pushed `a9ba8dd..33f4e6b`.
- All twelve invariants pass.

### 3. `seo-phase-5-structured-data` into `seo-phase-6-images-links-headers`

- Merge commit `420fff2`. **Conflicted** in `web/next.config.js` and
  `web/pages/blog/[slug].js`.
- `next.config.js`: HEAD kept the bare `/blog/page` redirect, incoming removed it.
  Invariant 8 is the arbiter — removed.
- `[slug].js`: HEAD kept `allBlogPosts` / the slug sort at the head of `relatedTo`,
  incoming had `const words = topicWords(blogPost);`. Invariant 7 is the arbiter —
  incoming.
- Diff against the old tip is exactly the three phase-1-2 files. Phase 6's
  `noUpscaleImageBuilder`, `BODY_IMAGE_SIZES`, `FEATURE_IMAGE_SIZES` and the
  unlinked Makelog entry are intact.
- Build clean. Pushed `f07be58..420fff2`.
- All twelve invariants pass.

### 4. `seo-phase-6-images-links-headers` into `seo-phase-7-final-report`

- Merge commit `739a1e9`. **Conflicted** in `web/next.config.js` and
  `web/pages/blog/[slug].js`.
- `next.config.js`: same bare `/blog/page` hunk, resolved the same way.
- `[slug].js`, hunk 1: HEAD had `BRANDLESS_TITLE_SLUGS`. Invariant 5 is the
  arbiter — removed.
- `[slug].js`, hunk 2: same `relatedTo` head. Invariant 7 — incoming.
- Auto-merged in phase 6's favour, and confirmed by reading the files:
  `noBrandSuffix` gone from `web/components/seo.js`, `about.js`, `changelog.js`,
  `index.js`, `pricing.js`; `seo.js` back to
  `pageTitle + (pageTitle.includes("Polymer") ? "" : " | Polymer")`;
  `Styled.SidebarTitle` gone and its type rules back inside
  `Styled.SidebarContent`'s `h2 { }` block.
- Build clean. Pushed `53645cd..739a1e9`.
- All twelve invariants pass.

### 5. `seo-phase-7-final-report` into `seo-phase-8-faq`

- Merge commit `313dc50`. **Conflicted** in `web/next.config.js` and
  `web/pages/blog/[slug].js` — same three hunks as step 4, resolved the same way.
- The merge also deleted `SEO-FINAL-REPORT.md` (299 lines) from the repo, which is
  phase 7's `2624a59` arriving. Invariant 12 satisfied; the file is at
  `/Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/SEO-FINAL-REPORT.md`.
- Invariant 5 still failed after the merge: `web/pages/faq.js:143` passed
  `noBrandSuffix`. That is phase 8's own new page, written before the derived
  suffix rule landed, so nothing in the merge could have caught it. Removed. Its
  `pageTitle` is "Polymer FAQ - Questions About the ATS and Job Board", which
  contains "Polymer", so `seo.js` suppresses the suffix anyway and the rendered
  `<title>` is unchanged.
- Build clean. Pushed `2c5be47..313dc50`.
- All twelve invariants pass.

### 6. `seo-phase-8-faq` into `contact-page`

Worked in the `/Users/jessica/wrk/wrk-corp/wrk-marketing.contact-page` worktree.

- Merge commit `100e0c8`. **Conflicted** in `web/next.config.js` and
  `web/pages/blog/[slug].js`.
- `next.config.js`: this one needed care. Git aligned the two sides badly — HEAD's
  block was the `/blog/page` redirect, the incoming block was the `/contact`
  redirect. Those are two independent removals, not one disagreement: `contact-page`
  removes `/contact` to `/about` because it adds a real `/contact` page, and phase 8
  removes the bare `/blog/page`. Kept both removals. The redirect list is now
  `/climate` and `/blog/page/1` only, verified by reading the block.
- `[slug].js`, hunk 1: `BRANDLESS_TITLE_SLUGS` — removed (invariant 5).
- `[slug].js`, hunk 2: `relatedTo` head — incoming (invariant 7).
- `[slug].js`, hunk 3: HEAD had `TABLE_SCROLL_FROM_COLUMNS` and
  `TABLE_MIN_COLUMN_WIDTH` — removed (invariant 10). The rest of the wide-table
  code auto-merged out: the `columns` prop on `Styled.Table`, the `scrolls`
  variable, `overflow-x`/`overflow-y` back to `overflow: hidden`, and the
  `min-width` line.
- Invariant 5 failed after the merge for the same reason as phase 8:
  `web/pages/contact.js:48` passed `noBrandSuffix`. Removed. `pageTitle` is
  "Contact Polymer - Talk to Sales and Support", so the rendered `<title>` is
  unchanged.
- `web/pages/contact.js` intact.
- Build clean, with `node_modules` symlinked in and `.env.local` sourced from the
  main checkout, symlink removed afterwards. Pushed `e48ad5d..100e0c8`.
- All twelve invariants pass.

### 7. `seo-phase-8-faq` into `small-business-industry-page`

Worked in the `/Users/jessica/wrk/wrk-corp/wrk-marketing.small-business-industry-page`
worktree.

- Merge commit `d60b258`. **Conflicted** in `web/next.config.js` and
  `web/pages/blog/[slug].js` — the bare `/blog/page` redirect,
  `BRANDLESS_TITLE_SLUGS`, the `relatedTo` head, and the two table-scroll
  constants. All four resolved by the invariant list. This branch keeps the
  `/contact` to `/about` redirect, which is correct here.
- `SEO-FINAL-REPORT.md` deleted by the merge, same as step 5.
- `web/pages/industries/applicant-tracking-for-small-business.js`, its
  `next.config.js` rewrite at line 101 and its `sitemap.xml.js` entry at line 21
  all intact.
- Build clean, same symlink procedure, symlink removed afterwards. Pushed
  `940beb9..d60b258`.
- All twelve invariants pass.

## PR state after the run

    #55 small-business-industry-page -> seo-phase-8-faq              MERGEABLE
    #54 contact-page                 -> seo-phase-8-faq              MERGEABLE
    #53 seo-phase-8-faq              -> seo-phase-7-final-report      MERGEABLE
    #52 seo-phase-7-final-report     -> seo-phase-6-images-links-headers MERGEABLE
    #51 seo-phase-6-images-links-headers -> seo-phase-5-structured-data  MERGEABLE
    #50 seo-phase-5-structured-data  -> seo-phase-4-metadata-headings MERGEABLE

#55 reported `UNSTABLE` rather than `CLEAN` immediately after the push, which was
three Vercel deployments still in flight, not a merge problem.

`#24 fix-pages-for-mobile-72925 -> main` is still `CONFLICTING`. It is unrelated to
this stack and was not in scope.
