# Phase 5 — real-values survey (READ-ONLY, nothing changed)

Branch `seo-phase-5-structured-data`, repo `/Users/jessica/wrk/wrk-corp/wrk-marketing`.
Purpose: establish what real values exist so the JSON-LD writers never have to invent one.

Trace: `web/components/seo.js` → `web/pages/_app.js` → `web/components/footer.js` → `web/components/logo.js` → `web/pages/terms.js` → `web/pages/privacy.js` → `web/pages/pricing.js` → `web/pages/index.js` → `web/pages/plato.js` → `web/pages/features.js` → `web/pages/about.js` → `web/pages/industries/applicant-tracking-for-startups.js` → `web/components/industries/*` → `web/pages/blog/[slug].js` → `web/lib/sanity.js` → `studio/sanity.json` → `studio/schemas/blogPost.js` → `web/pages/sitemap.xml.js` → `web/next.config.js` → `web/public/*`

Live checks: `https://www.polymer.co/pricing`, `https://www.polymer.co/blog/a-player`, HEAD on four URLs, Sanity CDN `a6d1clb1` / `production`.

---

## 1. Organization facts

### Exists

| Property | Value | Source |
|---|---|---|
| Legal entity | `Curious One, Inc.` | `web/pages/terms.js:279`, `web/pages/terms.js:18`, `web/pages/privacy.js:44` |
| d/b/a | `Polymer` | `web/pages/terms.js:279` ("doing business as Polymer"), `web/pages/privacy.js:44` |
| Brand name emitted today | `Polymer` | `web/components/seo.js:77` (`og:site_name`), `web/public/site.webmanifest` (`"name": "Polymer"`) |
| Site URL | `https://www.polymer.co` | `web/components/seo.js:12`, `web/pages/sitemap.xml.js:3` |
| Contact email | `support@polymer.co` | `web/components/footer.js:100`, `web/pages/terms.js:274`, `web/pages/pricing.js:209`, privacy policy contact block |
| Postal address | `1209 Orange St., Wilmington, DE 19801, United States` | `web/pages/terms.js:278-286` (`<address>`), privacy policy contact block |
| X/Twitter profile | `https://twitter.com/withPolymer` | `web/components/footer.js:109` |
| X/Twitter handle | `@withPolymer` | `web/components/seo.js:26` |
| Discord | `https://discord.gg/MgQxHMYZFN` | `web/components/footer.js:106` |
| Parent/affiliate | `https://www.curious.vc/` — footer reads "© 2025 \| A Curious Company" | `web/components/footer.js:161` |
| Logo raster asset | `/android-chrome-512x512.png` (512x512 PNG, black Polymer "P" mark on white) — also `/android-chrome-192x192.png` (192x192), `/apple-touch-icon.png` (180x180), `/mstile-150x150.png` (150x150) | `web/public/`, referenced from `web/public/site.webmanifest` and `web/components/seo.js:32-47` |
| OG card image | `/images/card.png` (1200x630); `/images/platocard.png` used by `/plato`; `/images/jobboardcard.png` exists | `web/public/images/`, `web/components/seo.js:14`, `web/pages/plato.js:19` |
| Product self-description | "Polymer gives you a beautiful job board and a powerful ATS to manage candidates. Collaborate with your hiring team from one place. Get started free." | `web/components/seo.js:23` (site-wide default meta description) |
| Longer product description | `web/public/llms.txt` lines 3 and 7-11 (per-product one-liners for /features, /features/jobboard, /features/candidate-management-software, /plato, /pricing) | `web/public/llms.txt` |

### Does NOT exist — do not invent

