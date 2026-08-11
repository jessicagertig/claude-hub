# Phase 5 — Article + BreadcrumbList on the blog post template

Item: workbook tab `05 Structured Data`, row A10 ("Blog posts (all) — Article + BreadcrumbList — headline, datePublished, dateModified, author, image").
Branch `seo-phase-5-structured-data`, repo `/Users/jessica/wrk/wrk-corp/wrk-marketing`.
Owned file: `web/pages/blog/[slug].js` — the only file changed. No branch created, nothing committed, nothing pushed.

Trace: `web/pages/blog/[slug].js` → `web/components/jsonLd.js` → `web/components/seo.js` → `web/pages/_app.js` → `web/pages/sitemap.xml.js` → `web/pages/blog.js` → `web/lib/sanity.js` → `studio/schemas/blogPost.js` → `web/components/navigation.js` → `web/components/footer.js` → `node_modules/@sanity/image-url` (1.0.1).

---

## Analogs read before writing

| File | What was taken from it |
|---|---|
| `web/components/jsonLd.js` | The shared component itself. Called with a unique `id`, never a hand-rolled `<script type="application/ld+json">`. Its `<` escape covers Sanity-authored strings, which matters here because `headline` and `description` are CMS text. |
| `web/pages/_app.js:23-44` | Module-level `const BASE_URL = "https://www.polymer.co"`, plain object literals with `"@context"` / `"@type"` quoted and the rest bare, a comment above each object naming the source of its values, and `<JsonLd id="..." schema={...} />` rendered as a sibling right after `<SEO ... />`. Also the exact `name` / `url` / logo URL for the Organization, so the blog's `author` / `publisher` node matches the site-wide one. |
| `web/components/seo.js:12-14, 58` | The canonical URL form: `baseUrl` with no trailing slash, `pathname ? \`${baseUrl}/${pathname}\` : baseUrl`. The breadcrumb's item URLs are built the same way so crumb 3 and the canonical are byte-identical. |
| `web/pages/sitemap.xml.js:3, 31, 54` | `const BASE_URL` naming, and the precedent that `_updatedAt` is this site's last-modified signal for blog URLs (`<lastmod>`). |
| `web/pages/blog.js:56-61` | The `/blog` index's own `pathname="blog"` and its visible title, which is where crumb 2's `name: "Blog"` and `item` come from. |
| `web/pages/blog/[slug].js` itself | Existing house idiom in the file I am editing: `const` arrow bindings, `urlFor(post.featureImage).size(1200, 630)` already used for `og:image` at line 245, `post.featureImage &&` guards at lines 245 and 260, `post.slug.current` at line 246, module-level `const RELATED_POST_COUNT` / `STOP_WORDS` above the component. |

Idiom checks that changed what I wrote:

- Conditional object spread (`...(x && { x })`) does **not** appear anywhere in `web/pages`, `web/components` or `web/lib` — grep returned nothing. So the optional `image` is handled with the file's own ternary style instead of introducing a form alien to the codebase.
- The import is written `../../components/jsonLd` to match the adjacent `../../components/seo` line, not the bare `components/jsonLd` form `_app.js` uses. Both forms exist in this file (`components/icon` at line 15), so I matched the neighbour.

---

## The `dateModified` decision — `_updatedAt`, emitted

**Emitted: `dateModified: post._updatedAt`.**

The facts:

- `studio/schemas/blogPost.js` has no editorial "last updated" field. Its full field list is `featureImage`, `editorialTitle`, `pageTitle`, `slug`, `publishDate`, `metaDescription`, `content`.
- Querying `a6d1clb1` / `production`, a `blogPost` document's complete key set is `_createdAt, _id, _rev, _type, _updatedAt, content, editorialTitle, featureImage, metaDescription, pageTitle, publishDate, slug`. `_updatedAt` is the only modified signal that exists.
- It is already in `pageProps` with **no query change**: `getStaticProps` at what is now line 376 fetches `*[_type == "blogPost" && slug.current == $slug][0]` with no projection, so the whole document lands in `post`. I checked before touching the projection — nothing was added to either query.
- I re-verified across all 26 published posts: every one has both `publishDate` and `_updatedAt`, and `_updatedAt` is never earlier than `publishDate`. Zero exceptions.

Why this is honest rather than a stand-in:

1. It is a real timestamp of a real write to this document. It is not `publishDate` re-labelled — `a-player` is `2023-02-28` published / `2023-03-02T19:45:42Z` modified, `hiring-gen-z` is `2026-05-21` / `2026-05-21T19:43:53Z`.
2. `web/pages/sitemap.xml.js:54` on this same branch already publishes `_updatedAt` as each blog URL's `<lastmod>`. Emitting anything else as `dateModified` — or omitting it — would put the Article node and the sitemap in disagreement about the same URL, which is the one thing Google actually penalises here.
3. The fields it moves on are page-visible fields. `pageTitle` and `metaDescription` render as the `<title>` and `<meta name="description">`; `content` renders as the body. A write to any of them genuinely changed the page.

