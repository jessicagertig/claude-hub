# HTML validity, blog routes

Branch `seo-phase-8-faq`. Baseline for attribution: `01bf61588d2a50ba6e8ece5b2111a60b36db884d`
("Merge pull request #46 from wrk-corp/plato-landing-page", Fri Jul 31 01:04:24 2026).

Findings file: `/private/tmp/claude-501/-Users-jessica-claude-hub-wrk-marketing/ae83cb44-eb97-4453-99a4-0718b5a2e1c9/scratchpad/html-validity-findings-blog.json`

## Result

62 error rows across nine routes. **Every one predates `01bf615`. Nothing was edited.**

Zero anchors without an `href` — 527 anchors across the nine routes, all of them linked, including
the `<a href="/faq">FAQ</a>` that phase 8 added to `web/components/footer.js`.

## Server

Port 3197 answered 200 before I did anything, so a sibling agent had already built and started it.
I did not build and did not restart. Verified it was the phase-8 build by fetching `/faq` (200,
a route that does not exist before `web/pages/faq.js`).

## Routes

`/blog`, `/blog/page/2`, `/blog/page/6`, and six posts chosen by grepping
`web/.next/server/pages/blog/*.html` for `<table`, `<nav aria-label`, `<figcaption`, `youtube`,
and `<blockquote` so the six cover every shape asked for:

| Route | Shape it covers |
|---|---|
| `/blog/talent-acquisition-vs-recruitment` | table |
| `/blog/agile-recruiting-process` | table of contents, no table |
| `/blog/best-applicant-tracking-software` | images with captions, 7 `figcaption` in 13 `figure` |
| `/blog/first-impression-bias` | YouTube embed |
| `/blog/skills-mapping-for-hiring-a-complete-guide` | blockquote, 4 of them |
| `/blog/post-to-we-work-remotely-6m-professionals-in-seconds` | one of the WhatJobs / We Work Remotely three |

## Validator

`npx html-validate` 8.29.0, presets `html-validate:recommended` + `html-validate:a11y`, config at
`hv-blog/.htmlvalidate.json` in the scratchpad. Turned off the style rules that would have buried
the real findings (`no-inline-style`, `void-style`, `attribute-boolean-style`, `long-title`,
`require-sri`, `prefer-native-element`, `svg-focusable`, `script-type`, `text-content`,
`unique-landmark`). Left every structural and a11y rule on.

html-validate does not check for an `<a>` with no `href`, because an `<a>` with no `href` is a
conforming HTML5 placeholder link. That is exactly the defect this round exists to catch, so it
needed its own check. `hv-blog/extra-checks.js` is a tag scanner covering:

- `<a>` with no `href`
- duplicate `id` on one page, and empty `id`
- `role` tokens against the full ARIA role list
- `aria-*` names against the ARIA 1.2 attribute list, and enumerated `aria-*` values against their
  allowed token lists
- `<img>` with no `alt` attribute at all, as distinct from `alt=""`
- `<h1>` count per page
- attribute names serialized with uppercase letters

`extra-checks.js` was self-tested against `hv-blog/selftest/fixture.html`, a page seeded with eight
defects (hrefless anchor, `role="notarole"`, `aria-current="banana"`, `aria-fake`, `<img>` with no
alt, a duplicated id, and two `<h1>`). All eight were caught. The zeros below are real zeros, not a
checker that silently matched nothing.

## Clean

| Check | Result |
|---|---|
| anchors with no `href` | 0 of 527 |
| duplicate `id` on one page | 0 |
| `a` inside `a`, `button` inside `a` | 0 |
| block-level element inside `<p>` | 0 |
| `<li>` outside `<ul>`/`<ol>`, `<td>`/`<th>` outside a row | 0 |
| more than one `<h1>`, or none | 0 — every route has exactly one |
| `aria-*` with an invalid value, unknown `aria-*` name | 0 |
| `role` value that is not a real ARIA role | 0 |
| form control with no accessible name | no form controls on these routes |

The duplicate-id collision the brief warned about — two `h2` headings in one post slugifying to the
same string — does not occur on any of these six posts. Full id inventory per post is clean apart
from the character-class issues listed below.

## Errors, all pre-existing

### 1. `<html>` has no `lang`, 9 routes

`<html>` at 1:17 on every route. There is no `web/pages/_document.js` in the repo, and
`git show 01bf615:web/pages/_document.js` returns `fatal: path ... does not exist`, so this is
Next.js 12's default `Document` and was the same before the engagement. Adding it means creating a
`_document.js`, which is new scope.

