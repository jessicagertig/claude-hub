# Phase 6 fixes — Round 2

## web/components/home/ready.js

Sanctioned item 2 asked for: remove the dead `https://www.bodeswell.io/` link, keep the logo and the quote themselves.
Status: DONE.

### Verification before the edit

`www.bodeswell.io` re-verified 2026-08-06, independently of the finding:

| Resolver | Query | Result |
|---|---|---|
| 1.1.1.1 | `www.bodeswell.io` A | NXDOMAIN |
| 8.8.8.8 | `www.bodeswell.io` A | NXDOMAIN |
| 9.9.9.9 | `www.bodeswell.io` A | NXDOMAIN |
| 1.1.1.1 | `bodeswell.io` A | NOERROR, zero records |
| 1.1.1.1 | `bodeswell.io` AAAA | NOERROR, zero records |
| 1.1.1.1 | `bodeswell.io` NS | `dns1.cscdns.net.`, `dns2.cscdns.net.` |

`curl -L https://www.bodeswell.io/` with a desktop Chrome user agent: HTTP code `000`, curl exit 6 (could not resolve host). No HTTP status is obtainable — the domain is registered and points at nothing.

No replacement URL was written, so there was nothing to fetch and confirm 200.

### The change

```diff
-      <Quote to="https://www.bodeswell.io/">
+      <Quote>
```

One line, line 87.

### Why this is the whole fix

`Quote` is defined at `web/components/quote.js` and imported in exactly one place — `web/components/home/ready.js:6`. Confirmed by grep over `web/pages` and `web/components`. It renders:

```jsx
<a href={props.to} target="_blank" rel="noreferrer">
```

unconditionally. With no `to` prop, `props.to` is `undefined` and React omits the `href` attribute. The `<a>` element, the `<Image>`, the `<blockquote>`, the two `<p>` elements and the `<cite>` are all untouched, so the logo and the quote stay exactly as they were.

`web/components/quote.js` was not modified. Nothing in it selects `a:hover`, so dropping `href` has no styling side effect — unlike `web/components/home/brands.js`, which needed `&[href]:hover` because its `Styled.Logos` did style anchor hover.

This matches the precedent already set in this branch's working tree for the other dead link: `web/components/home/brands.js:24` dropped `href: "https://www.makelog.com"` from the brand object and kept the `<a>` wrapper.

### Not done here, by scope

The QUESTIONS-FOR-JESSICA.md record was already written in round 1 — `QUESTIONS-FOR-JESSICA.md:206` carries the bodeswell.io entry with the same DNS evidence. That file is outside this agent's one owned file and was not edited.

The `alt` text (`"An image of Matthew Bellows, CEO at BodesWell.io"`) and the `<cite>` (`"Matthew Bellows, CEO, BodesWell.io"`) still name BodesWell.io. Those are the company name in prose, not links, and "keep the quote themselves" covers them. Whether the customer stays on the page at all is the open question already recorded for Jessica.

No binary asset was touched. No bot-walled link was removed. No test was written.

## web/components/home/brands.js

Sanctioned item 2 asked for: remove the dead `https://www.makelog.com` link, keep the logo.
Status: DONE.

No edit was made this round. The change was already present in the working tree and is correct; the round-2 finding's own reason was that it is uncommitted, and this agent does not commit. The working tree is what the orchestrator commits, so the tab row is true.

### Verification before accepting the existing edit

`www.makelog.com` re-verified 2026-08-06, independently of the finding:

| Resolver | Query | Result |
|---|---|---|
| 1.1.1.1 | `www.makelog.com` A | NOERROR — CNAME `comingsoon.namebright.com.` → `cdl-prd-https-247c6c9f427caacd.elb.us-east-1.amazonaws.com.` → 44.208.83.180, 54.84.240.235 |
| 8.8.8.8 | `www.makelog.com` A | identical chain, identical addresses |

| Fetch (desktop Chrome UA, `--resolve` to 54.84.240.235) | Result |
|---|---|
| `https://www.makelog.com` | curl exit 35, `SSL_ERROR_SYSCALL` in connection to `www.makelog.com:443`, HTTP code `000` |
| `http://www.makelog.com` | `200`, final URL `http://www.makelog.com/`, `<title>NameBright - Coming Soon</title>` |

The href in the file was the `https` scheme, which cannot complete a TLS handshake at all. Over `http` the domain answers with a NameBright domain-for-sale page. Dead, and invisible to a 4xx crawl because the parking page returns 200 — which is why no tab 14 row exists for it.

No replacement URL was written, so there was nothing to fetch and confirm 200.

### `https://ca.la` — ALIVE, left in place

Line 26 still carries `href: "https://ca.la"`. Re-verified independently:

| Resolver | `ca.la` A |
|---|---|
| 1.1.1.1 | NOERROR — 172.67.68.183, 104.26.5.176, 104.26.4.176 |
| 8.8.8.8 | same three addresses |
| 9.9.9.9 | same three addresses |

`curl -L https://ca.la` resolved to 104.26.4.176: `200`, final URL `https://www.mercer.design/`, `<title>Mercer: AI-Powered Tools for Fashion</title>`. CALA rebranded to Mercer; the link works for every visitor. The orchestrator's sanctioned-items text calls it SERVFAIL, which reproduces only against this machine's local resolver 192.168.0.1. Removing it would have been a live-link removal, so it was not touched.

### The change already in the working tree

```diff
-    { src: makelog, alt: "Makelog", href: "https://www.makelog.com", width: 100 },
+    { src: makelog, alt: "Makelog", width: 100 },
```

The map now wraps in `Link` only when `brand.href` exists and falls back to a bare `<a>`:

```diff
-          <Link key={brand.alt} href={brand.href}>
+          return brand.href ? (
+            <Link key={brand.alt} href={brand.href}>
+              <a target="_blank" rel="noreferrer">{logo}</a>
+            </Link>
+          ) : (
+            <a key={brand.alt}>{logo}</a>
+          );
```

and the hover rule in `Styled.Logos` narrowed:

```diff
-      &:hover {
+      &[href]:hover {
```

`src`, `alt` and `width` are unchanged on the Makelog entry, so the logo stays. The bare `<a>` is kept rather than a `<span>` because `Styled.Logos` styles the `a` selector — `display: flex`, `align-items`, `justify-content`, `opacity: 0.7`, `transition` — and swapping the element would have forced a CSS change. `target`/`rel` are dropped on the unlinked branch since there is no navigation. `&[href]:hover` keeps the hover brighten on the eight linked logos and removes the affordance from the unlinked one.

### Every other href in this file

Swept with a desktop Chrome UA, since this is the file I own:

| URL | Code | Final |
|---|---|---|
| `https://piratewires.com` | 429 | `https://www.piratewires.com/` |
| `https://tixel.com` | 200 | `https://tixel.com/us/` |
| `https://getcampfire.com` | 200 | `https://www.getcampfire.com/` |
| `https://filebase.com` | 200 | `https://filebase.com/` |
| `https://eeetwell.com` | 200 | `https://eeetwell.com/` |
| `https://joinleland.com` | 200 | `https://www.joinleland.com/` |
| `https://helium.com` | 200 | `https://www.helium.com/` |

