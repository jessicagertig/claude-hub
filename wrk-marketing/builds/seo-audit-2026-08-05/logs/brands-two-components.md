# brands.js — two styled components (LogoLink / Logo)

## Outcome: STOPPED. Nothing committed, nothing pushed.

The refactor was written and built on `seo-phase-6-images-links-headers`. The
href verification failed with the exact JSX specified, so per the stop
condition the work was reverted and no branch was touched.

## What was built

`Styled.Logos` lost its `> *` and `> a:hover` blocks, leaving only the flex
container rules. Two new components were added following the file's existing
arrow-function form and `Brands_` label prefix:

- `Styled.LogoLink` — `styled.a`, five shared declarations plus `&:hover { opacity: 1; }`
- `Styled.Logo` — `styled.div`, five shared declarations, no hover

Render used the specified JSX exactly:

```js
return brand.href ? (
  <Link key={brand.alt} href={brand.href}>
    <Styled.LogoLink target="_blank" rel="noreferrer">
      {logo}
    </Styled.LogoLink>
  </Link>
) : (
  <Styled.Logo key={brand.alt}>{logo}</Styled.Logo>
);
```

Build on Node 16.20.2 was clean.

## The href does NOT survive

Served on port 3197, fetched `/`. All eight linked logos rendered as `<a>`
with `target` and `rel` but **no `href` attribute**:

```html
<a target="_blank" rel="noreferrer" class="css-xtpsf1-Brands_LogoLink ejj5umn1">
```

Makelog was correct:

```html
<div class="css-10r60l9-Brands_Logo ejj5umn0">
```

The emitted CSS was correct in both cases — `Brands_LogoLink` carried the five
declarations plus `:hover{opacity:1}`, `Brands_Logo` carried the five with no
hover rule.

### Cause

Not Emotion. `next/link` never passes `href` down. From
`web/node_modules/next/dist/client/link.js:219` (next 12.1.0):

```js
if (props.passHref || child.type === 'a' && !('href' in child.props)) {
    childProps.href = localeDomain || addBasePath(addLocale(as, curLocale, ...));
}
```

`child.type === 'a'` is true only for a literal `<a>` element. An Emotion
`styled.a` is a function component, so the test fails and `href` is never
added to `childProps`. Emotion would forward `href` fine — it just never
receives one. This is why the current `<a target="_blank" rel="noreferrer">`
works and the styled component does not.

## Verified fix (built and confirmed, then reverted)

Adding `passHref` to the `Link` is a one-word change and produces correct
markup. Rebuilt and re-served on 3197:

```html
<a target="_blank" rel="noreferrer" href="https://piratewires.com" class="css-xtpsf1-Brands_LogoLink ejj5umn1">
<a target="_blank" rel="noreferrer" href="https://tixel.com" class="css-xtpsf1-Brands_LogoLink ejj5umn1">
<a target="_blank" rel="noreferrer" href="https://getcampfire.com" class="css-xtpsf1-Brands_LogoLink ejj5umn1">
<a target="_blank" rel="noreferrer" href="https://filebase.com" class="css-xtpsf1-Brands_LogoLink ejj5umn1">
<a target="_blank" rel="noreferrer" href="https://eeetwell.com" class="css-xtpsf1-Brands_LogoLink ejj5umn1">
<a target="_blank" rel="noreferrer" href="https://joinleland.com" class="css-xtpsf1-Brands_LogoLink ejj5umn1">
<div class="css-10r60l9-Brands_Logo ejj5umn0">
<a target="_blank" rel="noreferrer" href="https://helium.com" class="css-xtpsf1-Brands_LogoLink ejj5umn1">
<a target="_blank" rel="noreferrer" href="https://ca.la" class="css-xtpsf1-Brands_LogoLink ejj5umn1">
```

Eight `<a>` with href, Makelog a `<div>` with none.

