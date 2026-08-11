# Phase 6 review — images, links, headers

Branch `seo-phase-6-images-links-headers`, PR #51 (open, head `4ef4598`).
Tabs reviewed: 11 Images, 14 External Links, 10 Wrk Legacy, 15 Security Headers.

**Workbook check.** I ran `read-workbook.py` on all four tabs and compared every quoted
string. Tab 11 (79 data rows A7-A85, note A4, the Fix batch string, the five worst rows, the
eight truncated `_next/image` rows), tab 14 (16 rows A7-A22, 20 URLs, E17 "Update to
https://www.pcmag.com"), tab 10 (A7-A10) and tab 15 (A7-A10) all match the orchestrator's
quotation cell for cell. No misquote.

**One correction to the brief itself.** The brief states `https://ca.la` "no longer resolves —
SERVFAIL". It resolves. `dig ca.la @1.1.1.1` and `@8.8.8.8` both return NOERROR with three
Cloudflare A records (172.67.68.183, 104.26.4.176, 104.26.5.176), and `curl --resolve
ca.la:443:104.26.4.176 -L https://ca.la` returns `200` at `https://www.mercer.design/`. The
SERVFAIL comes from this machine's resolver at 192.168.0.1. The link was correctly left in place.

**One correction to a round-3 reviewer.** The `dead-links` agent reported "298 documents, zero
with a `drafts.` id prefix" and concluded the tab-10 and tab-14 replacements do not exist. It
queried the Sanity API unauthenticated, which never returns drafts. I re-queried project
`a6d1clb1` dataset `production` with the token in `web/.env.local`: all five drafts exist, with
`_updatedAt` between `2026-08-06T02:51:58Z` and `2026-08-06T09:39:55Z`. That finding is withdrawn.
The replacements are real; they are unpublished, which is a different problem and is below.

---

## 1. Still not done, and why

### HIGH — none of the review's work is on PR #51

Asked for: the phase-6 work, on the branch under review.
Status: **NOT DONE.**
Reason: `git diff --name-only seo-phase-5-structured-data...seo-phase-6-images-links-headers`
returns six files and `gh pr view 51` returns the same six. Thirteen files are modified in the
working tree; ten of them are not in the PR. What PR #51 ships today, at `4ef4598`:

| | On PR #51 (`4ef4598`) | In the working tree |
|---|---|---|
| `web/lib/sanityImage.js` | `.format('webp')` present | `.format('webp')` removed |
| `sizes` prop | on zero call sites | on nine call sites |
| CSP | pre-round-1 source list | eleven hosts added |
| `web/components/home/brands.js` | not in diff — `https://www.makelog.com` still linked | `href` removed |
| `web/components/home/ready.js` | not in diff — `https://www.bodeswell.io/` still linked | `to` prop removed |

Merging PR #51 as it stands ships `fm=webp`, which `SEO-CHANGELOG.md` line 3001 now records as
deliberately reversed, and ships neither the width fix nor either link removal.

### HIGH — tab 10 A8-A10 and tab 14 A7-A11: replacements exist only as unpublished Sanity drafts

Asked for: replace the three dead `help.wrk.xyz` links with current Polymer help articles;
remove or replace the crazyegg citation; link Topgrading's homepage or remove.
Status: **DONE INCOMPLETELY.**
Reason: every published document still carries the dead URL. Verified by authenticated GROQ:

- `changelog` `914dc19a-965f-4e6d-8187-2db998abba02` → still `help.wrk.xyz/.../5280480-configuring-a-custom-domain`
- `changelog` `609fbb42-fc71-4d5b-a64a-cb7d49d4c11f` → still `.../5721143-...-slack-workspace`
- `changelog` `3d2afcd8-1acf-429c-81fa-ece69c210185` → still `.../5721747-...-discord-server`
- `blogPost` `fcfc319d-8b14-46d0-aef5-fc1fdd751060` `content[77].sourceUrl` → still `crazyegg.com/blog/recooty-review/`
- `blogPost` `5fd6bab5-52c6-427b-8868-3ed93b458088` `content[35].markDefs[0].href` → still the topgrading 404

The `drafts.*` twins carry the correct values. `web/lib/sanity.js` builds its client with no
token and `useCdn: true`, so an unauthenticated read returns published documents only —
`/changelog` renders all three 404s to every reader today. Publishing is not sufficient on its
own: `web/pages/changelog.js` and `web/pages/blog/[slug].js` both use `getStaticProps` with no
`revalidate`, so a rebuild and redeploy is required after publish. **Neither tab closes when
PR #51 merges.**

A fourth published document is in the same state and appears on no tab: `blogPost`
`fcfc319d-...` `content[7].markDefs[0].href` still holds
`help.wrk.xyz/en/articles/4436181-have-your-job-posts-appear-in-google-jobs` (404 confirmed). Its
draft repoints it to the `help.polymer.co` form (200 confirmed). The markDef is orphaned — no
span carries it — so it renders no anchor either way.

### HIGH — tab 14 A17: one of the two pcmag markDefs is still `http`

Asked for: update `http://www.pcmag.com` to `https://www.pcmag.com`.
Status: **DONE INCOMPLETELY.**
Reason: `drafts.fcfc319d-8b14-46d0-aef5-fc1fdd751060` `content[116].markDefs[2].href` reads
`https://www.pcmag.com`; `content[115].markDefs[2].href` still reads `http://www.pcmag.com`.
Verified by direct query of both paths in both the draft and the published document. Block 116's
span `9968f7144d325` (text "PCMag") carries the mark, so 116 is the rendered anchor. Block 115's
markDef is orphaned and renders nothing — but the raw Portable Text is serialized into
`__NEXT_DATA__`, so the `http` form survives in the page JSON after publish. The same run
repointed the equally orphaned markDef in `content[7]` of the same document, so the two orphans
got different treatment.

### MED — tab 11 rows A66, A68, A69, A70, A71, A73, A76, A80: the quality half

Asked for: "next/image already optimizing; **lower quality**/width for marketing shots".
Status: **NOT DONE.**
Reason: `web/next.config.js` sets `domains` and `deviceSizes` and no `quality`; no call site
passes a `quality` prop; next/image's default is 75, which is what all eight crawled URLs show
(`&q=75`). The width half of that row is now covered on all eight — see the table in section 3.
The orchestrator's brief quotes these eight rows' paths but omits their Fix batch text, which is
why the quality instruction reached no agent.

### MED — seven responsive `next/image` call sites still emit `sizes="100vw"`

Asked for, per tab 11 note A4: fix "in the same templates".
Status: **DONE INCOMPLETELY.**
Reason: the repo has 16 `<Image layout="responsive">` call sites. Nine carry a `sizes` prop.
Seven do not, and each therefore fetches the `w=2304` candidate:

`web/components/feature-section.js:32` and `:41`, `web/components/feature-old.js:28`,
`web/components/home/tailor.js:46`, `web/components/home/integrations.js:144`,
`web/components/jobBoard/intro.js:41`, `web/components/plato/platoFeature.js:58`.

None of their assets is a tab-11 row — I checked each of the eight `_next/image` rows against its
call site and all eight are covered. This is the same defect left standing on files the fix
passes did not reach, not a tab row missed.

### MED — CSP source gaps (Report-Only, so nothing breaks today)

Asked for: "Report-Only policy covering self + Sanity CDN + analytics; enforce after a clean week."
Status: **DONE INCOMPLETELY.**
Reason: four classes of source the site loads are in no directive. Each files a browser console
report today and would be blocked if the key were switched to `Content-Security-Policy`.

1. `static.intercomassets.com` — 51 references in `js.intercomcdn.com/intersection/assets/app.js`,
   the bundle the widget stub pulls, including the default-avatar image set. `img-src` has no
   `static.intercomassets.com` and no `blob:`; `*.intercomcdn.com` does not match `intercomassets.com`.
2. `app.getsentry.com` — `widget.intercom.io/widget/yblhzder` carries
   `sentry_dsn:"https://…@app.getsentry.com/24287"`. Absent from `connect-src`. May be posted from
   inside the `www.intercom-reporting.com` iframe rather than the parent document.
3. Google Ads remarketing, non-`.com` domains — `gtag.js` for `G-SHNM5E7QKD` builds the
   `ga-audiences` URL only when the Google domain is **not** `google.com`
   (`d&&Ub(d,"google.")&&d!=="google.com"`). The policy allows `https://www.google.com` only, so
   `www.google.de`, `www.google.co.uk` and the rest are uncovered. The apex `https://google.com`
   `/pagead/form-data` and `/ccm/form-data` endpoints in the GTM container are likewise uncovered.
4. AdRoll cookie-match pixels — `roundtrip.js` does `var a=this.cm_urls.shift(),b=new
   Image;b.src=a` in `popAndSend`, and `cm_urls` is populated from AdRoll's server response. Those
   partner hosts cannot be enumerated from the bundle or the repo, so the img-src report stream
   never goes empty. This one is disclosed in the file comment.

### LOW — no CSP report collector, so the "clean week" cannot be measured

`web/pages/api/` holds only `hello.js`, the untouched Next scaffold; there is no `report-uri` or
`report-to` directive. Violations reach the visitor's own browser console and nowhere else. The
two gaps above are the concrete case: the `lex.33across.com` script fires only for US-non-California
Safari visitors, and the Google Ads hosts only when a container tag fires. Neither appears in a
local console pass. Disclosed in `logs/phase-6-security-headers.md`.

### LOW — `frame-ancestors 'self'` is inert as delivered

The directive is ignored in a `Content-Security-Policy-Report-Only` header — it neither restricts
framing nor reports on it. The framing restriction actually in force is `X-Frame-Options:
SAMEORIGIN`, three entries above it. The file comment above the policy reads "Every source below
traces to a file that proves the site loads it", which reads as though every directive is live.

### LOW — `img-src https://api.producthunt.com` has no call site

`grep -rn producthunt` over `web/` excluding `node_modules` and `.next` returns exactly two hits:
the `img-src` line and the `images.domains` line below it. No component, page, lib, style or
public asset references it, and no Sanity document does either. `images.domains` is a permission
list for `next/image`, not a load.

### LOW — the same asset carries two different `sizes` strings

`web/images/billboard.png` (tab 11 row A71) renders from `web/components/home/intro.js:51` and
`web/components/industries/industryHeader.js:42`. The `Styled.ImageContainer` / `Styled.ImageFrame`
/ `Styled.ImageWrapper` blocks are identical apart from the label, but `intro.js:52` carries four
clauses where `industryHeader.js:43` carries eight — the 480px, 896px, 1152px and 1280px padding
steps are skipped, so `intro.js` over-declares by 24px, 16px, 12px and 22px in those bands.
Over-declaration only; both strings pick the same srcset candidate at every band at DPR 1 and 2.

### LOW — both unlinked elements are still anchors

`web/components/home/brands.js:53` renders `<a key={brand.alt}>{logo}</a>` for the Makelog entry —
an anchor with no `href`. `web/components/quote.js:8` renders `<a href={props.to} target="_blank"
rel="noreferrer">` unconditionally, so with `to` dropped the Bodeswell quote keeps `target` and
`rel` on an anchor React renders without `href`. Both are held in place by the `a` selector in
`Styled.Logos` (brands.js:118) and by `Styled.Component` in quote.js; swapping either for a
`<span>` needs that selector widened. `brands.js:125` was changed from `&:hover` to `&[href]:hover`
in the same edit so the unlinked logo carries no hover affordance.

### LOW — pre-existing CSS defect in the container chain, not introduced here

`web/components/section.js:23` reads `${t.mq[56]} {aer` — a stray token opening the media-query
block. It compiles to `@media (min-width: 56rem){.k{aer margin-left:1rem;…}}` and the browser
drops the invalid declaration, so from 896px up every `Section`-wrapped page keeps
`margin-left: 0.75rem` from the `mq[40]` rule while `margin-right` becomes `1rem`. Not in this
branch's diff and not in the working tree. Recorded because it shifts the `/changelog` container
arithmetic by 4px for anyone re-deriving a `sizes` value from the source.

---

## 2. Needs Jessica

Five decisions. Each is a question no agent can settle.

**1. `fm=webp` or `auto=format` on the Sanity images?**
Commit `6523c92` shipped `.format('webp')`; the fix passes removed it and that removal is
uncommitted. Measured on tab 11 row A7 (`7502b125…-3200x3558.png?w=2304&q=75&fit=clip`):

| Request | Response |
|---|---|
| `auto=format`, no `Accept` header | `image/png`, 7,044,071 B — tab 11 cell B7 exactly |
| `auto=format`, Chrome `Accept` | `image/avif`, **314,063 B** |
| `auto=format`, `Accept` advertising webp but not avif | `image/webp`, 400,566 B |
| `auto=format&fm=webp`, any `Accept` | `image/webp`, 400,542 B |

`fm=webp` costs a Chrome-class client 86,479 bytes (27.5%) on this asset and does the tab's fix
column literally. `auto=format` alone is what the crawl already saw, so a re-crawl by the same
tool reports all 71 rows unchanged at the same sizes. Which ships?

**2. The CALA logo now points at Mercer.**
`https://ca.la` works — it 301s to `https://www.mercer.design/`, title "Mercer: AI-Powered Tools
for Fashion". `web/components/home/brands.js:26` still carries the CALA mark and `alt: "CALA"`.
Leave it, swap the logo for Mercer's, or drop the link and keep the logo?

**3. Publish the nine Sanity drafts?**
Tab 10 and tab 14 close on publish plus a rebuild, not on merging PR #51. One draft bundles work
from three phases: `drafts.fcfc319d-8b14-46d0-aef5-fc1fdd751060` differs from published at four
leaf paths — `pageTitle` (phase 4 / tab 07), `content[7].markDefs[0].href` (the out-of-tab 4436181
link), `content[77].sourceUrl` unset (tab 14 A10) and `content[116].markDefs[2].href` (tab 14 A17).
Publishing it ships all four; there is no way to take one without the rest. Publish now?

**4. Makelog and Bodeswell are unlinked but still on the page.**
`www.makelog.com` is a NameBright domain-for-sale page (HTTPS handshake fails, HTTP returns 200).
`www.bodeswell.io` is NXDOMAIN and the apex has zero A and zero AAAA records. Both logos and the
Bodeswell quote and attribution are intact with the links gone. Do the customers stay on the page?

**5. Lower `next/image` quality below the default 75 for the marketing shots?**
Tab 11's Fix batch for the eight `_next/image` rows asks for "lower quality/width". The width half
is done; the quality half is a one-line `images.quality` in `web/next.config.js` and is a visual
trade-off, not a mechanical one. Those eight rows total 1,313,455 crawler-reported bytes, and
those are PNG figures with no `Accept` header, so the real saving is smaller than the tab suggests.
Drop it, and to what?

---

## 3. Fixed during review

Everything in this section is **uncommitted working tree**, not on PR #51. See the first HIGH.

- **Tab 11, the width half — nine `sizes` props added.** Each value derived from that call site's
  own measured container chain, with the measurement written into a comment beside it. Full table
  below. None was copied from `platoVideo.js`.
- **Tab 11 row A69** (`billboard.602746ef.png`) — `web/components/candidateManagement/intro.js:48`
  now carries the same eight-clause string as `industryHeader.js:43`, which shares its container
  chain byte for byte. This was the last uncovered `_next/image` row.
- **Sanctioned item 2** — `https://www.makelog.com` removed from `web/components/home/brands.js:24`
  (logo, `alt` and `width` kept; the map wraps in `Link` only when `brand.href` exists);
  `https://www.bodeswell.io/` removed from `web/components/home/ready.js:87` (the `to` prop
  dropped; photo, quote and attribution untouched). `https://ca.la` correctly left in place.
- **Sanctioned item 2, the record** — all three customer links are now in `QUESTIONS-FOR-JESSICA.md`
  under "Phase 6, item 2b" with resolver output, HTTP results, file and line, and the stay-or-go
  decision put to Jessica.
- **The `ca.la` verdict** — `SEO-CHANGELOG.md` recorded it twice as SERVFAIL/dead and queued for
  removal. Both statements are corrected in place (lines 2529, 3123), the measurements are recorded
  at line 2525, and the href was never touched.
- **The `fm=webp` record** — the changelog stated four times that `fm=webp` was not applied when
  `6523c92` applied it. Corrected in place (lines 2463, 3001), including the round-1 reversal and
  the measurement it rests on.
- **The commit-state record** — the changelog stated "Nothing in this phase was committed or
  pushed" and printed a four-line `git status`. Corrected at line 2273 to name `6523c92` and PR #51.
- **The `web/pages/changelog.js` record** — the file was changed by `6523c92` and listed nowhere.
  Now in the file list at line 2306 and in the call-site count at line 2958.
- **CSP sources added in the fix passes** — `www.googleadservices.com`, `*.googlesyndication.com`,
  `lex.33across.com`, `connect.facebook.net` (script-src); `www.google.com`, `*.doubleclick.net`,
  `www.facebook.com` (img-src and connect-src); `intercom-sheets.com`, `www.intercom-reporting.com`,
  `app.intercom.com` (frame-src); the apex `analytics.google.com` (connect-src, with the `Pm()`
  derivation recorded in the file comment).
- **Tab 15 rows A8, A9, A10** — `nosniff`, `SAMEORIGIN`, `strict-origin-when-cross-origin`, at the
  tab's exact recommended values, on `source: '/:path*'`. **DONE.**
- **Tab 10 row A7** — the Webflow post. **DONE**, and the row's premise does not hold: published
  `blogPost` `54ea4d1f-deee-47c6-849e-da34989f5736` contains the string "wrk" exactly once across
  all fields, and that once is `slug.current`, which the row says to keep. `editorialTitle` reads
  "Easily display Polymer job posts on your Webflow site with our CMS integration". Its outbound
  links are three `webflow.com` URLs and `app.polymer.co/account/integrations/webflow` — it does
  not link the `help.wrk.xyz` custom-domain article the row attributes to it; that link is in
  `changelog` `914dc19a-…`. The slug is unchanged and the URL returns 200.
- **The 15 bot-walled links** — every one still present. All 12 drafts were diffed leaf-path against
  their published counterparts and not one bot-walled URL differs anywhere.

---

## Table 1 — `sizes` on every responsive `next/image` call site

Root font-size 16px, `box-sizing: border-box` globally (`web/styles/global.js`), breakpoints from
`web/styles/theme.js` (40rem=640, 56rem=896, 64rem=1024, 72rem=1152, 80rem=1280).
`deviceSizes` = `[640, 750, 828, 1088, 1494, 1662, 2304]` (`web/next.config.js`).

| Call site | Measured container chain → cap | `sizes` value now on it |
|---|---|---|
| `web/pages/blog.js:46` | `blogSection.js` WrapperContainer `mx(0)/mx(3)/mx(4)` → Container max-width 82rem `px(4)/px(5)/px(4)/px(3)` → `Styled.Post` 2×1fr, column-gap 32px then 64px at 72rem → **612px** at ≥1344 | `(min-width: 84rem) 612px, (min-width: 72rem) calc(50vw - 60px), (min-width: 56rem) calc(50vw - 48px), (min-width: 40rem) calc(100vw - 64px), calc(100vw - 32px)` |
| `web/pages/blog/[slug].js:393` (`FEATURE_IMAGE_SIZES`) | `Styled.Section mx(2)/mx(3)/mx(4)` → `container.js` max-width 80rem `px(4)/px(5)/px(8)/px(16)`; `Styled.Post` and `Styled.FeaturedImage` add no padding → **1152px** at ≥1312 | `(min-width: 1312px) 1152px, (min-width: 1152px) calc(100vw - 160px), (min-width: 896px) calc(100vw - 96px), (min-width: 640px) calc(100vw - 64px), calc(100vw - 48px)` |
| `web/pages/blog/[slug].js:211` (`BODY_IMAGE_SIZES`) | same, plus `Styled.Columns p(12)` from 56rem → `Styled.PageContent` flex:3 vs `Styled.Sidebar` flex:2 + `ml(12)`, sidebar frozen at max-width 20rem from viewport 1040 → **688px** at ≥1312 | `(min-width: 1312px) 688px, (min-width: 1152px) calc(100vw - 624px), (min-width: 1040px) calc(100vw - 560px), (min-width: 896px) calc(60vw - 144px), (min-width: 640px) calc(100vw - 64px), calc(100vw - 48px)` |
| `web/pages/changelog.js:50` (`BODY_IMAGE_SIZES`) | `Section mx` → Container max-width 80rem → `Styled.Post` grid 9×1fr → `Styled.PostContent` grid-column 3/span 7, max-width 40rem, cap reached ≈928px → **640px** (638px inside the 1px border) | `(min-width: 896px) 640px, (min-width: 640px) calc(100vw - 64px), calc(100vw - 48px)` |
| `web/components/feature.js:74` | Container → `Styled.Grid` max-width 1213px (never binds; container content caps at 1152), gap 48px@896 / 69px@1152, wider track 2fr of thirds → **722px** at ≥1280 | `(min-width: 1152px) 722px, (min-width: 896px) calc(66.7vw - 74px), calc(100vw - 32px)` |
| `web/components/home/intro.js:52` | `ImageContainer px(2)/px(3)/mx(4)+px(0)@56rem` → `ImageFrame` max-width 1435px, padding 20/32/40/44/48/54/59px → **1317px** at ≥1467 | `(min-width: 1467px) 1317px, (min-width: 1024px) calc(100vw - 128px), (min-width: 640px) calc(100vw - 104px), calc(100vw - 56px)` — four clauses, see the LOW above |
| `web/components/industries/industryHeader.js:43` | identical chain to `home/intro.js` → **1317px** | `(min-width: 1467px) 1317px, (min-width: 1280px) calc(100vw - 150px), (min-width: 1152px) calc(100vw - 140px), (min-width: 1024px) calc(100vw - 128px), (min-width: 896px) calc(100vw - 120px), (min-width: 640px) calc(100vw - 104px), (min-width: 480px) calc(100vw - 80px), calc(100vw - 56px)` |
| `web/components/candidateManagement/intro.js:48` | identical chain to `industryHeader.js` → **1317px** | same eight-clause string as `industryHeader.js:43` |
| `web/components/home/build.js:37` | `Section mx` → Container max-width 80rem `px(4)/px(5)/px(8)/px(16)` → **1152px** at ≥1312 | `(min-width: 1312px) 1152px, (min-width: 1152px) calc(100vw - 160px), (min-width: 896px) calc(100vw - 96px), calc(100vw - 64px)` |
| `web/components/plato/platoVideo.js:49` | pre-existing, `layout="fill"` → **1086px** | `(min-width: 1214px) 1086px, 100vw` |
| `web/components/feature-section.js:32` | — | **none** — emits `sizes="100vw"` |
| `web/components/feature-section.js:41` | — | **none** |
| `web/components/feature-old.js:28` | — | **none** |
| `web/components/home/tailor.js:46` | — | **none** |
| `web/components/home/integrations.js:144` | — | **none** |
| `web/components/jobBoard/intro.js:41` | — | **none** |
| `web/components/plato/platoFeature.js:58` | — | **none** |

The clamp in `web/lib/sanityImage.js` caps at the **source** width, not the rendered width. Across
tab 11's 71 Sanity rows it rewrites the URL for 27 (source 800, 1296 or 1999) and is a byte-for-byte
no-op for 44 (source 2400, 3200 or 3600) — 61% of the tab's Sanity bytes. The `sizes` prop is the
only lever that reaches those 44. The clamp should stay: with a correct `sizes` value the browser
can still pick a candidate wider than a narrow source, and the clamp stops Sanity upscaling it.

## Table 2 — tab 14, all 20 URLs

Status codes re-fetched 2026-08-06 with a desktop Chrome user agent, following redirects.

| Row | URL | Action asked | What happened | Status now |
|---|---|---|---|---|
| A7 | `help.wrk.xyz/en/articles/5280480-configuring-a-custom-domain` | Replace with current Polymer help article | Draft only — `drafts.914dc19a-…` `content[1].markDefs[0].href` → `help.polymer.co/en/articles/10250419-configuring-a-custom-domain`. Published unchanged. Note the renumber: 5280480 does not exist at help.polymer.co | 404 (replacement 200) |
| A8 | `help.wrk.xyz/…/5721143-…-slack-workspace` | Replace | Draft only — `drafts.609fbb42-…` `content[2].markDefs[0].href` → same id at `help.polymer.co`. Published unchanged | 404 (replacement 200) |
| A9 | `help.wrk.xyz/…/5721747-…-discord-server` | Replace | Draft only — `drafts.3d2afcd8-…` `content[2].markDefs[0].href` → same id at `help.polymer.co`. Published unchanged | 404 (replacement 200) |
| A10 | `www.crazyegg.com/blog/recooty-review/` | Remove or replace citation | Draft only — `drafts.fcfc319d-…` `content[77].sourceUrl` unset. `source: "Crazy Egg"` kept; `SourceRenderer` (`blog/[slug].js:159-163`) renders it as plain text with no `sourceUrl`. Block count unchanged, 134 both sides. Published unchanged | 404 |
| A11 | `topgrading.com/candidate-assessment/topgrading-job-scorecard/` | Link to Topgrading homepage or remove | Draft only — `drafts.5fd6bab5-…` `content[35].markDefs[0].href` → `https://topgrading.com/`. Anchor text "Topgrading Scorecards" intact. Published unchanged | 404 (replacement 200) |
| A12 | `pewresearch.org/social-trends/2022/02/16/…reshape-work-in-america/` | Loads for humans; leave | **Left. Untouched.** | 200 |
| A13 | `breezy.hr/` | Loads for humans; leave | **Left. Untouched.** | 200 |
| A14 | `g2.com/` + 3 G2 product pages | Leave | **Left. Untouched.** The document actually carries 5 distinct G2 URLs, all left | 403 |
| A15 | `capterra.com/` | Leave | **Left. Untouched.** | 403 |
| A16 | `quora.com/` | Leave | **Left. Untouched.** | 403 |
| A17 | `http://www.pcmag.com/` | **Update to `https://www.pcmag.com`** | Draft, partial — `content[116].markDefs[2].href` upgraded (the rendered one). `content[115].markDefs[2].href` still `http`. Published unchanged | http 200 (1 redirect); https 200 |
| A18 | `hrdive.com/…` (2 articles) | Leave | **Left. Untouched.** | 200 / 200 |
| A19 | `onlinelibrary.wiley.com/doi/abs/10.1002/ejsp.2420240606` | Leave | **Left. Untouched.** | 403 |
| A20 | `gusto.com/resources/…new-grad-hiring-report-2025` | Leave | **Left. Untouched.** | 403 |
| A21 | `youth.gov/feature-article/soft-skills-pay-bills` | Leave | **Left. Untouched.** | 403 |
| A22 | `grandviewresearch.com/industry-analysis/human-resource-management-hrm-market` | Leave | **Left. Untouched.** | 403 |

None of the 20 URLs exists in any repo file — `grep -rn "wrk\.xyz\|crazyegg\|topgrading\|pcmag"
web studio` returns hits only in `SEO-CHANGELOG.md`. All 20 are Sanity content, and every edit is a
draft, which satisfies the master prompt's "use drafts and list them for review".

Not on tab 14 but found in published Sanity content, all broken, none actioned: `springrecruit.com`
(NXDOMAIN), `polywork.com` and `www.polywork.com` (SERVFAIL, zero A records),
`kornferry.com/about-us/press/millennials-as-bosses` (404), `pallet.com/spotlight` (404),
`careerarc.com/lp/candidate-experience-study/` (404),
`hrsg.ca/hubfs/Complete%20Guide%20to%20Running%20Competency-Based%20Interviews.pdf` (404), and
`statista.com/statistics/738519/…` (302 loop, exhausts the redirect limit). The two DNS deaths
produce no HTTP status, so a crawl tabulating 4xx could never emit a row for them.

## Table 3 — oversized binaries NOT compressed (DEFERRED)

**No binary under `web/images/` or `web/public/` was re-encoded, resized, compressed or deleted.**
`git diff --stat seo-phase-5-structured-data...seo-phase-6-images-links-headers` is six text files;
`git status --porcelain -- web/images web/public` is empty. This list is a deferred inventory, not
work performed. Nothing on it is done.

| Bytes | File |
|---:|---|
| 2,596,065 | `web/images/jobboard/billboard.png` |
| 2,483,814 | `web/images/candidateManagement/jobboard.png` |
| 1,130,316 | `web/images/jobboard/jobdetail.png` |
| 867,190 | `web/images/clt.jpg` |
| 575,677 | `web/images/billboard.png` |
| 574,419 | `web/images/jobboard/jobsettings.png` |
| 561,660 | `web/images/candidateManagement/billboard.png` |
| 537,704 | `web/images/scoring-detail-feature.png` |
| 441,401 | `web/images/markdown.png` |
| 436,763 | `web/images/settings.png` |
| 400,233 | `web/images/autogenerate-feature.png` |
| 366,812 | `web/images/jobboard/jobboard-one-job.png` |
| 365,571 | `web/images/jobboard/jobboard-full.png` |
| 356,358 | `web/images/candidateManagement/profile.png` |
| 355,744 | `web/public/images/platocard.png` |
| 345,398 | `web/images/billboard-dark.png` |
| 344,825 | `web/public/images/jobboardcard.png` |
| 318,106 | `web/images/candidateManagement/messages.png` |
| 279,209 | `web/images/candidateManagement/dashboard.png` |
| 276,764 | `web/images/jobboard/tablespace_billboard.png` |
| 263,155 | `web/public/images/card.png` |
| 258,541 | `web/images/plato-video-still.png` |
| 215,247 | `web/images/WWR-feature.png` |
| 214,112 | `web/images/chat-feature.png` |
| 210,422 | `web/images/jobboard/jobboard-billboard.png` |
| 204,630 | `web/images/icon.png` |
| 173,670 | `web/images/team-feature.png` |
| 160,544 | `web/images/logos/igloo.svg` |
| 151,000 | `web/images/management.png` |
| 113,162 | `web/images/new-team-feature.png` |
| 111,698 | `web/images/notifications-feature.png` |

31 files over 100 kB, 16,392,610 bytes total. The three `web/public/images/*card.png` files are
share cards served as-is; the rest go through `next/image` and are never served at their stored
size. The 79 tab-11 rows are a separate list — those are Sanity CDN and `_next/image` URLs, and
Sanity never serves the stored original, so re-encoding a Sanity asset would change storage and no
page weight.

---

## The Content-Security-Policy, in full

**It is Report-Only.** The header key emitted by `web/next.config.js:56` is
`Content-Security-Policy-Report-Only`. No header key equals `Content-Security-Policy` anywhere in
the file, on the committed branch or in the working tree. Verified by requiring the config and
awaiting `headers()`: `source: '/:path*'`, four headers, `enforcing CSP present: false`. There is
no `web/middleware.js`, no `web/pages/_document.js` header injection, no `vercel.json` and no
`web/public/_headers` to override it.

| Directive | Source | File that proves the site loads it |
|---|---|---|
| `default-src` | `'self'` | Next's own bundles |
| `base-uri` | `'self'` | — hardening, no source loaded |
| `object-src` | `'none'` | — no `<object>` or `<embed>` in the repo |
| `frame-ancestors` | `'self'` | — inert in a Report-Only header; `X-Frame-Options: SAMEORIGIN` is what restricts framing |
| `form-action` | `'self'` | — no `<form>` in `web/pages` or `web/components` |
| `script-src` | `'self'` | Next bundles |
| | `'unsafe-inline'` | `web/pages/_app.js` inline snippets (GA4 `gtag`, GTM, AdRoll, Intercom) + Next's `__NEXT_DATA__` |
| | `https://www.googletagmanager.com` | `web/pages/_app.js:157` (`gtag/js?id=G-SHNM5E7QKD`), `:182` (`gtm.js?id=GTM-N6H844WJ`) |
| | `https://www.googleadservices.com` | `gtm.js?id=GTM-N6H844WJ` — `__awct` / `__awec` tags for `AW-16528421320` |
| | `https://*.googlesyndication.com` | same container |
| | `https://*.adroll.com` | `web/pages/_app.js:202` — `s.adroll.com/j/7HAXCLAXPNHL7DUHZJ7GQB/roundtrip.js` |
| | `https://lex.33across.com` | `roundtrip.js` — `_call_33across` builds the URL and calls `c.add_script_element(d)` |
| | `https://connect.facebook.net` | `roundtrip.js` — `render_advertisable_cell` injects `t.src=v` |
| | `https://widget.intercom.io` | `web/pages/_app.js:243` |
| | `https://*.intercomcdn.com` | `widget.intercom.io/widget/yblhzder` — `public_path:"https://js.intercomcdn.com/"` |
| | `https://us-assets.i.posthog.com` | `web/lib/posthog.js` — posthog-js asset host |
| | `https://www.youtube.com` | `web/components/plato/platoVideo.js:31`; `react-youtube` `iframe_api` via `web/pages/blog/[slug].js:21` |
| `style-src` | `'self' 'unsafe-inline'` | Emotion's runtime `<style>` injection (`web/styles/global.js` and every `Styled.*`); inline styles in the Termly blob in `web/pages/privacy.js` |
| `font-src` | `'self'` | `web/public/fonts/style.css` — every `@font-face` is a relative `.woff2`, no external stylesheet |
| `img-src` | `'self' data:` | `next/image` output; `blurDataURL` data URIs from `next-sanity-image` |
| | `https://cdn.sanity.io` | `web/lib/sanityImage.js` + the four `useNextSanityImage` call sites; `/blog/best-applicant-tracking-software` emits 28 direct `cdn.sanity.io` srcs |
| | `https://api.producthunt.com` | **no proving file** — mirrors `web/next.config.js` `images.domains` only. See the LOW above |
| | `https://www.googletagmanager.com`, `https://*.google-analytics.com`, `https://www.google.com`, `https://www.googleadservices.com`, `https://*.googlesyndication.com`, `https://*.doubleclick.net` | `gtag.js` for `G-SHNM5E7QKD` and `gtm.js?id=GTM-N6H844WJ` |
| | `https://*.adroll.com` | `roundtrip.js` — `popAndSend` does `b=new Image;b.src=a` |
| | `https://www.facebook.com` | `connect.facebook.net/en_US/fbevents.js` beacons `www.facebook.com/tr/` |
| | `https://*.intercomcdn.com` | `js.intercomcdn.com` asset host |
| `connect-src` | `'self'` | Next data requests |
| | `https://us.i.posthog.com`, `https://us-assets.i.posthog.com` | `web/lib/posthog.js` — `api_host` default |
| | `https://www.googletagmanager.com`, `https://*.google-analytics.com`, `https://www.google.com`, `https://www.googleadservices.com`, `https://*.googlesyndication.com`, `https://*.doubleclick.net` | `gtag.js` / `gtm.js` |
| | `https://analytics.google.com` (apex) | `gtm.js` — `Sm()` builds `"https://"+(b?b+".":"")+"analytics.google.com/"` from `b=Pm()`, and `Pm()` returns `""` unconditionally in this build, so no label is prepended. A `*.` wildcard requires at least one label and would not match |
| | `https://*.analytics.google.com` | same, defensive |
| | `https://*.adroll.com` | `roundtrip.js` |
| | `https://www.facebook.com` | `fbevents.js` |
| | `https://api-iam.intercom.io` | `web/pages/_app.js:229` — `api_base: "https://api-iam.intercom.io"` |
| | `https://*.intercom.io`, `wss://*.intercom.io` | `widget.intercom.io/widget/yblhzder` — `telemetry_base` and the messenger websocket |
| `frame-src` | `'self'` | — |
| | `https://www.youtube.com` | `web/components/plato/platoVideo.js:31` iframe; `react-youtube` in `web/pages/blog/[slug].js:350` |
| | `https://www.googletagmanager.com` | `web/pages/_app.js:263` — `ns.html?id=GTM-N6H844WJ` noscript iframe |
| | `https://*.googlesyndication.com`, `https://*.doubleclick.net` | `gtm.js` conversion iframes |
| | `https://*.intercom.io` | `widget.intercom.io` |
| | `https://intercom-sheets.com` | `yblhzder` config — `yt_iframe_proxy_path`, `sheets_proxy_path`. `.com` host; the `*.intercom.io` wildcard does not match it |
| | `https://www.intercom-reporting.com` | `yblhzder` config — `sentry_proxy_path` |
| | `https://app.intercom.com` | `yblhzder` config — `install_mode_base` |

No `report-uri` and no `report-to`: violations surface in the visitor's browser console only.

---

## Close

**Rounds run:** 3. **Converged:** no — round 3 still produced HIGH findings, and the round-3 fix
pass then changed the tree again (it added the two missing `sizes` props, at
`candidateManagement/intro.js:48` and `home/build.js:37`, after the round-3 reviewers had read it).

**Reviewers that failed to return:** none. Six angles ran in each of the three rounds —
`tab-11-format`, `tab-11-width`, `tab-14`, `tab-10-15`, `dead-links`, `deferrals` — and all
eighteen returned. One round-3 finding was withdrawn on verification (the `dead-links` agent's
unauthenticated Sanity query, above); that is a wrong finding, not a missing reviewer.

**Severity remaining:**

- **BLOCKER: none.**
- **HIGH ×3** — the work is uncommitted and PR #51 ships the opposite of the corrected record; the
  tab-10 and tab-14 replacements are unpublished drafts, so every one of those links still 404s for
  readers; tab 14 A17 upgraded one of two pcmag markDefs.
- **MED ×4** — the quality half of tab 11's eight `_next/image` rows; seven responsive call sites
  still at `sizes="100vw"`; four classes of CSP source gap.
- **LOW ×6** — no CSP report collector; inert `frame-ancestors`; unproven `api.producthunt.com`;
  two `sizes` strings for one asset; two href-less anchors; the pre-existing `aer` token in
  `web/components/section.js:23`.

**The three explicit answers:**

- **Is the CSP Report-Only? — YES.** The key is `Content-Security-Policy-Report-Only` on both the
  committed branch and the working tree. No enforcing CSP exists anywhere in the repo.
- **Were any bot-walled links removed? — NO.** All 15 are present. Every draft was diffed leaf-path
  against its published document and not one bot-walled URL differs.
- **Did any binary change? — NO.** The branch diff is six text files. `git status --porcelain --
  web/images web/public` is empty. Nothing was re-encoded, resized, compressed or deleted.