`piratewires.com` is a rate-limit bot-wall, not a death — it redirects to its own `www` host before returning 429. Left in place; removing it would be a BLOCKER.

### Tab 11 against this file

No action. All nine logos are static SVG imports from `web/images/logos/`, and the `<Image>` call already passes explicit `width={brand.width}` and `height={28}`, so it is not a responsive call site and the `sizes` prop does not apply to it. Nothing here is a Sanity CDN URL. No binary under `web/images/` was read, re-encoded, resized or deleted.

### Outside my one owned file, for whoever owns it

`QUESTIONS-FOR-JESSICA.md:200` reads "All three hrefs are still in the working tree as of this round; nothing has been removed yet." That sentence is now stale: the Makelog href is removed in the working tree and the bodeswell.io href was removed earlier this round. The three numbered entries below it (`:202` ca.la ALIVE, `:204` makelog DEAD, `:206` bodeswell DEAD) are accurate and match this agent's independent measurements exactly, including the open question of whether the two customers stay on the page. Not edited — outside this agent's owned file.

No binary asset was touched. No bot-walled link was removed. No test was written.

---

## web/pages/changelog.js — round 2

File owned: `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/pages/changelog.js`
Branch confirmed: `seo-phase-6-images-links-headers`. Not committed, not pushed.

### Tab 11, rows A13 / A15 / A56 — "Sanity: request fm=webp (or avif) + cap width at rendered size"

Tab 11 asked for: cap width at rendered size.
Status: DONE.

One change. `ImageRenderer`'s `<Image layout="responsive">` now passes `sizes={BODY_IMAGE_SIZES}`:

```
const BODY_IMAGE_SIZES = "(min-width: 896px) 640px, (min-width: 640px) calc(100vw - 64px), calc(100vw - 48px)";
```

Nothing else in the file changed. `noUpscaleImageBuilder` was already passed as `imageBuilder`
before this round and is untouched; the three rows are 3200px sources, so its
`Math.min(options.width, croppedImageDimensions.width)` returns 2304 unchanged and the `sizes`
prop is the only lever that reaches them.

### Where the value comes from

Computed from the CSS chain, not copied from another call site. `box-sizing: border-box` is set
globally at `web/styles/global.js:70`, so every figure below is a border box.

| Viewport | Chain | Slot width |
|---|---|---|
| < 640px | Section `mx(2)` = 8px each side, Container `px(4)` = 16px each side | `100vw - 48` |
| 640–896px | Section `mx(3)` = 12px, Container `px(5)` = 20px | `100vw - 64` |
| ≥ 896px | Section `mx(4)` = 16px, Container `px(8)` = 32px, then `Styled.Post` becomes a 9-column grid (`column-gap: spacing[8]` = 32px) and `Styled.PostContent` takes `grid-column: 3 / span 7` — 7 columns plus 6 gaps — under `max-width: 40rem` | `7 × (W − 256) / 9 + 192`, capped at 640 |

The 40rem cap binds once the Container content box `W` reaches 832px, i.e. a viewport of about
928px. Between 896px and 928px the real slot is 603–640px, so the flat `640px` clause overstates by
at most 37px across a 32px window; at both DPR 1 and DPR 2 the browser still picks the same srcset
candidate there (640 and 1494 respectively), so no extra clause was added for it.
`column-gap` widening to `spacing[16]` at `mq[72]` = 1152px and the Container's own `max-width: 80rem`
both land above the cap and change nothing.

### Measured, live, 2026-08-06

`https://www.polymer.co/changelog` currently serves five `cdn.sanity.io` images, every one
`sizes="100vw"` (`grep -o 'sizes=\"[^\"]*'` on the served HTML: `5 sizes="100vw"`). All five come
through this one `ImageRenderer`. Three are Tab 11 rows:

| Row | Asset | Tab bytes (B col) | Refetched, no `Accept` | w=2304, Chrome `Accept` | w=1088 | w=640 |
|---|---|---|---|---|---|---|
| A13 | `fa9fbbcf…-3200x1888.png` | 2,012,332 | 2,012,332 `image/png` | 107,395 `image/avif` | 38,390 | 16,515 |
| A15 | `c71e5e16…-3200x1684.png` | 1,857,699 | 1,857,699 `image/png` | 68,052 `image/avif` | 26,065 | 17,390 |
| A56 | `12d62b16…-3200x1792.png` | 874,338 | 874,338 `image/png` | 24,763 `image/avif` | 9,646 | 9,096 |

Every no-`Accept` figure matches the tab's B column to the byte. The other two assets on the page,
`3406e230…-2400x1260.png` (99,286) and `496024c1…-3600x1890.png` (88,137), are under the tab's
100 kB cutoff, which is why they are not rows; they get the same `sizes` prop and the same relief.

Before: at a 1440px viewport the browser took the 1494 candidate at DPR 1 and the 2304 candidate at
DPR 2, for a 640px slot. After: 640 at DPR 1, 1494 at DPR 2.

### Checks

- `@babel/parser` with the `jsx` plugin parses the edited file: PARSE OK.
- No binary under `web/images/` or `web/public/` touched; `git status` shows no binary path.
- No link removed or altered — this file has none of Tab 14's or Tab 10's URLs.
- Workbook re-read with `read-workbook.py "11 Images"`. Title A1, note A4, header row A6 and the
  `D13`/`D15`/`D56` Fix batch strings all match the orchestrator's quotation verbatim. No misquote.

## web/next.config.js

Two MED findings against this file, both on Tab 15 A7. Both fixed.

### Workbook check

Tab 15 read directly with `read-workbook.py "15 Security Headers"`. The orchestrator's
rendering matches the workbook exactly — A7/A8/A9/A10 headers, current states and
recommended values are all verbatim. No misquote to report.

### Finding 1 — connect-src missed the host GA4 actually uses

Tab 15 A7 asked for: a Report-Only policy covering self + Sanity CDN + analytics.
Status: was DONE INCOMPLETELY. Now DONE.
Reason it was incomplete: `https://*.analytics.google.com` matched no host the container
constructs, and the host it does construct was absent.

Verified by fetching `https://www.googletagmanager.com/gtm.js?id=GTM-N6H844WJ` (440,369
bytes) and reading the constructions rather than trusting the finding text. Exactly one
occurrence of `analytics.google.com` in the bundle:

```
Pm=function(){var a=Im,b="";return b}
function Rm(a){a=a===void 0?"g/collect":a;return"https://"+(Pm()||"www")+".google-analytics.com/"+a}
function Sm(a){a=a===void 0?"g/collect":a;var b=Pm();return"https://"+(b?b+".":"")+"analytics.google.com/"+a}
var Tm={},Um=(Tm[17]=function(){return gk()&&!Pm()?hk()+"/ag/g/c":Sm()},Tm[16]=...Rm()...
```

`Pm()` returns `""` unconditionally in this build, so in `Sm()` the ternary `(b?b+".":"")`
contributes nothing and the URL is the apex `https://analytics.google.com/g/collect`. A CSP
wildcard of the form `*.analytics.google.com` requires at least one label and does not match
an apex. The sibling `Rm()` prepends `(Pm()||"www")`, producing
`https://www.google-analytics.com/g/collect`, which the existing `*.google-analytics.com`
does match — that entry was already correct.

