# /privacy markup — three defect classes fixed

Worktree `/Users/jessica/wrk/wrk-corp/wrk-marketing.privacy-markup`, branch
`privacy-markup` created with `wt switch --create privacy-markup --base
seo-phase-1-2-deorphan-crawl`. Base `ea8719f`. Commit `adf5e5c`. Not pushed, no PR.

One file changed: `web/pages/privacy.js`. The template literal went 166,679 to 162,209
bytes; the rest of the file is untouched.

## What was done

`web/pages/privacy.js` holds Termly's generated HTML as a single template literal
consumed by `dangerouslySetInnerHTML` on `<div className="privacy">`. The literal was
parsed with the HTML5 parsing algorithm (`parse5` 7.3.0, fragment context `div`), the
`bdt` elements renamed to `span` in the tree, and the tree re-serialized. Nothing else.

Rebuilding the tree with the spec parser rather than hand-editing is what makes the
result provable: the serialized output is the DOM a browser was already constructing
from the broken source, so correcting the nesting cannot move content. Stray closes
with no opener were dropped by the parser; the 35 unclosed `<div>` elements are now
closed explicitly at the end of the fragment, which is exactly where the parser was
already closing them, and that is the run of 35 `</div>` now on line 54.

1. **Out-of-order closing tags — 1214 to 0.** Every tag now balances:
   `div` 405/405, `span` 2287/2287, `li` 52/52, `ul` 52/52, `p` 17/17, `td` 36/36,
   `tr` 12/12, `a` 38/38, `em` 36/36, `strong` 86/86, `u` 11/11, `table` 1/1,
   `tbody` 1/1, `style` 2/2, `br` 137 void. Before the fix `span` was 1781 open against
   2521 close, `div` 405 against 370, `li` and `ul` 52 against 103 each, `p` 17
   against 1, `a` 38 against 39.

   The `</main>`, `</body>` and `</html>` closes the validator reported are not in
   this file. There were never any such tags in `privacy.js`; they were the page's own
   closing tags being reported out of order because the privacy markup left elements
   open past the end of the fragment. They resolve with everything else.

2. **`<bdt>` — 506 to 0.** Each `<bdt class="…">` became `<span class="…">`, class
   preserved. Checked before choosing `span`: the `<style>` block at the top of
   `privacy.js` targets only `[data-custom-class='…']` and its descendants, never `bdt`
   or `.question` or any other bdt class; `grep -riE 'bdt'` across every `.css`,
   `.scss`, `.js`, `.jsx`, `.ts`, `.tsx` in the repo outside `.next/` and this file
   returns nothing. The classes carried by the 506 elements are `question`,
   `block-component`, `statement-end-if-in-editor`, `else-block` and
   `forloop-component`, all Termly template markers. `bdt` and `span` are both
   unstyled inline elements and neither is a "special" or "formatting" element to the
   parser, so the rename changes neither the parse nor the box model. No selector
   anywhere in the project depends on element type position: `styles/global.js` and
   `styles/theme.js` contain no `span`, `nth-of-type`, `nth-child` or sibling-combinator
   selectors, and the only `:first-of-type` in `components/basicPage.js:75` is scoped to
   `h2`, of which the privacy markup has none.

3. **Raw `&` — 1 to 0.** `Sales & Marketing Tools` is now `Sales &amp; Marketing Tools`.
   It was the only unencoded `&` in the file and the file contained no character
   references at all beforehand, so this is the only entity now present.

The 50 literal no-break space characters were re-substituted after serialization so the
file keeps them as literal U+00A0 rather than `&nbsp;`. Same rendered character either
way; the point was to keep the diff to the three classes in scope.

## Proof the text did not change

The page was built and served on port 3196 before and after, and the served HTML fetched
with `curl` each time. Text content was extracted by parsing the whole document with
`parse5` and concatenating every text node outside `script`, `style`, `noscript` and
`template`.

- `/private/tmp/claude-501/-Users-jessica-claude-hub-wrk-marketing/ae83cb44-eb97-4453-99a4-0718b5a2e1c9/scratchpad/privacy-text-before.txt`
- `/private/tmp/claude-501/-Users-jessica-claude-hub-wrk-marketing/ae83cb44-eb97-4453-99a4-0718b5a2e1c9/scratchpad/privacy-text-after.txt`

Both 35,403 bytes, both md5 `b47b523d16f43e5a71b1f09da96e3839`. `cmp` reports no
difference.

Two stronger checks were run on top of that:

- The fix script asserts that re-parsing its own output yields a tree deep-equal to the
  parse of the original input with `bdt` renamed, comparing tag name, namespace,
  attribute list in order, text node values and comment values at every node. It writes
  nothing if that assertion fails.
