# Phase 4, items 1 and 2 — Sanity-side blog metadata (title tags + meta descriptions)

Scope: every row on tab "07 Title Rewrites" and tab "12 Meta Rewrites" whose URL is under
`https://www.polymer.co/blog/`. Five rows: tab 07 sheet rows 16, 17, 18, 19 and tab 12 row 14.

**No file in `/Users/jessica/wrk/wrk-corp/wrk-marketing` was created, edited or deleted.**
This item owns Sanity documents only. Five `drafts.<id>` documents were created. Nothing was
published. Every published document is byte-identical to what it was before this run — verified
field by field after the write, see "Verification" below.

## What was read before writing

- `web/components/seo.js` — line 18 `pageTitle ? pageTitle + " | Polymer" : "Polymer: Hiring made simple"`;
  line 20 `editorialTitle || pageTitle || "Hiring made simple"`; line 57 `<title>{seo.pageTitle}</title>`;
  line 80 `og:title` content is `seo.editorialTitle || seo.pageTitle`.
- `web/pages/blog/[slug].js` — lines 240-247 pass `pageTitle={post.pageTitle}`,
  `editorialTitle={post.editorialTitle}`, `metaDescription={post.metaDescription}` into `<SEO>`;
  line 252 renders `<h1>{post.editorialTitle}</h1>`.
- `studio/schemas/blogPost.js` — `editorialTitle` (line 50) is described as "The title that will
  display on page with the article content"; `pageTitle` (line 57) as "The title that will display
  on the browser tab and in shared links"; `metaDescription` (line 81) is a `text` field with
  `Rule.required().min(90).max(200)`.
- `web/lib/sanity.js`, `web/pages/blog.js`, `web/pages/changelog.js`, `web/pages/sitemap.xml.js` —
  every existing Sanity call site in the repo, for client idiom. All four use the shared
  `web/lib/sanity.js` client with `useCdn: true` and read-only `.fetch()`. None of them writes.
  There is no existing write-side analog anywhere in the repo, so the write script was kept
  entirely outside it, in the session scratchpad.

## Field choice, and why

Tab 07 is headed "Title Tag Rewrites (13 pages)" and its `Current title` column holds the values
that are in the `<title>` element today — e.g. B18 is `Why Hiring Gen Z Looks Broken and What to Do
About It | Polymer`, which is `post.pageTitle` plus the suffix `seo.js` line 18 appends. So tab 07
targets **`pageTitle`**, and `editorialTitle` was left alone on all four rows.

Consequence worth knowing: `pageTitle` drives `<title>` only. `og:title` on line 80 of `seo.js`
resolves to `seo.editorialTitle` first, and every blog post has a non-empty `editorialTitle`
(the schema marks it required), so the rewrites below change the browser tab and the Google result
but **not** the title shown when a post is shared on social. That is narrower than the schema's own
description of the field ("the browser tab and in shared links"). Filed as a question, not fixed.

Tab 12 is headed "Meta Description Rewrites (9 over 155 chars)" and its one blog row targets
**`metaDescription`**. The new value is 123 characters, inside the schema's `min(90).max(200)`,
so the draft will not trip Studio validation.

## Review list — approve these in the Studio before they go live

Five drafts. Each one differs from its published document in exactly one field.

### 1. `/blog/hello-polymer` — tab 07 sheet row 16
- Draft id: `drafts.2dc23f74-13f3-45c6-aff2-8bf7830e6261`
- Field: `pageTitle`
- Before: `Hello Polymer` (13)
- After: `Hello Polymer - Why We Built a Simpler ATS` (42)
- Rendered `<title>`: `Hello Polymer - Why We Built a Simpler ATS | Polymer` (52) — within the tab's 60 limit
- Untouched on this document: `editorialTitle` = `Hello Polymer`, `metaDescription` = `We have a big change in the works. In the coming days, we will be rebranding from Wrk to Polymer.`

### 2. `/blog/use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site` — tab 07 sheet row 17
- Draft id: `drafts.54ea4d1f-deee-47c6-849e-da34989f5736`
- Field: `pageTitle`
- Before: `Webflow Job Boards` (18)
- After: `Webflow Job Board: Show Polymer Jobs on Your Webflow Site` (57)
- Rendered `<title>`: `Webflow Job Board: Show Polymer Jobs on Your Webflow Site | Polymer` (**67**) — **over the tab's own 60 limit.** Copy left exactly as the auditor wrote it, per the no-fabrication rule.
- Untouched: `editorialTitle` = `Easily display Polymer job posts on your Webflow site with our CMS integration`, `metaDescription` = `With just a quick setup, you'll be able to build a custom job board in Webflow that displays your jobs from Polymer.`