- **No LinkedIn company-page URL anywhere in the repo.** Every "LinkedIn" hit is the *integration feature* (`web/pages/features.js:138-140`, `web/components/home/integrations.js:45-53`, `web/pages/pricing.js:234`, the seven industry pages), never a Polymer profile link. `sameAs` cannot include LinkedIn from repo evidence.
- **No `x.com/...` URL.** The only X/Twitter link on the site is the legacy `twitter.com/withPolymer` host.
- **No Facebook, Instagram, YouTube channel, GitHub org, Crunchbase or Product Hunt profile URL.** `web/components/footer.js:368` still declares a `Styled.Badge` styled component labelled `ProductHunt_Badge`, but nothing renders it and there is no Product Hunt URL in the file. `next.config.js:5` allow-lists `api.producthunt.com` as an image domain; no URL.
- **No telephone number** anywhere in the repo or on the live site.
- **No founder or employee names.** `web/pages/about.js` has principles and a Charlotte skyline photo, no people. `web/images/people/` holds four 112x112 customer-quote headshots (`bodeswellQuote.jpg`, `calaQuote.jpg`, `clutchQuote.jpg`, `visibleQuote.jpg`), which are customers, not staff.
- **No founding date / `foundingDate`** anywhere.
- **No vector logo file for Polymer.** `web/components/logo.js` draws the mark as an inline `<svg>` in JSX; there is no `.svg` asset. `web/images/logos/` contains *customer* logos (batch, cala, campfire, eeetwell, filebase, helio, helium, igloo, killcliff, leland, makelog, piratewires, tixel) plus partner marks (`webflow_logo.svg`, `whatjobs_logo.svg`, `wwr_logo.svg`). `web/images/icon.png` (520x520) is imported by nothing and lives outside `web/public/`, so it has no public URL.
- **Two different "where Polymer is" statements exist.** `web/pages/about.js:73` says "Founded and headquartered in Charlotte"; `web/pages/terms.js:281-285` and the privacy policy give the Delaware registered-agent address. Nothing in the repo gives a Charlotte street address. See QUESTIONS-FOR-JESSICA.

---

## 2. Pricing

`web/pages/pricing.js:25-28` — the exact object:

```js
const prices = {
  annual: { starter: 124, growth: 233, scale: 415 },
  monthly: { starter: 149, growth: 279, scale: 499 }
};
```

- **Default shown is ANNUAL.** `web/pages/pricing.js:17` is `const [isAnnual, setIsAnnual] = useState(true)`, so the server-rendered HTML and first paint show `$124 / $233 / $415`. Confirmed on the live page — `https://www.polymer.co/pricing` serves those three numbers.
- **Both rates are displayed as a per-month figure.** `web/pages/pricing.js:74-76` renders `${price}` + `/` + `month` for whichever mode is active, so the annual number is a monthly-equivalent price, not a yearly total. There is no yearly total anywhere on the page. `1488 / 2796 / 4980` per year are derivable but are not written anywhere — treat them as absent.
- **Annual discount label:** `2 months free!` (`web/pages/pricing.js:62`), restated in `web/public/llms.txt` as "Annual billing is 2 months free."
- **Plan names:** `Starter` (`pricing.js:72`), `Growth` (`pricing.js:112`, badged `Most Popular` at `pricing.js:110`), `Scale` (`pricing.js:151`).
- **Currency:** the page prints a bare `$` and never says USD. The USD declaration is in `web/pages/terms.js:173-175`: "all Dollar amounts are amounts of United States Dollars. You must pay for paid Service Plans in United States Dollars." `web/public/llms.txt` also uses bare `$`. So `priceCurrency: "USD"` traces to terms.js, not to pricing.js.
- **Plan limits:** Starter — up to 5 published jobs, up to 5 users, 50 Plato AI credits per month (`pricing.js:85-93`). Growth — 20 / 20 / 100 (`pricing.js:125-133`). Scale — 50 / 50 / 150 (`pricing.js:164-172`). All three end with "All features included."
- **Free-trial terms, verbatim** (`web/pages/pricing.js:194`): "You'll have unlimited time to explore Polymer and a 14-day free trial when you publish your first job." Confirmed on the live page.
- **No free/$0 tier is sold on this page.** `web/pages/terms.js:78` does say "When you create your account, you begin on a free-of-charge Service Plan," and every CTA is labelled "Get started free" pointing at `https://app.polymer.co/auth-register`.
- **Above 50 published jobs:** no price. `web/pages/pricing.js:202-210` is a `mailto:support@polymer.co` contact banner, not a plan.
- **Climate:** 1% of every payment to Stripe Climate, link `https://climate.stripe.com/Cg9EBK` (`web/pages/pricing.js:358-364`, `web/pages/terms.js:266-270`, redirect `/climate` at `web/next.config.js:14-18`).

---

## 3. Visible FAQs

**None exists. Not on any page.**

