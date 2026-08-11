# HTML validity, the seven /applicant-tracking-for-* routes

Branch `seo-phase-8-faq` at `c126cf0`. Boundary commit `01bf615`.

## Outcome

Nothing to fix. Every validity error the seven pages emit was already there at `01bf615`, so all of it is reported and none of it touched. No file was edited.

## Server

`curl -s -o /dev/null -w "%{http_code}" http://localhost:3197/` answered `000` on the first two checks, and the shared scratchpad held a `build-3197.lock` directory created seconds earlier, so another agent was mid-build. I polled instead of racing it and the port answered `200` fifteen seconds later. The checkout `/Users/jessica/wrk/wrk-corp/wrk-marketing` was on `seo-phase-8-faq` at `c126cf0` with `web/.next/BUILD_ID` = `_2vESNSNSehNd2wV171Oh` written at the same minute, so the served build is the right branch. **I did not build and did not start or stop anything.**

## Validator

Two passes, because no single off-the-shelf validator covers the whole list.

1. `npx html-validate@8` (8.29.0), config at `/private/tmp/claude-501/-Users-jessica-claude-hub-wrk-marketing/ae83cb44-eb97-4453-99a4-0718b5a2e1c9/scratchpad/industries-validity/.htmlvalidate.json`, extending `html-validate:recommended`, `html-validate:document` and `html-validate:a11y`. I turned off only cosmetic rules (`attr-quotes`, `void-style`, `attribute-boolean-style`, `no-trailing-whitespace`, `long-title`, `require-sri`, `no-inline-style`). The resolved rule set (verified with `--print-config`) includes `no-dup-id`, `heading-level`, `element-permitted-content`, `element-required-ancestor`, `element-permitted-parent`, `wcag/h37`, `input-missing-label`, `attribute-allowed-values`, `no-abstract-role`, `unique-landmark` and `no-implicit-button-type`, which covers duplicate ids, heading skips, block-in-`p`, orphan `li`/`td`/`th`, missing `alt`, unlabelled form controls and bad `aria-`/`role` values.

2. A parse5 6 script at `/private/tmp/claude-501/-Users-jessica-claude-hub-wrk-marketing/ae83cb44-eb97-4453-99a4-0718b5a2e1c9/scratchpad/industries-validity/checks.js` for the four items html-validate does not flag: anchors with no `href` at all (valid HTML, so no rule covers it, and it is the exact Phase 6 defect this round exists for), `<h1>` count per page, `role`/`aria-` token validity checked against my own lists, and attributes React passed through that are not valid on the element they landed on.

Served HTML is saved under `.../industries-validity/html/`, raw html-validate output in `raw.json`, explicit-check output in `checks.json`.

## What came back clean

Across all seven routes: no anchor without `href`, no duplicate `id`, no nested interactive elements, no block-level element inside `<p>`, no `<li>` outside a list, no `<td>`/`<th>` outside a row, no `<img>` missing its `alt` attribute, no heading level skip, exactly one `<h1>` per page, no invalid `aria-` value and no unreal `role`. There are no form controls on these routes.

The seven pages produce a byte-for-byte identical error *set* (78 instances each, same rules, same elements), which is expected: they are the same component tree with different copy.

## The errors, all pre-existing

### `<html>` has no `lang` (1 per page)

`web/pages/_document.js` is absent at `01bf615` and absent at HEAD, so `<html>` comes from the Next.js 12.1.0 default Document, which emits no `lang`.

### `<meta charSet="utf-8"/>` (1 per page)

`web/components/seo.js:57`. `git show 01bf615:web/components/seo.js` has the identical line at 55. HTML attribute names are case-insensitive, so this is a lint preference, not a parse error.

### `<link rel="preload" as="image" imagesrcset="..." imagesizes="...">` has no `href` (1 per page)

`web/components/industries/industryHeader.js:30-37` via `next/dist/client/image.js:662-665`. next/image 12.1.0 writes `href: imgAttributes.srcSet ? undefined : imgAttributes.src`, so a priority preload never gets an `href` once a srcSet exists. `priority={true}` and `layout="responsive"` are both present at `01bf615`. This engagement added only the `sizes` prop, which feeds `imagesizes`, not `href`. Worth noting separately: the HTML spec allows `href` to be absent on `rel=preload` `as=image` when `imagesrcset` is present, so html-validate is stricter than the spec here.

