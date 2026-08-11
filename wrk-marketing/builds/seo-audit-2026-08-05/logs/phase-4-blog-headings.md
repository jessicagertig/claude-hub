# Phase 4, item 3 continued — blog template heading artifacts

Tab 17 Headings, rows 9-18. File owned and touched: `web/pages/blog/[slug].js` (only file changed).

Branch `seo-phase-4-metadata-headings`. Nothing committed, nothing pushed, no branch created.

## Analogs read before writing

- `web/components/navigation.js` — `Styled.Nav = styled.nav((props) => { const t = props.theme; return css\`label: Navigation_Nav; ...\` })`, and the `aria-label="Home"` / `aria-label="open the menu"` idiom.
- `web/components/footer.js` — second `Styled.Nav = styled.nav(...)`, same shape.
- `web/components/start.js` — `Styled.Title = styled.h2(...)` / `Styled.Description`, the house pattern for naming a headline's styled component.
- `web/components/container.js` and `web/styles/theme.js`, `web/styles/global.js` — to work out exactly what an `h2` inherits versus a `div`, so the swap could be proved visually identical rather than assumed.

## Fix 1 — Table of contents (rows 9-15, 7 posts)

`TableOfContents` inside `BlogPost` previously returned a fragment:

```jsx
<>
  <h2>{props.value.heading}</h2>
  <ul>{sectionLinks}</ul>
</>
```

Now returns:

```jsx
<Styled.TableOfContents aria-label={props.value.heading}>
  <div>{props.value.heading}</div>
  <ul>{sectionLinks}</ul>
</Styled.TableOfContents>
```

`Styled.TableOfContents` is a new `styled.nav` at the bottom of the file, placed directly after `Styled.Content`.

The heading text still comes from `props.value.heading` (the editor-authored `toc.heading` in Sanity). Not a word changed — only the element carrying it and its place in the outline.

`div`, not `p`: `Styled.Content` already styles `p` (`t.mt(4)`, `line-height: 1.6`, `my(6)` at `mq[40]`) and that rule reaches every descendant paragraph, so a `<p>` would have needed an override fight. `Styled.Content` has no `div` rule, so a `div` inherits nothing it has to undo.

### Visual delta: none. Proved, not assumed.

Old rule, `Styled.Content h2`:

```
scroll-margin-top: 2rem; margin-top: 2rem; font-weight: 600; font-size: 1.25rem;
mq[40]: margin-top: 3rem; font-size: 1.5rem;
mq[72]: scroll-margin-top: 3rem; font-size: 2rem;
```

New rule, emitted by the dev server for the label `div` (copied from the rendered HTML of `/blog/talent-acquisition`):

```
.css-1n827f2-…-BlogPost_TableOfContents div{margin-top:2rem;font-weight:600;font-size:1.25rem;}
.css-1n827f2-…-BlogPost_TableOfContents div{margin-top:3rem;font-size:1.5rem;}
.css-1n827f2-…-BlogPost_TableOfContents div{font-size:2rem;}
```

Same values at the same three breakpoints. The remaining `h2` versus `div` differences all cancel: `web/styles/global.js` resets `h1`-`h6` to `margin: 0`, `font-size: inherit`, `font-weight: inherit` — a `div` already has those — and sets `line-height: 1.21` on `body`, which the `div` inherits (nothing between `body` and the label sets `line-height`; checked `Container`, `Styled.Section`, `Styled.Post`, `Styled.Columns`, `Styled.PageContent`, `Styled.Content`).

**Deliberately dropped:** `scroll-margin-top`. The ToC heading never carried an `id` and no anchor ever targeted it, so the declaration was inert. Say the word and I will put it back for byte-equality.

The `<ul>` was left alone. It carries no class of its own and is styled by the `Styled.Content ul, ol` descendant rule (`t.my(2)`, `t.ml(8)`, `list-style-type: disc`, `li { my(3) }`, the underlined-link `a` rule) — a descendant selector, so wrapping it in the `nav` changes nothing. Confirmed in the rendered markup: `<nav aria-label="Table of contents" class="…"><div>Table of contents</div><ul><li><a href="/blog/talent-acquisition#what-is-talent-acquisition">…`.

Margin collapsing is unchanged too: the `nav` has no padding and no border, so the label's `margin-top` collapses through it exactly as the `h2`'s did.

`aria-label={props.value.heading}` rather than `aria-labelledby` + an `id`: one attribute instead of two, and it matches how `navigation.js` names its interactive regions.

## Fix 2 — sidebar CTA (rows 16-18, 3 posts)

### What the audit found, and what is actually true

The tab's fix reads "Move CTA below content headings," and my brief framed it as a document-order problem. **There is no document-order problem.** In `Styled.Columns`, `Styled.PageContent` (the article) is rendered first and `Styled.Sidebar` second — that has always been the order in this file, it was not touched by phases 1-3 (`git diff 01bf615 -- 'web/pages/blog/[slug].js'` shows no change there). The CTA was already after the entire article in document order.

