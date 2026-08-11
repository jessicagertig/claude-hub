# Phase 6 fixes — round 3

## web/components/home/brands.js

Sanctioned item 2 asked for: remove the dead `https://www.makelog.com` link, keep the logo.

Status: DONE in the working tree. No edit made this round.

### The finding is a commit-state finding, not a file-content finding

The round-3 finding says the removal "is an uncommitted working-tree edit and is not on the branch."
That is accurate and reproduces:

```
git -C /Users/jessica/wrk/wrk-corp/wrk-marketing status --porcelain
 M web/components/home/brands.js
```

`web/components/home/brands.js` is in `git status --porcelain` as ` M` and is not in
`git diff --name-only seo-phase-5-structured-data...HEAD`. Committing is the orchestrator's step and
this agent is instructed not to commit and not to push. There is no edit to
`web/components/home/brands.js` that moves the change onto the branch. The file's content is already
what the tab row asks for, so this round changed nothing in it.

### Independent re-verification of the two domains, 2026-08-06

`www.makelog.com` — DEAD.

| Check | Result |
|---|---|
| `dig www.makelog.com A` | NOERROR — CNAME `comingsoon.namebright.com.` → `cdl-prd-https-247c6c9f427caacd.elb.us-east-1.amazonaws.com.` → 44.208.83.180, 54.84.240.235 |
| `dig makelog.com A` | NOERROR — 44.208.83.180, 54.84.240.235 (apex behaves identically) |
| `curl -L https://www.makelog.com` | curl exit 35, `LibreSSL SSL_connect: SSL_ERROR_SYSCALL in connection to www.makelog.com:443`, HTTP code `000` |
| `curl -L http://www.makelog.com` | `200`, final URL `http://www.makelog.com/`, `<title>NameBright - Coming Soon</title>` |

A registrar parking page reachable only over plain HTTP. The `href` on line 24 is removed in the
working tree.

`ca.la` — ALIVE. Left in place, as in rounds 1 and 2.

| Resolver | `ca.la` A |
|---|---|
| system (192.168.0.1) | SERVFAIL |
| 1.1.1.1 | NOERROR — 104.26.4.176, 172.67.68.183, 104.26.5.176 |
| 8.8.8.8 | NOERROR — same three addresses |
| 9.9.9.9 | NOERROR — same three addresses |

`curl -L --resolve ca.la:443:172.67.68.183 https://ca.la` with a desktop Chrome user agent:
`200`, final URL `https://www.mercer.design/`, `<title>Mercer: AI-Powered Tools for Fashion</title>`.
CALA rebranded to Mercer; the link resolves and loads for every visitor whose resolver is not the
one on this machine. The orchestrator's sanctioned-items text calls `https://ca.la` dead with
SERVFAIL as the evidence; SERVFAIL reproduces only against the local resolver 192.168.0.1. Removing
it would be a live-link removal, so line 26 is untouched.

### Working-tree diff, unchanged from round 1

```
-    { src: makelog, alt: "Makelog", href: "https://www.makelog.com", width: 100 },
+    { src: makelog, alt: "Makelog", width: 100 },
```

```
-        {brands.map((brand) => (
-          <Link key={brand.alt} href={brand.href}>
-            <a target="_blank" rel="noreferrer">
-              <Image ... />
-            </a>
-          </Link>
-        ))}
+        {brands.map((brand) => {
+          const logo = (
+            <Image ... />
+          );
+
+          return brand.href ? (
+            <Link key={brand.alt} href={brand.href}>
+              <a target="_blank" rel="noreferrer">
+                {logo}
+              </a>
+            </Link>
+          ) : (
+            <a key={brand.alt}>{logo}</a>
+          );
+        })}
```

```
-      &:hover {
+      &[href]:hover {
```