### 2. GTM `<noscript>` `<iframe>` has no `title`, 9 routes

`<iframe src="https://www.googletagmanager.com/ns.html?id=GTM-N6H844WJ" height="0" width="0" style="display:none;visibility:hidden">`

Rendered by `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/pages/_app.js` lines 253-261.
`git show 01bf615:web/pages/_app.js | grep -n ns.html` puts the same iframe at line 225 of the
baseline file. `git diff 01bf615 seo-phase-8-faq -- web/pages/_app.js` shows the engagement added
only the two `JsonLd` schema blocks; the iframe is untouched.

### 3. Two `<img>` with no `alt` attribute at all, `/blog` only

`/blog` at 1:18235 and 1:18840 (the post `hiring-gen-z`), and 1:38284 and 1:38889
(`employer-branding-steps`). Two elements per post because Next.js 12's `Image` emits the `<img>`
plus a `<noscript>` duplicate.

`/Users/jessica/wrk/wrk-corp/wrk-marketing/web/components/blogIndex.js:29` is
`alt={post.featureImage.altText}`. When `altText` is unset in Sanity, React omits the attribute
entirely rather than writing `alt=""`.

`git log -S 'alt={post.featureImage.altText}' 01bf615..seo-phase-8-faq -- web/` returns one commit,
`5aed26f` "Paginate the blog with real URLs instead of a Load more button". Reading that commit's
diff, the line is deleted from `web/pages/blog.js:37` and added to
`web/components/blogIndex.js:29`, byte-identical. It is a file move, not a behavior change.
`git show 01bf615:web/pages/blog.js` confirms the baseline expression is the same string.

The absent `altText` is Sanity content. The engagement's Sanity work only wrote alt text: the
content refresh set `featureImage.altText` on eleven posts (see `refresh-*.md` and
`sanity-strip-sweep-{a,b}.md` in this directory) and neither `hiring-gen-z` nor
`employer-branding-steps` is among them. `phase-2.md:381` records `/blog/hiring-gen-z` returning
200 on the live site during phase 2, so the post predates the engagement.

### 4. Heading level skips `h1` to `h4`, 1 route

`/blog/post-to-we-work-remotely-6m-professionals-in-seconds` at 1:27064, `<h4>` with the text
"Integration Updates". The page outline is `h1` → `h4` → `h3` → `h2`.

The `h4` is a Portable Text block in Sanity. `web/pages/blog/[slug].js` overrides only the `h2`
block renderer; `h3` and `h4` fall through to `@portabletext/react` defaults.
`builds/seo-audit-2026-08-05/logs/phase-4-blog-headings.md:132` records the same
`h1` → `h4` → `h3` sequence for this post, and line 138 states it is "authored in Sanity, not in the
template" and was deliberately not touched. Pre-existing, and already a known deferral.

### 5. Four `<th>` with no `scope`, 2 routes

`/blog/skills-mapping-for-hiring-a-complete-guide` at 1:34588, 34607, 34635, 34664 and
`/blog/talent-acquisition-vs-recruitment` at 1:29913, 29940.

`/Users/jessica/wrk/wrk-corp/wrk-marketing/web/pages/blog/[slug].js:183`, `TableRenderer`, is
`<th key={i}>{cell}</th>`. `git log -S '<th key={i}>{cell}</th>' 01bf615..seo-phase-8-faq -- web/`
returns nothing, and the renderer is byte-identical in `git show 01bf615:web/pages/blog/[slug].js`.
WCAG advisory, not an HTML5 conformance error.

### 6. `<div id="">`, 1 route

`/blog/first-impression-bias` at 1:49561, inside the `BlogPost_Embed` figure. `YouTubeEmbed` in
`web/pages/blog/[slug].js:149-165` renders `react-youtube`, whose default `id` prop is the empty
string, so React writes `id=""`. The component is byte-identical at `01bf615`.

### 7. Five heading `id` values that are not valid CSS selectors, 3 routes

| Route | Element |
|---|---|
| `/blog/agile-recruiting-process` 1:44302 | `<h2 id="5-steps-to-implement-an-agile-recruiting-process">` |
| `/blog/best-applicant-tracking-software` 1:28005 | `<h2 id="what-is-applicant-tracking-software-(and-how-does-it-work)">` |
| `/blog/best-applicant-tracking-software` 1:46146 | `<h2 id="7-of-the-best-applicant-tracking-software-solutions-for-small-businesses">` |
| `/blog/talent-acquisition-vs-recruitment` 1:28264 | `<h2 id="talent-acquisition-vs.-recruitment:-what&#x27;s-the-difference">` |
| `/blog/talent-acquisition-vs-recruitment` 1:30945 | `<h2 id="why-(and-when)-to-choose-recruitment">` |

