# Phase 6, item 1 — image delivery

Branch `seo-phase-6-images-links-headers`. Repo `/Users/jessica/wrk/wrk-corp/wrk-marketing`.

## Outcome in one line

Tab 11's headline numbers are a crawler artifact — the site already serves AVIF, and the 7.0 MB PNG is really 314 kB in a browser. One real defect existed underneath (Sanity upscaling sources narrower than 2304px) and is now fixed in one file.

> **Corrected 2026-08-06.** Three statements below were false and are corrected in place, each marked with this style of block. In summary: (1) `fm=webp` **was** applied — commit `6523c92` chains `.format('webp')` — and this file said twice that it was not; the round-1 fix pass then removed it again on measurement. (2) The clamp in `web/lib/sanityImage.js` caps at the **source** width, which is a no-op for the 44 of 71 Sanity rows whose source is 2304px or wider, so "cap width at rendered size" reached only 27 rows, not the tab. (3) The width half is therefore **not** fixed in one file: the lever is the `sizes` prop, added across five files in the round-1 fix pass.

## What changed

| File | Change |
|---|---|
| `web/lib/sanityImage.js` | New. Exports `noUpscaleImageBuilder`, an `imageBuilder` for `useNextSanityImage` that clamps the requested width to the asset's own width. |
| `web/pages/blog.js` | Import it; pass `{ imageBuilder: noUpscaleImageBuilder }` to the one `useNextSanityImage` call. |
| `web/pages/blog/[slug].js` | Same, at both `useNextSanityImage` calls (`ImageRenderer` for in-body Portable Text images, and the feature image in `BlogPost`). |
| `web/pages/changelog.js` | Same, at its one `useNextSanityImage` call. **Added 2026-08-06** — this row was missing, and the "Not actioned" section below claimed the file was untouched. It is in `6523c92`: `import { noUpscaleImageBuilder }` at `:12` and `{ imageBuilder: noUpscaleImageBuilder }` at `:27`. |

No binary touched. No href or link text touched. `next lint` clean on all four files; `next build` green, all 26 blog posts prerendered.

## Finding 1 — the tab's `fm=webp` instruction, and what actually shipped

> **Corrected 2026-08-06.** This section's closing line read "Not done, deliberately." That is false as a record of what shipped. `web/lib/sanityImage.js` in commit `6523c92` ("Serve Sanity images as webp, and add security headers", 2026-08-05 22:40:17 -0500) chains `.format('webp')`, and all four `useNextSanityImage` call sites pass that builder — so every one of tab 11's 71 `cdn.sanity.io` rows shipped requesting `fm=webp`, exactly as the tab's Fix column asks. The measurement below is sound and was acted on afterwards: the round-1 fix pass removed `.format('webp')` again, restoring `auto=format`. Re-measured 2026-08-06 with the cache warm, identical to the table below: `auto=format` + Chrome `Accept` → `image/avif`, 314,063 bytes; `auto=format` + an `Accept` advertising WebP but not AVIF → `image/webp`, 400,566 bytes; `auto=format&fm=webp` + Chrome `Accept` → `image/webp`, 400,542 bytes. So `auto=format` already degrades on its own, and `fm=webp` costs a Chrome-class client 86,479 bytes on this asset. **Tab 11 asked for `fm=webp`. Status: DONE in `6523c92`, then deliberately reversed in the working tree on the measurement below. Which way it ships is one `.format('webp')` line and is Jessica's call.**


Tab 11 cell A4 says Sanity images are "requested as PNG at w=2304 without an explicit webp/avif format" and asks for `fm=webp`. Both halves are wrong.

`useNextSanityImage` already calls `.auto('format')` on every URL it builds — that is the `auto=format` visible in every crawled URL. `auto=format` is content negotiation: Sanity picks the best format the requesting client's `Accept` header allows. A crawler that sends no image `Accept` header gets the PNG; that is what Screaming Frog recorded.

Measured on the tab's worst row, `7502b125…-3200x3558.png?w=2304&q=75&fit=clip&auto=format`:

| Request | Response |
|---|---|
| no `Accept` header (crawler) | `image/png`, 7,044,071 bytes |
| `Accept: image/avif,image/webp,…` (Chrome) | `image/avif`, **314,063 bytes** |
| explicit `fm=webp` | `image/webp`, 400,542 bytes |

Sampled 18 rows spanning the whole tab: **every one** returns AVIF to a real browser. 39,251,301 crawl-reported bytes → 2,443,805 actual, a 16x aggregate gap.

Adding `fm=webp` as the tab asks pins every image to WebP and **loses AVIF** — 400 kB instead of 314 kB on that asset, ~27% worse. `6523c92` added it; the round-1 fix pass removed it again on this measurement. See the correction block at the top of this section.

## Finding 2 — "all 111 images lack width/height (CLS risk)" is a false positive

Counted rather than assumed:

- **Zero raw `<img>` tags** exist anywhere in `web/pages/` or `web/components/`. Every image goes through `next/image`.
- All 15 `next/image` call sites under `web/components/` pass explicit `width` and `height`. The one exception, `web/components/plato/platoVideo.js`, uses `layout="fill"`, which correctly takes neither.
- The Sanity call sites get `width`/`height` from `useNextSanityImage` — the hook returns them (dist/index.js lines 100-113) and they are spread onto `<Image {...imageProps} />`.

The attributes are absent from the *rendered* HTML because `layout="responsive"` in Next 12 deliberately strips them and substitutes an aspect-ratio box. Confirmed on live `https://www.polymer.co/blog`: 0 `width=` attributes, and 5 wrapper spans carrying `padding-top:52.5%` — exactly 1890/3600, the source aspect ratio. **Space is reserved before the image loads, so there is no layout shift.** The crawler counted attributes; the technique does not use them.

Actual count of images needing a width/height change: **0**.

## Finding 3 — the one real defect: Sanity upscales small sources

`next-sanity-image`'s built-in `DEFAULT_IMAGE_BUILDER` (dist/index.js lines 23-31) calls `.width(options.width)` with whatever `next.config.js` `deviceSizes` offers — `[640, 750, 828, 1088, 1494, 1662, 2304]` — and never checks how wide the source actually is. Sanity upscales rather than clamping. Verified by reading served pixel dimensions:

```
1d078cc7…-800x600.png  requested w=640  -> served 640x480
                       requested w=1088 -> served 1088x816
                       requested w=2304 -> served 2304x1728   (2.9x upscale)
```

That asset is the feature image on `blog/onboarding` ("What is Employee Onboarding? A Definitive Guide"). Its srcset offered a 195 kB blurry upscale against 59 kB at native width.

27 of the 71 Sanity assets in Tab 11 have sources narrower than 2304px (24 at 1999px, 2 at 1296px, 1 at 800px). Measured warm-cache, AVIF-to-AVIF, at the top srcset candidate:

**1,639,397 → 997,314 bytes, a 39.1% saving, with zero assets getting larger.**

Measurement caveat worth recording: a first run showed 13 of 27 getting *bigger*. That was a cold-cache artifact — Sanity serves WebP on first hit for a new derivative and backfills AVIF asynchronously. The w=2304 URLs were warm because the live site serves them; the capped URLs were cold. After warming both sides, all 27 returned AVIF and all 27 shrank. Any future re-measurement must warm both sides first.

Verified in the built output for `blog/onboarding` — the 800px source now tops out at `w=800`, the two 1999px sources at `w=1999`, and the 3600px source still goes to `w=2304`.