`src`, `alt` and `width` on the Makelog entry are unchanged, so the logo stays on the page. The bare
`<a>` is kept rather than a `<span>` because `Styled.Logos` styles the `a` selector — `display: flex`,
`align-items`, `justify-content`, `opacity: 0.7`, `transition`. `&[href]:hover` keeps the hover
brighten on the eight linked logos and removes the clickable affordance from the unlinked one.

### QUESTIONS-FOR-JESSICA.md

Already carries all three entries, at
`/Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/QUESTIONS-FOR-JESSICA.md`
lines 211–219: `ca.la` ALIVE do-not-remove with the resolver split, `www.makelog.com` DEAD with the
NameBright evidence, `www.bodeswell.io` DEAD NXDOMAIN, and the open decision of whether the two
customers stay on the page at all. The file is outside this agent's one owned file and was not
edited. Note it lives in the audit build directory, not in the `wrk-marketing` repo — `find` over the
repo returns no `QUESTIONS-FOR-JESSICA.md`.

### Binary assets

None touched. `web/images/logos/makelog.svg` and `web/images/logos/cala.svg` are unread and unmodified.

---

## web/components/home/build.js

Tab 11 A4 asked for: cap width at rendered size, applied "in the same templates".

Status: DONE.

`sizes` added to the `layout="responsive"` `<Image>` at line 25. Without it next/image 12.1.0 emits
`sizes="100vw"` (`node_modules/next/dist/client/image.js:208` — `sizes: !sizes && kind === 'w' ? '100vw' : sizes`)
and the browser takes the widest `deviceSizes` candidate, `w=2304`.

```
sizes="(min-width: 1312px) 1152px, (min-width: 1152px) calc(100vw - 160px), (min-width: 896px) calc(100vw - 96px), calc(100vw - 64px)"
```

### Measured box chain

`Styled.Component` (section) -> `Container` -> `Styled.Screen` -> the inner `div` -> `<Image>`.
Root font-size 16px. `box-sizing: border-box` globally (`web/styles/global.js:70`). Breakpoints from
`web/styles/theme.js`: `mq[40]`=640, `mq[56]`=896, `mq[72]`=1152, `mq[80]`=1280.

| Element | Horizontal contribution |
|---|---|
| `Styled.Component` (build.js:45,49,53) | `mx(2)`=8px per side; `mx(3)`=12px from 640; `mx(4)`=16px from 896. `py`/`pt`/`padding-bottom` are vertical only. |
| `Container` (`web/components/container.js:14,19,23,27`) | `max-width: 80rem`=1280 (border-box), `px(4)`=16 per side; `px(5)`=20 from 640; `px(8)`=32 from 896; `px(16)`=64 from 1152. |
| `Styled.Screen` (build.js:79) | `position: relative`, no padding or margin. |
| inner `div` (build.js:85-98) | `width: 100%`, `border: ${t.spacing[2]}`=8px per side; `border: none` from 640. From 896 it is `position: absolute !important; top: 0` against `Styled.Screen`, whose content width is the same, so the width is unchanged. |

| Viewport | Content width | `sizes` term |
|---|---|---|
| < 640 | 100vw - 16 - 32 - 16 = 100vw - 64 | `calc(100vw - 64px)` |
| 640 - 896 | 100vw - 24 - 40 = 100vw - 64 | same term |
| 896 - 1152 | 100vw - 32 - 64 = 100vw - 96 | `calc(100vw - 96px)` |
| 1152 - 1312 | 100vw - 32 - 128 = 100vw - 160 | `calc(100vw - 160px)` |
| >= 1312 | 1280 - 128 = 1152 | `1152px` |

The `max-width: 80rem` cap binds when `100vw - 32 >= 1280`, i.e. from 1312px.

The `<640` and `640-896` bands both come to `100vw - 64px`, so they are one term.
The largest declared value is 1152px, which selects the `1494` candidate instead of `2304` on a
desktop at DPR 1.

