# Phase 6, item 4 — Security headers

**File touched:** `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/next.config.js` (the only file I own; nothing else read-modified)
**Branch:** `seo-phase-6-images-links-headers` (already checked out; no branch/commit/push made)
**Tab:** 15 Security Headers

## What shipped

An `async headers()` function added to `nextConfig`, placed immediately before the existing `async redirects()`, matching its shape (2-space indent, single quotes, no semicolons, `return [ … ]` of plain objects).

`source: '/:path*'` — all routes, which is the 107-URL surface the tab reports.

| Header | Value |
|---|---|
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `SAMEORIGIN` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Content-Security-Policy-Report-Only` | the policy below |

The CSP header key is **`Content-Security-Policy-Report-Only`**. There is no `Content-Security-Policy` key anywhere in the file — nothing enforces. Asserted mechanically (see Verification).

The policy is built from a `const contentSecurityPolicy` array of directive strings `.join('; ')` at the top of the file, above `nextConfig`.

## The policy

```
default-src 'self';
base-uri 'self';
object-src 'none';
frame-ancestors 'self';
form-action 'self';
script-src 'self' 'unsafe-inline' https://www.googletagmanager.com https://*.adroll.com https://widget.intercom.io https://*.intercomcdn.com https://us-assets.i.posthog.com https://www.youtube.com;
style-src 'self' 'unsafe-inline';
font-src 'self';
img-src 'self' data: https://cdn.sanity.io https://api.producthunt.com https://www.googletagmanager.com https://*.google-analytics.com https://*.adroll.com https://*.intercomcdn.com;
connect-src 'self' https://us.i.posthog.com https://us-assets.i.posthog.com https://www.googletagmanager.com https://*.google-analytics.com https://*.analytics.google.com https://*.adroll.com https://api-iam.intercom.io https://*.intercom.io wss://*.intercom.io;
frame-src 'self' https://www.youtube.com https://www.googletagmanager.com https://*.intercom.io
```

(shipped as one line; the line breaks above are for reading only)

## Every source, and the file that proves the site loads it

### A. Hosts named literally in a file

| Source | Directives | File that proves it |
|---|---|---|
| `https://www.googletagmanager.com` | script-src, img-src, connect-src, frame-src | `web/pages/_app.js:145` (`<Script src="https://www.googletagmanager.com/gtag/js?id=G-SHNM5E7QKD">`), `:170` (inline GTM loader building `https://www.googletagmanager.com/gtm.js?id=GTM-N6H844WJ`), `:251` (`<noscript><iframe src="https://www.googletagmanager.com/ns.html?id=GTM-N6H844WJ">` — that one is why it is in frame-src) |
| `https://s.adroll.com` (covered by `https://*.adroll.com`) | script-src | `web/pages/_app.js:190` — `var roundtripUrl = "https://s.adroll.com/j/" + adroll_adv_id + "/roundtrip.js"` |
| `https://widget.intercom.io` | script-src | `web/pages/_app.js:231` — `s.src='https://widget.intercom.io/widget/yblhzder'` |
| `https://api-iam.intercom.io` | connect-src | `web/pages/_app.js:217` — `window.intercomSettings = { api_base: "https://api-iam.intercom.io", … }` |
| `https://us.i.posthog.com` | connect-src | `web/.env.local` → `NEXT_PUBLIC_POSTHOG_HOST=https://us.i.posthog.com`, and the same value as the hardcoded fallback in `web/lib/posthog.js:13` (`process.env.NEXT_PUBLIC_POSTHOG_HOST \|\| "https://us.i.posthog.com"`), passed as `api_host` at `:18` |
| `https://us-assets.i.posthog.com` | script-src, connect-src | `web/node_modules/posthog-js/dist/module.js` — `loadExternalDependency` calls `requestRouter.endpointFor("assets", …)`; `endpointFor`'s assets branch returns `"https://" + this.region + "-assets" + Ko + e` where `Ko` is `.i.posthog.com`, and the `region` getter matches `/https:\/\/(app\|us\|us-assets)(\.i)?\.posthog\.com/i` against our `api_host` → region `"us"` → `https://us-assets.i.posthog.com`. posthog-js is loaded from `web/lib/posthog.js:1` and initialised at `web/pages/_app.js:53` |
| `https://www.youtube.com` | script-src, frame-src | Two independent proofs. (1) `web/components/plato/platoVideo.js:31` — a literal `<iframe src={`https://www.youtube.com/embed/${youtubeId}?…`}>`. (2) `web/pages/blog/[slug].js:20` imports `react-youtube`, which loads its API via `web/node_modules/youtube-player/dist/loadYouTubeIframeApi.js:26` — `loadScript(protocol + '//www.youtube.com/iframe_api', …)`. That script is fetched into our page, so it needs script-src, not just frame-src |
| `https://cdn.sanity.io` | img-src | `web/next.config.js` `images.domains`; plus direct URL construction — `web/pages/blog/[slug].js:24` `urlFor()` via `@sanity/image-url`, used at `:232` and `:294` for the OG image. `useNextSanityImage` at `web/pages/blog.js:24`, `web/pages/changelog.js:23`, `web/pages/blog/[slug].js:137` and `:208` returns a `loader`, and the components spread `{...imageProps}` into `next/image` (e.g. `web/pages/blog.js:35`), so the browser requests `cdn.sanity.io` directly rather than `/_next/image` |
| `https://api.producthunt.com` | img-src | `web/next.config.js:5` `images.domains` |
| `data:` | img-src | `web/node_modules/next/dist/client/image.js:102` (`data:image/gif;base64,R0lGOD…` lazy placeholder) and `:534` (`data:image/svg+xml,…` sizer for `layout="responsive"` / `"intrinsic"`). Both are emitted by every `next/image` on the site |
| `'self'` for font-src | font-src | `web/public/fonts/style.css` — eight `@font-face` rules with relative `url('SuisseIntl-*.woff2')`, all in `web/public/fonts/`. Loaded by the manual `<link href="/fonts/style.css" rel="stylesheet" />` at `web/pages/_app.js:120`. Same-origin, so `'self'` is the whole of it — no third-party font host |
| `'unsafe-inline'` in script-src | script-src | Four inline `dangerouslySetInnerHTML` scripts in `web/pages/_app.js`: GA4 config `:151`, GTM loader `:165`, AdRoll pixel `:180`, Intercom settings + loader `:214` and `:228`. Plus Next 12's own `__NEXT_DATA__` inline script (there is no `pages/_document.js`, so no nonce plumbing exists) |
| `'unsafe-inline'` in style-src | style-src | Emotion injects `<style>` elements at runtime — `@emotion/react` `<Global styles={globalStyles} />` at `web/pages/_app.js:237`, the `css` prop at `:240`, and every `@emotion/styled` component. Also a literal `<style>` block and inline `style="…"` attributes inside the Termly HTML blob in `web/pages/privacy.js` (the `<style>` ends at `:49`, inline `style=` at `:51`–`:52`), rendered via `dangerouslySetInnerHTML`. `next/image` also writes inline `style` attributes |

