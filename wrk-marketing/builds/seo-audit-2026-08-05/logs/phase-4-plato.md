# Phase 4, item 3 — /plato missing H1

Branch: `seo-phase-4-metadata-headings` (already checked out; nothing committed, nothing pushed, no branch created).
Owned files: `web/pages/plato.js`, `web/components/plato/*` — nothing outside that scope was touched.

## Rows applied

| Tab | Row | URL | Action |
|---|---|---|---|
| 17 Headings | 7 | https://www.polymer.co/plato | MISSING H1 → added, exact prescribed wording |
| 07 Title Rewrites | 9 | https://www.polymer.co/plato | title rewrite → `pageTitle` prop updated |
| 12 Meta Rewrites | — | — | no `/plato` row exists on tab 12; nothing to apply |

Tab 12's nine data rows are the seven `/industries/` pages, `/blog/first-impression-bias`, and `/terms`. `/plato` is not among them, so the existing `metaDescription` on `web/pages/plato.js` is untouched.

## Change 1 — the H1

**File:** `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/components/plato/platoHero.js`

Added as the first child of `Styled.Section`, ahead of `Styled.Glow`:

```jsx
<Styled.Heading>Plato: AI candidate screening built into your ATS</Styled.Heading>
```

and the styled component, placed directly after `Styled.Section` in the `Styled` block at the bottom of the file:

```js
// Visually hidden, not display:none — the hero's visual title is an animated
// non-heading, so the page's h1 is served to every agent but not painted.
Styled.Heading = styled.h1`
  label: PlatoHero_Heading;
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0 0 0 0);
  white-space: nowrap;
  border: 0;
`;
```

### Copy fidelity

The heading text is byte-for-byte cell C7's prescribed copy, `Plato: AI candidate screening built into your ATS` — 49 characters, pure ASCII, sentence case as written. The single quotes surrounding it in the cell are the auditor's quoting and are not part of the heading, per tab 17's own read note. Nothing was rewritten, recased, or shortened.

### Rendering — visually hidden, per the approved decision

The visually-hidden pattern was used exactly as prescribed. `display: none`, `visibility: hidden`, `font-size: 0` and background-matched text were all avoided — those are cloaking. This log does not re-open the decision; it is recorded as entry 1 in `/Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/QUESTIONS-FOR-SHAWN.md`, which I read first, and this implementation matches what that entry says was shipped (exact wording, `position: absolute; width: 1px; height: 1px; clip: rect(0 0 0 0)`, in the DOM and served identically to every agent).

### Placement — verified first in document order

`web/pages/plato.js` renders, in order: `<SEO>` (`next/head` only, no body output), `<Navigation />`, `<PlatoHero />`, `<PlatoDescription />`, `<PlatoFeatures />`, `<PlatoFilter />`, `<PlatoPrivacy />`, `<PlatoVideo />`, `<Start />`.

Heading elements on the page, found by grepping `styled.h1|h2|h3|h4`, `<h1`–`<h3` and `as="h` across `web/components/plato/`, `web/components/navigation.js` and `web/components/start.js`:

- `components/navigation.js` — **no heading element at all**, so nothing precedes the hero.
- `components/plato/platoHeroCard.js:165` — `Styled.Headline = styled.h2` — this was the page's **first** heading before this change.
- `components/plato/platoCandidateRecord.js:209` and `:502` — `styled.h3`.
- `components/plato/platoFeature.js:131`, `platoFilter.js:138`, `platoPrivacy.js:125`, `components/start.js:105` — `styled.h2`.

Inside `PlatoHero`'s JSX the new `<h1>` is the first child of `Styled.Section`, which is the component's root element — so it precedes `Styled.Stage`, `Styled.Grid`, `Styled.CardWrap`, and therefore precedes `PlatoHeroCard`'s `<h2>`. The page's heading order is now h1 → h2 → h3, not h2 → h3.

### The hero already had no heading element

`Styled.EyebrowTitle`, `Styled.Eyebrow` and `Styled.Title` ("**Plato** by Polymer") are all `styled.div` — the hero's visible title is not, and was not, a heading element. `Styled.HookLine` and `Styled.HookAnswer` are `div` too. So the new `<h1>` displaces nothing and creates no duplicate-heading conflict with the animated title.