Change: added `https://analytics.google.com` to `connect-src`, one token, before the existing
wildcard. The wildcard is kept rather than replaced: `Sm()` builds either form from the same
`(b?b+".":"")` expression, so a container republish that turns the region prefix on emits
`<region>.analytics.google.com` from this same line.

### Finding 2 — AdRoll cookie-match pixels are an unbounded img-src class

Tab 15 A7 asked for: enforce after a clean week.
Status: the gap is real and cannot be closed by adding hosts. Documented in the file instead.
Reason: the destination hosts are not derivable from the repo or from the bundle.

Verified by fetching `https://s.adroll.com/j/7HAXCLAXPNHL7DUHZJ7GQB/roundtrip.js` (116,080
bytes). The advertisable id matches the loader at `web/pages/_app.js` line 190. Four
occurrences of `cm_urls`, and none of them is a push:

```
this.cm_urls=[]                                                     // constructor
...cookieMatch=function(){var a=this.cm_urls.length;...popAndSend()}
__adroll__.prototype.popAndSend=function(){if(!(0>=this.cm_urls.length)){
  var a=this.cm_urls.shift(),b=new Image;b.src=a;b.setAttribute("alt","")}}
```

The array is initialised empty and only ever read and shifted in this bundle, so it is
populated from AdRoll's server response. Those partner hosts cannot be enumerated by
inspection at any cost, so `img-src` cannot cover them and the violation stream will not go
empty while the AdRoll pixel loads.

Not fixed by widening `img-src` to `*`, which would remove the directive's meaning. Recorded
as a comment paragraph in the file naming the mechanism, so the "clean week" gate is read
correctly by whoever reviews the report stream.

### Outside my one owned file, for whoever owns it

`QUESTIONS-FOR-JESSICA.md` question 1 under "Phase 6, item 4" discloses the identical
unbounded-violation problem for the GTM container's third-party tags but does not mention the
AdRoll cookie-match class. That file is not mine; the AdRoll class needs the same sentence
added there.

### Scope

This file was already modified in the working tree when I arrived — an earlier agent's
uncommitted expansion of `script-src`, `img-src`, `frame-src` and `connect-src` plus the
vendor host-derivation comment. Confirmed against `git show HEAD:web/next.config.js`, whose
`connect-src` still reads `...https://*.google-analytics.com https://*.analytics.google.com
https://*.adroll.com...` with no apex and no comment block. My contribution to the diff is
exactly two comment paragraphs and the one `connect-src` token. Nothing pre-existing was
rewritten or removed.

Verified after editing by requiring the config and awaiting `headers()`: source is `/:path*`;
the four keys are `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy` and
`Content-Security-Policy-Report-Only`; no key equals `Content-Security-Policy`, so the policy
is still Report-Only and Tab 15 is not a BLOCKER. Both `https://analytics.google.com` and
`https://*.analytics.google.com` present as distinct tokens, no duplicate tokens, all 11
directives well-formed.

No binary asset was touched. No bot-walled link was removed. No file other than this one and
this log was modified. No test was written. Not committed.

Correction applied after the first write of this section: the source comment initially said "all
three Sanity assets on this page are 3200px wide". The page renders five, three of them 3200px wide
plus a 2400x1260 and a 3600x1890. Comment now reads "every Sanity asset this page renders is 2400px
or wider", which is what makes the clamp a no-op for all five. Re-parsed: PARSE OK.

---

## logs/phase-6-images.md

Finding asked for: make the tab-11 record true — `SEO-CHANGELOG.md:2441` claimed "All four are corrected in place", the fourth being the entry in `logs/phase-6-images.md`, and that file was never touched.
Status: DONE.

The correction was performed on the log. Five false statements were found, not the two the finding named, and all five are corrected in place with a dated block rather than a rewrite.

### Verification before the edits

| Claim | How checked | Result |
|---|---|---|
| `6523c92` shipped `.format('webp')` | `git show 6523c92:web/lib/sanityImage.js` | Present, chained between `.quality()` and `.fit('clip')` |
| The working tree has it removed | `cat web/lib/sanityImage.js`, `git status --short` | Absent; ` M web/lib/sanityImage.js` uncommitted |
| `6523c92` touched `web/pages/changelog.js` | `git show 6523c92 -- web/pages/changelog.js` | Import at `:12`, `{ imageBuilder: noUpscaleImageBuilder }` at `:27` |
| The byte measurements the log rests on | three `curl` fetches of the row A7 asset, cache warm | `auto=format` + Chrome `Accept` → `image/avif` 314,063; `Accept` without AVIF → `image/webp` 400,566; `&fm=webp` → `image/webp` 400,542 — identical to the numbers already in the file |
| The `sizes` props exist | `grep -n "sizes=\|SIZES"` across the six call sites | `web/pages/blog.js:46`, `web/pages/blog/[slug].js:211` and `:393`, `web/pages/changelog.js:50`, `web/components/home/intro.js:52`, `web/components/feature.js:74` |
| 44 of 71 Sanity rows have a source ≥ 2304px | 71 rows minus the file's own Finding 3 count of 27 narrower sources | 44 |

No replacement URL was written, so there was nothing to fetch and confirm 200. The three `curl` calls above are measurements of an asset already named in the file, not new links.

### The five statements corrected

1. Line 35, `## Finding 1` — "Adding `fm=webp` as the tab asks **would have** pinned every image to WebP... **Not done, deliberately.**" False. `6523c92` did it, at all four `useNextSanityImage` call sites. Now states DONE in `6523c92`, then reversed in the working tree by the round-1 fix pass on the measurement, with the re-measured bytes and the note that which way it ships is one line and Jessica's call.
2. The `## Finding 1` heading itself — "the tab's main instruction **would have made things worse**" framed the row as not actioned. Retitled "the tab's `fm=webp` instruction, and what actually shipped".
3. Line 67, `## Finding 3` — "the 3600px source **correctly** still goes to `w=2304`". This is the sentence the verifier's HIGH finding quoted. `w=2304` for a 3600px source is the clamp doing nothing: `Math.min(options.width, croppedImageDimensions.width)` against a `deviceSizes` ceiling of 2304 is byte-identical to the default builder for any source ≥ 2304px. Now states the no-op, that Finding 3 reaches 27 rows and not the tab, that the lever is the `sizes` prop, that no responsive call site passed one so `next/image` emitted `sizes="100vw"`, and that the round-1 fix pass added them across six call sites in five files.
4. "Not actioned" bullet — "`web/pages/changelog.js`... so untouched." False; struck through with the commit evidence and a note that Question 18 in `QUESTIONS-FOR-JESSICA.md` is stale for the same reason.
5. Closing framing — "the derivative, which is already AVIF and now correctly width-capped." False at the time of writing for 44 of 71 rows. Now scoped to the 27, with the `sizes` props named as what reaches the rest.

The "What changed" table was missing `web/pages/changelog.js` and said "all three files"; the row was added and the count corrected to four. A summary block at the top of the file lists all of it so a reader hits the corrections before the original text.

### Scope

