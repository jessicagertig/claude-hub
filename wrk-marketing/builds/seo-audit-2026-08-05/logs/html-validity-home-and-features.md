
---

# HTML validity, routes `/`, `/features`, `/features/jobboard`, `/features/candidate-management-software`, `/plato`

Agent: home-and-features. Branch validated: `seo-phase-8-faq` at `c126cf0`. Attribution boundary: `01bf615` (`Merge pull request #46 from wrk-corp/plato-landing-page`, Fri Jul 31 2026), confirmed an ancestor of `seo-phase-8-faq`.

## Server

Port 3197 answered `000` when I checked, so nothing was serving. I took a lock directory in the shared scratchpad, checked out `seo-phase-8-faq` in `/Users/jessica/wrk/wrk-corp/wrk-marketing` (working tree was clean on `seo-phase-6-images-links-headers`), built with Node 16.20.2, and started `npx next start -p 3197`. **I am the agent that started the server on 3197.** It is still running; the checkout is left on `seo-phase-8-faq`.

## Validator

`html-validate` 7.18.1, installed with `npm install html-validate@7 --no-save` into the scratchpad and driven through its Node API rather than the CLI, so I could disable the formatting rules that would drown generated markup in noise.

Config: `extends: ["html-validate:recommended"]`, plus `heading-level`, `input-missing-label`, and `no-missing-references` turned on (none are in the recommended preset). Turned off: `attr-case`, `attr-delimiter`, `attr-quotes`, `attr-spacing`, `attribute-boolean-style`, `attribute-empty-style`, `doctype-style`, `element-case`, `no-dup-class`, `no-inline-style`, `no-raw-characters`, `no-self-closing`, `no-trailing-whitespace`, `no-utf8-bom`, `prefer-tbody`, `script-type`, `tel-non-breaking`, `long-title`, `void-style`, `void`, `require-sri`, `no-unused-disable`. Every one of those is a source-formatting preference that says nothing about the validity of machine-generated HTML.

`html-validate` 7.18 has no rule for several items on the checklist, so I wrote explicit checks alongside it in the same pass: anchors with no `href` attribute at all, `img` with no `alt` attribute at all, duplicate `id` values, `role` values checked against the ARIA 1.2 role list, `aria-*` names checked against the defined attribute set with per-attribute value domains (boolean, tristate, true/false/undefined, and the enumerated ones), `h1` count, and a stack-based scan for interactive elements nested inside each other plus form controls with no accessible name. I also collected every distinct `tag|attribute` pair per page and reviewed the list by hand for attributes React had passed through.

Scripts: `scratchpad/validate.js` (phase 8) and `scratchpad/validate-baseline.js` (01bf615). Raw output: `scratchpad/raw-validation.json` and `scratchpad/raw-validation-baseline.json`.

## Attribution method

Two independent passes, and I only trusted a finding's attribution when both agreed.

**Pass 1, git.** For every source file the served markup traced back to, `git diff --stat 01bf615..seo-phase-8-faq -- <path>`. An empty result means the file is byte-identical to the baseline and nothing in it can be this engagement's doing. For the files that did change, I read the full diff and checked whether the specific line producing the error was a context line or a `+` line. Then `git blame -L <line>,<line> seo-phase-8-faq -- <path>` on each implicated line, and `git merge-base --is-ancestor <commit> 01bf615` on the blamed commit to place it on the correct side of the boundary:

| Source line | Blamed commit | Side | Commit |
|---|---|---|---|
| `web/components/plato/platoMark.js:26` | `e140d4fd` | PRE | feat(plato): add Plato landing page with animated hero, 2026-07-24 |
| `web/components/feature-section.js:275` | `79b5b87f` | PRE | revamp features page, 2025-12-15 |
| `web/components/feature-section.js:372` | `79b5b87f` | PRE | revamp features page, 2025-12-15 |
| `web/components/feature-section.js:392` | `79b5b87f` | PRE | revamp features page, 2025-12-15 |
| `web/components/feature-section.js:408` | `79b5b87f` | PRE | revamp features page, 2025-12-15 |
| `web/components/feature-section.js:574` | `79b5b87f` | PRE | revamp features page, 2025-12-15 |
| `web/components/navigation.js:151` | `619212d8` | PRE | Update marketing page designs, 2025-12-09 |
| `web/pages/_app.js:124` | `df20c5d1` | PRE | add referrals, 2024-09-08 |
| `web/pages/_app.js:254` | `df20c5d1` | PRE | add referrals, 2024-09-08 |