> **Corrected 2026-08-06.** That last clause originally read "the 3600px source **correctly** still goes to `w=2304`", and "correctly" is what hid the size of the gap. `w=2304` for a 3600px source is not the clamp working — it is the clamp doing nothing. `noUpscaleImageBuilder` takes `Math.min(options.width, croppedImageDimensions.width)`, and `next.config.js` `deviceSizes` tops out at 2304, so for any source 2304px or wider the URL is byte-identical to `next-sanity-image`'s default builder. **44 of tab 11's 71 `cdn.sanity.io` rows have a source ≥ 2304px (3200, 3600, 2400). This file's Finding 3 therefore covers 27 rows, not the tab**, and as written it told Jessica the opposite by calling the untouched case "correct."
>
> Tab 11 asked for: cap width at rendered size.
> Status as of this item's own work: NOT DONE for those 44 rows. Reason: the clamp caps at source width, not rendered width, and no responsive `<Image>` call site passed a `sizes` prop, so `next/image` emitted `sizes="100vw"` (`node_modules/next/dist/client/image.js:208`) and the browser took the largest srcset candidate. Verified on live `https://www.polymer.co/blog`: 5× `sizes="100vw"`, all 5 feature images 3600x1890 or 2400x1260 — not one image on that page was changed by Finding 3's fix.
>
> Status after the round-1 fix pass: DONE, in five files, uncommitted at the time of writing. `sizes` props measured from each real container chain rather than copied from `web/components/plato/platoVideo.js:49`: `web/pages/blog.js:46`, `web/pages/blog/[slug].js:211` (`BODY_IMAGE_SIZES`) and `:393` (`FEATURE_IMAGE_SIZES`), `web/pages/changelog.js:50` (`BODY_IMAGE_SIZES`), `web/components/home/intro.js:52`, `web/components/feature.js:74`.

## Not actioned

- ~~**`web/pages/changelog.js`** has a fourth `useNextSanityImage` call with the same upscale defect. Outside my ownership (`web/pages/blog.js`, `web/pages/blog/[slug].js`, `web/components/`), so untouched. One import plus one options argument adopts the fix — see the question file.~~ **False, corrected 2026-08-06.** The file was touched: `6523c92` carries the import and the options argument, and the commit message says so ("changelog.js now uses it too rather than the default builder"). It also gained a `sizes` prop at `:50` in the round-1 fix pass. Question 18 in `QUESTIONS-FOR-JESSICA.md`, which asks whether this file should get the fix, is stale for the same reason; that file is not this one's to edit.
- **`web/next.config.js`** shows an uncommitted diff adding `headers()` and a Report-Only CSP. That is the security-headers item's in-flight work, not mine. It does not touch `images.deviceSizes`, so it does not affect this analysis, and its `img-src` already allows `https://cdn.sanity.io`.
- **`web/components/home/partnerSetup.js`** imports `next/image` but renders no `<Image>`. Dead import, unrelated to this item, left alone.
- **No binary re-encoded, resized, compressed or deleted.**

## The oversized-asset list, and why compression is probably moot

Important framing for the compression decision: **the stored originals are never served.** Sanity always delivers a derivative built from the URL parameters. Re-encoding the stored PNGs would not change a single byte of page weight — it would only reduce Sanity asset storage. Page weight is governed entirely by the derivative, which is already AVIF. **Corrected 2026-08-06:** this sentence ended "and now correctly width-capped." At the time it was written the derivative was width-capped only for the 27 sources narrower than 2304px — see the correction under Finding 3. It is width-capped for the rest as of the round-1 fix pass's `sizes` props, which are uncommitted at the time of writing.

139 stored assets exceed 100 kB. 103 are referenced by a document; **36 are referenced by nothing at all, totalling 37.1 MB** of orphaned storage.

Largest twelve, with the page each appears on:

| stored | dimensions | referenced by |
|---|---|---|
| 6.97 MB | 3600x1890 | `blogPost` four-steps-to-build-a-recruiting-strategy-for-your-startup |
| 5.91 MB | 3200x3558 | `blogPost` employer-branding-steps |
| 4.68 MB | 3200x1892 | `blogPost` employer-branding-steps |
| 3.81 MB | 3200x5480 | `blogPost` skills-mapping-for-hiring-a-complete-guide |
| 3.31 MB | 1999x1923 | `blogPost` recruiting-generation-z |
| 2.98 MB | 3200x1888 | `changelog` |
| 2.71 MB | 3200x2168 | `blogPost` employer-branding-steps |
| 2.61 MB | 3200x3456 | **nothing — orphaned** |
| 2.60 MB | 3200x3456 | `blogPost` skills-mapping-for-hiring-a-complete-guide |
| 2.60 MB | 3200x3456 | **nothing — orphaned** |
| 2.37 MB | 3200x2188 | `blogPost` post-to-we-work-remotely-6m-professionals-in-seconds |
| 2.33 MB | 3200x2188 | **nothing — orphaned** |