- Zero matches for `faq`, `frequently asked`, `accordion`, `<details`, `<summary>` across `web/pages`, `web/components`, `studio` (the only `question` hits are `web/pages/features.js:74-75` "Custom application questions" as a feature name, `web/pages/about.js:32` `<h3>Question the standards</h3>` as a principle heading, and Termly's `<bdt class="question">` wrapper spans inside the `web/pages/privacy.js` HTML blob).
- Only four question-mark strings exist in page copy and all four are CTA headlines with no answer beneath them: `web/pages/pricing.js:202` "Need more jobs or custom solutions?", and `title:` fields at line 123 of the fintech, legal-services, real-estate and greentech industry pages ("Ready to transform your fintech hiring?" etc.).
- Live confirmation: `https://www.polymer.co/pricing` and `https://www.polymer.co/blog/a-player` both render no Q&A block.
- The workbook's row A12 assigns FAQPage to "Comparison pages (planned /compare/\*)". **Those pages do not exist** — `web/pages` has no `compare/` directory. So no FAQPage anywhere in phase 5.
- Blog posts are Portable Text from Sanity and could contain a question-shaped `h2`, but no post renders a question/answer *component*, and there is no per-post FAQ field on `blogPost`. `/blog/a-player` contains a table of sample interview questions with "ideal answers" — that is article content about interviewing, not a site FAQ, and marking it up as FAQPage would be a policy violation.

---

## 4. Blog post dates

`studio/schemas/blogPost.js` field list, in order: `featureImage` (with `altText`, `source`, `sourceUrl`), `editorialTitle`, `pageTitle`, `slug`, `publishDate`, `metaDescription`, `content`.

- **Published date: `publishDate`** — `studio/schemas/blogPost.js:70-79`, `type: "date"`, `validation: Rule.required()`. Date-only, no time and no timezone (values look like `"2026-05-21"`). Rendered at `web/pages/blog/[slug].js:253` as `Posted on ${moment(post.publishDate).format("MMMM D, YYYY")}`. Also the sort key for related posts (`[slug].js:338`).
- **Modified date: a real `dateModified` field does NOT exist.** There is no `updatedAt`, `modifiedDate`, `lastUpdated` or similar field on the schema, and the live documents confirm it. Querying `a6d1clb1` / `production`, a `blogPost` document's full key set is exactly:
  `['_createdAt', '_id', '_rev', '_type', '_updatedAt', 'content', 'editorialTitle', 'featureImage', 'metaDescription', 'pageTitle', 'publishDate', 'slug']`
  The only modified signal is Sanity's system field **`_updatedAt`**.
- **`_updatedAt` is already available on the page with no query change.** `web/pages/blog/[slug].js:327-329` fetches the whole document — `*[_type == "blogPost" && slug.current == $slug][0]` with no projection — so `post._updatedAt`, `post._createdAt`, `post._id` and `post._rev` are all already in `pageProps`.
- **`_updatedAt` is real and sane.** Across all 26 posts it is always at or after `publishDate` — e.g. `hiring-gen-z` `publishDate` `2026-05-21` / `_updatedAt` `2026-05-21T19:43:53Z`; `a-player` `2023-02-28` / `2023-03-02T19:45:42Z`; `behavioral-interview-scoring-matrix` `2023-08-08` / `2023-08-08T11:56:35Z`.
- **Precedent on this branch:** `web/pages/sitemap.xml.js:31` and `:54` already use `_updatedAt` as `<lastmod>` for every blog URL, with the comment at `:45-46` — "Only the two CMS-driven index pages have an honest last-modified date. The rest ship with the code, so they carry no lastmod rather than a made-up one."
- **Caveat the writer must respect:** `_updatedAt` moves on *any* document write, including a metadata-only edit. Every one of the four `pageTitle` / `metaDescription` Sanity drafts sitting unpublished from phase 4 will bump `_updatedAt` when approved, without the article body changing.
- **No author exists.** `blogPost` has no author field, no reference to a person document, and there is no `author` schema (`studio/schemas/` is `blogPost.js`, `changelog.js`, `schema.js`, `youtube.js`). `web/pages/blog/[slug].js` renders no byline — line 253 prints only the date. Live check on `/blog/a-player` confirms no byline. The only `author` identifier in the template (`[slug].js:157-163`) is the **blockquote attribution** inside a quote block, which is the person being quoted, not the post author. The workbook's row A10 "author (add real author profiles)" has nothing to draw on.
- **Image for Article:** `featureImage` is optional in practice — `[slug].js:245` and `:260` both guard with `post.featureImage &&`. The 1200x630 URL form already used for `og:image` is `urlFor(post.featureImage).size(1200, 630)` (`[slug].js:245`, builder at `:21`).
- Total: **26 `blogPost` documents**.

---

## 5. Breadcrumb reality

- **No visible breadcrumb navigation exists anywhere.** Zero matches for `breadcrumb` or `crumb` across `web` and `studio`. `web/components/navigation.js` is a flat top-level menu (`/features`, `/plato`, `/pricing`, `/blog`) plus a logo home link; `web/components/header.js` renders a title + description block. Live check on `/pricing` and `/blog/a-player` confirms none. So any `BreadcrumbList` would be markup with no on-page counterpart.
- **Actual URL hierarchy (canonical form, from each page's `pathname` prop into `web/components/seo.js:13`):**

| Live path | `pathname` prop → canonical | File |
|---|---|---|
| `/` | none — `web/pages/index.js` renders **no `<SEO>` at all**, so it falls through to the prop-less `<SEO />` in `web/pages/_app.js:93`; canonical `https://www.polymer.co`, title "Polymer: Hiring made simple" | `web/pages/index.js` |
| `/about` | `about` | `web/pages/about.js:25` |
| `/blog` | `blog` | `web/pages/blog.js:59` |
| `/blog/<slug>` | `blog/${post.slug.current}` | `web/pages/blog/[slug].js:246` |
| `/changelog` | `changelog` | `web/pages/changelog.js:59` |
| `/features` | `features` | `web/pages/features.js:409` |
| `/features/jobboard` | `features/jobboard` | `web/pages/features/jobboard.js:15` |
| `/features/candidate-management-software` | `features/candidate-management-software` | `web/pages/features/candidate-management-software.js:15` |
| `/plato` | `plato` | `web/pages/plato.js:20` |
| `/pricing` | `pricing` | `web/pages/pricing.js:39` |
| `/privacy` | `privacy` | `web/pages/privacy.js:62` |
| `/terms` | `terms` | `web/pages/terms.js:11` |
| `/404` | `404` | `web/pages/404.js:11` |
| `/applicant-tracking-for-<vertical>` (x7) | `applicant-tracking-for-<vertical>` — **top-level, no `/industries` segment** | line 90 of each `web/pages/industries/*.js` |

- **The industry pages really are served at two paths.** `web/next.config.js:26-57` declares seven **rewrites** (not redirects) from `/applicant-tracking-for-X` → `/industries/applicant-tracking-for-X`. In the Pages Router the underlying file route stays reachable, so both URLs return 200 on production — verified with HEAD: `https://www.polymer.co/applicant-tracking-for-startups` → `200`, `https://www.polymer.co/industries/applicant-tracking-for-startups` → `200`. Both serve the same component, so both emit the same canonical `https://www.polymer.co/applicant-tracking-for-startups`. **Any BreadcrumbList `item` URL for these pages must use the top-level form**, matching the canonical, the footer links (`web/components/footer.js:117-149`) and `web/pages/sitemap.xml.js:17-23`, whose comment at `:5-8` states this convention explicitly.
- **Consequence for the workbook's row A11** ("Industry ATS pages (7) — Service or WebPage + BreadcrumbList"): the seven industry pages have **no parent page**. There is no `/industries` index route (`web/pages/industries/` contains only the seven leaf files) and no "Industries" landing page. The only honest hierarchy is `Home → <industry page>` — a two-item list. A `Home → Industries → X` chain would require inventing a URL that returns 404.
- Real parent-child chains that do exist: `/features` → `/features/jobboard`, `/features` → `/features/candidate-management-software`, `/blog` → `/blog/<slug>`.
- Note: `web/pages/sitemap.xml.js` and `web/public/llms.txt` both 404 on production today (HEAD-checked) — they are phase 1-4 work on this branch, not yet deployed.

---

## 6. Existing JSON-LD

**None. Zero.** `grep -rni "ld+json|schema\.org|jsonld|json-ld|itemscope|itemprop|vocab="` across the whole repo excluding `node_modules` returns nothing. `web/components/seo.js` emits only `<title>`, `description`, canonical, favicons/manifest, `google-site-verification`, two `twitter:*` tags and five `og:*` tags. `web/pages/_app.js` adds a stylesheet link and analytics `<Script>` tags (GA4 `G-SHNM5E7QKD`, GTM `GTM-N6H844WJ`, AdRoll, Intercom `yblhzder`) — no structured data. This matches the workbook header "Structured Data (0 pages have any)".

---

## Values that phase 5 tabs ask for and that DO NOT exist

Listing these so no downstream agent fills them in:

1. LinkedIn profile URL (row A7 `sameAs`).
2. Any author identity for blog posts (row A10 `author`).
3. A dedicated `dateModified` field (row A10) — only `_updatedAt`.
4. Any FAQ content (row A12) and the `/compare/*` pages themselves.
5. `aggregateRating` / `ratingValue` / `reviewCount` / `review` — explicitly forbidden and no source data exists.
6. `foundingDate`, `numberOfEmployees`, `telephone`, a vector logo file, a Charlotte street address.
7. A yearly total price. Only the two monthly-equivalent rates exist.
8. An `/industries` index URL to hang a three-level breadcrumb on.