The reason the CTA reads as the first `H2` on exactly those three posts is that **those three posts contain no `h2` at all.** Queried directly against Sanity (`a6d1clb1` / `production`, `count(content[_type=="block" && style=="h2"])` over all 26 `blogPost` documents):

| slug | h2 blocks | all heading blocks |
|---|---|---|
| `one-click-distribution-to-we-work-remotelys-community-of-job-seekers` | 0 | 0 |
| `post-jobs-with-whatjobs-across-500-partners` | 0 | 4 (all `h3`) |
| `post-to-we-work-remotely-6m-professionals-in-seconds` | 0 | 2 (`h4`, then `h3`) |

No DOM move can place the CTA below content headings that do not exist. Moving the sidebar would have been a no-op for the three flagged posts and would have risked the desktop flex-row layout I was told not to change.

### What I did instead

The same fix the tab prescribes one row up for the ToC, applied to the same class of artifact: a boilerplate marketing CTA is not a content heading, so it no longer occupies a heading slot.

```jsx
<Styled.SidebarContent>
  <Styled.SidebarTitle>Get your hiring process up and running in minutes.</Styled.SidebarTitle>
  <p>It&apos;s completely free to get your job board set up.</p>
  <Button type="link" size="large" to="/" label="Learn more" />
</Styled.SidebarContent>
```

The `h2 { ... }` block moved out of `Styled.SidebarContent` into a new `Styled.SidebarTitle = styled.div(...)` placed immediately after it, carrying the identical declarations. Copy unchanged, character for character.

A dedicated styled component rather than renaming the selector to `div` inside `Styled.SidebarContent`: a bare `div { }` there would also match any `div` that `Button` renders. `Styled.SidebarTitle` cannot leak.

### Visual delta: none. Proved.

Old: `h2 { ${[t.text.h3]}; line-height: 1.3; ${t.mq[40]} { ${[t.text.h2]}; } }` → 700/1.25rem/1.3, then 700/1.5rem.

New, emitted by the dev server:

```
.css-1d5cu8o-…-BlogPost_SidebarTitle{font-weight:700;font-size:1.25rem;line-height:1.3;}
.css-1d5cu8o-…-BlogPost_SidebarTitle{font-weight:700;font-size:1.5rem;}
```

`Styled.SidebarContent`'s own `display: none` / `display: block` at `t.mq[56]`, `text-align`, padding and `p` rule are all untouched. The desktop flex-row layout is untouched: `Styled.Columns`, `Styled.Sidebar` and `Styled.PageContent` were not edited at all.

### What I deliberately did NOT move

- `Styled.Sidebar` and `Styled.SidebarContent` stay exactly where they are in the JSX — inside `Styled.Columns`, after `Styled.PageContent`. No reordering, no relocation outside `Styled.Columns`, no wrapping.
- No change to `Styled.Columns`, `Styled.Sidebar`, `Styled.PageContent` or any breakpoint.
- The `Button`, the description `p` and the CTA copy are untouched.
- The phase-1 related-posts module (`Styled.Related` and its `<h2>Keep reading</h2>`) is untouched.

## Verification

`./node_modules/.bin/eslint "pages/blog/[slug].js"` — clean (only the unrelated `caniuse-lite is outdated` notice).

`next dev` on port 3111, four posts fetched and their heading outlines extracted from the rendered HTML. Server stopped afterwards; port 3111 confirmed free.

`/blog/talent-acquisition` (ToC post) — "Table of contents" is gone from the outline and now renders as `<nav aria-label="Table of contents">`. First `H2` is now the real content heading "What is talent acquisition?".

The three CTA posts — "Get your hiring process up and running in minutes." is gone from the outline on all three. Rendered outlines now:

- `one-click-distribution-…`: `h1` → `h2 Keep reading` → `h2 Start hiring with Polymer for free` → footer `h2`s.
- `post-jobs-with-whatjobs-across-500-partners`: `h1` → four `h3` → `h2 Keep reading` → …
- `post-to-we-work-remotely-6m-professionals-in-seconds`: `h1` → `h4` → `h3` → `h2 Keep reading` → …

On those three posts the first `H2` is now `Keep reading`, from the phase-1 related-posts module. That is a real content-navigation heading rather than boilerplate promotion, but it is worth knowing it is what the auditor's crawler will see next.

## Out of scope, observed while verifying

- Two of the three posts have a heading-level skip authored in Sanity, not in the template: `post-jobs-with-whatjobs-across-500-partners` jumps `h1` → `h3` (four times), and `post-to-we-work-remotely-6m-professionals-in-seconds` goes `h1` → `h4` → `h3`. Fixing these means editing `content` in Sanity. Not touched — my brief is the template file, and these rows are not on the tab.
- `web/components/footer.js` renders `h2` for "Links", "Resources", "Company", "Industries" inside its `Styled.Nav`, on every page of the site. Same class of artifact as the two I fixed. Not flagged on tab 17 and not my file. Not touched.

Both logged to `QUESTIONS-FOR-JESSICA.md`.
