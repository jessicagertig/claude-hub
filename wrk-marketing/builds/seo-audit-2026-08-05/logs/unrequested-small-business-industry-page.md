# Unrequested-change audit: `small-business-industry-page`

Read-only pass. Base for every comparison: `seo-phase-8-faq`. Pre-engagement reference: `main`.

## What the branch contains

    git -C /Users/jessica/wrk/wrk-corp/wrk-marketing diff --stat seo-phase-8-faq..small-business-industry-page

     web/components/footer.js                                     |   5 +
     web/components/industryJsonLd.js                             |   2 +-
     web/next.config.js                                           |   4 +
     web/pages/industries/applicant-tracking-for-small-business.js | 140 +++++
     web/pages/sitemap.xml.js                                     |   1 +

Five commits: one substantive (`049f670 Add an applicant tracking page for small business`) and four merges of `origin/seo-phase-8-faq` into the branch. The merges contribute nothing over the base, which is why the diff is 151 added lines and 1 changed line.

## Result

**Nothing to remove.** Every hunk is either Jessica's explicit ask or a mechanism without which that ask does not function.

## Per-file reasoning

### `web/pages/industries/applicant-tracking-for-small-business.js` (new) — KEEP

Named in the approved list: "the small-business industry page".

I compared it structurally against the pre-existing analog `web/pages/industries/applicant-tracking-for-startups.js`, which is on `main` untouched by this engagement. Every row of the manifest is SAME:

| Element | startups (analog) | small business (new) |
|---|---|---|
| Imports | React, useContext, ReferralContext, SEO, IndustryJsonLd, Challenges, Start, {IndustryHeader, IndustryFeatures, IndustryBenefits, IndustryIntegrations} | identical list, identical order |
| `verticalData` keys | industry, title, metaDescription, heroTitle, heroDescription, challenges, benefits, features, integrations | identical set, identical order |
| `challenges` entries | 4, each `{icon, title, description}` | 4, each `{icon, title, description}` |
| `benefits` entries | 5 strings | 5 strings |
| `features` entries | 3, each `{title, description}` | 3, each `{title, description}` |
| Render order | SEO, IndustryJsonLd, IndustryHeader, Challenges, IndustryFeatures, IndustryBenefits, IndustryIntegrations, Start | identical |
| Props on each | same names on all eight | same names on all eight |
| CTA | `appendReferral("https://app.polymer.co/auth-register")`, label "Get started free" | identical |

No EXTRA component, no EXTRA prop, no new block type, no FAQ section, no second JSON-LD emitter, no styling overrides. Nothing here that the seven siblings do not already have. The only difference is copy, and the copy is the page she asked for.

### `web/components/footer.js` (+5) — KEEP, mechanism

Adds one `<li>` to the existing Industries `<ul>`:

    <li>
      <Link href="/applicant-tracking-for-small-business">
        <a>Small business</a>
      </Link>
    </li>

`main` already lists all seven industry pages in this exact block (lines 117, 122, 127, 132, 137, 142, 147). This `<ul>` is the site's only entry point to an industry page. Applying the test — "would the thing the cell asks for work without this" — a page nothing links to is an orphan, which is the site's own P1 issue (Overview A11/B11, "Orphaned high-value pages"). The link is how the approved page is reachable at all.

Nothing else in `footer.js` changed. No reordering of the existing seven, no restyling, no other section touched.

### `web/next.config.js` (+4) — KEEP, mechanism

Adds the eighth rewrite:

    {
      source: '/applicant-tracking-for-small-business',
      destination: '/industries/applicant-tracking-for-small-business',
    },

The seven sibling rewrites are pre-engagement code on `main` (lines 24-49). The new page declares `pathname="applicant-tracking-for-small-business"` to both `SEO` and `IndustryJsonLd`, and the footer links to that top-level URL. Without the rewrite that URL 404s and the canonical, `og:url` and breadcrumb all point at a dead address. This is the "if you had to add an href, you needed an `a` tag" shape exactly.

The `headers()` block and the `/climate` redirect in the same file are untouched.

### `web/pages/sitemap.xml.js` (+1) — KEEP, mechanism

One line added to `staticRoutes`, in the alphabetical position the list already uses:

    "applicant-tracking-for-small-business",

`sitemap.xml.js` is authorised by Overview issue #2, K12: "Generate a sitemap.xml from the Next.js app (app/sitemap.ts) covering all marketing pages + blog posts; submit in Search Console." A marketing page missing from the sitemap defeats that cell. The file's own header comment, already present at the branch base, says: "New pages need a line here." No other route added, none removed, no query or serializer change.

### `web/components/industryJsonLd.js` (1 changed line) — KEEP, mechanism

Comment only:

    -// holds only the seven leaf files — so Home -> this page is the whole hierarchy.
    +// holds only the industry leaf files — so Home -> this page is the whole hierarchy.

`industryJsonLd.js` is on the approved list (named in tab 05). I verified the count claim directly:

    git ls-tree --name-only seo-phase-8-faq:web/pages/industries/          -> 7 files
    git ls-tree --name-only small-business-industry-page:web/pages/industries/ -> 8 files

The word "seven" became false the moment the approved page landed. The rest of the file — `ORGANIZATION_ID`, the `url` computation, the two-item `BreadcrumbList`, the props — is byte-identical. This is not a rewrite of the analog, and not an unasked-for refactor; it is the comment being kept true.

## Things I specifically looked for and did not find

- No changes to `web/components/industries/*` (the shared industry components). The new page consumes them as-is.
- No changes to `components/seo.js`, `challenges.js`, or `start.js`.
- No new shared abstraction (no industry-page factory, no config array, no data file) introduced to accommodate an eighth page.
- No touching of the seven sibling industry pages.
- No table, heading, or CTA changes anywhere.

## Uncertain

None. Every hunk resolves cleanly to the approved page or to a mechanism the page requires.
