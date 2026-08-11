# Unrequested-change audit: `seo-phase-1-2-deorphan-crawl`

## Base commit correction

The task named `67dbdd3` as the base. `67dbdd3` is itself "Merge pull request #47 from
wrk-corp/seo-phase-1-2-deorphan-crawl", so `git diff 67dbdd3..seo-phase-1-2-deorphan-crawl`
returns phase 3's work and none of phase 1 or 2. The pre-engagement point is `01bf615`
("Merge pull request #46 from wrk-corp/plato-landing-page"), which is also
`git merge-base main seo-phase-1-2-deorphan-crawl`.

I judged `git diff 01bf615..67dbdd3`, which is exactly the nine commits of phases 1 and 2:

    6229f91 De-orphan the blog and add crawl infrastructure
    05eed5c Close the gaps the phase 1+2 review found
    5aed26f Paginate the blog with real URLs instead of a Load more button
    753a3c4 Publish llms-full.txt
    7420868 Remove the Keep reading block from the job board page
    475d355 Link the job board post from the features copy
    10468d0 Move the job board post link to the customization block
    789d54c Underline the inline link in a feature description
    67dbdd3 Merge pull request #47

Fourteen files:

    A  SEO-CHANGELOG.md
    A  web/components/blogIndex.js
    M  web/components/feature.js
    M  web/components/jobBoard/features.js
    A  web/lib/blog.js
    M  web/next.config.js
    M  web/pages/blog.js
    M  web/pages/blog/[slug].js
    A  web/pages/blog/page/[page].js
    M  web/pages/features/jobboard.js
    A  web/pages/sitemap.xml.js
    A  web/public/llms-full.txt
    A  web/public/llms.txt
    A  web/public/robots.txt

## Removal

### The "Keep reading" heading demoted out of the outline, `web/pages/blog/[slug].js`

Commit `6229f91` built the related-posts module with a real heading:

    <Styled.Related>
      <h2>Keep reading</h2>

Commit `05eed5c` replaced it with a `div`:

    <Styled.Related aria-label="Keep reading">
      <Styled.RelatedTitle>Keep reading</Styled.RelatedTitle>

and moved the styling from an `h2 { ... }` rule inside `Styled.Related` into a new
`Styled.RelatedTitle = styled.div(...)`. That commit's message lists six changes and does
not mention this one at all.

No cell authorises it. Tab 17's only rows about demotion are C9-C15 ("Make ToC a
`<nav>`/aside, not a content heading") on seven named posts, and C16-C18 ("Move CTA below
content headings") on three named posts. The related-posts module is not a table of
contents and is not the boilerplate CTA; it did not exist when the crawl ran, so no tab row
describes it. Tab 01's rows say "Link"; the master prompt's Phase 1 item 2 says "Add a
related-posts module to the blog post template (3 links minimum, topically matched)". The
module renders its three links identically with the `h2` in place, so the demotion is not
the mechanism of anything a cell asked for.

This is the same shape Jessica already reversed on another branch, in this same file: "the
sidebar CTA is an `<h2>` again".

Restore target is the `6229f91` markup, which is the state of the module before the
unauthorised commit touched it.

## Uncertain, left alone

### `Cache-Control` on the sitemap response

`web/pages/sitemap.xml.js`, added by `05eed5c`:

    res.setHeader("Cache-Control", "public, s-maxage=3600, stale-while-revalidate=86400");

Tab 02 says nothing about caching. But the route the tab asked for is `getServerSideProps`,
so every crawler hit is a live Sanity fetch, and the header changes nothing about the XML
the tab specified. Reads either way, so per the rules it is a mechanism and it stays.

### The `Styled.RelatedTitle` restore and `aria-label`

Removing the demotion also drops `aria-label="Keep reading"` from `Styled.Related`, added in
the same hunk. With the `h2` back inside the `<aside>`, the label is redundant, and the
pre-demotion markup did not carry it. Restoring `6229f91` exactly means dropping it. Called
out here so the fix agent does not treat keeping it as the safer choice.

## Kept, with the authorising cell