Only `logs/phase-6-images.md` was edited. No source file, no `SEO-CHANGELOG.md`, no `QUESTIONS-FOR-JESSICA.md` — the stale Question 18 and the stale phase-6 heading in that file are named in the log for whoever owns it. No binary asset touched. No bot-walled link removed. No test written. Nothing committed or pushed.

---

## QUESTIONS-FOR-JESSICA.md — round 2

File owned: `/Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/QUESTIONS-FOR-JESSICA.md`
Branch confirmed: `seo-phase-6-images-links-headers`. Nothing committed, nothing pushed. No file in
`/Users/jessica/wrk/wrk-corp/wrk-marketing` was modified by this agent.

Three MED findings, all the same defect: the document Jessica reads to decide states the opposite of
what the working tree and the Sanity dataset hold. All three fixed, plus two stale section headings
and one gap a sibling handed over.

### Finding 1 — Tab 11, the 71 `cdn.sanity.io` rows, the record of the format decision

Tab 11 asked for: `fm=webp` (or avif), and per the phase instructions a record of any deviation.
Status of the record: was DONE INCOMPLETELY. Now DONE.
Reason it was incomplete: line 240 was headed "`fm=webp` shipped", said "`web/lib/sanityImage.js`
calls `.format('webp')`", and closed "I did not pick — the branch currently holds the first" of three
options. The tree holds the third.

Verified against the tree before writing, not taken from the finding:

```
grep -n "\.format(" web/lib/sanityImage.js
9:// already applies to every builder it constructs. Do not add .format('webp'):
```

The single match is comment text warning against it. Stripping comment lines leaves
`.quality()`, `.fit('clip')` and `.width()` and no `.format()`. The builder emits
`?w=<n>&q=75&fit=clip&auto=format`.

Rewritten as question 3 under "Phase 6, item 1 — image delivery". It now leads "**`fm=webp` is NOT
applied**", names `6523c92` as having shipped it and the round-1 pass as having taken it back out on
a measurement, keeps the three-row byte table with the **shipped** row re-marked (it was marking the
WebP row as shipped), and states the choice as made rather than pending — the measurement decides it
and no decision was left for her. What it now discloses that it did not before: a re-crawl by the
same tool will report all 79 rows again at the same byte sizes, because the emitted URL is unchanged
from the audited one. The one-line reversal is still offered, with the trade named.

Also corrected in the same pass, because the same claim appears twice — line 186, row 8 under
"Tab 11 read (images)". It read "The tab's blanket fix (`fm=webp` + cap width at rendered size) will
shrink it", telling her both halves ship. Now struck and marked fixed, with the cap's real effect
measured today on that asset (`1d078cc7…-800x600.png`, Chrome `Accept`):

| Request | Bytes | Content-Type |
|---|---|---|
| `w=2304&q=75&fit=clip&auto=format`, no `Accept` (what the audit measured) | 6,625,346 | image/png |
| `w=2304`, Chrome `Accept` (before) | 195,745 | image/avif |
| `w=800`, Chrome `Accept` (**what the tree ships**) | 58,722 | image/avif |
| `w=800`, no `Accept` | 291,380 | image/png |

The 6,625,346 figure reproduces tab 11 cell B8 to the byte. A 70% cut for a real visitor from the
width cap alone, which is the largest measured win on the branch and was not stated anywhere in her
file before.

`SEO-CHANGELOG.md:2987` names the same staleness and leaves it for whoever owns that file. Not mine;
not touched.

### Finding 2 — Tab 14 rows A7-A11 and A17, the handover record

Tab 14 asked for: replace the 5 confirmed-dead links and list the result for review.
Status of the record: was DONE INCOMPLETELY. Now DONE.
Reason it was incomplete: the section heading read "nothing changed, all 20 are in Sanity", the body
read "so this item hands over rather than fixes", and the crazyegg question offered two options
("drop the link and keep the sentence, or drop the sentence with it") neither of which describes the
block. Three writes had landed since that text was written.

Re-verified myself, read-only GROQ against `a6d1clb1` / `production` with the token in
`web/.env.local` (read once, file not modified, no mutation of any kind):

| Tab row | Draft | Field | Value read back |
|---|---|---|---|
| A7 | `drafts.914dc19a-…` | `content[1].markDefs[0].href` | `https://help.polymer.co/en/articles/10250419-configuring-a-custom-domain` |
| A8 | `drafts.609fbb42-…` | `content[2].markDefs[0].href` | `…/5721143-have-new-candidate-notifications-show-up-in-a-slack-workspace` |
| A9 | `drafts.3d2afcd8-…` | `content[2].markDefs[0].href` | `…/5721747-have-new-candidate-notifications-show-up-in-a-discord-server` |
| A10 | `drafts.fcfc319d-…` | `content[77].sourceUrl` | `null`; `_type` `image`, `source` still `Crazy Egg` |
| A11 | `drafts.5fd6bab5-…` | `content[35].markDefs[0].href` | `https://topgrading.com/` |
| A17 | `drafts.fcfc319d-…` | `content[116].markDefs[2].href` | `https://www.pcmag.com` |

Published documents untouched: `5fd6bab5-…` `_rev` `D1lygl0QlSsqL8Gf8Zw18X`, `fcfc319d-…` `_rev`
`LK25dP7vICeIYdOu8ZrX7Z` — the pre-audit values. Published `fcfc319d-…` `content[77].sourceUrl` is
still `https://www.crazyegg.com/blog/recooty-review/`, confirming nothing shipped. Twelve
`drafts.*` documents in the dataset.

All five replacements fetched before being written into her file, desktop Chrome UA:

| URL | Code |
|---|---|
| `https://help.polymer.co/en/articles/10250419-configuring-a-custom-domain` | 200 |
| `https://help.polymer.co/en/articles/5721143-…-slack-workspace` | 200 |
| `https://help.polymer.co/en/articles/5721747-…-discord-server` | 200 |
| `https://topgrading.com/` | 200 |
| `https://www.pcmag.com` | 200 |

Originals re-fetched and still dead: crazyegg article 404, topgrading article 404,
`help.wrk.xyz/en/articles/5280480-configuring-a-custom-domain` 404.

Heading changed to "five Sanity drafts are waiting for you, nothing published". Question 1 struck and
marked fixed, carrying the six-row draft table above so she can work the Studio from it, plus the
published `_rev` values as proof nothing shipped, and the sentence **"Tab 14 closes when you publish
those drafts, not when this PR merges."**

Question 2, crazyegg: struck, and the false choice corrected explicitly. The link is already dropped;
`content[77]` is an `image` block and the dead URL was its `sourceUrl`, not a link inside prose, so
there is no sentence to drop. `SourceRenderer` at `web/pages/blog/[slug].js:159-163` renders
`Source: Crazy Egg` as plain text once `sourceUrl` is absent. The only remaining decision is whether
that unlinked credit line stays, and the default is stated: it stays, because the screenshot did come
from Crazy Egg.

No bot-walled link was touched by this agent, and none needed to be — this file records, it does not
edit Sanity.

### Finding 3 — sanctioned item 2, the dead customer links

Asked for: record each one so she can decide whether the customers stay on the page.
Status: was DONE INCOMPLETELY. Now DONE.
Reason it was incomplete: line 200 read "All three hrefs are still in the working tree as of this
round; nothing has been removed yet", which was the framing for her decision at line 208.