`Styled.Screen`'s descendant selector `div { border: ...; width: 100% }` also matches next/image's
own wrapper and sizer divs, but both carry inline `border: 0`, `padding: 0`, `width: initial`
(`node_modules/next/dist/client/image.js`, `wrapperStyle` and `sizerStyle`), and inline wins over the
emotion class, so the 8px border is counted once — on the explicit `div` at build.js:24.

### The component is unreferenced

`web/components/home/build.js` is imported by no file. Searched `web/pages` and `web/components` for
`<Build`, for an import ending in `build`, and for the string `home/build`: zero hits. Nothing renders
it, so `images/settings.png` (3840x2160) never reached the crawler — consistent with it having no row
in tab 11. The `sizes` prop is correct for the layout the file declares and takes effect if the
component is ever mounted.

### Workbook check

`python3 read-workbook.py "11 Images"` A4 matches the orchestrator's quote verbatim, including
"fix in the same templates". No misquote.

The eight `_next/image` rows in tab 11 are A66 `jobdetail`, A68 `profile`, A69 `billboard.602746ef`,
A70 `jobsettings`, A71 `billboard.5d18896b`, A73 `plato-video-still`, A76 `chat-feature`, A80
`messages`. No `settings.png` row.

### Scope

One file edited: `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/components/home/build.js`. One JSX
attribute and one JSX comment added; no code restructured, nothing removed. No binary touched. No
link touched. No commit, no push. `@babel/parser` with the `jsx` plugin parses the file clean.

---

## SEO-CHANGELOG.md

File owned: `/Users/jessica/wrk/wrk-corp/wrk-marketing/SEO-CHANGELOG.md`. Branch confirmed
`seo-phase-6-images-links-headers`. Not committed, not pushed. No other file touched. No binary
read or written. No link removed anywhere.

### Workbook check

`python3 read-workbook.py "11 Images"`. Title A1, note A4, header row A6, the five worst rows and
the `D7`-style Fix batch string all match the orchestrator's quotation verbatim. The eight
`_next/image` rows read exactly as quoted, with `D66`–`D80` all
`next/image already optimizing; lower quality/width for marketing shots`. No misquote in the
orchestrator's brief.

One thing the workbook itself has wrong, which underpins all 71 Sanity rows and is already recorded
in the changelog: note A4 says the Sanity images are "requested as PNG at w=2304 without an explicit
webp/avif format", but every URL in column A already carries `auto=format`, and PNG comes back only
to a client that sends no image `Accept` header.

### Finding 1 — MED, rows A66/68/69/70/71/73/76/80 closed on a capability the config does not have

Asked for (tab D column): "next/image already optimizing; lower quality/width for marketing shots".

Status of the record before this round: DEFECT. `SEO-CHANGELOG.md` said twice, at the
"Oversized images NOT compressed" paragraph and under "Tab rows not actioned", that these rows are
"served through Next's own optimizer, which already negotiates WebP/AVIF".

Verified, not accepted:

- `web/next.config.js` `images` sets `domains` and `deviceSizes` only. There is no `formats` key.
  Next 12.1.0 (`node_modules/next/package.json`) defaults `images.formats` to `['image/webp']`;
  `node_modules/next/dist/server/config.js:272` is the validator that only lets `image/avif` and
  `image/webp` through, which is the opt-in point. The branch never touched `images.formats` —
  `git diff seo-phase-5-structured-data...seo-phase-6-images-links-headers -- web/next.config.js`
  is the CSP constant and the `headers()` block.
- All eight rows fetched from production 2026-08-06, `w=2304&q=75`, with a Chrome
  `Accept: image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8` header: every one
  returns `content-type: image/webp`. Not one returns AVIF. A71 is 130,106 bytes as WebP against
  155,421 as PNG with no `Accept` header.

Tab 11's Fix column for these eight asks for no format change, so no tab instruction is unmet. The
defect was the record, and it is corrected in both places.

### Finding 3 — MED, the same eight rows recorded as un-reconstructed and needing nothing