The full 139-row table with every asset, its stored size, dimensions and referencing documents is below.

The eight `_next/image` rows on Tab 11 are truncated in the source spreadsheet (a literal `...` replaces the encoded path) and were not reconstructed. They are static imports served through Next's own optimizer, which already negotiates WebP/AVIF; their call sites all pass explicit `width`/`height`.

---

## Full asset table (139 stored assets over 100 kB)

| stored | dimensions | referenced by |
|---|---|---|
| 6.97 MB | 3600x1890 | `blogPost` four-steps-to-build-a-recruiting-strategy-for-your-startup |
| 5.91 MB | 3200x3558 | `blogPost` employer-branding-steps |
| 4.68 MB | 3200x1892 | `blogPost` employer-branding-steps |
| 3.81 MB | 3200x5480 | `blogPost` skills-mapping-for-hiring-a-complete-guide |
| 3.31 MB | 1999x1923 | `blogPost` recruiting-generation-z |
| 2.98 MB | 3200x1888 | `changelog` (no slug) |
| 2.71 MB | 3200x2168 | `blogPost` employer-branding-steps |
| 2.61 MB | 3200x3456 | **nothing — orphaned** |
| 2.60 MB | 3200x3456 | `blogPost` skills-mapping-for-hiring-a-complete-guide |
| 2.60 MB | 3200x3456 | **nothing — orphaned** |
| 2.37 MB | 3200x2188 | `blogPost` post-to-we-work-remotely-6m-professionals-in-seconds |
| 2.33 MB | 3200x2188 | **nothing — orphaned** |
| 2.28 MB | 3200x2188 | `blogPost` post-jobs-with-whatjobs-across-500-partners |
| 2.27 MB | 3200x2190 | `blogPost` talent-acquisition |
| 2.24 MB | 3200x1702 | **nothing — orphaned** |
| 2.24 MB | 3200x1684 | `changelog` (no slug) |
| 2.19 MB | 3200x3496 | `blogPost` talent-acquisition |
| 2.07 MB | 3200x2388 | **nothing — orphaned** |
| 2.07 MB | 3200x2388 | `blogPost` employer-branding-steps |
| 2.01 MB | 3200x2314 | **nothing — orphaned** |
| 1.99 MB | 3200x2168 | `blogPost` one-click-distribution-to-we-work-remotelys-community-of-job-seekers |
| 1.97 MB | 3200x2314 | `blogPost` use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site |
| 1.96 MB | 3200x2728 | **nothing — orphaned** |
| 1.95 MB | 3200x1926 | `blogPost` employer-branding-steps |
| 1.85 MB | 3200x2168 | **nothing — orphaned** |
| 1.84 MB | 3200x2168 | `blogPost` use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site |
| 1.78 MB | 3200x1932 | `blogPost` employer-branding-steps |
| 1.76 MB | 3200x2168 | `blogPost` use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site |
| 1.73 MB | 3200x2168 | `blogPost` use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site |
| 1.72 MB | 3200x2168 | `blogPost` use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site |
| 1.71 MB | 3200x1996 | **nothing — orphaned** |
| 1.71 MB | 3200x2168 | `blogPost` use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site |
| 1.71 MB | 1999x1100 | `blogPost` best-job-board-software |
| 1.68 MB | 3200x1996 | **nothing — orphaned** |
| 1.68 MB | 3200x2200 | `blogPost` talent-acquisition |
| 1.68 MB | 3200x2168 | `blogPost` use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site |
| 1.66 MB | 3200x2090 | `blogPost` one-click-distribution-to-we-work-remotelys-community-of-job-seekers |
| 1.63 MB | 1990x1999 | `blogPost` job-rejection-email |
| 1.63 MB | 3200x1650 | `blogPost` employer-branding-steps |
| 1.59 MB | 3200x2168 | `blogPost` use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site |
| 1.57 MB | 3200x2090 | `blogPost` use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site |
| 1.57 MB | 3200x1996 | **nothing — orphaned** |
| 1.55 MB | 3200x1842 | **nothing — orphaned** |
| 1.54 MB | 3200x2418 | `blogPost` talent-acquisition |
| 1.52 MB | 2304x1210 | **nothing — orphaned** |
| 1.39 MB | 3600x1890 | `blogPost` five-things-a-startup-should-keep-in-mind-when-hiring |
| 1.37 MB | 3200x1996 | **nothing — orphaned** |
| 1.31 MB | 3200x1814 | `blogPost` talent-acquisition |
| 1.28 MB | 1999x1182 | `blogPost` job-rejection-email |
| 1.25 MB | 1999x1588 | `blogPost` first-impression-bias |
| 1.25 MB | 1999x1196 | `blogPost` best-applicant-tracking-software |
| 1.22 MB | 3200x1792 | `changelog` (no slug) |
| 1.20 MB | 1999x1369 | **nothing — orphaned** |
| 1.19 MB | 3200x2064 | `blogPost` talent-acquisition |
| 1.13 MB | 3200x1996 | `blogPost` employer-branding-steps |
| 1.10 MB | 1999x1745 | `blogPost` best-applicant-tracking-software |
| 1.06 MB | 1999x1121 | `blogPost` job-rejection-email |
| 1.05 MB | 1999x1662 | `blogPost` job-rejection-email |
| 0.96 MB | 1943x1999 | `blogPost` agile-recruiting-process |
| 0.94 MB | 1831x1999 | **nothing — orphaned** |
| 0.94 MB | 1999x1911 | `blogPost` interview-feedback-examples |
| 0.92 MB | 1999x1905 | `blogPost` first-impression-bias |
| 0.91 MB | 1811x1999 | `blogPost` recruiting-generation-z |
| 0.91 MB | 1999x1100 | `blogPost` best-job-board-software |
| 0.89 MB | 2400x1260 | **nothing — orphaned** |
| 0.88 MB | 2752x1700 | **nothing — orphaned** |
| 0.87 MB | 1999x1999 | `blogPost` employee-turnover |
| 0.87 MB | 1999x1355 | `blogPost` recruiting-generation-z |
| 0.84 MB | 1999x1508 | `blogPost` employee-turnover |
| 0.83 MB | 1999x1247 | `blogPost` first-impression-bias |
| 0.83 MB | 1999x1247 | `blogPost` a-player, `blogPost` best-applicant-tracking-software |
| 0.80 MB | 1999x898 | `blogPost` a-player |
| 0.80 MB | 1755x1999 | `blogPost` recruiting-generation-z |
| 0.79 MB | 1831x1999 | `blogPost` a-player |
| 0.78 MB | 1919x1999 | `blogPost` recruiting-generation-z |
| 0.78 MB | 920x690 | `blogPost` employee-turnover |
| 0.77 MB | 1999x1511 | **nothing — orphaned** |
| 0.77 MB | 1999x1877 | `blogPost` best-applicant-tracking-software |
| 0.77 MB | 1999x1747 | `blogPost` behavioral-interview-scoring-matrix |
| 0.76 MB | 1999x1100 | `blogPost` best-applicant-tracking-software |
| 0.74 MB | 1999x1247 | `blogPost` best-job-board-software |
| 0.73 MB | 1999x1355 | `blogPost` job-rejection-email |
| 0.72 MB | 1999x1375 | **nothing — orphaned** |
| 0.71 MB | 1999x1480 | `blogPost` problem-solving-interview-questions |
| 0.69 MB | 1999x1251 | `blogPost` recruiting-generation-z |
| 0.67 MB | 1999x1442 | `blogPost` recruiting-generation-z |
| 0.66 MB | 1999x1175 | `blogPost` best-applicant-tracking-software |
| 0.65 MB | 1999x1100 | `blogPost` best-applicant-tracking-software |
| 0.65 MB | 1999x1134 | **nothing — orphaned** |
| 0.64 MB | 1288x1999 | `blogPost` behavioral-interview-scoring-matrix |
| 0.61 MB | 1999x1370 | `blogPost` best-applicant-tracking-software |
| 0.61 MB | 1999x1452 | `blogPost` onboarding, `blogPost` employee-turnover |
| 0.61 MB | 1999x1255 | `blogPost` agile-recruiting-process |
| 0.59 MB | 1999x1121 | `blogPost` first-impression-bias |
| 0.59 MB | 1999x1165 | `blogPost` agile-recruiting-process |
| 0.59 MB | 1999x1797 | `blogPost` best-applicant-tracking-software |
| 0.57 MB | 1999x1121 | `blogPost` first-impression-bias |
| 0.57 MB | 1999x1031 | `blogPost` onboarding |
| 0.56 MB | 1999x1264 | `blogPost` first-impression-bias |
| 0.56 MB | 1999x1236 | `blogPost` interview-feedback-examples |
| 0.55 MB | 1999x1290 | **nothing — orphaned** |
| 0.55 MB | 1999x1122 | `blogPost` first-impression-bias |
| 0.54 MB | 1999x1015 | `blogPost` employee-turnover |
| 0.54 MB | 1999x1031 | `blogPost` problem-solving-interview-questions |
| 0.52 MB | 3200x2188 | `blogPost` post-to-we-work-remotely-6m-professionals-in-seconds |
| 0.52 MB | 1999x1263 | `blogPost` behavioral-interview-scoring-matrix |
| 0.50 MB | 1999x1121 | `blogPost` first-impression-bias |
| 0.49 MB | 2560x1720 | **nothing — orphaned** |
| 0.48 MB | 908x1999 | `blogPost` behavioral-interview-scoring-matrix |
| 0.48 MB | 1999x1290 | `blogPost` agile-recruiting-process |
| 0.46 MB | 2560x2036 | **nothing — orphaned** |
| 0.46 MB | 1999x994 | `blogPost` employee-turnover |
| 0.39 MB | 1999x1100 | `blogPost` best-job-board-software |
| 0.37 MB | 1999x1081 | `blogPost` best-applicant-tracking-software |
| 0.36 MB | 1999x1100 | `blogPost` best-job-board-software |
| 0.36 MB | 2448x2036 | **nothing — orphaned** |
| 0.35 MB | 1999x1125 | `blogPost` job-rejection-email, `blogPost` problem-solving-interview-questions, `blogPost` behavioral-interview-scoring-matrix |
| 0.32 MB | 1999x1100 | `blogPost` best-job-board-software |
| 0.31 MB | 2000x1050 | `blogPost` utc-is-the-timezone-of-the-future |
| 0.28 MB | 2454x1936 | **nothing — orphaned** |
| 0.27 MB | 1999x1122 | `blogPost` talent-acquisition |
| 0.27 MB | 2560x1600 | **nothing — orphaned** |
| 0.25 MB | 1408x1120 | **nothing — orphaned** |
| 0.24 MB | 2732x1650 | **nothing — orphaned** |
| 0.23 MB | 1999x1188 | `blogPost` best-applicant-tracking-software |
| 0.21 MB | 1999x939 | `blogPost` best-applicant-tracking-software |
| 0.21 MB | 1999x1100 | `blogPost` best-job-board-software |
| 0.21 MB | 2560x1600 | **nothing — orphaned** |
| 0.18 MB | 800x600 | `blogPost` onboarding |
| 0.17 MB | 3600x1890 | `blogPost` how-to-have-your-job-posts-show-up-in-the-google-jobs-search-widget |
| 0.17 MB | 1999x951 | `blogPost` best-applicant-tracking-software |
| 0.16 MB | 2448x1600 | **nothing — orphaned** |
| 0.16 MB | 2454x1600 | **nothing — orphaned** |
| 0.15 MB | 2560x1600 | **nothing — orphaned** |
| 0.15 MB | 2560x1600 | **nothing — orphaned** |
| 0.14 MB | 2560x1600 | **nothing — orphaned** |
| 0.13 MB | 1296x1144 | `blogPost` how-to-have-your-job-posts-show-up-in-the-google-jobs-search-widget |
| 0.11 MB | 2304x1210 | **nothing — orphaned** |
| 0.10 MB | 3600x1890 | `blogPost` employer-branding-steps |