The finding said one href had been removed. **Two had.** Verified in the tree:

```
web/components/home/brands.js:24  { src: makelog, alt: "Makelog", width: 100 },      # no href
web/components/home/brands.js:26  { src: cala, alt: "CALA", href: "https://ca.la", width: 70 },
web/components/home/ready.js:87   <Quote>                                            # no `to`
```

`git diff web/components/home/ready.js` shows `-<Quote to="https://www.bodeswell.io/">` / `+<Quote>`.
`web/components/quote.js:8` passes `props.to` straight into `href`, so React omits the attribute and
the quote renders unlinked with photo, blockquote and `<cite>` intact.

All three domains re-verified independently rather than trusted:

| Domain | Result |
|---|---|
| `ca.la` @1.1.1.1 | NOERROR — 104.26.5.176, 104.26.4.176, 172.67.68.183; `curl -L` → `https://www.mercer.design/` 200. **ALIVE, href left in place.** |
| `www.makelog.com` @1.1.1.1 | CNAME `comingsoon.namebright.com.` → ELB → 44.208.83.180, 54.84.240.235. Parking page. DEAD. |
| `www.bodeswell.io` @1.1.1.1 | no A record; `bodeswell.io` no A, no AAAA. DEAD. |

The preamble now names both removals with file and line, states the ca.la href is untouched because
it works, and confirms both logos and the quote are still on the page. Entries 2 and 3 each gained a
bold sentence describing what the page renders now — for Makelog, the bare `<a>` and the
`&[href]:hover` narrowing that removes the clickable affordance; for Bodeswell, the omitted `href`.
The closing decision paragraph now says option (a) is the current state and re-frames option (c) as
"the dead links put back", since "left exactly as they are" no longer means what it did.

### Two stale section headings, same defect class

- "Tab 11 read (images) — read-only, nothing changed" carried a question underneath it now marked
  fixed. Now reads "the read pass changed nothing; question 3 below was fixed later by the item-1
  work".
- "Phase 6, item 1 — image delivery (tab 11; `web/lib/sanityImage.js` new, `blog.js` +
  `blog/[slug].js` changed)" omitted two files the item has since touched. Now also names
  `changelog.js` and `home/intro.js`.

### One gap handed to me by the `web/next.config.js` owner

That agent's section above records: "`QUESTIONS-FOR-JESSICA.md` question 1 under 'Phase 6, item 4'
discloses the identical unbounded-violation problem for the GTM container's third-party tags but does
not mention the AdRoll cookie-match class. That file is not mine; the AdRoll class needs the same
sentence added there." It is my file, so I added it — after verifying the mechanism myself rather
than relaying it. Fetched `https://s.adroll.com/j/7HAXCLAXPNHL7DUHZJ7GQB/roundtrip.js`, 200,
116,080 bytes; the advertisable id matches the loader at `web/pages/_app.js:194`. Four `cm_urls`
occurrences: `cm_urls=[]`, two `.length` reads, one `.shift()`. Nothing pushes to it, so the hosts
come from AdRoll's server response at runtime and cannot be enumerated at any cost.

Question 1's opening claim was false as written — "the one hole I cannot close" — and is now "one of
two holes". The new paragraph names the mechanism, cites `web/next.config.js:27-29` where the same
explanation lives as a comment, records that widening `img-src` to `*` would silence it and destroy
the directive, and gives her the operational consequence she would otherwise learn the hard way:
**an `img-src` violation stream that never empties is expected, not a signal to keep waiting.**

### Final re-verification, after the edits

Siblings were writing the tree throughout, so every claim was re-checked at the end:

| Check | Expected | Actual |
|---|---|---|
| `.format(` in code in `web/lib/sanityImage.js` | 0 | 0 (single match is the comment forbidding it) |
| makelog `href` in `brands.js` | 0 | 0 |
| `href: "https://ca.la"` in `brands.js` | 1 | 1 |
| `<Quote to=` in `ready.js` | 0 | 0 |
| `"Content-Security-Policy"` key in `next.config.js` | 0 | 0 — still Report-Only, no BLOCKER |
| binary paths under `web/images/` or `web/public/` in `git status` | 0 | 0 |

### Scope

One file edited: `QUESTIONS-FOR-JESSICA.md`, plus this log. No file in the source repo was modified
by this agent — `git status` shows only sibling agents' work. No binary read, re-encoded, resized or
deleted. No link removed anywhere. No Sanity mutation: the dataset was read authenticated and
read-only, and `web/.env.local` was read once and not modified. No test written. Not committed, not
pushed.

## logs/phase-6-fixes-round-1.md

Finding (MED) asked for: every change carries a log record naming what was asked, whether it is done,
and the reason. Five `## File:` sections were destroyed by an overwrite before round 1 ended and were
never re-reported, leaving three working-tree files and two Sanity edits with no record.
Status: DONE.

Appended 247 lines to `logs/phase-6-fixes-round-1.md` (783 → 1030). The existing 783 lines are
byte-identical; the append was `cat >>`, and the line numbers of every pre-existing section are
unchanged (`## QUESTIONS-FOR-JESSICA.md` :3, `web/pages/blog/[slug].js` :78, the crazyegg Sanity
section :267, `web/next.config.js` :382, `web/pages/blog.js` :526, `SEO-CHANGELOG.md` :631).

Five records written, at `:806`, `:863`, `:915`, `:962`, `:996`:

| Record | Tab row | Status recorded |
|---|---|---|
| `web/lib/sanityImage.js` | Tab 11, `fm=webp` | NOT DONE as written — working tree removes `.format('webp')`, leaves `auto=format`; deviation recorded for Jessica |
| `web/lib/sanityImage.js` | Tab 11, cap width | NOT DONE by this file — the clamp caps at SOURCE width; the width half is at the call sites |
| `web/components/home/intro.js` | Tab 11, cap width | DONE |
| `web/components/home/brands.js` | Sanctioned item 2, makelog | DONE |
| Sanity `fcfc319d` `content[116].markDefs[2].href` | Tab 14 A17 | DONE for the reader-visible markDef; `content[115]` duplicate named as residue |
| Sanity `5fd6bab5` `content[35].markDefs[0].href` | Tab 14 A11 | DONE |

The destroyed text is unrecoverable — the log is untracked in `~/claude-hub`, so there is no committed
copy. The records are not a reconstruction of what the original agents wrote and say so at the top of
the section. Every fact in them was measured by this agent in round 2, on 2026-08-06:

- Row A7's asset at `w=2304&q=75&fit=clip`: `auto=format` + Chrome `Accept` → image/avif 314,063 B;
  `auto=format&fm=webp` → image/webp 400,542 B; `auto=format` no `Accept` → image/png 7,044,071 B.
- `intro.js` `sizes` re-derived from `web/styles/theme.js` (`mq[30]`=480 … `mq[80]`=1280) and the
  file's own `Styled.ImageContainer` / `Styled.ImageFrame` padding ladder. Eight viewport bands
  tabulated; every band is exact or over-declared, none under-declared.