### 3. `/blog/hiring-gen-z` — tab 07 sheet row 18
- Draft id: `drafts.e563dba0-f14d-4493-ab3c-20de909bae59`
- Field: `pageTitle`
- Before: `Why Hiring Gen Z Looks Broken and What to Do About It` (53)
- After: `Why Hiring Gen Z Looks Broken - And How to Fix It` (49)
- Rendered `<title>`: `Why Hiring Gen Z Looks Broken - And How to Fix It | Polymer` (59) — within the tab's 60 limit, which is the whole point of this row (D18 reads "Over 60 chars - truncates")
- Untouched: `editorialTitle` = `Why Hiring Gen Z Looks Broken and What to Do About It` — still the old wording, so the H1 and the title tag now say different things
- The dash in the new value is ASCII HYPHEN-MINUS U+002D, exactly as the workbook holds it, not an en dash

### 4. `/blog/best-applicant-tracking-software` — tab 07 sheet row 19
- Draft id: `drafts.fcfc319d-8b14-46d0-aef5-fc1fdd751060`
- Field: `pageTitle`
- Before: `7 Best Applicant Tracking Softwares For Small Businesses` (56)
- After: `7 Best Applicant Tracking Systems for Small Businesses (2026)` (61)
- Rendered `<title>`: `7 Best Applicant Tracking Systems for Small Businesses (2026) | Polymer` (**71**) — **over the tab's own 60 limit, and 61 before the suffix is even appended.** This row's stated problem (D19) is "Over 60; 'Softwares' is nonstandard"; the rewrite fixes the second half and makes the first half worse. Copy left exactly as written.
- Untouched: `editorialTitle` = `7 Best Applicant Tracking Software Solutions (and How to Find the Right One for Your Business)`, `metaDescription` = `Take a look at our list of the 7 best applicant tracking software solutions to find the right hiring platform for your small business or startup.`

### 5. `/blog/first-impression-bias` — tab 12 row 14
- Draft id: `drafts.a239b0d1-bad6-459f-98d1-b809d5a82dc7`
- Field: `metaDescription`
- Before: `Find out how to identify and overcome first impression bias when hiring (spoiler alert: using a hiring platform to reduce bias and create a fairer hiring process)` (162)
- After: `How to identify and overcome first impression bias in hiring - plus how structured scoring and anonymized review reduce it.` (123) — within the tab's 155 limit and inside the schema's `min(90).max(200)`
- `seo.js` appends nothing to `metaDescription`, so 123 is also what renders
- Untouched: `pageTitle` = `Overcome First Impression Bias When Hiring`, `editorialTitle` = `How to Overcome (and Recognize) First Impression Bias When Hiring`
- The clause separator before "plus" is ASCII HYPHEN-MINUS U+002D, as the workbook holds it

## Verification

After the write, every one of the five published documents and its draft were fetched again and
compared field by field, excluding `_id`, `_rev`, `_createdAt`, `_updatedAt`. Result for all five:
the set of differing fields is exactly the one field named above — `["pageTitle"]` for documents
1-4, `["metaDescription"]` for document 5. `content`, `featureImage`, `slug`, `publishDate` and
`editorialTitle` are identical between draft and published on every document. Published
`pageTitle` and `metaDescription` values are unchanged from the pre-run read.

No draft existed for any of the five documents before this run, so nothing anyone else had in
progress was overwritten. Each draft was created with `createIfNotExists` and then patched with
`.set()`, never `createOrReplace`. `.publish()` was never called and no document without a
`drafts.` prefix was ever passed to a mutation.

## Documents matched

All five slugs matched exactly one published `blogPost` each. No slug came up empty, so there is
no missing-document finding. The published document was isolated from any draft in the query with
`!(_id in path("drafts.**"))`.

| Slug | Published `_id` |
|---|---|
| `hello-polymer` | `2dc23f74-13f3-45c6-aff2-8bf7830e6261` |
| `use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site` | `54ea4d1f-deee-47c6-849e-da34989f5736` |
| `hiring-gen-z` | `e563dba0-f14d-4493-ab3c-20de909bae59` |
| `best-applicant-tracking-software` | `fcfc319d-8b14-46d0-aef5-fc1fdd751060` |
| `first-impression-bias` | `a239b0d1-bad6-459f-98d1-b809d5a82dc7` |

## One observation outside this item's scope

`/blog/hello-polymer`'s published `metaDescription` still reads "In the coming days, we will be
rebranding from Wrk to Polymer." It is 97 characters, under the 155 limit, so tab 12 has no row
for it and nothing here changed it.

## How it was done

A throwaway script in the session scratchpad, not a file in the repo:
`/private/tmp/claude-501/-Users-jessica-claude-hub-wrk-marketing/ae83cb44-eb97-4453-99a4-0718b5a2e1c9/scratchpad/blog-drafts.js`
plus `verify.js` alongside it. Both read `SANITY_API_WRITE_TOKEN` out of
`web/.env.local` at runtime; the token is not written into this log or any other file, and
`.env.local` was read only, never modified. The script has a dry-run default and an `--apply`
flag; the dry run was inspected before anything was written.

## Files written by this item

- `/Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/logs/phase-4-sanity.md` (this file)
- Three questions appended to `/Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/QUESTIONS-FOR-JESSICA.md` under "Phase 4, items 1 and 2 — Sanity blog metadata"

Nothing appended to `BLOCKED.md`. Not blocked.
