# Phase 5, foundation — shared JSON-LD component + site-wide Organization and WebSite

Branch `seo-phase-5-structured-data`, repo `/Users/jessica/wrk/wrk-corp/wrk-marketing`. Nothing committed, nothing pushed.

Owned and touched, both:

- `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/components/jsonLd.js` — new, 22 lines
- `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/pages/_app.js` — +26 lines, nothing removed

Tab 05 row A7 ("Site-wide — Organization + WebSite — name, url, logo, sameAs (X, LinkedIn, Discord) — Emit once in root layout") is the row this item actions. `_app.js` is this repo's root layout: it is the Pages Router wrapper every one of the 22 routes renders through, and it already renders the prop-less `<SEO />` for the same reason.

---

## Analogs read before writing

`web/components/seo.js` is the only file in the repo that imports `next/head` (grep across `web/pages` and `web/components`), so it is the sole analog for a head-tag component. Read alongside it: `web/components/container.js` and `web/components/logo.js` for the prevailing component shape, and `web/pages/sitemap.xml.js` as the most recent SEO-infrastructure file on this branch.

What was matched:

| Trait | Source | Followed in `jsonLd.js` |
|---|---|---|
| `import React from "react";` then `import Head from "next/head";` | `web/components/seo.js:1-2` | yes — 20 of 23 files under `web/components` open with `import React` |
| Arrow-function component, `export default <Name>;` on the last line | `web/components/seo.js:4` and `:92` | yes (`container.js` and `logo.js` use `export default function`, but the head-tag analog is `seo.js`) |
| Descriptive `key` on each emitted tag | `web/components/seo.js:58,66,71,75,76,77,82,87` — `key="canonical"`, `key="ogurl"`, `key="ogimage"` … | yes — `key={id}` |
| camelCase filename | `web/components/logoPartner.js`, `web/components/basicPage.js` | `jsonLd.js` |
| `id` as the identifier prop on an injected script | `web/pages/_app.js` `<Script id="google-analytics-ga4">`, `id="google-tag-manager"`, `id="adroll-pixel"`, `id="intercom-chat"` | `id` doubles as the DOM id and the React key |
| `const BASE_URL = "https://www.polymer.co";` at module scope | `web/pages/sitemap.xml.js:3` | same constant name in `_app.js` |
| Module-scope const with an explanatory comment above it | `web/pages/_app.js:17-20` (`TRACKING_PARAM_KEYS`) | the two schema objects sit next to it in the same style |

No styled components: this emits a head tag and renders nothing visible, exactly like `seo.js`, which also has no `const Styled = {}`.

## The key strategy, and why it is `id`

`next/head` deduplicates by `key` — its `unique()` reducer keeps a `Set` of keys and drops the second child carrying one it has already seen. Without distinct keys two `<script type="application/ld+json">` blocks are still both emitted (only `title` and `base` dedupe by tag type), but the moment a page renders two blocks the safe form is a distinct key per block, which is what `seo.js` does for its meta tags.

`id` is passed by the caller rather than derived from `schema["@type"]`. Deriving looked shorter, but an agent passing a `@graph` wrapper (no top-level `@type`) would produce the key `undefined` twice and next/head would silently drop the second block. A caller-supplied `id` has no such failure: a forgotten prop yields no key at all, and both blocks still render.

The other agents' call site is two props:

```jsx
<JsonLd id="article" schema={articleSchema} />
```

`id` must be unique within a page. Taken so far: `organization` and `website`, on every page.

## `<` is escaped

`JSON.stringify(schema).replace(/</g, "\\u003c")` — a `</script>` inside any string value would otherwise close the tag early and break the page. The site-wide values here are static, but the blog and industry agents feed Sanity-authored strings (`editorialTitle`, `metaDescription`) into the same component, and that is an authoring surface, not a constant. JSON reads `<` back as `<`, so the parsed value is unchanged.

## What `_app.js` now emits, on every page

```js
const organizationSchema = {
  "@context": "https://schema.org",
  "@type": "Organization",
  name: "Polymer",
  url: BASE_URL,
  logo: `${BASE_URL}/android-chrome-512x512.png`,
  sameAs: ["https://twitter.com/withPolymer", "https://discord.gg/MgQxHMYZFN"],
};

const websiteSchema = {
  "@context": "https://schema.org",
  "@type": "WebSite",
  name: "Polymer",
  url: BASE_URL,
};
```

Every value traced to a source:

| Property | Value | Where it comes from |
|---|---|---|
| `Organization.name` / `WebSite.name` | `Polymer` | `web/components/seo.js:77` (`og:site_name`), `web/public/site.webmanifest` |
| `url` (both) | `https://www.polymer.co` | `web/components/seo.js:12`, `web/pages/sitemap.xml.js:3` |
| `logo` | `https://www.polymer.co/android-chrome-512x512.png` | `web/public/android-chrome-512x512.png`, 512x512, referenced from `web/public/site.webmanifest`. Live `HEAD` during this run returned `200 image/png`, so the URL is not a promise about an undeployed file |
| `sameAs[0]` | `https://twitter.com/withPolymer` | `web/components/footer.js:109` |
| `sameAs[1]` | `https://discord.gg/MgQxHMYZFN` | `web/components/footer.js:106` |

Rendered on `/about` in a dev server on port 3111, copied from the response body:

```html
<script type="application/ld+json" id="organization">{"@context":"https://schema.org","@type":"Organization","name":"Polymer","url":"https://www.polymer.co","logo":"https://www.polymer.co/android-chrome-512x512.png","sameAs":["https://twitter.com/withPolymer","https://discord.gg/MgQxHMYZFN"]}</script>
<script type="application/ld+json" id="website">{"@context":"https://schema.org","@type":"WebSite","name":"Polymer","url":"https://www.polymer.co"}</script>
```

`/` returns the same two blocks — checked because `web/pages/index.js` renders no `<SEO>` of its own and everything site-wide reaches it only through `_app.js`. The server was stopped afterwards and port 3111 is free.

## Omitted on purpose

- **`sameAs` has no LinkedIn entry.** Row A7 names one. The survey found no Polymer company page anywhere in the repo — every "LinkedIn" string is the integration feature. Question 1 under "Phase 5, item 0" in `QUESTIONS-FOR-JESSICA.md` already asks for the URL; when it arrives it is one array element.
- **`WebSite` has no `potentialAction` / `SearchAction`.** The site has no search endpoint: `find web/pages -iname "*search*"` returns nothing, there is no `pages/search.js`, and no search input exists in any component. A `SearchAction` here would point at a URL that 404s.
- **No `aggregateRating`, `ratingValue`, `reviewCount` or `review`** anywhere, per row A8's note and the master prompt.
- **No `address`, `email`, `legalName`, `telephone`, `foundingDate`.** The brief named name, url, logo and sameAs as the properties worth having, and the address is itself an open question (Charlotte in `web/pages/about.js:73` versus the Delaware registered-agent address in `web/pages/terms.js:278-286`), already filed as question 2 under "Phase 5, item 0".

## BreadcrumbList site-wide: not done, and it should not be

Row A7 does not ask for it — breadcrumbs appear on row A10 (blog posts) and row A11 (industry pages), both of which belong to other agents. The brief raised whether `_app.js` should carry a site-wide one anyway. It should not:

- Of the 22 routes, 14 hang directly off the root (`/about`, `/pricing`, `/plato`, `/features`, `/blog`, `/changelog`, `/terms`, `/privacy`, `/404`, and the seven industry pages, which are served at the top level — `web/next.config.js:26-57` rewrites `/applicant-tracking-for-X` to the `industries/` file, and both URLs return 200). A generated trail for those is `Home → <page>`, and for `/` itself it is a single item.
- Only four routes have a real parent: `/features/jobboard`, `/features/candidate-management-software`, and `/blog/<slug>` under `/blog`.
- A site-wide implementation needs the current route, which means `useRouter()` in `_app.js` plus a path-to-label map — a lookup table of human names for every URL. Any label not already written on the site would be invented, which rule 4 forbids, and the seven industry pages have no parent page to name at all (there is no `/industries` index route).

So the shape that is both honest and small is per-template: the blog agent emits `Home → Blog → <post>` from data it already has, and the industry agent emits the two-item `Home → <page>`. Filed as a question rather than emitted as noise — see the new "Phase 5, foundation" section of `QUESTIONS-FOR-JESSICA.md`.

## Check left behind

`/private/tmp/claude-501/-Users-jessica-claude-hub-wrk-marketing/ae83cb44-eb97-4453-99a4-0718b5a2e1c9/scratchpad/escape-check.js` — two asserts on the `<` escape (no `</script>` survives; the string round-trips through `JSON.parse` unchanged). It is a scratchpad file, deliberately not added to the repo: this branch adds no test tooling and the repo has none.