- `https://www.makelog.com` → code 000 (TLS handshake fails); `http://www.makelog.com` → 200,
  NameBright parking page. `ca.la` → 172.67.68.183 / 104.26.4.176 / 104.26.5.176 on 1.1.1.1, fetch
  200 → `https://www.mercer.design/`, so it is ALIVE and was left alone.
- Replacement URLs fetched and confirmed before being written into a record:
  `https://www.pcmag.com` 200, `https://topgrading.com/` 200. Dead originals re-fetched:
  `https://topgrading.com/candidate-assessment/topgrading-job-scorecard/` 404, no redirect.
- Live read-only GROQ on both blogPosts: draft `_rev`s `QzNVnRn1RN9Wy2ys8PEBCp` and
  `guLb7mLdCgNrjUoWf9NRxo`; published `_rev`s still the pre-audit 2023 values
  (`LK25dP7vICeIYdOu8ZrX7Z` / 2023-02-15, `D1lygl0QlSsqL8Gf8Zw18X` / 2023-01-31); `count(content)`
  134 and 155 in draft and published alike.
- `content[115]`'s single span `82cbf6406b5d0` has `marks: []`, confirming the duplicate pcmag markDef
  renders no anchor. `markDefs[0]` `https://www.g2.com/` and `markDefs[1]` `https://www.capterra.com`
  are byte-identical in both blocks — bot-walls, untouched.

`web/components/feature.js`, `web/pages/changelog.js` and
`web/components/industries/industryHeader.js` appeared in the working tree during round 2. They are
round-2 agents' files; the appended section names them as belonging in this log rather than round 1's,
so their absence there is not read as a second gap.

### Not changed

No file in `/Users/jessica/wrk/wrk-corp/wrk-marketing` was created, edited or deleted. No Sanity
mutation of any kind — the token in `web/.env.local` was read once for authenticated read-only GROQ
and the file was not modified, and the token is not reproduced anywhere. No binary read or written.
No link removed or altered. Branch `seo-phase-6-images-links-headers` at start and end. Nothing
committed, nothing pushed. No test written.

## web/components/feature.js

Tab 11 A66, A68, A70, A76, A80 asked for: "next/image already optimizing; lower quality/width for marketing shots" — the width half.
Status: DONE.

A69 and A71 are billboard images rendered by `web/components/candidateManagement/intro.js`, `web/components/home/intro.js` and `web/components/industries/industryHeader.js`. Those are not this agent's file and were not touched.

### The change

One prop on the single `<Image layout="responsive">` at line 65:

```diff
                 layout="responsive"
+                sizes="(min-width: 1152px) 722px, (min-width: 896px) calc(66.7vw - 74px), calc(100vw - 32px)"
```

Plus an eight-line comment above `export default function Feature` recording where the numbers come from, so `722px` is not a bare magic number the next grid change silently invalidates.

### Where the numbers come from

Measured, not guessed. `Container` is `max-width: 80rem` with `px(4)` / `px(5)` at `mq[40]` / `px(8)` at `mq[56]` / `px(16)` at `mq[72]`. `Styled.Grid` is `max-width: 1213px`, `grid-template-columns: 1fr 2fr` when `layout="thirds"` and `502fr 642fr` otherwise, `gap: 48px` at `mq[56]`, `69px` at `mq[72]`. The `2fr` of `thirds` is 0.667 of the track space against the default column's 642/1144 = 0.561, so `thirds` is the wider of the two everywhere and one `sizes` string sized to it cannot undershoot the other.

`platoVideo.js`'s `(min-width: 1214px) 1086px` was not copied. It describes a full-width `Styled.Frame` inside the same `Container`; this is a grid column beside a text column, and its width is different at every breakpoint.

### Measured against the running dev server on :3000

`Styled.ImageColumn`'s real width vs. the width the `sizes` attribute declares at that viewport, resolved through a probe element rather than by re-deriving the arithmetic:

| Viewport | Clause in force | Actual column | Declared | Headroom | Undershoot |
|---|---|---|---|---|---|
| 1440 | `722px` | 722.0 | 722 | 0 | no |
| 1152 | `722px` | 626.7 | 722 | 95.3 | no |
| 1151 | `calc(66.7vw - 74px)` | 682.7 | 693.7 | 11.0 | no |
| 896 | `calc(66.7vw - 74px)` | 512.7 | 523.6 | 10.9 | no |
| 375 | `calc(100vw - 32px)` | 328.0 | 343 | 15.0 | no |

No viewport undershoots, so no image is served below its rendered size. The 95px headroom at exactly 1152px is the cost of one flat value across the whole `mq[72]` band; at DPR 2 it selects the same 1494 candidate the true width would, so it costs nothing there, and at DPR 1 it is one srcset step.

The 1440 row is the `thirds` layout. The default `502fr 642fr` layout measured 607.8px at the same viewport on `/`, under the same 722px declaration.

### Chosen srcset candidate, before and after

`deviceSizes` is `[640, 750, 828, 1088, 1494, 1662, 2304]` in `web/next.config.js` and is pre-existing — this branch's diff to that file is the CSP and headers block only.

Every one of the five images the tab lists for this component, re-read from `img.currentSrc` at viewport 1440 DPR 1:

| Tab row | Built asset in currentSrc | Chosen `w` before | after |
|---|---|---|---|
| A66 | `jobdetail.f5606e05.png` | 2304 | 750 |
| A68 | `profile.5970387b.png` | 2304 | 750 |
| A70 | `jobsettings.a5f65853.png` | 2304 | 750 |
| A76 | `chat-feature.6216d26a.png` | 2304 | 750 |
| A80 | `messages.314784b3.png` | 2304 | 750 |

All five hashes are the ones in the tab's own truncated URLs.

### Bytes, fetched from production

`https://www.polymer.co/_next/image?url=%2F_next%2Fstatic%2Fmedia%2F<hash>.png&w=<w>&q=75`, desktop Chrome UA:

| Tab row | w=2304 | Tab's recorded bytes | Match | w=750 |
|---|---|---|---|---|
| A66 | 290408 | 290408 | exact | 55055 |
| A68 | 179989 | 179989 | exact | 44663 |
| A70 | 159870 | 159870 | exact | 32664 |
| A76 | 122204 | 122204 | exact | 32084 |
| A80 | 111538 | 111538 | exact | 29960 |

The `w=2304` column reproduces the tab's B-column byte-for-byte, which confirms these five rows are these five call sites. 864,009 bytes to 194,426 at DPR 1. All five drop under the 100 kB threshold that put them on the tab.

### Scope

`web/components/feature.js` has exactly four importers — `components/home/features.js`, `components/candidateManagement/features.js`, `components/jobBoard/features.js`, `components/industries/industryFeatures.js` — and all four were measured. `components/feature-old.js` (imported by `pages/about.js`) and `components/feature-section.js` (imported by `pages/features.js`) are separate files and were not touched.

The one console warning during measurement was next/image's LCP `priority` hint on `jobsettings`, produced by this agent's own `scrollIntoView` making a below-fold image the LCP element. It is an artifact of the measurement, not of the change, and does not occur on normal load.

No binary asset was touched. No bot-walled link was removed. No replacement URL was written, so there was nothing to fetch and confirm 200. No test was written. Nothing was committed.

---

