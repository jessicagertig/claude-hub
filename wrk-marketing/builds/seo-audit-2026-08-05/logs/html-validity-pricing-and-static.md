# HTML validity — /pricing, /about, /changelog, /faq, /terms, /privacy, /404

Branch validated: `seo-phase-8-faq` at `c126cf0`.
Attribution boundary: `01bf615` (Merge pull request #46 from wrk-corp/plato-landing-page).

**Outcome: nothing on these seven routes is attributable to this engagement. No file was
edited. Every error listed below existed at `01bf615` and is reported only.**

## Server

`curl -s -o /dev/null -w "%{http_code}" http://localhost:3197/` returned `000` on the first
check, so I took a `mkdir`-based lock in the scratchpad and started to build. Between that
check and the checkout the shared working tree had already moved from
`seo-phase-6-images-links-headers` to `seo-phase-8-faq`, and a re-check showed
`next start -p 3197` running as pid 87897 with the port answering `200`. Another agent had
built and served it at 22:24. I released the lock and built nothing, started nothing,
stopped nothing. `startedServer: false`.

The long-running `next dev` on port 3000 (pid 93353) is Jessica's and was left alone.

## Validator

Two passes, because neither alone covers the brief.

1. `npx html-validate` 8.29.0 under Node 16.20.2, config at
   `/private/tmp/claude-501/-Users-jessica-claude-hub-wrk-marketing/ae83cb44-eb97-4453-99a4-0718b5a2e1c9/scratchpad/hv-pricing-static/.htmlvalidate.json`,
   extending `html-validate:recommended` and `html-validate:document`, with `wcag/h37`
   (missing `alt`), `heading-level`, `no-dup-id`, `element-permitted-content`,
   `element-required-attributes`, `attribute-allowed-values`, `input-missing-label` and
   `form-dup-name` forced to `error`.

2. A `parse5` 6.0.1 walker,
   `/private/tmp/claude-501/-Users-jessica-claude-hub-wrk-marketing/ae83cb44-eb97-4453-99a4-0718b5a2e1c9/scratchpad/hv-pricing-static/checks.js`,
   for the items html-validate has no rule for. A hrefless `<a>` is legal HTML, so
   html-validate will never report one; that is the exact defect this round exists to catch,
   which is why the second pass is not optional. The walker checks: `<a>` with no `href`,
   `a` inside `a`, `button`/`input`/`select`/`textarea` inside `a`, `a` inside `button`,
   block-level elements inside `<p>`, `<li>` whose parent is not `ul`/`ol`/`menu`,
   `<td>`/`<th>` whose parent is not `tr`, `<img>` with no `alt` attribute at all,
   `<h1>` count per document, duplicate `id`, `role` values against the ARIA 1.2 role list,
   `aria-*` names against the ARIA 1.2 attribute list with enumerated values checked, and
   attributes present on an element where that element does not define them (the
   React-prop-leak check).

A synthetic file confirmed the config is live: `<img src="x.png">` produced `wcag/h37`
and `<p><div>x</div></p>` produced `no-implicit-close` and `close-order`.

Served HTML was fetched with `curl` into
`.../scratchpad/hv-pricing-static/{pricing,about,changelog,faq,terms,privacy,404}.html`.
`/404` returned HTTP 404 with the 404 page body, which is correct.

## Clean — checked explicitly, zero found on all seven routes

- Anchors with no `href`: **0**. Also `href=""`: **0**.
- `a` inside `a`, `button`/`input`/`select`/`textarea` inside `a`, `a` inside `button`: **0**.
- Block-level elements inside `<p>`: **0**.
- `<li>` outside `ul`/`ol`, `<td>`/`<th>` outside `<tr>`: **0**.
- `<img>` with no `alt` attribute: **0**.
- `<h1>` count: exactly **1** on every route (`Pricing`, `About us`, `Changelog`,
  `Frequently asked questions`, `Terms of Service`, `Privacy policy`, `404`).
- Invalid `role` values, unknown or badly-valued `aria-*`: **0**.
- Form controls with no accessible name: no form controls on these routes. The only
  `<button>` shared by all seven is the nav toggle, which carries
  `aria-label="open the menu"`. `/pricing` adds the Monthly/Annual toggles, both with text.
- Duplicate `id`: **0** everywhere except `/privacy` (below). The three `JsonLd` script ids
  this engagement added (`organization`, `website`, `pricing-product`, `faq-page`) collide
  with nothing.

## Errors found, all pre-`01bf615`

### 1. `<html>` has no `lang` — all seven routes

`web/pages/_document.js` does not exist, so Next.js renders its default `Document` and the
`<html>` tag ships bare. `git ls-tree 01bf615 web/pages/` lists no `_document.js` either, and
this engagement did not add one. Fix would be a new `_document.js`; out of scope.

### 2. GTM `<noscript>` `<iframe>` has no `title` — all seven routes

    <iframe src="https://www.googletagmanager.com/ns.html?id=GTM-N6H844WJ" height="0" width="0" style="display:none;visibility:hidden"></iframe>

`web/pages/_app.js:254`. `git show 01bf615:web/pages/_app.js` has the identical block at line
224. The full `01bf615..HEAD` diff of `_app.js` is 30 added lines, all of them the
`organizationSchema`/`websiteSchema` constants and the two `<JsonLd>` elements. The iframe is
untouched.

### 3. Emotion emits `<style>` inside `<body>` — all seven routes

25 to 61 occurrences per route, under `<div>`, `<nav>`, `<section>`, `<header>`, `<footer>`,
`<button>`, `<li>` and `<ul>`. `<style>` is metadata content and is not permitted as flow
content; the W3C validator reports it the same way. This is `@emotion/react` SSR inserting a
`<style data-emotion="...">` beside every styled component, set up at
`web/pages/_app.js:241` (`<Global styles={globalStyles} />`) and produced by every
`styled.*` call in the codebase. Changing it means switching Emotion's extraction mode
across the whole site.

`/faq` is a page this engagement created, so its 31 `<style>` tags are new bytes. They are
new instances of a mechanism that predates `01bf615` and that every other page already
exhibits; the page uses `styled.div` exactly as the rest of the codebase does. Not fixable
without the site-wide change, so it is reported with the rest.

### 4. React props reaching the DOM as invalid attributes

`color="gradient"` and `color="black"` on `<span>`, twice per route on all seven:

    <span class="css-1xssoaz e5alsqi0" color="gradient">Sign up</span>
    <span class="css-au11tj e5alsqi0" color="black">Log in</span>

`web/components/button-new.js:44` declares `Styled.Button = styled.span(...)` and line 22
passes `color={color}`. `color` is a real HTML attribute on the obsolete `<font>`, so
`@emotion/is-prop-valid` forwards it and it lands on a `<span>`, where it is invalid. Callers
are `web/components/navigation.js:56,63,89,96`. Neither file appears in
`git diff --stat 01bf615..HEAD -- web/`.

`reversed=""` on `<section>`, three times on `/about`:

    <section reversed="" class="css-1yvpkyt-Feature e1seixtm2">
    <section reversed="" class="css-buqvfo-Feature_Pitch e1seixtm1">
    <section reversed="" class="css-1stz8i1-Feature_Screen e1seixtm0">

`web/components/feature-old.js:40,60,72` are all `styled.section` receiving `reversed`;
`reversed` is valid only on `<ol>`, so the same forwarding happens. Driven by
`reversed={true}` at `web/pages/about.js:76`. `feature-old.js` is not in the diff, and the
only change to `about.js` since `01bf615` is the `pageTitle` string on the `<SEO>` element.

### 5. `/pricing` skips h1 to h3

    <h1>Pricing</h1>  ...  <h3>Starter</h3>

`web/pages/pricing.js:109`, then 149, 188, 239. The first `<h2>`
(`All plans include everything you need`) is at line 254, after all four `<h3>`s.

`git show 01bf615:web/pages/pricing.js | grep -n "<h[1-4]"` returns the same five headings at
lines 72, 112, 151, 202, 217 — same tags, same text, same order. The engagement's 39-line
change to `pricing.js` is the `JsonLd` import, the `monthlyRate` helper, the `pricingSchema`
object, the `<JsonLd id="pricing-product">` element and the `pageTitle`/`editorialTitle`
swap. No heading was touched.

### 6. `/privacy` — the Termly export is not well-formed HTML

`web/pages/privacy.js` holds the whole policy as a template literal (`const html = ...`,
line 5 onward, with the body markup on line 44) rendered through `BasicPage`. Counts on the
served page:

| what | count |
|---|---|
| `<bdt>` (Termly's dynamic-text tag, not an HTML element) | 506 |
| `close-order` (end tag with open elements, stray end tags, unclosed elements) | 1214 |
| `no-implicit-close` (`<p>` closed by an adjacent `<div>`) | 35 |
| `<div>`/`<ul>`/`<tr>`/`<table>` inside `<span>` | 26 |
| duplicate `id="control"` | 13 (14 total) |
| raw `&` not encoded | 1 |

The duplicate id is Termly's, not Sanity's: `id="control"` sits on every numbered section
heading, so `#control` only ever reaches `1. WHAT INFORMATION DO WE COLLECT?` and the other
13 sections have no working in-page anchor.

Attribution is exact. The full `01bf615..HEAD` word-diff of `web/pages/privacy.js` is three
occurrences of `https://polymer.co/` becoming `https://www.polymer.co/` in an `href` and its
link text. Counted directly against the base:
`git show 01bf615:web/pages/privacy.js | grep -o '<bdt' | wc -l` gives 506 and HEAD gives
506; `id="control"` is 14 in both. Nothing structural changed.

Also worth naming though it is not a validity error: the policy's section headings are
`<span data-custom-class="heading_1">`, not real headings, so `/privacy` has an `<h1>` and
then no content headings at all — the only `<h2>`s on the page are the four footer column
headings.

## Reported as noise, not errors

- `attr-case`: `charSet="utf-8"` (`web/components/seo.js:57`, a context line in the diff, not
  changed) and `srcSet=` inside `next/image`'s `<noscript>` fallback on `/about` and
  `/changelog`. HTML attribute names are case-insensitive; these are not validity errors.
- `valid-id`: html-validate applies the HTML 4.01 "id must begin with a letter" rule and so
  flags `#__next`, `#__NEXT_DATA__` and the 85 changelog date anchors (`id="2026-01-31"` and
  the rest, from `web/pages/changelog.js:73`, unchanged from `01bf615:68`). HTML5 permits any
  id without ASCII whitespace, so these are valid. They are awkward in a CSS selector or
  `querySelector`, which needs escaping, but nothing on this site is styled by id.

## Files this engagement changed that render these routes

For the record, so the "no findings are ours" claim is checkable:
`web/pages/pricing.js` (+39), `web/pages/faq.js` (new, +205), `web/pages/changelog.js` (+7),
`web/pages/about.js` (1 line), `web/pages/terms.js` (1 line), `web/pages/privacy.js`
(3 URL swaps), `web/pages/_app.js` (+30), `web/components/seo.js` (+5),
`web/components/footer.js` (+5), `web/components/jsonLd.js` (new),
`web/components/softwareApplicationJsonLd.js` (new), `web/lib/sanityImage.js` (new).
`web/pages/404.js` was not changed.

Each was read against `01bf615`. The footer addition is
`<li><Link href="/faq"><a>FAQ</a></Link></li>` inside the existing `<ul>` — a well-formed
`<li>` with a real `href`. `jsonLd.js` emits a `<script type="application/ld+json" id={id}>`
into `<head>`, which is valid and collides with no other id. `changelog.js` added a `sizes`
attribute to a `next/image`, which is valid on `<img>`. Nothing in any of them produces an
error on these seven routes.
