# Phase 3, item 2 — the /contact 404

Branch: `seo-phase-3-redirects-canonicals` (already checked out; no branch created, nothing committed, nothing pushed).
File owned and touched: `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/next.config.js` — the only file edited.
No `web/pages/contact.js` was created. See "Open item" below.

## Tab rows read

Read via `read-workbook.py "06 Backlinked 404"`. The tab is 10 rows x 6 cols; rows 3 and 5 are empty spacers; rows 7-10 are the only data rows. All four were read.

- **Row 7** (actioned) — A7 `https://www.polymer.co/contact`, B7 `22.0`, C7 `n/a (within 557 total)`, D7 `404 - confirmed by fetch 2026-08-03`, E7 `Restore /contact with demo/sales form; until then 301 -> /about or /pricing`, F7 `Footer 'Contact us' and pricing's enterprise 'Contact Us' CTA imply this page should exist; 404 kills enterprise-intent conversions`
- **Row 8** (not actioned) — A8 `https://polymer.co/?partner_source=whatjobs`, D8 `200 via 308 to www (parameter preserved)`, E8 `Keep live; add canonical -> https://www.polymer.co/ (tab 04)`
- **Row 9** (not actioned) — A9 `http://polymer.co/`, D9 `308 -> https://www`, E9 `No action - redirect chain is single-hop and correct`
- **Row 10** (not actioned) — A10 `https://www.polymer.co/blog/use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site`, D10 `200 - live`, E10 `Refresh content (see tab 10); do not change URL without 301`

Tab instruction note, A4: `SE Ranking backlink index (July 2026) cross-referenced against live status checks. Only one backlinked URL 404s - but it is the contact page.`

## The change

`web/next.config.js`, inside the existing `async redirects()`.

Before:

```js
  async redirects() {
    return [
      {
        source: '/climate',
        destination: 'https://climate.stripe.com/Cg9EBK',
        permanent: false,
      },
    ]
  },
```

After:

```js
  async redirects() {
    return [
      {
        source: '/climate',
        destination: 'https://climate.stripe.com/Cg9EBK',
        permanent: false,
      },
      {
        source: '/contact',
        destination: '/about',
        statusCode: 301,
      },
    ]
  },
```

Nothing else in the file changed. `reactStrictMode`, `images`, `env`, the `/climate` entry and all seven `rewrites()` entries are byte-identical to before.

Verified the file still parses and emits the rule:

```
$ node -e "const c=require('./next.config.js'); c.redirects().then(r=>console.log(JSON.stringify(r,null,2)))"
[
  { "source": "/climate", "destination": "https://climate.stripe.com/Cg9EBK", "permanent": false },
  { "source": "/contact", "destination": "/about", "statusCode": 301 }
]
```

## Status code: this config produces a literal 301, not a 308

The tab says **301** (E7: `until then 301 -> /about or /pricing`). I did not treat 301 and 308 as interchangeable.

`permanent: true` in Next.js emits **308**, not 301 — confirmed in this repo's own copy of Next rather than from memory. `web/node_modules/next/dist/lib/load-custom-routes.js` line 60:

```js
return route.statusCode || (route.permanent ? _constants.PERMANENT_REDIRECT_STATUS : _constants.TEMPORARY_REDIRECT_STATUS);
```

`statusCode` takes precedence over `permanent`, and lines 44-50 define the accepted set:

```js
const allowedStatusCodes = new Set([
    301,
    302,
    303,
    307,
    308
]);
```

301 is accepted by Next 12.1.0 (`web/node_modules/next/package.json` -> `"version": "12.1.0"`), so the tab's stated code is available exactly and there was no reason to substitute one.

**Does 308 vs 301 matter for the 22 backlinks?** For Google specifically, no — Google treats 301 and 308 identically for canonicalization and link-equity consolidation. But they are not interchangeable in general, and the difference is not zero here:

1. 308 is the newer code (RFC 7538, 2015). Third-party backlink and link-check crawlers — including the class of tool that produced this audit's SE Ranking index — are more variable about 308 than about 301, and a client that does not recognise a 3xx code is specified to treat it as a plain non-redirect error response. With 22 backlinks from 22 third-party sites, the consumers of this redirect are exactly those third-party crawlers plus browsers.
2. The semantic difference (308 preserves the request method and body across the redirect; 301 historically permits a POST to become a GET) is irrelevant here — every hit on `/contact` is a GET from a browser or crawler.

So the SEO outcome is very likely the same either way, but 301 is the strictly wider-supported of the two, it is what the tab specifies, and it costs nothing. That is why the entry uses `statusCode: 301` rather than `permanent: true`.

## Two deviations from the existing entry's shape, both deliberate

The instruction was to match the existing `/climate` entry's shape. Two things differ, named here rather than left to be discovered:

1. **`statusCode: 301` instead of the `permanent` key.** The `/climate` entry uses `permanent: false`. `permanent` cannot express 301 at all — it only selects between 308 and 307. Using `permanent: true` to satisfy the shape would have shipped a status code the tab did not ask for. Structure otherwise matches: same array, same position, same `source`/`destination` key order, same trailing-comma and two-space style.
2. **Relative destination `/about`, not the absolute `https://www.polymer.co/about` from the master prompt's redirect map.** `/climate` is absolute because its destination is a genuinely external host (Stripe). `/about` is a page in this app — `web/pages/about.js` exists, confirmed by listing `web/pages/` — and all seven `rewrites()` destinations in this same file are relative for the same reason. The relative form also preserves the incoming scheme and host, so a request that already reached `https://www.polymer.co/contact` lands on `https://www.polymer.co/about` in one hop, which is the master prompt's stated target. An absolute destination would have been a second hop for apex-host traffic, since the apex-to-www 308 (tab 06 row 9) already runs ahead of Next. Same destination page either way; say the word if you want the absolute form written out literally.

## What I did not do, and why

**Did not create `web/pages/contact.js`.** Restoring the page is row 7's stated preference (`Restore /contact with demo/sales form`), and the master prompt names it the preferred remedy. It requires writing new marketing copy and a working demo/sales form on a live site — a content and lead-capture decision, not an implementation detail, and not mine to make. The 301 removes the 404 today and is reversible in one line the moment a real page exists. Logged as an open item.

**Rows 8, 9 and 10 are not actionable in this repo** — detail in the returned `tabRowsNotActioned`. In short: row 9 says "No action" outright; rows 8 and 9 both concern the apex-to-www 308, which is host-level Vercel/DNS behaviour and already correct, not a `next.config.js` rule; row 8's actual ask is a canonical tag, which is tab 04 and belongs to the `web/components/seo.js` item, not to me; row 10 is a live 200 whose ask is an editorial content refresh on tab 10, with an explicit instruction *not* to change the URL, so there is no redirect to write.

## Corroboration worth carrying forward

Row 7's note F7 says the footer and pricing CTAs "imply this page should exist". They do not link to it. `web/components/footer.js` line 98 and `web/pages/pricing.js` line 204 both point at `mailto:support@polymer.co` (read-only check; I own neither file and changed neither). Consequence: there are no internal links to repoint, and every hit on `/contact` arrives from the 22 external backlinks — so this one redirect fully recovers the loss.

## Nothing blocked

`BLOCKED.md` was not written. Open item appended to `QUESTIONS-FOR-JESSICA.md` under the heading "Phase 3, item 2 — /contact".