## web/components/industries/industryHeader.js — Round 2

**Tab 11 asked for:** row A71 (`_next/image?url=...billboard.5d18896b.png&w=2304&q=75`, 155,421 B) —
"next/image already optimizing; lower quality/width for marketing shots".

**Status: DONE.**

Added a `sizes` prop to the `<Image>` at line 45. One line; the surrounding comment explains the numbers.

```
sizes="(min-width: 1467px) 1317px, (min-width: 1280px) calc(100vw - 150px), (min-width: 1152px) calc(100vw - 140px), (min-width: 1024px) calc(100vw - 128px), (min-width: 896px) calc(100vw - 120px), (min-width: 640px) calc(100vw - 104px), (min-width: 480px) calc(100vw - 80px), calc(100vw - 56px)"
```

Before: no `sizes` prop, so next/image emitted `sizes="100vw"` and the browser took the largest
srcset candidate. Confirmed on the live site — `currentSrc` was `&w=2304` at every viewport measured.

### The row this file owns

Row A71 is `images/billboard.png`, imported by this file at line 7 and by
`web/components/home/intro.js` at line 7 — the same source file, the same build hash
`billboard.5d18896b.png`. Verified against the live site: `/` and
`/applicant-tracking-for-startups` both serve `billboard.5d18896b.png`.

Row A69 (`billboard.602746ef.png`) is **not** this file. It is
`images/candidateManagement/billboard.png`, rendered by `web/components/candidateManagement/intro.js`
on `/features/candidate-management-software` — verified by fetching that page and finding
`billboard.602746ef.png` in the markup. A separate file, not mine to touch.

### Where the numbers come from

`Styled.ImageContainer` horizontal space + `Styled.ImageFrame` padding, per breakpoint.
`html { box-sizing: border-box }` in `web/styles/global.js` line 70, so `max-width: 1435px` on
`Styled.ImageFrame` includes its own 59px padding: 1435 - 59*2 = 1317px.

| Nominal viewport | Container | Frame padding | Total deduction | sizes clause |
|---|---|---|---|---|
| < 480 | `px(2)` = 16 | 20px = 40 | 56 | `calc(100vw - 56px)` |
| >= 480 (`mq[30]`) | 16 | 32px = 64 | 80 | `calc(100vw - 80px)` |
| >= 640 (`mq[40]`) | `px(3)` = 24 | 40px = 80 | 104 | `calc(100vw - 104px)` |
| >= 896 (`mq[56]`) | `mx(4)`+`px(0)` = 32 | 44px = 88 | 120 | `calc(100vw - 120px)` |
| >= 1024 (`mq[64]`) | 32 | 48px = 96 | 128 | `calc(100vw - 128px)` |
| >= 1152 (`mq[72]`) | 32 | 54px = 108 | 140 | `calc(100vw - 140px)` |
| >= 1280 (`mq[80]`) | 32 | 59px = 118 | 150 | `calc(100vw - 150px)` |
| >= 1467 | max-width cap | | | `1317px` |

Breakpoints from `web/styles/theme.js` line 94; `html` sets no `font-size`, so 1rem = 16px.

### Verification — measured, not read off the CSS

Measured in Chromium via same-origin iframes at fixed widths, first against the live site
(pre-fix layout) and then against the local dev server serving this branch.

**1. Rendered width at 16 viewports, live site.** Predicted from the table above vs. measured
`getBoundingClientRect().width` on the hero `<img>`: **16/16 exact**, including both sides of every
breakpoint. 375→304, 480→385, 640→521, 896→761, 1024→881, 1152→997, 1280→1115, 1440→1275,
1467→1302, 1500→1317, 1700→1317.

**2. The `sizes` string resolves to the rendered width, 18 viewports, dev server.** Compiled the
string into an equivalent stylesheet (each clause becomes a media query) and measured a probe div
against the real image at 320/375/414/479/480/500/639/640/768/895/896/1024/1152/1280/1440/1467/1500/1920.
Every clause and every threshold resolves to **rendered width + 15px** — exactly the classic
scrollbar, since `100vw` includes it and the layout viewport does not. That is the over-fetch
direction and it never crosses a srcset candidate step. At and above 1467 the cap clause resolves to
1317 with delta 0.

A first pass of this probe had a split bug (the lookahead `,\s*(?=\()` never separated the trailing
non-parenthesised fallback clause), which silently skipped the two narrowest clauses. Re-run with a
plain `split(',')` — no clause contains a comma — and all 18 widths pass.

**3. The attribute survives the framework.** `curl` of
`http://localhost:3000/industries/applicant-tracking-for-startups` returns the `sizes` attribute
byte-identical to what is in the source, the 15-entry `srcSet` intact, and no
`has "sizes" property but it will be ignored` warning. `next/dist/client/image.js` line 150:
`sizes` is honoured for `layout="fill"` and `layout="responsive"`. Next 12.1.0 confirmed via
`require('next/package.json').version`.

Note `getWidths` (same file, line 149) only filters the candidate list by the smallest `vw`
percentage — `sizes` does **not** shrink the srcset. It changes which candidate the browser picks.
That is the whole mechanism of this fix.

### Payload effect

Real bytes from the live `/_next/image` endpoint with a Chrome `Accept` header (all served
`image/webp`, HTTP 200): 384→8,428 · 640→21,530 · 750→28,666 · 828→32,776 · 1088→50,450 ·
1494→77,856 · 1662→89,852 · 2304→130,106.

Candidate picked, before (`100vw`) vs after, at DPR 1:

| Viewport | Before | After | Saved |
|---|---|---|---|
| 1920 | 2304 (130,106 B) | 1494 (77,856 B) | 52,250 B |
| 1440 | 1494 | 1494 | 0 |
| 1280 | 1494 (77,856 B) | 1088 (50,450 B) | 27,406 B |
| 1024 | 1088 | 1088 | 0 |
| 896 | 1088 (50,450 B) | 828 (32,776 B) | 17,674 B |
| 768 | 828 (32,776 B) | 750 (28,666 B) | 4,110 B |

At DPR 2: 896 → 2304 becomes 1662, saving 40,254 B; 768 → 1662 becomes 1494, saving 11,996 B;
480 → 1088 becomes 828, saving 17,674 B; 375 → 750 becomes 640, saving 7,136 B. At 1024 and wider on
DPR 2 both land on the 2304 ceiling, so no change there.

### Deviation from the sibling worth naming

The finding said intro.js's string "applies verbatim". It does not, quite. `web/components/home/intro.js`
carries a four-clause string that skips the 480, 896, 1152 and 1280 padding steps; this file has all
eight clauses. Every skipped step in intro.js over-states the width, so intro.js is safe but
imprecise — and at 480px DPR 2 the difference is real: the four-clause value picks candidate 1088
where the eight-clause value picks 828. I wrote the complete string rather than copy an incomplete
one. Round 2's finding 3 asks the intro.js owner to add those same four steps; when that lands the
two strings should match character for character. If it does not land, these two files will differ
and the difference is deliberate.

### Untouched

`quality` not changed — `q=75` is next/image's default and lives in shared config, not this file.
No binary under `web/images/` or `web/public/` read, moved, re-encoded or deleted; `git status` on
both directories is empty. No other file modified.

