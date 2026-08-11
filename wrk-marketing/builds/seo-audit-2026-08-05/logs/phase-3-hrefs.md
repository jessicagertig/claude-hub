# Phase 3, item 3 — internal links pointing at redirecting URLs

Branch: `seo-phase-3-redirects-canonicals` (already checked out; no branch/commit/push performed).
Files owned by this item: anything under `web/pages/` or `web/components/` EXCEPT `web/components/seo.js` and `web/next.config.js`.

## Tab rows read

Read all of tab "16 Redirect Links" via
`python3 /Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/read-workbook.py "16 Redirect Links"`.

| Row | Linked URL | Status | Redirects to | Fix |
|---|---|---|---|---|
| A1 | Internal Links to Redirecting URLs | | | (tab title banner) |
| A2 | MakeReality.io · Polymer Technical SEO Audit | | | (subtitle banner) |
| A4 | "Only two internal 3xx targets exist (apex forms of the homepage, 308 -> www). 52 external links also point at redirecting URLs - harmless, fix opportunistically during content refreshes." | | | (instruction note, merged A4:D4) |
| 6 | Linked URL | Status | Redirects to | Fix (header row) |
| 7 | `https://polymer.co` | 308.0 | `https://www.polymer.co/` | Update internal hrefs to the www URL |
| 8 | `https://polymer.co/` | 308.0 | `https://www.polymer.co/` | Update internal hrefs to the www URL |
| 9 | `(52 external URLs)` | 3xx | various | Opportunistic: update to final destinations during post refreshes |

Rows 7 and 8 are the only actionable rows. Row 9 is an aggregate placeholder naming no specific URL, so nothing in the workbook identifies which 52 external links redirect — not actionable, see "Not actioned" below.

## How the search was done

Full-repo grep for `polymer.co`, excluding `node_modules/`, `.git/` and the `web/.next/` build output (build output is regenerated, never edited). Every hit was then classified by host form:

```
grep -rno "https\?://polymer\.co[^\"'< )]*"  web/pages web/components web/lib web/public
grep -rnoE "[a-zA-Z0-9._-]*polymer\.co"      web/pages web/components web/lib web/public
```

Apex-host absolute URLs found anywhere in source — three sites, all three actioned:

```
6  web/pages/privacy.js:44:https://polymer.co/
1  web/pages/plato.js:19:https://polymer.co/images/platocard.png
1  web/pages/features/jobboard.js:16:https://polymer.co/images/jobboardcard.png
```

The 6 occurrences in `web/pages/privacy.js` are 3 `<a>` elements, each contributing one `href` attribute plus one identical visible link text.

## Changes made

### 1. `web/pages/privacy.js` line 44 — 3 anchor hrefs (tab row 8)

This file is a Termly-generated HTML blob held in a single 167 KB template literal named `html`, rendered by `PrivacyPage` through `<div className="privacy" dangerouslySetInnerHTML={{ __html: html }} />` on line 66. `next/link` is not available inside it, so an absolute href is the only form the blob can carry. Per tab row 8 the target is `https://www.polymer.co/`.

Three occurrences, before → after, verbatim:

before (×3):
```
<a href="https://polymer.co/" data-custom-class="link">https://polymer.co/</a>
```
after (×3):
```
<a href="https://www.polymer.co/" data-custom-class="link">https://polymer.co/</a>
```

The `href` changed on all three. The **visible link text was deliberately left as `https://polymer.co/`** — tab row 8's Fix column says "Update internal hrefs to the www URL", and link text is prose in a legal document, not a crawlable URL. Raised as a question for Jessica.

The Edit tool cannot operate on this file (the whole blob is one 167 KB line), so the substitution ran as
`perl -pi -e 's{href="https://polymer\.co/"}{href="https://www.polymer.co/"}g'`
and was verified afterwards:

- apex `href="https://polymer.co/"` occurrences: 3 → 0
- www `href="https://www.polymer.co/"` occurrences: 0 → 3
- remaining bare `https://polymer.co/` strings (the 3 visible link texts): 3
- file size 167339 → 167351 bytes, exactly +12 (3 × the 4 characters `www.`)
- template-literal integrity: backtick count 2 → 2, `${` count 0 → 0, so no interpolation was introduced and the literal is still closed

### 2. `web/pages/plato.js` line 19 — og:image URL

before:
```
        image="https://polymer.co/images/platocard.png"
```
after:
```
        image="https://www.polymer.co/images/platocard.png"
```

### 3. `web/pages/features/jobboard.js` line 16 — og:image URL

before:
```
        image="https://polymer.co/images/jobboardcard.png"
```
after:
```
        image="https://www.polymer.co/images/jobboardcard.png"
```

**These two were changed, and this is the explicit disclosure the task asked for.** The task said to report OG image paths on the apex host and not to change them without saying so. Reasons for changing them:

- The 308 in tab rows 7–8 is host-level, so `https://polymer.co/images/platocard.png` takes the same apex→www hop as the homepage. An OG image URL is fetched by every social and AI crawler that renders a card.
- The analog is `web/components/seo.js` itself. Its own fallback is `` let card = image ? `${image}` : `${baseUrl}/images/card.png` `` with `let baseUrl = "https://www.polymer.co"`. Every card image this site serves by default is already on the www host; these two pages were the only ones overriding `image`, and they were the only two doing it on the apex host. The change makes them match the component's own default.
- Both files exist in the repo — `web/public/images/platocard.png` and `web/public/images/jobboardcard.png` — and are served by the same deployment on both hosts, so the URL change cannot break the asset.

`web/components/seo.js` was NOT touched (another agent owns it). Nothing in `web/components/seo.js` needed a change for this item anyway; its `baseUrl` is already the www host.

## Inspected and deliberately not changed

- **`web/pages/terms.js`** — 10 `polymer.co` mentions, and the file contains **zero** `href` attributes and zero `<Link>` elements (verified by grep). Every mention is plain prose or an email address: `located at polymer.co and app.polymer.co` (lines 10, 18), `our privacy policy at polymer.co/privacy` (line 50), `available at polymer.co/pricing` (line 79), and `support@polymer.co` (lines 69, 168, 183, 242, 248, 274). Prose is not a link and takes no redirect hop. No change.
- **`web/components/footer.js`** — all internal navigation already goes through `next/link` with root-relative hrefs (`/features`, `/plato`, `/pricing`, `/changelog`, `/blog`, `/about`, `/privacy`, `/terms`, the seven industry paths, and `/` on the logo). Its only bare `polymer.co` is `mailto:support@polymer.co` on line 100. Nothing to fix.
- **`web/pages/pricing.js`** — line 209 is `mailto:support@polymer.co`; lines 105, 145, 184 are `app.polymer.co`. No change.
- **Different hosts, on the do-not-touch list, left alone everywhere:** `app.polymer.co` (`web/components/navigation.js`, `web/components/footer.js`, `web/components/start.js`, `web/components/home/intro.js`, `web/components/home/ready.js`, `web/components/jobBoard/intro.js`, `web/components/jobBoard/basics.js`, `web/components/candidateManagement/intro.js`, `web/components/plato/platoDescription.js`, `web/pages/pricing.js`, `web/pages/terms.js`, and all seven `web/pages/industries/*.js`), `developer.polymer.co` (`web/components/footer.js`, `web/components/jobBoard/basics.js`), `help.polymer.co` (`web/components/footer.js`, `web/components/home/integrations.js`), `jobs.polymer.co` (no occurrences in source at all).

## Found outside my owned files — reported, not touched

- **`web/pages/sitemap.xml.js` line 3** — `const BASE_URL = "https://www.polymer.co";`. Already www, correct, and it is a page file I own, but no change was needed.
- **`web/components/seo.js` line 12** — `let baseUrl = "https://www.polymer.co";`. Already www and correct. Owned by another agent; not touched.
- **`web/lib/posthog.js` line 21** — a code comment, `// Share the anonymous distinct_id cookie across *.polymer.co so a visitor's`. A cookie-domain wildcard in prose, not a URL, and `web/lib/` is outside my owned paths. No action.
- **`web/public/llms.txt`** — 17 `www.polymer.co` URLs (all correct), plus `support@polymer.co` (line 22), `developer.polymer.co` (line 26) and `help.polymer.co` (lines 27–28). No apex URLs. `web/public/` is outside my owned paths. No action needed regardless.
- **`web/public/robots.txt` line 16** — `https://www.polymer.co/sitemap.xml`, already www. Outside my owned paths. No action.
- **`web/.next/`** — many apex `polymer.co` strings in `server/pages/*.html`, `server/chunks/*.js` and `static/chunks/*.js`. This is committed build output, regenerated by `next build`; it is not source and was not edited.

## Not actioned

- **Tab row 9, `(52 external URLs)` / `3xx` / `various`** — an aggregate placeholder. The workbook names none of the 52 URLs, so there is nothing to look up, and its own Fix column calls it "Opportunistic: update to final destinations during post refreshes". Tab note A4 calls these "harmless". Out of scope for this item, and the blog content they live in is Sanity-hosted rather than in this repo.
- **Rows A1, A2, A4 and 6** — banner, subtitle, instruction note and header row. Not data.

## Verification

Final sweep of my owned paths:

```
grep -rno "https\?://polymer\.co[^\"'< )]*" web/pages web/components
web/pages/privacy.js:44:https://polymer.co/     (visible link text ×3, hrefs all now www)
```

No apex-host `href`, `src` or `image` value remains anywhere under `web/pages/` or `web/components/`.

`git diff --stat` at the end of this item (the `web/components/seo.js` and `web/next.config.js` rows belong to the two sibling agents, not to this item):

```
 web/components/seo.js          | 1 +
 web/next.config.js             | 5 +++++
 web/pages/features/jobboard.js | 2 +-
 web/pages/plato.js             | 2 +-
 web/pages/privacy.js           | 2 +-
```

No branch created, nothing committed, nothing pushed. No test files and no spec files written. `BLOCKED.md` not written; not blocked.