The caveat, which stands and is filed as a question: `_updatedAt` moves on **any** document write. Approving the four unpublished phase-4 `pageTitle` / `metaDescription` drafts will bump `dateModified` on those four posts without the article body changing. That is a metadata change to the page rather than an editorial revision. The alternative — omitting `dateModified` entirely — loses the row A10 / tab 13 E-E-A-T signal for all 26 posts to avoid an overstatement on four, and leaves the Article contradicting the sitemap. I took the timestamp.

Explicitly not done: `publishDate` is **not** emitted as `dateModified`.

## The `author` decision — Organization, not a person

`studio/schemas/blogPost.js` has no author field, there is no author document type (`studio/schemas/` is `blogPost.js`, `changelog.js`, `schema.js`, `youtube.js`), and the template renders no byline — line 253 prints only the date, and live `/blog/a-player` confirms. The only `author` identifier already in this file (line 157-163, now 173-179) is blockquote attribution, i.e. the person being quoted inside an article, never the article's author.

So `author` is the same `polymerOrganization` object as `publisher`: an unbylined post on Polymer's own blog is written by Polymer. No person's name is invented, no profile URL is invented, and the node's `name`, `url` and `logo` all come from `web/pages/_app.js:29-36`.

This is a judgement call and it is one line to reverse — delete `author: polymerOrganization,` and the Article keeps `publisher`. Filed as a question. What row A10 actually asks for ("add real author profiles") needs a Sanity schema change, which is outside this item.

## `image`

`urlFor(post.featureImage).size(1200, 630).url()` — the same 1200x630 render `og:image` already uses on line 245 (now 294).

`.url()` is load-bearing and is the one non-obvious thing in this diff. `seo.js:14` gets away with passing the bare builder because it interpolates it into a template literal, which calls `toString()`. `JSON.stringify` does not — `@sanity/image-url` 1.0.1's `ImageUrlBuilder` has no `toJSON`, so a bare builder serialises as its own `options` object. Verified directly:

```
JSON.stringify of builder: {"image":{"options":{"projectId":"a6d1clb1","dataset":"production","source":{...
chain.url()               https://cdn.sanity.io/images/a6d1clb1/production/abc123-1200x630.png?w=1200&h=630
```

Absent-image handling: `featureImage` has no `validation: Rule.required()` on the schema and the template already guards it twice, so the ternary yields `undefined` and `JSON.stringify` drops the key entirely. Verified: `JSON.stringify({headline:"x", image: undefined, datePublished:"2023-01-01"})` → `{"headline":"x","datePublished":"2023-01-01"}`. All 26 published posts happen to have a feature image today (`*[_type=="blogPost" && !defined(featureImage)]` returns `[]`), so the guard is for the schema's permissiveness, not for current data.

## BreadcrumbList

`Home → Blog → <post>`, a real three-level chain — `/blog` is a real index page at `web/pages/blog.js` that links to every post, and `web/components/navigation.js:49` links to it from the top-level menu.

| Position | `name` | Source of the name | `item` | Source of the URL |
|---|---|---|---|---|
| 1 | `Home` | `web/components/navigation.js:22` and `web/components/footer.js:155`, both `aria-label="Home"` on the logo link | `https://www.polymer.co` | `web/components/seo.js:13` — with no `pathname` the canonical is the bare base URL, no trailing slash |
| 2 | `Blog` | `web/components/navigation.js:49`, `web/components/footer.js:74`, and `<Header title="Blog" />` at `web/pages/blog.js:61` | `https://www.polymer.co/blog` | `web/pages/blog.js:59` `pathname="blog"`; `web/pages/sitemap.xml.js:12` |
| 3 | `post.editorialTitle` | the rendered `<h1>` at line 252 (now 301) | `${BASE_URL}/blog/${post.slug.current}` | identical construction to `pathname={\`blog/${post.slug.current}\`}` on the `<SEO>` below it |

Crumb 3 and the canonical agree byte for byte — verified in the rendered HTML on two posts (below).

One difference between the two references worth recording: `web/pages/sitemap.xml.js:54` wraps the slug in `encodeURIComponent`, `web/components/seo.js` does not. For all 26 existing slugs `encodeURIComponent` is a no-op (they are lowercase ASCII kebab-case — see the slug list I pulled), so the two produce the same string. I matched the canonical, because the canonical is the authority for a page's own URL and a breadcrumb whose last item disagreed with the canonical would be the actual defect.

