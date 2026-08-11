# Unrequested-change audit: `seo-phase-6-images-links-headers`

Read-only pass. No command run against the repository changed anything.

Diff read: `seo-phase-5-structured-data..seo-phase-6-images-links-headers`
Tabs read in full: Overview, 11 Images, 14 External Links, 15 Security Headers, 16 Redirect Links, 10 Wrk Legacy
Master prompt read in full: `master-prompt-pages-router.md`

## The split that governs the whole report

`git merge-base seo-phase-5-structured-data seo-phase-6-images-links-headers` is `53680ed`.
`git log seo-phase-6..seo-phase-5` returns exactly two commits: `0af2887` (a merge of
seo-phase-4-metadata-headings into phase 5) and `1b6c3f0`, Jessica's own commit
"Revert the CTA demotion, derive the brand suffix, drop the comments".

So the 21-file `seo-phase-5..seo-phase-6` diff is two different populations:

- **13 files phase 6 actually authored** (`git diff 53680ed..seo-phase-6 --stat`):
  SEO-CHANGELOG.md, blogIndex.js, candidateManagement/intro.js, feature.js,
  home/brands.js, home/build.js, home/intro.js, home/ready.js,
  industries/industryHeader.js, lib/sanityImage.js, next.config.js,
  pages/blog/[slug].js, pages/changelog.js.
- **8 more files that appear only because phase 6 has not merged `1b6c3f0` forward**:
  components/seo.js, plato/platoHero.js, lib/blog.js, pages/about.js,
  pages/index.js, pages/pricing.js, pages/blog/page/[page].js, pages/sitemap.xml.js,
  plus part of blogIndex.js, next.config.js and [slug].js.

Everything in the second population is something Jessica already ruled out. It is on
this branch and it has to come off, but the remedy is one action rather than thirteen
edits: merge `seo-phase-5-structured-data` into `seo-phase-6-images-links-headers`.
`53680ed` (the merge base) carries every one of these hunks and phase 5 removes them,
so a three-way merge drops them all without a conflict.

## The one genuine phase-6 finding: the `https://ca.la` href

`web/components/home/brands.js` line 26.

```
main / seo-phase-5:  { src: cala, alt: "CALA", href: "https://ca.la", width: 70 },
seo-phase-6:         { src: cala, alt: "CALA", width: 70 },
```

`ca.la` is alive. The branch's own SEO-CHANGELOG.md agrees, in the table under
"The three customer links on the home page":

| URL | DNS | HTTP | Change made |
|---|---|---|---|
| `https://ca.la` | NOERROR on 1.1.1.1, 8.8.8.8 and 9.9.9.9 | 301 to `https://www.mercer.design/`, 200 | **none, the link works** |

and it states outright: "The href at `brands.js:26` was never touched." The committed
file says otherwise. A later fix pass removed it and the changelog was never corrected.

No tab authorises it either way. `ca.la` is not on tab 14, whose five confirmed 404s
are the three `help.wrk.xyz` articles, `crazyegg.com/blog/recooty-review/` and
`topgrading.com/candidate-assessment/topgrading-job-scorecard/`. The round brief is
explicit: "`https://ca.la` is ALIVE and its link stays."

The `makelog` href removal on line 24 and the `<Quote>` change in `home/ready.js` stay.
Both are named as correct in the round brief.

## What authorises the rest of phase 6's own work

### `sizes` props and `lib/sanityImage.js`

Tab 11 column D on all 71 Sanity rows: "Sanity: request fm=webp (or avif) + cap width
at rendered size". Tab 11 column D on the eight `_next/image` rows (A66, A68-A71, A73,
A76, A80): "next/image already optimizing; lower quality/width for marketing shots".
Master prompt phase 6.1: "width capped at rendered size".

For `next/image` with `layout="responsive"`, `sizes` IS the width cap. With no `sizes`
the component emits `sizes="100vw"` and the browser takes the top srcset candidate,
2304, which is the `w=2304` every tab 11 row records. So `sizes` is the mechanism the
cell asks for, not an addition beside it. `noUpscaleImageBuilder` is separately named
as approved in the round brief, and the `{ imageBuilder: noUpscaleImageBuilder }`
argument at the four `useNextSanityImage` call sites is how a builder gets used.