- `dom-compare.js` parses the two served pages, locates `div.privacy` in each, and
  asserts the two subtrees are deep-equal once `bdt` is read as `span`. It passes.

Both scripts are in
`/private/tmp/claude-501/-Users-jessica-claude-hub-wrk-marketing/ae83cb44-eb97-4453-99a4-0718b5a2e1c9/scratchpad/tools/`,
alongside the served HTML in `../hv-privacy/privacy-{before,after}.html`.

## Validator counts

`npx html-validate` 8.29.0 under Node 16.20.2, run on the served `/privacy` page, using
a copy of the config from the earlier round
(`.../scratchpad/hv-pricing-static/.htmlvalidate.json`, extending
`html-validate:recommended` and `html-validate:document`). The before column reproduces
the numbers in `html-validity.md` exactly.

| Rule | Before | After |
|---|---|---|
| `close-order` | 1214 | **0** |
| `element-name` (unknown `<bdt>`) | 506 | **0** |
| `element-permitted-content` | 51 | 27 |
| `no-implicit-close` | 35 | **0** |
| `no-dup-id` | 13 | 13 |
| `element-required-attributes` | 2 | 2 |
| `valid-id` | 2 | 2 |
| `attr-case` | 1 | 1 |
| `no-raw-characters` | 1 | **0** |
| **Total** | **1825** | **45** |

`element-permitted-content` needs its breakdown, because the total falling from 51 to 27
hides a small rise in one sub-count.

| Message | Before | After |
|---|---|---|
| `<div>` not permitted under `<span>` | 20 | 0 |
| `<ul>` not permitted under `<span>` | 3 | 0 |
| `<tr>` not permitted under `<span>` | 2 | 0 |
| `<table>` not permitted under `<span>` | 1 | 0 |
| `<style>` not permitted under `<div>` | 17 | 19 |
| `<style>` not permitted under `<nav>` | 5 | 5 |
| `<style>` not permitted under `<header>` | 1 | 1 |
| `<style>` not permitted under `<button>` | 1 | 1 |
| `<style>` not permitted under `<footer>` | 1 | 1 |

The 26 "under `<span>`" errors were the mis-nesting and are gone. The `<style>` under
`<div>` count rose by 2, and the 2 are the two `<style>` blocks that live inside the
privacy markup itself. They did not move: the DOM comparison above proves every node is
where it was. What changed is that the validator can now see their real parent. While
the markup was malformed its recovery placed them somewhere it did not complain about;
with the tree well formed they are plainly children of a `<div>` and join the
pre-existing "`<style>` element inside `<body>`" row of `html-validity.md`, which that
report scores as framework noise with no SEO or AEO effect. Nothing was added to the
page to cause it.

## Build

`next build` on Node 16.20.2 with `web/.env.local` sourced into the environment and
`node_modules` symlinked in from the main checkout, both before and after the edit. Both
builds compiled successfully. The only warning is `@next/next/no-css-tags` at
`_app.js:94:7`, which is pre-existing and unrelated. The symlink was removed after the
final build and the port 3196 server was stopped; nothing is listening on 3196 now.
`.env.local` was sourced into the shell only, never copied and never written anywhere.

## Noticed, left alone

- `no-dup-id` 13, all `Duplicate ID "control"`. `privacy.js` has 13 section headings
  carrying `<span id="control">`. Out of scope and unchanged.
- `valid-id` 2, `element id must begin with a letter` — the Next runtime's `__next` and
  `__NEXT_DATA__`. Not this file.
- `element-required-attributes` 2, the missing `<html lang>` and the GTM `<iframe>`
  without a `title`. Both from the absent `web/pages/_document.js` and from
  `_app.js`, per `html-validity.md`.
- `attr-case` 1, `charSet` in `components/seo.js`.
- `html-validity.md` attributes one instance of "`color` attribute leaking onto a
  `<span>`" to `privacy.js:44`. There is no `color` attribute anywhere in the file. Its
  attributes are `style` 1625, `data-custom-class` 687, `class` 506, `href` 38, `id` 33,
  `rel` 3, and nothing else. That instance comes from somewhere else on the page,
  most likely `components/button-new.js` where the same row's other 15 originate.
- The file still carries Termly's empty template markers: 367 of the 506 renamed
  elements are `<span class="…"></span>` with no content at all. The 506 break down as
  `block-component` 303, `statement-end-if-in-editor` 107, `forloop-component` 49,
  `question` 35, `else-block` 12; only the 35 `question` ones hold a filled-in value.
  They are inert and deleting them was not in scope, but they are a large part of why
  the markup is 162 KB for 35 KB of text.
- The `<div style="color: #555555;font-size: 1rem;padding-top:16px;">` Termly credit line
  at the end of the literal sits inside the 35 previously-unclosed divs. It always did,
  in the DOM; the fix only made that explicit in the source.