For the missing `<html lang>`, the thing to attribute is an absence, which blame cannot see. `git log --all -- web/pages/_document.js` returns nothing: the file has never existed on any branch, so Next.js has always rendered its default `<html>`. `web/next.config.js` has no `i18n` key at `01bf615` or now. The attribute has never been emitted.

**Pass 2, baseline build.** File-level git attribution is only as good as my reading of the diff, and the failure that prompted this round (Phase 6 removing two `href`s and leaving the `<a>` elements) was exactly a case of reading a diff and missing what it produced. So I built `01bf615` and validated it identically. `git archive 01bf615 | tar -x` into `scratchpad/baseline`, symlinked the existing `web/node_modules`, and built with Node 16.20.2. The first build died in `getStaticPaths` with `` `dataset` must be provided to perform queries `` because the Sanity credentials live in a gitignored env file. Rather than copy env values around, I deleted `pages/blog`, `pages/blog.js`, and `pages/changelog.js` from the extracted copy: none of my five routes need them, and Next does not fail a build over `next/link` targets that have no page. Second build succeeded. Served on 3198, fetched the same five routes, ran the same validator.

Then a per-message set diff between the two runs, keyed on rule plus message plus CSS selector. That is what makes the conclusion falsifiable instead of a claim about what I think the diff does.

## Result of the baseline diff

| Route | 01bf615 | seo-phase-8-faq | Delta |
|---|---|---|---|
| `/` | 70 | 72 | +2 |
| `/features` | 117 | 117 | 0 |
| `/features/jobboard` | 61 | 61 | 0 |
| `/features/candidate-management-software` | 59 | 59 | 0 |
| `/plato` | 211 | 210 | -1 |

Every difference resolves to one of three things.

**Added, 3 total.** Three new `<style>` elements in the body, one per new styled component: `Styled.LogoLink` and `Styled.Logo` in `web/components/home/brands.js` (the Phase 6 hrefless-anchor fix, which split the brand logo list into a linked and an unlinked variant) and `Styled.Heading` in `web/components/plato/platoHero.js`. These are not markup anyone wrote. `@emotion/react` inserts a `<style data-emotion="...">` tag inline next to each styled component during SSR because there is no `web/pages/_document.js` giving Emotion an `extractCritical` or `CacheProvider` hook. Declaring a styled component in this codebase produces one of these unavoidably. The pattern accounts for 49 of the 72 findings on `/` and 166 of the 210 on `/plato`, and it was there at `01bf615` in the same proportion.

**Removed, 2.** On `/plato`, `x/no-h1` and `heading-level` "Initial heading level must be `<h1>` but got `<h2>`". The visually-hidden `<h1>` added at `web/components/plato/platoHero.js:95` fixed both. `/plato` is the only route whose validity improved.

**Shifted, the rest.** Selector index renumbering. On `/`, `/features/jobboard`, and `/features/candidate-management-software` the hrefless preload `<link>` moved from `link:nth-child(21)` or `:nth-child(26)` to `:nth-child(29)` or `:nth-child(30)` because this engagement added a canonical `<link>` and three `ld+json` `<script>` elements to `<head>`. On `/plato`, roughly forty `<style>` selectors moved from `section:nth-child(4) > div:nth-child(4)` to `div:nth-child(6)` because the new `<h1>` is now the section's first child. Same elements, same errors, different ordinals.

**Nothing was fixed and nothing was touched.** There was nothing in scope to fix.

## What each finding actually is

The instruction was to report invalid markup, so I separated genuine HTML conformance errors from `html-validate` opinions and from WCAG failures. All of these are pre-existing; the distinction matters for whoever decides what to do about them later.

Real conformance errors, in the sense that the W3C Nu validator would also reject them:

- `<style>` in the body. Per WHATWG, `style` is metadata content, permitted in `head` or in a `noscript` that is a child of `head`. Emotion SSR, every route, hundreds of instances.
- `<h3>` and `<p>` inside `<button>` on `/features`, 12 each. `button`'s content model is phrasing content; both are flow-only. `Styled.TabTitle` (`styled.h3`, line 392) and `Styled.TabDescription` (`styled.p`, line 408) sit inside `Styled.Tab` (`styled.button`, line 372) in `web/components/feature-section.js`, all from `79b5b87f` in December 2025. This is the "block-level elements inside `<p>`" hazard in its other form: the browser reparents and React hydrates badly.
- `<span size="32" radius="9">` on `/plato`, 4 instances. `radius` is not an HTML attribute on any element and `size` is valid only on `input` and `select`. `PlatoChip` at `web/components/plato/platoMark.js:26` passes `size` and `radius` into `Styled.Chip`, a `styled.span`, and Emotion forwards unknown lowercase props to the DOM. The fix would be transient props or `shouldForwardProp`. From `e140d4fd`, the Plato landing page commit of 2026-07-24, six days before the boundary. `html-validate` does not catch this; my attribute-name sweep did.