---

## SEO-CHANGELOG.md

Three findings, all against the record rather than against shipped code. The only file I edited is
`/Users/jessica/wrk/wrk-corp/wrk-marketing/SEO-CHANGELOG.md`.

### HIGH — sanctioned item 2, `https://ca.la` recorded as dead

Asked for: verify each of the three customer links is dead yourself before touching it.
Status: DEFECT, fixed in the record. `ca.la` is alive and its href was never touched.

Verified independently before writing anything:

| Check | Result |
|---|---|
| `dig +short ca.la A @1.1.1.1` | `104.26.4.176`, `172.67.68.183`, `104.26.5.176` |
| `dig +short ca.la A @8.8.8.8` | same three records |
| `curl --resolve ca.la:443:104.26.4.176 https://ca.la`, desktop Chrome UA | `301` → `https://www.mercer.design/` |
| `curl https://www.mercer.design/`, desktop Chrome UA | `200` |
| `dig +short www.makelog.com @1.1.1.1` | CNAME `comingsoon.namebright.com` → `cdl-prd-https-247c6c9f427caacd.elb.us-east-1.amazonaws.com` → `54.84.240.235`, `44.208.83.180` |
| `curl https://www.makelog.com` | `000` — TLS handshake failure |
| `curl http://www.makelog.com` | `200`, NameBright parking page |
| `dig www.bodeswell.io A @1.1.1.1` | NXDOMAIN |

Working tree at the time of the fix: `brands.js:24` has the `makelog` href removed, `brands.js:26`
still carries `href: "https://ca.la"`, and `ready.js:87` had gone from `<Quote to="https://www.bodeswell.io/">`
to `<Quote>` between two of my own commands — a concurrent agent. So two of the three hrefs are gone
and the live one was never removed.

Four places in the changelog said or implied `ca.la` was dead. All four are corrected:

1. The Phase 6 working-tree bullet — rewritten. The file list above it was also five readings stale
   (four files listed, ten modified), so it was re-taken with the round-2 state and each new file
   attributed to the change that owns it.
2. A new `#### The three customer links on the home page` subsection under item 2, carrying the DNS
   and HTTP table above, both `before:`/`after:` diffs, and the decision that is Jessica's.
3. Item 2's verifier HIGH-1 — text preserved verbatim per this document's convention, with a bold
   note appended saying which part of it is wrong and which part still holds.
4. The closing "Raised by verifiers and not filed in the questions file" paragraph — rewritten,
   quoting what it used to say.

Item 2's `**Files:** none. Zero files were changed by this item.` line is also no longer true and now
names both files. Verifier LOW-5(b), "there is no diff from this item at all", got a bold note: there
is one now, and it removes no bot-walled link.

### MED — Tab 15 A7, the Content-Security-Policy record was stale

Asked for: Report-Only policy covering self + Sanity CDN + analytics.
Status: the header is correct and Report-Only. The record of it was the `6523c92` version.

Diffed `git show 6523c92:web/next.config.js` against the working tree. **Eleven** hosts were added,
not the ten the finding names — it missed the apex `https://analytics.google.com` in connect-src:

- script-src: `www.googleadservices.com`, `*.googlesyndication.com`, `lex.33across.com`, `connect.facebook.net`
- img-src: `www.google.com`, `www.googleadservices.com`, `*.googlesyndication.com`, `*.doubleclick.net`, `www.facebook.com`
- connect-src: `analytics.google.com`, `www.google.com`, `www.googleadservices.com`, `*.googlesyndication.com`, `*.doubleclick.net`, `www.facebook.com`
- frame-src: `*.googlesyndication.com`, `*.doubleclick.net`, `intercom-sheets.com`, `www.intercom-reporting.com`, `app.intercom.com`

Header key is still `Content-Security-Policy-Report-Only`; `grep -c "Content-Security-Policy'"` on
the file returns nothing that enforces. Directive count unchanged at eleven.

Edits:

- The printed policy block is now the working tree, labelled as such, with the `6523c92` form quoted
  beneath it for the diff.
- New `#### D. The eleven hosts round 1 added` — one row per host naming the bundle it comes from
  (`roundtrip.js`'s `add_script_element` / `render_advertisable_cell`, the GTM container's
  `__googtag`/`__awct`/`__awec` tags for `AW-16528421320`, `widget.intercom.io/widget/yblhzder`),
  plus the `Sm()` / `Pm()` reason the apex `analytics.google.com` cannot be matched by the wildcard.
  It also records the two classes that stayed out: the `__TAGGY_INSTALLED`-gated Google hosts, and
  AdRoll's `cm_urls` cookie-match pixels, which cannot be enumerated from the repo at all — so
  "clean week" has to be defined as clean apart from that class before the key is flipped.
- The "Known gaps … not closed" paragraph now names the four Intercom sources and the missing
  `media-src` that actually remain.
- Item 4 LOW-1 got a bold note (frame-src half closed, rest stands); LOW-2 got one (closed outright,
  plus the fourth host it did not know about).
- The security-headers `needsLiveCheck` list: the doubleclick expectation is gone, the AdRoll
  cookie-match class is added as its own entry.

### MED — the same ca.la line at :2985

Same defect, same fix, covered by item 4 of the HIGH above.

### Stale references the same fix passes created, corrected in the same edit

Per the hub CLAUDE.md rule on stale references after amendments:

- Item 1's HIGH bold note said three `sizes` call sites and that `blog.js` / `changelog.js` were "not
  yet in that list". There are **seven**, verified by `grep -rn "sizes=" web/pages web/components`:
  `blog/[slug].js:211` and `:393`, `blog.js:46`, `changelog.js:50`, `feature.js:74`, `intro.js:52`,
  `industryHeader.js:43`. Corrected, and deliberately still not marked resolved — none of it has
  been measured against a build.
- Item 1's own prose at the `**The clamp does not reach the other 44 rows**` paragraph carried the
  same "none of the three call sites" claim. Corrected.
- The `needsLiveCheck` entry saying `changelog.js` has no `sizes` prop. Corrected, and a new entry
  added: the seven values are arithmetic off the CSS, not observed widths, so the check is a
  DevTools `currentSrc` pass, not a byte measurement.
- The `QUESTIONS-FOR-JESSICA.md` section said sixteen questions under four headings. It is twenty
  under five — round 1 added the `Phase 6, item 2b` heading (3) and a fourth item-1 question (the
  `fm=webp` measurement), and struck the `changelog.js` one. Counted per heading with
  `grep -cE "^[0-9]+\. "`. The changelog's enumeration was renumbered per-heading to match the file,
  which also makes the existing cross-reference at "question 3 under Phase 6, item 4" correct — it
  was already using per-heading numbering against a running-count list.
- The closing "Two questions … are stale" paragraph: both are fixed in that file now.

### Not done

Nothing about `ca.la` was changed in code — the href at `web/components/home/brands.js:26` is
untouched and must stay. No binary read, moved or modified; `git status` carries no path under
`web/images/` or `web/public/`, and `git diff --stat seo-phase-5-structured-data...seo-phase-6-images-links-headers`
is six text files. No file other than `SEO-CHANGELOG.md` edited by me. Nothing committed.