### B. Vendor sibling hosts — the vendor is file-proven, the sibling host is not named in any repo file

I included these because leaving them out would fill the report week with noise from three vendors we knowingly load. Each is a wildcard on a domain whose primary host is proven above. **Strike any of them if you would rather see the reports.**

| Source | Directives | Justified by |
|---|---|---|
| `https://*.adroll.com` (beyond `s.adroll.com`) | script-src, img-src, connect-src | `roundtrip.js` from `s.adroll.com` is the AdRoll bootstrap; it fires pixels and beacons at other `*.adroll.com` hosts |
| `https://*.intercomcdn.com` | script-src, img-src | `widget.intercom.io/widget/yblhzder` is a bootstrap that pulls the messenger bundle and its assets from Intercom's CDN |
| `https://*.intercom.io` and `wss://*.intercom.io` | connect-src, frame-src | The messenger opens a websocket and renders in an iframe; `api-iam.intercom.io` (file-proven) is only its REST host |
| `https://*.google-analytics.com` | img-src, connect-src | Where `gtag/js?id=G-SHNM5E7QKD` sends its hits. Wildcard rather than `www.` because GA4 uses region-sharded collect hosts (`region1.google-analytics.com`) |
| `https://*.analytics.google.com` | connect-src | GA4's alternate collect endpoint |