WCAG failures rather than conformance errors, meaning the markup parses fine but fails an accessibility criterion:

- `<html>` with no `lang`, every route. WCAG 3.1.1.
- The GTM `<iframe>` with no `title` at `web/pages/_app.js:254`, every route. WCAG 4.1.2.
- Four `h2` to `h4` skips on `/features`, from `Styled.TraitTitle` (`styled.h4`, line 574) following `Styled.HeaderTitle` (`styled.h2`, line 186) with no `h3` between them in the mobile-tab layout.

`html-validate` findings that are not errors under the current spec, which I am flagging so nobody spends time on them:

- `<button>` with no `type`, 25 on `/features` and 1 elsewhere. `type` defaults to `submit`; omitting it is conforming. It matters only inside a `form`, and none of these are.
- `<link href="/fonts/style.css" rel="stylesheet">` inside `<div id="__next">`. WHATWG lists `stylesheet` among the body-ok `rel` values, so a stylesheet link in the body is conforming. `html-validate` 7 does not model body-ok.
- `<link rel="preload" as="image" imagesrcset="...">` with no `href`. WHATWG explicitly permits omitting `href` when `rel` contains `preload`, `as` is `image`, and `imagesrcset` is present. Emitted by `next/image` for the three routes with a `priority` hero image.
- `valid-id` on `#__next` and `#__NEXT_DATA__`. HTML5 permits any `id` with no ASCII whitespace; `html-validate` additionally wants a leading letter. Both ids are Next.js's.

## Checklist items that came back clean

- **Anchors with no `href`:** zero, all five routes. The Phase 6 regression is gone. `web/components/home/brands.js` now renders `Styled.Logo`, a `div`, for the one brand with no `href` (Makelog), and `web/components/quote.js` renders `Styled.Content` bare when `props.to` is absent instead of wrapping it in an `<a href={undefined}>`.
- **Duplicate ids:** zero. Only two ids exist anywhere on these routes, `__next` and `__NEXT_DATA__`, both framework-generated. The blog-heading collision the brief describes cannot occur here; these routes render no Portable Text.
- **Interactive nesting:** zero. No `a` in `a`, no `button` in `a`, nothing.
- **Block-level inside `<p>`:** zero. Both `no-implicit-close` and `element-permitted-content` stayed silent for `p`. The one `<p>` this engagement changed is `web/components/jobBoard/features.js:32`, which adds a `next/link` to a blog post inside a `Feature` description. It serves as `<p class="css-hjle0f-Feature_Description e191q7j93">See how it compares to<!-- --> <a href="/blog/best-job-board-software">other job board software</a>.</p>`, phrasing content throughout, with the `<a>` correctly generated because `next/link` wraps a bare string child.
- **`<li>` outside a list, `<td>`/`<th>` outside a row:** zero, `element-required-ancestor` silent.
- **Images with no `alt` attribute:** zero. `next/image`'s placeholder carries `alt="" aria-hidden="true"` and every content image has a non-empty `alt`.
- **`<h1>` count:** exactly one per route. `/plato` had none at `01bf615`.
- **`aria-*` values and `role` values:** zero problems. No `role` attribute appears on any of these five routes at all.
- **Form controls with no accessible name:** not applicable. These routes contain no `input`, `select`, or `textarea`. `/contact` is another agent's route.
- **React pass-through attributes:** one case, the `PlatoChip` `size`/`radius` pair above. Every other unusual-looking attribute in the sweep is a legitimate SVG attribute (`stroke-width`, `clip-rule`, `fill-rule`, `gradientUnits`, `shape-rendering`, `stop-color`, `rx`, `ry`, `offset`, `mask`).

## Artifacts

- Findings: `/private/tmp/claude-501/-Users-jessica-claude-hub-wrk-marketing/ae83cb44-eb97-4453-99a4-0718b5a2e1c9/scratchpad/html-validity-findings-home-and-features.json`
- Served HTML, phase 8: `scratchpad/served-html/`
- Served HTML, `01bf615`: `scratchpad/baseline-html/`
- Raw validator output: `scratchpad/raw-validation.json`, `scratchpad/raw-validation-baseline.json`
- Validator scripts: `scratchpad/validate.js`, `scratchpad/validate-baseline.js`
- Build logs: `scratchpad/build-phase8.log`, `scratchpad/build-baseline.log`
- Baseline tree: `scratchpad/baseline/`. Its server on 3198 is stopped. The phase 8 server on 3197 is left running for the other agents in this round.