`passHref` is already the house form for this exact shape. `web/components/blogIndex.js`
wraps `Styled.Post` and `Styled.PageLink` (both `styled.a`) in `<Link ... passHref>`
at lines 23, 55, 60 and 67.

## Second option worth a decision

All eight hrefs are external absolute URLs opened with `target="_blank"`.
`next/link` contributes nothing to an external URL — no client-side routing,
no prefetch. Dropping the `Link` wrapper and putting the href straight on the
component removes the `passHref` subtlety entirely:

```js
return brand.href ? (
  <Styled.LogoLink key={brand.alt} href={brand.href} target="_blank" rel="noreferrer">
    {logo}
  </Styled.LogoLink>
) : (
  <Styled.Logo key={brand.alt}>{logo}</Styled.Logo>
);
```

This one was not built or served. Choosing between it and `passHref` is the
open decision.

## Branch state

| Branch | Edited | Built | Committed | Pushed |
|---|---|---|---|---|
| `seo-phase-6-images-links-headers` | reverted to clean | clean, twice | no | no |
| `seo-phase-7-final-report` | not touched | — | no | no |
| `seo-phase-8-faq` | not touched | — | no | no |
| `contact-page` | not touched | — | no | no |
| `small-business-industry-page` | not touched | — | no | no |

`seo-phase-6-images-links-headers` is checked out at 740728b with a clean
working tree. No worktree was entered, no symlink created, no `.env.local`
copied or read.

---

# Run 2 (2026-08-07) — shipped with `passHref`

## Outcome: DONE. All five branches committed and pushed.

The open decision from Run 1 was settled in favour of `passHref`, keeping the
`next/link` wrapper. The `Link`-less variant sketched under "Second option
worth a decision" was not built.

## The change

Identical on all five branches. `web/components/home/brands.js` ends at blob
`7597ab5f5b291808dc49e3e77aec9010c6ff0a00` on every one of them.

Render:

```js
return brand.href ? (
  <Link key={brand.alt} href={brand.href} passHref>
    <Styled.LogoLink target="_blank" rel="noreferrer">
      {logo}
    </Styled.LogoLink>
  </Link>
) : (
  <Styled.Logo key={brand.alt}>{logo}</Styled.Logo>
);
```

Two new components, both in the file's existing arrow-function form with
`const t = props.theme;` and the `Brands_` label prefix. `t` is unused in both,
which matches the house form — `Styled.Content` in `web/components/blogIndex.js`
declares `t` and never uses it either.

- `Styled.LogoLink` — `styled.a`, `label: Brands_LogoLink`, the five shared
  declarations plus `&:hover { opacity: 1; }`
- `Styled.Logo` — `styled.div`, `label: Brands_Logo`, the same five, no hover

The five declarations are written out in both. No mixin, no shared fragment,
no `styled(Styled.Logo)` inheritance.

`Styled.Logos` lost its trailing child-selector blocks and now ends at the
`${t.mq[56]}` breakpoint, holding only its flex-container rules.

## Per-branch starting point

`seo-phase-6-images-links-headers`, `seo-phase-7-final-report`,
`seo-phase-8-faq` and `contact-page` all started at blob
`f7281641933133665a2fd3eea3cf2721a49e37f3` — byte-identical files with the
`> *` / `> a:hover` container selectors and a `<div key={brand.alt}>` for
Makelog. Phase 6 was edited by hand; the resulting commit was replayed onto
phase 7 and phase 8 with `git am` and onto `contact-page` with `git apply`.

`small-business-industry-page` started at blob
`774a3fafbea18ada75e9cf3b2725dd5d1f8f3f37`, which still had the original
defect. Two differences from the other four, both removed in one step:

- Makelog rendered as `<a key={brand.alt}>{logo}</a>` — an anchor with no href
- `Styled.Logos` styled its children through a descendant `a { ... }` block
  with a nested `&[href]:hover` guard, rather than `> *` plus `> a:hover`

Its file was edited directly and lands on the same blob as the other four.