The changelog said they "were not fetchable as written and were not reconstructed" — in the same
sentence that named all eight reconstructed filenames — and that "all their call sites already pass
explicit `width` and `height`", which put all eight under "Tab rows not actioned" as needing nothing.

Re-fetched all eight myself rather than taking round 2's five, joining the content hash back to
`/_next/static/media/`, no `Accept` header:

| Row | Asset | Tab B column | Fetched |
|---|---|---|---|
| A66 | `jobdetail.f5606e05.png` | 290408 | 290408 |
| A68 | `profile.5970387b.png` | 179989 | 179989 |
| A69 | `billboard.602746ef.png` | 161941 | 161941 |
| A70 | `jobsettings.a5f65853.png` | 159870 | 159870 |
| A71 | `billboard.5d18896b.png` | 155421 | 155421 |
| A73 | `plato-video-still.d3d29022.png` | 132084 | 132084 |
| A76 | `chat-feature.6216d26a.png` | 122204 | 122204 |
| A80 | `messages.314784b3.png` | 111538 | 111538 |

Eight of eight, byte for byte. Call sites traced: A66/A68/A70/A76/A80 through
`web/components/feature.js:73` (four importers — `components/home/features.js`,
`components/candidateManagement/features.js`, `components/jobBoard/features.js`,
`components/industries/industryFeatures.js`); A69 through
`web/components/candidateManagement/intro.js:47`; A71 through `web/components/home/intro.js:51` and
`web/components/industries/industryHeader.js:42` (same source `web/images/billboard.png`, same build
hash); A73 through `pages/plato.js:11` → `web/components/plato/platoVideo.js:45`, which is
`layout="fill"` and already carried `sizes="(min-width: 1214px) 1086px, 100vw"` before this audit.

Seven of the eight have had a `sizes` prop added across the three fix rounds; A73 already had one.
The record now carries the per-row table and the byte figures, and says the width half is actioned
and uncommitted while the quality half was not touched (every call site is still at next/image's
default `q=75`, and no tab row names a target quality).

### Finding 4 — MED, the record never said how many call sites still emit `sizes="100vw"`

Counted the whole surface rather than the seven the record named. 16 `<Image layout="responsive">`
call sites in `web/pages` and `web/components`, enumerated by walking every `.js` file and reading
the enclosing `<Image …/>` block for a `sizes=` attribute. Nine carry one; **seven do not**:

| Call site | Renders on |
|---|---|
| `web/components/feature-old.js:28` | `/about`; `/` behind `NEXT_PUBLIC_REFERRER_SOURCE` via `components/home/partnerSetup.js` |
| `web/components/feature-section.js:32` | `/features` |
| `web/components/feature-section.js:41` | `/features` |
| `web/components/home/integrations.js:144` | `/` |
| `web/components/home/tailor.js:46` | `/` |
| `web/components/jobBoard/intro.js:41` | `/features/jobboard` |
| `web/components/plato/platoFeature.js:58` | `/plato` |

Importers traced for each; `partnerSetup` is rendered at `pages/index.js:25` behind
`process.env.NEXT_PUBLIC_REFERRER_SOURCE`, `platoFeature` through
`components/plato/platoFeatures.js` at `pages/plato.js:27`. None of the seven carries a tab 11 row
of its own, which is why the record now names them under note A4's "fix in the same templates"
rather than under a row.

The count moved twice while this round ran — `web/components/candidateManagement/intro.js` and
`web/components/home/build.js` both gained a prop from concurrent round-3 agents — so the entry says
so and is written as a snapshot.

### Finding 5 — MED, the needsLiveCheck entry asked for a pass that had already been run

The entry read "The seven `sizes` props have not been measured against a build or a browser. Each
value is arithmetic off the container chain in the CSS, not an observed rendered width." Checked
each against its own log:

