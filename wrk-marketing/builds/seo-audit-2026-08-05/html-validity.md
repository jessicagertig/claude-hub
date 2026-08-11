# HTML validity — 204 errors, all pre-existing

Four validators (`html-validate` 8.29.0 and 7.18.1) over 28 routes on `seo-phase-8-faq`.

**None of the 204 was introduced by this engagement.** Every one traces to before `01bf615`, the last commit before the audit work started. Nothing was touched.

Sorted by instance count. The SEO/AEO column is about ranking and answer extraction only, per your scope; accessibility impact is deliberately not scored.

| Violation | Instances | Where it comes from | SEO/AEO | What it causes |
|---|---|---|---|---|
| `<style>` element inside `<body>` | 28 | Emotion SSR — no `web/pages/_document.js` exists, so Emotion injects its style tags inline instead of into `<head>`. 72 tags in the built homepage | **No** | Nothing. Browsers and crawlers accept it. It is invalid only because `<style>` is spec'd for `<head>` |
| `<html>` has no `lang` | 28 | `web/pages/_document.js` is absent, so Next's default supplies a bare `<html>` | **No** | Google detects language from content and has said `lang` is not a ranking signal. It does drive screen-reader voice selection and browser translation prompts |
| GTM `<iframe>` has no `title` | 28 | `web/pages/_app.js:254`, the `<noscript>` Google Tag Manager frame | **No** | Nothing. The iframe is `display:none` and carries no content to index |
| `id` invalid as a CSS selector | 27 | 21 from the Next 12 runtime (`__next`, `__NEXT_DATA__`); **5 from blog content** — `blog/[slug].js:272` slugifies each H2 into an anchor id; 1 from `react-youtube`'s empty default id | **No** | The Next ones are inert. The blog ones are your table-of-contents anchors — they work, they just start with a character a CSS selector cannot address |
| `imagesrcset` / `srcSet` attribute casing | 26 | `next/image` and its `<noscript>` fallback, via `seo.js:57`, `industryHeader.js:30`, `feature.js:60` | **No** | Nothing. HTML attribute names are case-insensitive; the validator is flagging the serialization |
| `color` attribute leaking onto a `<span>` | 15 | `web/components/button-new.js:22` — `Styled.Button` is a `styled.span` and the `color` prop passes through to the DOM. 1 from `privacy.js:44` | **No** | An unknown attribute in the markup. No crawler reads it |
| `<button>` has no `type` | 12 | `web/components/navigation.js:31` (the mobile menu toggle), `feature-section.js:50` and `:86` | **No** | Defaults to `type="submit"`. Harmless outside a form, which these are |
| Element in disallowed position | 8 | `web/pages/_app.js:124` — `<link rel="stylesheet">` for the fonts sits inside `<div id="__next">` rather than `<head>`. 2 from `feature-section.js` | **No** | The stylesheet still loads. `_app.js` cannot reach `<head>` without a `_document.js` |
| `<meta charSet>` casing | 7 | `web/components/seo.js:57` | **No** | Nothing. Case-insensitive |
| `<nav>` with no accessible name | 7 | `web/components/navigation.js:21`, `web/components/footer.js:22` | **No** | Two unlabelled `<nav>` landmarks per page |
| `<th>` has no `scope` | 6 | **Blog content** — `blog/[slug].js:184`, `TableRenderer` renders `<th key={i}>{cell}</th>` | **Yes, mildly** | Header cells are not bound to their columns, so a table's structure is weaker for anything parsing it. Affects the comparison tables |
| `<img>` with no `alt` attribute at all | 4 | **Blog content** — two posts have no `featureImage.altText` in Sanity: `hiring-gen-z` and `employer-branding-steps`. Each renders twice (`next/image` plus its `<noscript>` fallback) on `/blog` | **Yes** | Two cards on the blog index have images an answer engine cannot describe. Missing entirely is worse than `alt=""`, which at least declares the image decorative |
| Heading level skipped | 3 | `feature-section.js:74` and `:111` (`<h4>` directly after `<h2>`), `pricing.js:109`, and **blog content** where an `h4` is authored in Sanity with no `h3` above it | **Yes, mildly** | Breaks the document outline an answer engine uses to understand section hierarchy. Same class of defect as tab 17 |
| Invalid `size` / `radius` attributes on a `<span>` | 1 (4 elements) | `web/components/plato/platoMark.js:26` — `Styled.Chip` is a `styled.span` and both props leak to the DOM | **No** | Unknown attributes in the markup |
| `reversed` attribute on a `<section>` | 1 (3 elements) | `web/components/feature-old.js:40`, driven by `reversed={true}` at `about.js:76` | **No** | Unknown attribute |
| Unknown element `<bdt>` | 1 (506 elements) | `web/pages/privacy.js:44` — Termly's generated markup | **No** | An element no parser recognises, treated as an inline unknown. Cosmetically inert |
| Tags closed out of order | 1 (1214 errors) | `web/pages/privacy.js:44` — Termly's generated markup | **Yes** | The single worst item here. A parser recovering from 1214 mis-nested closes will build a DOM that does not match the intent, so anything extracting content from `/privacy` gets an unreliable tree |
| Raw `&` not encoded | 1 | `web/pages/privacy.js:44` — Termly's generated markup | **No** | Parsers recover |

---

## What actually matters

Four items, and three of them are content rather than code.

**1. `/privacy` is structurally broken.** 1214 out-of-order closing tags and 506 `<bdt>` elements, all from Termly's generated HTML pasted into `web/pages/privacy.js:44`. This is the only error in the set that could genuinely mislead a parser about what the page says. You have said the policy's edits are made in the codebase rather than regenerated in Termly, so this is fixable here.

**2. Two blog posts have no feature image alt text.** `hiring-gen-z` and `employer-branding-steps`, missing on both the published documents and the drafts. Both appear on `/blog` page 1. This is a Sanity content gap, not code — one field each.

**3. Six `<th>` cells have no `scope`.** `blog/[slug].js:184`. One attribute on one line, and it applies to every table in the blog, including the ATS comparison table.

**4. Three heading skips**, one of which is authored in Sanity content rather than in code.

Everything else on the list is framework noise: Emotion's style injection, Next's own runtime ids, attribute-case complaints that are not real, and props leaking to the DOM from styled components. None of it is read by a crawler.

## The `_document.js` observation

Three of the four largest counts — the inline `<style>` tags, the missing `lang`, and the misplaced font stylesheet — all exist because this project has no `web/pages/_document.js`. Adding one would resolve 64 of the 204 in a single file. None of those 64 affects SEO or AEO.
