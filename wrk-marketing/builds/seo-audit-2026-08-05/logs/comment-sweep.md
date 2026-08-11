# Comment sweep

Jessica, 2026-08-06, of the comments this engagement wrote: "please clean up
your code comments. Remove them." Her standing rule is "Don't add unnecessary
comments."

**Scope.** Every comment added since `01bf615`, the last pre-engagement commit,
across the nine engagement branches. Found by reading the `+` lines of
`git diff 01bf615..<branch> -- 'web/*' 'studio/*'` and by comparing, per file,
the comment text present on the branch against the comment text present at
`01bf615`. Removed: multi-line rationale blocks, JSX `{/* ... */}`
sizes-measurement blocks, `ponytail:` markers, single-line explanations, and one
trailing comment. Kept: every comment that existed at `01bf615`, verified with
`git show 01bf615:<path>`.

**Method.** Comment lines were deleted in place. No code line was touched, no
block was reflowed or reindented, and no blank line was removed except one (see
`contact-page` below). Each branch was linted with

```
export PATH="/Users/jessica/.nvm/versions/node/v16.20.2/bin:$PATH"
cd /Users/jessica/wrk/wrk-corp/wrk-marketing/web && npx next lint --dir pages --dir components --dir lib
```

and every run finished with only the pre-existing `pages/_app.js` manual
stylesheet warning. The two worktree branches have no `node_modules`, so their
edited files were copied into the main checkout, linted there, then the main
checkout was restored with `git checkout -- web/` and confirmed clean before
committing in the worktree.

**Verification, all nine branches.** Two passes after the sweep commits:

- no comment text remains that is absent from the `01bf615` version of the same
  file, and
- no comment text present at `01bf615` has gone missing.

Both passes are clean on all nine branches.

---

## seo-phase-1-2-deorphan-crawl

- Sweep commit `ea8719f`, 43 comment lines across 6 files.
- `web/components/blogIndex.js`, `web/components/seo.js`, `web/lib/blog.js`,
  `web/pages/blog/[slug].js`, `web/pages/blog/page/[page].js`,
  `web/pages/sitemap.xml.js`
- Lint clean.
- Also on this branch, commit `396d236`, three changes no cell authorises:
  - the reciprocal link graph in `relatedTo`, `web/pages/blog/[slug].js`. The
    Map seed, the loop re-running `strongestFor` for every other post, and the
    final re-sort are replaced by the plain top-N chain. The slug sort, the
    `wordsFor` memo and the `overlapScore` / `strongestFor` extractions collapse
    back to the single chain `6229f91` had. `documentFrequency`'s null-prototype
    initializer and the `.filter((scored) => scored.score > 0)` are unrelated to
    reciprocity and stay.
  - the bare `/blog/page` redirect in `web/next.config.js`. The `/blog/page/1`
    entry stays.
  - the `metaDescription` prop on `web/pages/blog/page/[page].js`.

## seo-phase-3-redirects-canonicals

- Sweep commit `70fecda`, 53 comment lines across 7 files.
- `web/components/blogIndex.js`, `web/components/seo.js`, `web/lib/blog.js`,
  `web/next.config.js`, `web/pages/blog/[slug].js`,
  `web/pages/blog/page/[page].js`, `web/pages/sitemap.xml.js`
- Lint clean.
- Also on this branch, commit `d65454a`, the "Keep reading" shape.
  `<Styled.RelatedTitle>` back to `<h2>`, the `Styled.RelatedTitle` component
  deleted, its type rules moved back into `Styled.Related` as an `h2 { }` block,
  and `aria-label="Keep reading"` dropped. `Styled.Related` is byte-identical to
  the `6229f91` version and to
  `git show seo-phase-4-metadata-headings:web/pages/blog/[slug].js`.

## seo-phase-4-metadata-headings

- Sweep commit `7628829`, 1 comment, 1 file.
- `web/components/seo.js`, the trailing `// Homepage canonical keeps the trailing slash`
  on the `canonicalUrl` line. Commit `1b6c3f0` had already removed the rest of
  this branch's comments.
- Lint clean.

## seo-phase-5-structured-data

- Sweep commit `a9ba8dd`, 69 comment lines across 7 files.
- `web/components/industryJsonLd.js`, `web/components/jsonLd.js`,
  `web/components/seo.js`, `web/components/softwareApplicationJsonLd.js`,
  `web/pages/_app.js`, `web/pages/blog/[slug].js`, `web/pages/pricing.js`
- Lint clean.

## seo-phase-6-images-links-headers

- Sweep commit `f07be58`, 204 comment lines across 16 files.
- `web/components/blogIndex.js`, `web/components/candidateManagement/intro.js`,
  `web/components/feature.js`, `web/components/home/build.js`,
  `web/components/home/intro.js`, `web/components/industries/industryHeader.js`,
  `web/components/industryJsonLd.js`, `web/components/jsonLd.js`,
  `web/components/seo.js`, `web/components/softwareApplicationJsonLd.js`,
  `web/lib/sanityImage.js`, `web/next.config.js`, `web/pages/_app.js`,
  `web/pages/blog/[slug].js`, `web/pages/changelog.js`, `web/pages/pricing.js`
- Includes the 40-line CSP rationale block at the top of `web/next.config.js`
  and the five JSX `{/* Rendered width ... */}` blocks.
- Lint clean.
- The earlier removal round had already taken part of this branch; what is above
  is what was actually still in the files.

## seo-phase-7-final-report

- Sweep commit `53645cd`, 268 comment lines across 20 files.
- The phase 6 list plus `web/components/plato/platoHero.js`,
  `web/lib/blog.js`, `web/pages/blog/page/[page].js`,
  `web/pages/sitemap.xml.js`
- Lint clean.

## seo-phase-8-faq

- Sweep commit `2c5be47`, 286 comment lines across 21 files.
- The phase 7 list plus `web/pages/faq.js` (the sourcing block above `faqs` and
  the FAQPage block above `faqSchema`).
- Lint clean.

## contact-page

- Sweep commit `e48ad5d`, 321 comment lines across 23 files.
- The phase 8 list plus `web/pages/api/contact.js` and `web/pages/contact.js`.
- One blank line was also removed: the separator between the header comment and
  `const CONTACT_ADDRESS` in `web/pages/api/contact.js`, which existed only to
  separate the removed comment and would otherwise have left the file starting
  on a blank line.
- Linted by copying the 23 edited files into the main checkout; the main
  checkout was then restored with `git checkout -- web/`, the two files it does
  not carry (`web/pages/api/contact.js`, `web/pages/contact.js`) deleted, and
  `git status` confirmed empty. Lint clean.

## small-business-industry-page

- Sweep commit `940beb9`, 294 comment lines across 21 files.
- Same file list as `seo-phase-8-faq`.
  `web/pages/industries/applicant-tracking-for-small-business.js` carries no
  comments at all, so it is not in the diff.
- Linted the same way as `contact-page`; every edited file already exists in the
  main checkout, so the restore was `git checkout -- web/` alone and
  `git status` confirmed empty. Lint clean.

---

## Nothing recorded as blocked

No comment removal would have left a syntax error or an empty block, so nothing
was skipped. No branch was pushed, merged or cascaded into the one above it, and
no branch was deleted. `main` was not touched.