HTML5 permits any non-empty, space-free string as an `id`, so these are conforming HTML. They are
not valid CSS selectors and would need escaping in `querySelector`. In-page navigation still works:
the table of contents builds its `href` fragment with the same `slugify(toPlainText(section).toLowerCase())`
call, so the two strings always agree.

`web/pages/blog/[slug].js:272` is the h2 renderer.
`git log -S 'return <h2 id={slug}>{children}</h2>' 01bf615..seo-phase-8-faq -- web/pages/blog/`
returns nothing; the renderer is byte-identical at `01bf615`. The odd characters come from the
Sanity heading text.

### 8. `<style>` in `<body>`, 357 occurrences across 9 routes

`<style data-emotion="...">` appears under `div`, `nav`, `section`, `aside`, `button`, `header`,
and `footer`. `<style>` is metadata content and is non-conforming outside `<head>`, though every
browser accepts it. Per route: 38, 38, 38, 40, 40, 40, 40, 41, 42.

This is `@emotion/styled` server-side rendering, the styling mechanism for the entire site. It
predates the engagement by the whole life of the codebase, and it fires once per styled component
on every page including ones this engagement never touched. Two of the 357 are inside `<nav>`
elements this engagement added (the pagination nav in `web/components/blogIndex.js` and the table
of contents nav in `web/pages/blog/[slug].js`), but the construct is Emotion's, not the component's
— the same `<style>` would appear under any element those components rendered. Changing it means
changing Emotion's SSR mode globally. Reported, not touched.

### 9. Informational

`id="__next"` and `id="__NEXT_DATA__"` begin with an underscore, 2 per route. Next.js 12 internals,
no repo file emits them. HTML5 permits it.

`charSet` (1 per route) and `srcSet` (1 to 14 per route) are serialized with uppercase letters.
HTML attribute names are ASCII case-insensitive, so both parse as `charset` and `srcset`; this is a
serialization quirk, not invalid markup. `charSet` comes from
`/Users/jessica/wrk/wrk-corp/wrk-marketing/web/components/seo.js:59`, unchanged at `01bf615`
(`git diff 01bf615 seo-phase-8-faq -- web/components/seo.js` shows only the canonical link and the
title-suffix change). `srcSet` comes from `next/image`'s `<noscript>` fallback, which assembles raw
markup rather than going through React's attribute mapping. `viewBox` also appears uppercase and is
**not** a finding — `viewBox` is the correct, case-sensitive SVG attribute name.

## Engagement-introduced markup on these routes, checked and clean

The commits between `01bf615` and `seo-phase-8-faq` that render on these nine routes are
`web/components/blogIndex.js` (new), `web/pages/blog/page/[page].js` (new), `web/pages/blog.js`
(gutted to a thin wrapper), `web/pages/blog/[slug].js`, `web/lib/blog.js` (new),
`web/lib/sanityImage.js` (new), `web/components/seo.js`, `web/components/jsonLd.js` (new),
`web/pages/_app.js`, and `web/components/footer.js`. Each new structure in the served output:

- Pagination, `web/components/blogIndex.js:49-73`. `<nav aria-label="Blog pages">` containing eight
  anchors, every one with an `href`, `aria-current="page"` on the current page, `rel="prev"` and
  `rel="next"` on the neighbours. All valid.
- Table of contents, `web/pages/blog/[slug].js:237-260`. Changed by `46bd4e9` from a bare
  `<h2>` + `<ul>` fragment to `<nav aria-label="Table of contents"><div>…</div><ul>…</ul></nav>`.
  Valid, and it does not create a heading skip: the post goes `h1` then straight to the content
  `h2`s.
- Related posts, `web/pages/blog/[slug].js:347-361`. `<aside><h2>Keep reading</h2><ul><li><a>…</a><p>…</p></li></ul></aside>`.
  Valid.
- `JsonLd`, `web/components/jsonLd.js`. Adds `<script type="application/ld+json">` with `id`
  `organization`, `website`, `article`, and `breadcrumb`. No id collides with anything.
- Footer FAQ link, `web/components/footer.js`. Serves as `<a href="/faq">FAQ</a>`. This is the
  construct that broke on the homepage in phase 6; here `next/link` injected the `href` correctly.