### C. Deliberately left out

- **`'unsafe-eval'`** — nothing in the repo proves it is needed. GTM sometimes wants it. Left out on purpose so the report week tells us instead of guessing.
- **Sanity API hosts** (`a6d1clb1.api.sanity.io`, `apicdn.sanity.io`) — not in connect-src, because every `sanity.fetch()` runs server-side: `web/pages/blog.js:71` inside `getStaticProps` (`:70`), `web/pages/changelog.js:89` inside `getStaticProps` (`:88`), `web/pages/blog/[slug].js:363` inside `getStaticPaths` (`:361`) and `:378`/`:382` inside `getStaticProps` (`:375`), `web/pages/sitemap.xml.js:43` inside `getServerSideProps` (`:42`). The browser never talks to the Sanity API. Only `cdn.sanity.io` (images) is browser-facing.
- **`https://termly.io`** — the master prompt flagged the Termly blob, but the only Termly reference in `web/pages/privacy.js` is a plain `<a href="https://termly.io/products/privacy-policy-generator">` attribution link at `:52`. No Termly script, no Termly consent banner. Links are not governed by CSP, so no source is needed.
- **`https://i.ytimg.com`** — nothing loads YouTube thumbnails into our page. `web/components/plato/platoVideo.js:45` uses a local `StaticImageData` import for its still; YouTube's own thumbnails render inside the iframe, which is a separate origin with its own CSP.
- **Every other host in the repo** (`app.polymer.co`, `help.polymer.co`, `developer.polymer.co`, `twitter.com`, `discord.gg`, `stripe.com`, `climate.stripe.com`, the customer-logo links) — all `<a href>` navigation targets, not subresource loads. `http://www.w3.org` and `https://schema.org` are XML namespace and JSON-LD `@context` strings, never fetched.
- **`report-uri` / `report-to`** — see below.

## No report collection endpoint

There is none, and I did not invent one. `web/pages/api/` contains a single file, `web/pages/api/hello.js`, which is the untouched Next scaffold returning `{ name: 'John Doe' }`. No CSP report route exists anywhere in the repo.

Consequence: violations appear in each visitor's own browser console and nowhere else. That is still useful — open the site in Chrome with the console up and click through the pages, and you will see exactly what the policy would have blocked. But it does not aggregate across real traffic, so a source that only breaks for, say, a visitor whose GTM container fires an ad tag we never see locally will not surface. Building a `pages/api/csp-report.js` collector is a separate item; I did not scope-creep into it.

## Verification

`node -e` required the config, awaited `headers()`, and asserted on the result:

- `source` is `/:path*`
- all four headers emit with the values in the table above
- the CSP value contains no newline or carriage return (a multi-line header value would be dropped or truncated)
- no header key equals `Content-Security-Policy` — only `Content-Security-Policy-Report-Only`
- `redirects` and `rewrites` are both still functions on the exported config

All assertions passed. `async headers()` has been supported since Next 9.5, so 12.1.0 is fine.

I did not run `next build` or start a dev server — that is a live check for whoever runs the branch.

## Not actioned from the tab

Nothing. All four rows shipped. Row 7's column C is a rollout procedure rather than a header value, and that procedure — Report-Only first, enforce after a clean week — is what shipped; the enforcement step is the follow-up.

## Follow-up

Once the report week is clean, the switch to enforcing is a one-word edit in `web/next.config.js`: change the key `Content-Security-Policy-Report-Only` to `Content-Security-Policy`. Do not do it until the console is quiet on the blog (YouTube embed), `/plato` (the video iframe), `/privacy` (the Termly blob), and a page with Sanity images.