Browser-measured (3): `web/pages/blog.js:46` (`phase-6-fixes-round-1.md`, "Check — real browser
selection, not reasoning" — fresh `new Image()` with a cache-busted srcset over the real
`deviceSizes` ladder at DPR 1, 1662 → 640 for a 612px slot, after the first probe was confounded by
the already-loaded `<img>`); `web/components/feature.js:74` (`phase-6-fixes-round-2.md` — probe
element measuring `Styled.ImageColumn`'s real width at five viewports on :3000, then `img.currentSrc`
re-read at 1440 DPR 1 for all five tab rows, 2304 → 750); `web/components/industries/industryHeader.js:43`
(`phase-6-fixes-round-2.md` — `getBoundingClientRect().width` at 16 viewports live, 16/16 against the
predicted table; the `sizes` string compiled into a stylesheet and measured against a probe div at 18
viewports on the dev server; `curl` confirming the attribute survives with the 15-entry `srcSet`).

Arithmetic only (6): both `web/pages/blog/[slug].js` sites, `web/pages/changelog.js:50` (slot width
derived from the `Styled.Post` 9-column grid — production bytes were fetched per candidate, but the
chosen candidate is stated, not read off `currentSrc`), `web/components/home/intro.js:52`, and the
two round-3 additions.

The entry is now split into those two lists, with the log evidence named on each line, so the
DevTools pass is scoped to the six that need it. The "not measured against a `next build`" half of
the original sentence is true of all nine and is kept.

### Finding 2 — HIGH, the record never said the PR ships the opposite of what it describes

`git diff --stat seo-phase-5-structured-data...seo-phase-6-images-links-headers`: six files —
`SEO-CHANGELOG.md`, `web/lib/sanityImage.js`, `web/next.config.js`, `web/pages/blog.js`,
`web/pages/blog/[slug].js`, `web/pages/changelog.js`. Read the diff rather than the file list:

- `web/lib/sanityImage.js` in the diff chains `.format('webp')`. The working tree does not — the
  round-1 reversal the record calls deliberate is uncommitted.
- No file in the diff carries a `sizes` prop.
- `web/next.config.js` in the diff is the pre-round-1 policy without the eleven added hosts.
- `web/components/home/brands.js` and `web/components/home/ready.js` are not in the diff at all, so
  `https://www.makelog.com` and `https://www.bodeswell.io/` are still linked on `/`.

Individual entries were marked "uncommitted at the time of writing"; nothing said what they add up
to. A table stating exactly that now sits directly under the working-tree file list at the top of
the Phase 6 section, with the note that committing is the orchestrator's step and no fix round on
this branch was permitted to commit or push.

### Stale references this amendment created, corrected in the same pass

- The `git status --short` snapshot at the top of the section listed ten files; it lists twelve now,
  with `web/components/candidateManagement/intro.js` and `web/components/home/build.js` added and
  the lead-in sentence re-dated to round 3.
- The bullet naming the files that carry `sizes` props listed six; it names eight files / nine call
  sites.
- Item 1's HIGH-finding bold note said "Seven responsive `next/image` call sites now pass a `sizes`
  prop"; it now says seven as of the end of round 2 and points at the round-3 count below it.
- The needsLiveCheck `changelog.js` entry said "so do six other call sites"; eight.
- The "Raised by verifiers and since filed" paragraph said "now applied on seven call sites"; nine.
- `web/components/home/build.js`'s `sizes` attribute is at `:37`, not `:36` — the round-3 log for
  that file cites line 25 for the `<Image>`, which is the pre-edit number.

### Not done

Nothing else in the file was touched. The verifier text throughout Phase 6 open items is preserved
verbatim, per the convention the rest of this changelog follows — corrections are appended in bold
rather than rewritten over the finding.

### Scope

One file edited: `/Users/jessica/wrk/wrk-corp/wrk-marketing/SEO-CHANGELOG.md`. No code file, no
binary, no Sanity document, no link. No replacement URL was written, so there was nothing to fetch
and confirm 200 beyond the eight `_next/image` and CSP-unrelated verification fetches above, all of
which returned 200. No test written. No commit, no push.