`fm=webp` is absent from `lib/sanityImage.js` and the round brief says that stands.

### Security headers

Tab 15 rows A8, A9, A10 give `nosniff`, `SAMEORIGIN` and
`strict-origin-when-cross-origin` as recommended values; row A7 gives "Start with
Report-Only policy covering self + Sanity CDN + analytics; enforce after a clean week",
and tab 15 A4 says "Ship via next.config headers()". `async headers()` in
`web/next.config.js` emits exactly those four, the CSP one under the key
`Content-Security-Policy-Report-Only`. The host list in `contentSecurityPolicy` is what
"covering self + Sanity CDN + analytics" requires for a policy that does not report
noise on every page view.

### Sanity drafts

Tab 14 rows E7/E8/E9 ("Replace with current Polymer help article", "Replace",
"Replace"), E10 ("Remove or replace citation"), E11 ("Link to Topgrading homepage or
remove") and E17 ("Update to `https://www.pcmag.com`") authorise the six draft edits
the changelog lists, with the one exception below. Tab 14 E12-E22 say "leave" for the
bot-walled rows and none was removed.

### SEO-CHANGELOG.md

Master prompt rule 4: "Keep a changelog. Append every change (file, URL affected,
before to after) to `SEO-CHANGELOG.md` in the repo."

## Three things I am not removing, and why

### 1. Phase 6's own explanatory comments

Roughly 130 comment lines across `lib/sanityImage.js`, `next.config.js`, six
components, `[slug].js` and `changelog.js`.

The case for removing them: `1b6c3f0` is Jessica's own commit and its third paragraph
is "Comments added by phases 1-4 removed." It deleted every explanatory comment phases
1 through 4 added, in nine files. Phase 6's comments are the same species.

The case for keeping them: no cell speaks to comments either way, and `1b6c3f0` scoped
itself to phases 1-4. The `lib/sanityImage.js` header is also the only record of why
`fm=webp` is deliberately absent, with the byte measurements behind it, and the round
brief says that decision stands. Deleting the comment invites the next agent to re-add
`.format('webp')`.

Over-removal is worse than a flagged uncertainty, so I left them and flagged it. This
is one decision, not 130.

### 2. `sizes` on `web/components/home/build.js`

That component renders `images/settings.png`, which is not one of tab 11's 79 rows.
Row A70 is `jobsettings.a5f65853.png`, which is `web/images/jobboard/jobsettings.png`,
rendered by a `web/components/jobBoard/` component that got no `sizes` at all. So the
nine `sizes` props were chosen by "which templates hold an `<Image layout="responsive">`"
rather than row by row, and this one lands on an image the tab never listed.

It reads either way: tab 11 A4 says "fix in the same templates", the master prompt says
"template-level fix", and without `sizes` this page fetches a 2304px derivative for a
1152px slot. Mechanism, so it stays.

### 3. The sixth dead help link in `drafts.fcfc319d-...`

`content[7].markDefs[0].href`,
`help.wrk.xyz/en/articles/4436181-have-your-job-posts-appear-in-google-jobs` repointed
to `help.polymer.co/...`.

Tab 10 A4 says "Polymer's pre-rebrand help center (help.wrk.xyz) is offline; these
links 404 for every reader" and rows A8, A9, A10 name three. Tab 14's own title says
"5 real". This is a fourth `help.wrk.xyz` link and a sixth 404, on no tab row, and the
branch's changelog says the markDef is orphaned: "no span in that block carries it, so
it renders no clickable link today and fixing it closes no crawler-visible defect."

Against that, tab 10's subject is the offline help center as such, and the edit sits in
an unpublished draft Jessica reviews before publishing. Quoted and left alone.

## Not present on this branch

`TABLE_SCROLL_FROM_COLUMNS` and `TABLE_MIN_COLUMN_WIDTH` do not appear anywhere under
`web/` on `seo-phase-6-images-links-headers`. That finding belongs to another branch.