## Served-markup verification

Every branch was built on Node 16.20.2, served with `next start -p 3197`, and
`/` was fetched and read. All five produced the same nine elements:

```html
<a target="_blank" rel="noreferrer" href="https://piratewires.com" class="css-xtpsf1-Brands_LogoLink ejj5umn1">
<a target="_blank" rel="noreferrer" href="https://tixel.com" class="css-xtpsf1-Brands_LogoLink ejj5umn1">
<a target="_blank" rel="noreferrer" href="https://getcampfire.com" class="css-xtpsf1-Brands_LogoLink ejj5umn1">
<a target="_blank" rel="noreferrer" href="https://filebase.com" class="css-xtpsf1-Brands_LogoLink ejj5umn1">
<a target="_blank" rel="noreferrer" href="https://eeetwell.com" class="css-xtpsf1-Brands_LogoLink ejj5umn1">
<a target="_blank" rel="noreferrer" href="https://joinleland.com" class="css-xtpsf1-Brands_LogoLink ejj5umn1">
<div class="css-10r60l9-Brands_Logo ejj5umn0">
<a target="_blank" rel="noreferrer" href="https://helium.com" class="css-xtpsf1-Brands_LogoLink ejj5umn1">
<a target="_blank" rel="noreferrer" href="https://ca.la" class="css-xtpsf1-Brands_LogoLink ejj5umn1">
```

Eight `<a>` each carrying `href`, `target="_blank"` and `rel="noreferrer"`.
Makelog a `<div>` with no `href`. This is the check Run 1 failed; `passHref`
is what fixes it.

Emitted CSS, checked on phase 6 and on `small-business-industry-page`:

```css
.css-xtpsf1-Brands_LogoLink{display:flex;align-items:center;justify-content:center;opacity:0.7;transition:opacity 0.2s ease;}
.css-xtpsf1-Brands_LogoLink:hover{opacity:1;}
.css-10r60l9-Brands_Logo{display:flex;align-items:center;justify-content:center;opacity:0.7;transition:opacity 0.2s ease;}
```

(vendor prefixes elided above; they are present and unchanged)

Both classes carry the five declarations. Only `Brands_LogoLink` has a hover
rule, so hover brightens the eight links and not Makelog. `Brands_Logos` emits
only its flex rules and the two breakpoint overrides — `gap: 1.5rem 2rem`,
then `2rem 2.5rem`, then `nowrap` / `40px` — with zero occurrences of
`Brands_Logos>*` or `Brands_Logos>a:hover` in the served HTML. Centering,
opacity, transition and gaps are all unchanged from before.

## Branch state

Each branch: checked out, edited, built clean, served and verified, committed,
pushed. Local and remote match on all five.

| Branch | Commit | Build | Pushed |
|---|---|---|---|
| `seo-phase-6-images-links-headers` | `0fda03c` | clean | yes |
| `seo-phase-7-final-report` | `0d97bf1` | clean | yes |
| `seo-phase-8-faq` | `c126cf0` | clean | yes |
| `contact-page` | `ccd8908` | clean | yes |
| `small-business-industry-page` | `83961d6` | clean | yes |

Commit message on all five: `Split brand logos into linked and unlinked styled components`

## Worktree handling

`contact-page` and `small-business-industry-page` were built in their existing
worktrees. For each: `web/node_modules` was symlinked to
`/Users/jessica/wrk/wrk-corp/wrk-marketing/web/node_modules`, the main
checkout's `.env.local` was sourced into the build shell's environment only,
the build and the serve ran, then the symlink was removed before committing.
No `.env.local` was copied into either worktree and no token was written to
any file, log or commit. Both worktrees are clean and neither has a
`web/node_modules` entry now.

The main checkout is back on `seo-phase-6-images-links-headers` with a clean
tree. No `next start` process is left running on 3197. Nothing below phase 6
was touched, and `web/components/quote.js` was not touched on any branch.