### `id="__next"` and `id="__NEXT_DATA__"` do not begin with a letter (2 per page)

Both emitted by Next.js 12.1.0 itself. `next` is `12.1.0` in `git show 01bf615:web/package.json` and unchanged.

### `<style>` is not permitted as content under `<div>`/`<section>`/`<header>`/`<nav>`/`<button>`/`<footer>` (56 per page)

Emotion server-side style insertion. `@emotion/react` `^11.8.2` and `@emotion/styled` `^11.8.1` are in `git show 01bf615:web/package.json` lines 12-13. Emotion SSR writes a `<style data-emotion>` tag immediately before each styled element, which puts it in `<body>`. This is the single largest count and it is entirely the styling system.

### Two `<nav>` landmarks with no accessible name (2 per page)

`web/components/navigation.js:21` (`Styled.Nav`, `styled.nav` at :117) and `web/components/footer.js:22` (`Styled.Nav`, `styled.nav` at :310). `git show 01bf615:web/components/navigation.js` has both the element and the styled definition with no `aria-label`; same for `footer.js`. `git diff 01bf615..HEAD -- web/components/navigation.js` is empty. The only `footer.js` change since `01bf615` adds an `<li>` FAQ link *inside* that nav; it neither creates the nav nor removes a name it never had.

### `<button aria-label="open the menu">` has no `type` (1 per page)

`web/components/navigation.js:31` (`Styled.Toggle`, `styled.button` at :151). Present at `01bf615`; `navigation.js` is unchanged since.

### `srcSet` should be lowercase (4 per page)

All four are next/image `<img>` elements, from `web/components/industries/industryHeader.js:30` and `web/components/feature.js:60-68`. `layout="responsive"` produces a srcSet regardless of the `sizes` prop (`node_modules/next/dist/client/image.js:209`), and `layout="responsive"` is on both `<Image>` elements at `01bf615`. Case-insensitive attribute name, so cosmetic.

### GTM `<noscript><iframe>` has no `title` (1 per page)

`web/pages/_app.js:253-261`. `git show 01bf615:web/pages/_app.js` lines 223-231 are the same iframe with no `title`.

### `color` attribute on `<span>` (9 per page)

`web/components/button-new.js:22` and `:44`. `Styled.Button = styled.span`, and Emotion forwards `color` to the DOM because `@emotion/is-prop-valid` treats `color` as a valid HTML prop. It is valid on `<font>`, `<hr>` and `<basefont>`, not on `<span>`. The nine per page break down as `web/components/navigation.js:56`, `:63`, `:89`, `:96` (Log in and Sign up, rendered once in `Styled.NavButtons` and once in the mobile menu), `web/components/industries/industryHeader.js:21` (the hero CTA), `web/components/feature.js:42` (three Learn more buttons, one per feature), and `web/components/start.js:33` (the closing CTA).

Attribution: `git diff 01bf615..HEAD -- web/components/button-new.js` is empty, as are the diffs for `navigation.js`, `start.js` and `challenges.js`; the only `industryHeader.js` change is the `sizes` prop. `git blame web/components/feature.js` puts `color="black"` on line 42 at commit `619212d8` (2025-12-09), well before `01bf615`.

## What this engagement did change on these routes, and why none of it is in the list above

`git diff 01bf615..HEAD` touches, inside this route tree: the seven page files (a literal `metaDescription`, a `pathname` fix on legal-services, an `IndustryJsonLd` element, and one benefits-copy edit each), `web/components/industryJsonLd.js` and `web/components/jsonLd.js` (new, both render `<script type="application/ld+json">` into `<Head>`), `web/components/seo.js` (canonical link, title suffix), `web/pages/_app.js` (organization and website JSON-LD), `web/components/industries/industryHeader.js` (`sizes`), `web/components/feature.js` (`sizes`, a React `key` fix, and an `a` rule inside the description style block), and `web/components/footer.js` (an `<li>` FAQ link).

The four `id` values this engagement introduced into the served head are `organization`, `website`, `industry-service` and `industry-breadcrumb`. All begin with a letter and none collide with each other or with anything else on the page, which the `no-dup-id` and `valid-id` results confirm.

The `<li>` added to the footer sits directly inside the existing `<ul>` and wraps a next/link `<a>` that renders with `href="/faq"`, so it is neither an orphan `li` nor an hrefless anchor.