`position: 3` keeps its `item` rather than dropping it as the current page. Both forms are valid; carrying the URL makes the mismatch-with-canonical check possible at a glance.

---

## What was emitted, in full

```json
{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "What is an A-Player? A Complete Guide on How to Source, Hire, & Retain Them",
  "description": "Find out how to source, hire, and retain A-player talent for your business (and why A-players are so important in the first place). ",
  "mainEntityOfPage": "https://www.polymer.co/blog/a-player",
  "datePublished": "2023-02-28",
  "dateModified": "2023-03-02T19:45:42Z",
  "author": {
    "@type": "Organization",
    "name": "Polymer",
    "url": "https://www.polymer.co",
    "logo": { "@type": "ImageObject", "url": "https://www.polymer.co/android-chrome-512x512.png" }
  },
  "publisher": { "...same object..." },
  "image": "https://cdn.sanity.io/images/a6d1clb1/production/1328eba18b7fef627eb48ac9393a63111b30d962-3600x1890.png?w=1200&h=630"
}
```

```json
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    { "@type": "ListItem", "position": 1, "name": "Home", "item": "https://www.polymer.co" },
    { "@type": "ListItem", "position": 2, "name": "Blog", "item": "https://www.polymer.co/blog" },
    { "@type": "ListItem", "position": 3, "name": "What is an A-Player? A Complete Guide on How to Source, Hire, & Retain Them", "item": "https://www.polymer.co/blog/a-player" }
  ]
}
```

Every value traced:

| Property | Value from | Source |
|---|---|---|
| `headline` | `post.editorialTitle` | the rendered `<h1>`; required on the schema. Longest across all 26 posts is 94 chars (`best-applicant-tracking-software`), under Google's 110-char guidance; none exceed it |
| `description` | `post.metaDescription` | required on the schema, `min(90).max(200)`; already the `<meta name="description">` and `og:description` |
| `mainEntityOfPage` | `postUrl` | same construction as the canonical |
| `datePublished` | `post.publishDate` | `studio/schemas/blogPost.js:70-79`, `type: "date"`, required. Date-only ISO 8601, valid for schema.org `Date` |
| `dateModified` | `post._updatedAt` | Sanity system field; see the decision section |
| `author` / `publisher` | `polymerOrganization` | `name`, `url`, logo URL all identical to `web/pages/_app.js:29-36` |
| `image` | `urlFor(post.featureImage).size(1200, 630).url()` | the existing builder at line 21-25 of this file |

## Deliberately NOT emitted

- **`aggregateRating`, `ratingValue`, `reviewCount`, `review`** — no source data, forbidden by the master prompt and by Google's self-serving-review policy. Not present in either block.
- **`FAQPage`** — the survey found zero visible Q&A on any page of the site, and no per-post FAQ field on `blogPost`. `/blog/a-player` does contain a table of interview questions with model answers, but that is article content *about* interviewing, not a site FAQ; marking it up would be a policy violation. Row A12 assigns FAQPage to `/compare/*` pages that do not exist.
- **A named person as `author`** — no such data exists anywhere.
- **`wordCount`, `articleSection`, `keywords`, `inLanguage`, `speakable`** — not requested by row A10, and `articleSection` / `keywords` have no source (the schema has no taxonomy; the related-posts feature at lines 46-65 substitutes word overlap precisely because none exists).

## Verification

Local dev server (`next dev -p 3112`, started and stopped by this item; port confirmed free afterwards, no other process touched). Nothing on this branch is deployed, so production could not be used.

- All four blocks present on a post page with unique ids: `organization`, `website` (from `_app.js`), `article`, `breadcrumb`. No id collision with the foundation's blocks.
- `/blog/a-player` — full JSON of both blocks captured above; canonical `https://www.polymer.co/blog/a-player` equals crumb 3's `item`.
- `/blog/hiring-gen-z` — `datePublished 2026-05-21`, `dateModified 2026-05-21T19:43:53Z`, `image` present, `author @type Organization Polymer`, all three crumbs correct, canonical equals crumb 3's `item`.
- Both blocks parse as JSON (`json.loads` on the extracted script bodies, not a regex eyeball).
- Cross-post data checks against `a6d1clb1`/`production`: 26 posts, all have `publishDate` and `_updatedAt`, none has `_updatedAt` earlier than `publishDate`, none has a headline over 110 chars, none is missing `featureImage`.

Dev-server artifact worth knowing about, unrelated to this change: after the first `/blog/<slug>` request compiles the route, every *other* slug 404s for the rest of that dev-server's life with `error - Error: Cannot find module for page: /blog/[slug]` in the log. Restarting the server and requesting a different slug first serves that one correctly. It is a Next 12 on-demand-entries quirk with the bracketed dynamic route, present before this change; that is why the two posts above were verified across two server lifetimes.
