# Unrequested-change audit: `seo-phase-8-faq`

Read-only. Diff range `seo-phase-7-final-report..seo-phase-8-faq`. Pre-engagement
baseline for "what was there before" is `01bf615` (`main`, `Merge pull request #46
from wrk-corp/plato-landing-page`), which is the merge-base of `main` and this branch.

## What the branch contains

Ten commits, thirteen files:

```
80a9135 Add an objection-handling FAQ page
1e508ba Stop claiming unlimited team members on the industry pages
71f5b0f Correct the stale no-author comment on the blog template
8625945 Bring BLOCKED.md up to date with what has since shipped
738c0e2 Let a wide Portable Text table scroll instead of being crushed
c3791f2 Host the interview scoring matrix as a download
(plus four merges from seo-phase-7-final-report)
```

## REMOVE

### The wide-table scroll CSS in `web/pages/blog/[slug].js`

Commit `738c0e2`. Already named as unauthorised in the round brief, and the diff
confirms the full extent: it is not only the CSS, it is a new prop on
`Styled.Table` threaded from `TableRenderer`, two new module constants and an
eight-line comment.

No tab mentions tables at all. I checked every tab named in the master prompt for
this branch and the Overview: issue #17 (`17 Headings`) is the only heading/markup
hygiene item and it names H1s and first-H2s; `11 Images` covers image sizing;
nothing in the workbook asks for table layout, horizontal scrolling, or minimum
column widths. The trigger was almost certainly the approved ATS listicle
comparison table, which is wider than any table that existed before. That is a
reason, not an authorisation: the approval covers the table's content, and no cell
asks for the template to be restyled around it.

Pre-engagement text confirmed identical on `01bf615` and on
`seo-phase-7-final-report`, so restoring the base-branch form restores the
pre-engagement form. Both regions verified byte-for-byte against
`git show 01bf615:web/pages/blog/[slug].js`.

## KEEP

### `web/pages/faq.js`

Jessica's own ask, on the approved list. The `FAQPage` JSON-LD it emits is
independently named by Overview K15 / tab `05 Structured Data`: "FAQPage only
where visible FAQs exist" (master prompt Phase 5). The page renders every
question and answer visibly and builds the schema from the same `faqs` array, so
the markup cannot drift from the visible copy.

### The `/faq` entry in `web/components/footer.js`

Mechanism of the approved page. A page with no internal link is the exact defect
Overview issue #1 exists to fix: J11, "unreachable from any internal link", P1,
"~49% of the site's organic traffic". Shipping a new page reachable only from
`sitemap.xml` would create an eleventh orphan while the engagement is closing ten.
The link sits in the existing "Resources" column between "Quick start guide" and
"Changelog"; nothing else in the footer moved.

### The `"faq"` entry in `web/pages/sitemap.xml.js`

Master prompt Phase 2 item 1: "emit every marketing route + every Sanity post".
`/faq` is a marketing route. One line added to the existing `staticRoutes` array.

### The `unlimited team members` copy fix on six industry pages

On the approved list ("the industry-page copy fix that stopped six pages claiming
unlimited team members against the 5/20/50 caps in `web/pages/pricing.js`").
Also covered by master prompt rule 5, "Never fabricate data". Six single-line
edits inside each page's `benefits` array, no structural change:

| Page | before | after |
|---|---|---|
| cryptocurrency | Collaborate with unlimited team members at no extra cost | Collaborate with technical and operations team members |
| greentech | Collaborate with unlimited team members across all departments at no extra cost | Collaborate with team members across all departments |
| healthcare | Collaborate with unlimited clinical and business team members | Collaborate with clinical and business team members |
| legal-services | Collaborate with unlimited team members at no extra cost | Collaborate with legal and administrative team members |
| real-estate | Collaborate with unlimited team members across all locations and departments | Collaborate with your whole team across all locations and departments |
| startups | Collaborate with unlimited team members at no extra cost | Collaborate with founding and hiring team members |

### `web/public/behavioral-interview-scoring-matrix.xlsx`

On the approved list, and named in two cells: tab `01 Orphaned Pages` F8, "Link +
refresh + add downloadable template", and tab `13 Content Freshness` E9, "Add
downloadable scorecard template (also feeds 'interview scorecard template', 210
vol)". `git grep` finds no reference to the filename anywhere in the repo, so the
link to it lives in the Sanity post draft, which is the approved refresh work.

### `BLOCKED.md`

Master prompt rule 3: "Log anything you cannot automate ... in a running
`BLOCKED.md`". A running file is maintained; three of its entries became untrue
when the work shipped. The rewrite marks the orphaned-pages entry and the
`/contact` entry unblocked, corrects the HSTS entry's claim that
`web/next.config.js` "defines only `redirects()` and `rewrites()`" now that phase
6 added `headers()`, and drops stale line numbers from the footer/pricing finding.
It deletes no unresolved blocker: the one remaining open item, HSTS preload
submission, keeps its "To unblock, we need" paragraph intact.

### The `Article.author` comment in `web/pages/blog/[slug].js`

Commit `71f5b0f`, comment-only, zero behaviour. The comment was written during
this engagement (it is absent from `01bf615`) and said "Posts carry no byline:
`studio/schemas/blogPost.js` has no author field and there is no author document
type". That is false on the base branch, which already carries the author field
(`studio/schemas/blogPost.js` line 92, `to: [{ type: "author" }]`), the GROQ
projection `author->{ name, photo }`, the rendered byline, and the
`post.author ? {"@type": "Person"} : {"@id": ORGANIZATION_ID}` branch in the
Article schema. Author bylines are named by Overview K23, "Refresh each post (2026
data, updated modified dates, author bylines, downloadable templates)", and tab
`13 Content Freshness` E7, "add 2026 context + author byline + dateModified
schema". Correcting a comment that an authorised change made false is maintenance
of the engagement's own work, not new scope.

## UNCERTAIN — both stay

### The `FAQ` line in `web/public/llms.txt`

One line added under `## Docs & API`. Tab `08 llms.txt` specifies five sections and
their contents; B10 for `## Docs & API` is "developer.polymer.co, help docs URL",
which the FAQ is neither. Against that: A4 says "keep it accurate", Overview K18
says llms.txt should describe "Polymer, pricing, features and canonical URLs", and
the section on the base branch already lists Changelog, which is equally not a doc.
Nothing about the line is wrong, and removing it restores no pre-engagement state
because llms.txt did not exist before this engagement. Reads either way, so it
stays.

Noted, not proposed: `web/public/llms-full.txt` has no FAQ entry, so the two files
now cover different page sets. That is an omission, not an unrequested change, and
it is outside a removal round.

### `noBrandSuffix` on the FAQ page's `<SEO>` call

`web/pages/faq.js` passes `noBrandSuffix` with
`pageTitle="Polymer FAQ - Questions About the ATS and Job Board"`. The settled
decision removes that prop from `components/seo.js` in favour of
`pageTitle.includes("Polymer")`. This page's title contains "Polymer", so the
rendered title is unchanged either way and the prop becomes inert once the
`seo.js` change lands. Flagging it so the dangling prop is deleted with the rest
of `noBrandSuffix` rather than left behind. Not a removal for this round: the
change belongs with the `seo.js` work, not here.
