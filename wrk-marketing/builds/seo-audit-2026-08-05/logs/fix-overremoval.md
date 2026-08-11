# Correcting the removal round's over-removals

Three items, applied branch by branch. No pushes, no merges, no cascading a
branch into the one above it. Lint run per branch with Node 16.20.2:
`npx next lint --dir pages --dir components --dir lib`. The only warning
anywhere was the pre-existing `pages/_app.js` manual-stylesheet one.

## Item 1 — www og:image URLs

| Branch | State |
|---|---|
| `seo-phase-3-redirects-canonicals` | **Fixed**, commit `2c0e351` |
| `seo-phase-4-metadata-headings` | Already correct |
| `seo-phase-5-structured-data` | Already correct |
| `seo-phase-6-images-links-headers` | Already correct |
| `seo-phase-7-final-report` | Already correct |
| `seo-phase-8-faq` | Already correct |
| `contact-page` | Already correct |
| `small-business-industry-page` | Already correct |

Only phase 3 had been reverted. Both files went back to the www host:

- `web/pages/plato.js` → `https://www.polymer.co/images/platocard.png`
- `web/pages/features/jobboard.js` → `https://www.polymer.co/images/jobboardcard.png`

## Item 2 — `updatedDate` in the sitemap

| Branch | State |
|---|---|
| `seo-phase-4-metadata-headings` | **Fixed**, commit `da8ce20` |
| `seo-phase-5-structured-data` | Already correct |
| `seo-phase-6-images-links-headers` | Already correct |
| `seo-phase-7-final-report` | Already correct |
| `seo-phase-8-faq` | Already correct |
| `contact-page` | Already correct |
| `small-business-industry-page` | Already correct |

Only phase 4 had been stripped. In `web/pages/sitemap.xml.js`, `updatedDate`
went back into `postsQuery` and the post `<lastmod>` back to
`post.updatedDate || post._updatedAt`. After the edit, phase 4's
`sitemap.xml.js` diffs byte-identical against phase 5's version.

## Item 3 — the "Keep reading" `<h2>`

All six named branches needed it; the region was byte-identical across all
six before the edit, so the same exact-string patch applied to each.

| Branch | Commit |
|---|---|
| `seo-phase-5-structured-data` | `76d95e6` |
| `seo-phase-6-images-links-headers` | `a60113d` |
| `seo-phase-7-final-report` | `781fd13` |
| `seo-phase-8-faq` | `1b648cd` |
| `contact-page` | `db6a6a5` |
| `small-business-industry-page` | `74e0a47` |

Each is the same three edits in `web/pages/blog/[slug].js` and nothing else:

- `<Styled.RelatedTitle>Keep reading</Styled.RelatedTitle>` → `<h2>Keep reading</h2>`
- the `Styled.RelatedTitle` styled component deleted
- its type rules moved back into `Styled.Related` as an `h2 { }` block
- `aria-label="Keep reading"` dropped from `Styled.Related`

`Styled.Related` verified byte-identical to commit `6229f91`'s version on
every one of the six.

`contact-page` and `small-business-industry-page` also carry the wide-table
scroll code (`TABLE_SCROLL_FROM_COLUMNS`, `TABLE_MIN_COLUMN_WIDTH`, the
`columns` prop on `Styled.Table`) that `seo-phase-8-faq` removed in `7070ec8`.
That is their own later work and was left untouched; each branch's diff is
11 insertions and 15 deletions, the three edits only.

## Lint note for the two worktree branches

`/Users/jessica/wrk/wrk-corp/wrk-marketing.contact-page/web` and
`/Users/jessica/wrk/wrk-corp/wrk-marketing.small-business-industry-page/web`
have no `node_modules`, so `npx next lint` there fetched a current Next that
refuses Node 16.20.2. Installing dependencies in the worktrees was out of
scope, so each branch's exact `[slug].js` content was copied into the main
checkout, linted against the pinned Next 12.1.0 toolchain, and the main
checkout restored with `git checkout --` immediately after. Both came back
clean, and the main checkout's tree was verified clean afterwards.

## Left alone, flagging for a decision

`seo-phase-3-redirects-canonicals` still carries `Styled.RelatedTitle`. It was
not on item 3's list, so it was not touched. The stack now reads: phase 1-2
`<h2>`, **phase 3 `Styled.RelatedTitle`**, phase 4 through 8 and both worktree
branches `<h2>`. `Styled.RelatedTitle` was introduced by `05eed5c` ("Close the
gaps the phase 1+2 review found") on `seo-phase-1-2-deorphan-crawl`; phase 3
branched off a point that includes `05eed5c` but not phase 1-2's restore
`0054be6`, which is why it sits in the middle of the stack still holding the
old shape.

`seo-phase-9-content-refresh` and `blog-author-and-updated-date` also carry
`Styled.RelatedTitle` and lack the sitemap `updatedDate`. Neither was named in
any of the three items and neither contains `seo-phase-8-faq`'s tip, so both
were left alone.