| Change | Authorising cell |
|---|---|
| `web/public/robots.txt`: allow all, explicit `GPTBot`/`ClaudeBot`/`PerplexityBot`/`Google-Extended`, `Sitemap:` line | Tab 03 rows 7-9 (A7 `User-agent: *` / B7 `Allow: /`; A8 the four AI crawlers / B8 `Allow`; A9 `Sitemap:` / B9 `https://www.polymer.co/sitemap.xml`) |
| `web/pages/sitemap.xml.js`: every marketing route plus every Sanity post, `lastmod` from `_updatedAt`, absolute `https://www.polymer.co` URLs | Tab 02 C7 "Add app/sitemap.ts emitting all marketing routes + every Sanity blog post with lastModified from CMS timestamps"; C8 "www host only, absolute HTTPS URLs" |
| `latestUpdatedAt`, the split `postsQuery`/`logsQuery`, `encodeURIComponent` on slugs | Mechanism of tab 02 C7's "lastModified from CMS timestamps" and C8's absolute URLs |
| Blog pagination pages listed in the sitemap | Mechanism: the pages exist because of Overview K11's pagination, and tab 02 C7 says all marketing routes |
| `web/public/llms.txt` with `# Polymer`, `## Products`, `## Pricing`, `## Docs & API`, `## Guides` | Tab 08 rows 7-11, section by section: B7 the one-paragraph definition naming Curious One, Inc.; B8 the five product links on absolute www URLs; B9 the three plan prices and the 14-day trial; B10 developer.polymer.co plus help docs; B11 "Top 8-10 evergreen posts" (ten listed, the same ones tab 01 de-orphans) |
| `web/public/llms-full.txt` | Tab 08 row 12 (B12 "Extended page-level summaries"), and named in the approvals list |
| URL-based pagination: `web/components/blogIndex.js`, `web/lib/blog.js`, `web/pages/blog/page/[page].js`, the rewrite of `web/pages/blog.js` | Jessica's approval ("URL-based blog pagination"); Overview K11 "Add full blog pagination/archive to /blog"; master prompt Phase 1 item 1 "render **all** posts on `/blog` (pagination or full archive)" |
| The `/blog/page` and `/blog/page/1` permanent redirects in `web/next.config.js` | Mechanism of pagination, and the exact example the round's instructions give: "the route file, the page-count helper and the redirects that stop `/blog/page/1` duplicating `/blog`" |
| Loss of the "Load more" button and `Styled.LoadMoreWrapper` | Mechanism: it is the control the URL-based pagination replaces |
| Related-posts module in `web/pages/blog/[slug].js` (`RELATED_POST_COUNT`, `STOP_WORDS`, `topicWords`, `relatedTo`, the `otherBlogPosts` query, `Styled.Related`) | Master prompt Phase 1 item 2 "Add a related-posts module to the blog post template (3 links minimum, topically matched)"; Overview K11 "add related-post links from crawlable posts" |
| The symmetric link graph in `relatedTo` | Mechanism of tab 01 rows 7-16, every one of which says "Link". Top-N alone left `job-rejection-email` (row 11) with no inbound link, so it did not deliver what the rows asked for |
| Job board post link in `web/components/jobBoard/features.js` | Tab 01 F16 "Link from /features/jobboard + blog index; refresh" |
| `Link` import and the `key={typeof p === "string" ? p : index}` change in `web/components/feature.js` | Mechanism: `Styled.Description` rendered each entry as plain text, and a React element cannot be its own key |
| The `a { ... }` rule in `Styled.Description` | Jessica's settled decision: "the inline link in a feature description is underlined" (commit `789d54c`) |
| `pageTitle="Job Board Software - Branded, Instant, Free to Start"` in `web/pages/features/jobboard.js` | Tab 07 E10 "Job Board Software - Branded, Instant, Free to Start | Polymer"; `components/seo.js` supplies the suffix. Kept by Jessica in commit `7420868`: "The tab 07 title rewrite and the apex-to-www og:image change stay: both were instructed" |
| `image="https://www.polymer.co/images/jobboardcard.png"` | Tab 16 D7-D8 "Update internal hrefs to the www URL"; master prompt Phase 3 redirect map row 2. Kept by Jessica in commit `7420868` |
| Absence of a "Keep reading" section on `/features/jobboard` | Jessica removed it herself in `7420868` |
| `SEO-CHANGELOG.md` | Master prompt Rules of engagement item 4 "Keep a changelog. Append every change (file, URL affected, before → after) to `SEO-CHANGELOG.md` in the repo" |