### Analogs read before writing

Three existing heading components in the same directory, plus the file being edited:

- `components/plato/platoPrivacy.js:125` — `Styled.Title = styled.h2((props) => { const t = props.theme; return css\`label: PlatoPrivacy_Title; ...\`; })`
- `components/plato/platoFilter.js:138` — same function form, `label: PlatoFilter_Title`
- `components/plato/platoHeroCard.js:165` — `Styled.Headline = styled.h2\`label: PlatoHeroCard_Headline; ...\`` — plain tagged-template form, no theme destructure

Both forms are house style. The function form (`const t = props.theme`) is used when the component reads the theme; the plain tagged-template form when it does not. The new `Styled.Heading` reads no theme value — the visually-hidden rule set is entirely fixed lengths — so it takes the plain form, matching `Styled.Glow`, `Styled.Stage`, `Styled.Eyebrow` and `Styled.Title` in the same file. It carries a `label:` first, sits on the `const Styled = {}` object at the bottom of the file, and is declared in the same order it appears in the JSX (immediately after `Styled.Section`, before `Styled.Glow`).

A repo-wide grep for an existing visually-hidden helper (`clip: rect`, `sr-only`, `visually`, `screen-reader`, `srOnly`, `VisuallyHidden`) across all `.js` and `.css` outside `node_modules` returned nothing — there was no existing utility to reuse, so the rule set is inline on the one component that needs it. No shared helper, mixin or util file was created for a single use.

`Styled.Section` is `position: relative; overflow: hidden`, so the absolutely-positioned 1px heading is contained by the hero section and cannot affect layout. `Styled.Section` is not a flex or grid container at the level the heading sits, so it adds no track and no flex item that would shift the existing children.

## Change 2 — the title tag

**File:** `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/pages/plato.js`, line 16

```diff
-        pageTitle="Plato AI"
+        pageTitle="Plato AI - AI Candidate Screening & Resume Review"
```

Tab 07 row 9 prescribes the rendered title `Plato AI - AI Candidate Screening & Resume Review | Polymer` (59 chars). `web/components/seo.js` line 17-19 reads:

```js
pageTitle: pageTitle
  ? pageTitle + " | Polymer"
  : "Polymer: Hiring made simple",
```

so the prop must be the prescribed value **minus** the ` | Polymer` suffix, which is what was passed. Verified by computation: prop = 49 chars, prop + `" | Polymer"` = 59 chars, an exact character-for-character match to cell E9. **Under the tab's own 60-char limit** — this row is not one of the four the tab-07 reader flagged as breaching the limit after the append (those are sheet rows 7, 10, 17, 19).

The dash is ASCII hyphen-minus U+002D and the ampersand is a literal `&`, both as the cell holds them. Casing is the cell's title case, verbatim.

`editorialTitle`, `metaDescription`, `image` and `pathname` on the same `<SEO>` call were left exactly as they were — no tab row prescribes a change to any of them for `/plato`.

## Verification

- `./node_modules/.bin/eslint components/plato/platoHero.js pages/plato.js` from `web/` — exit 0, no errors, no warnings (only an unrelated global `caniuse-lite is outdated` notice).
- `git diff` reviewed: exactly two files changed, 17 insertions, 1 deletion, no incidental reformatting.

## Not done, deliberately

- No commit, no push, no branch created.
- No test and no spec written.
- No file outside `web/pages/plato.js` and `web/components/plato/` touched. In particular `web/components/seo.js` was read but **not** edited — the homepage default-string question on tab 07 row 7 belongs to another item.
- Tab 17 rows 8-18 (`/pricing` duplicate H2, the ToC and CTA H2 rows on nine blog posts) are not mine and were not touched. Row 8 prescribes no change in any case ("Fine to keep; low priority").
- Nothing appended to `BLOCKED.md`; not blocked.
- Nothing appended to `QUESTIONS-FOR-JESSICA.md` — this item raised no open question. The one judgement call, visible vs. visually-hidden, was decided before the item started and is already recorded for Shawn.
