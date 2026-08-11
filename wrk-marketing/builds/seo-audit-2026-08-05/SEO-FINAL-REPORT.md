# SEO Final Report — polymer.co

Phase 7 of the MakeReality technical SEO audit (`Polymer-Technical-SEO-Audit_MakeReality.xlsx`, Screaming Frog crawl 2026-08-03, 17 issues across 33 pages / 31 indexable 2xx), executed against `/Users/jessica/wrk/wrk-corp/wrk-marketing` as six stacked branches, one per phase.

**Nothing is merged and nothing is deployed.** Five pull requests are open — #47 through #51 — each based on the one before it, and this branch carrying the report is the sixth in the stack. Every fix described below exists only as branch code or as an unpublished Sanity draft. Verified live at the time of writing: `https://www.polymer.co/robots.txt` 404, `/sitemap.xml` 404, `/llms.txt` 404, `/contact` 404, the homepage emits no `<link rel="canonical">`, and the only response header on `https://www.polymer.co/` is the platform-set `strict-transport-security: max-age=63072000`.

---

## 1. Issues closed, by audit number

`DONE` below means **code-complete on its branch**, not live. No state in this table is visible to a crawler today.

| # | Pri | Issue (Overview tab name) | PR | State | What remains |
|---|---|---|---|---|---|
| 1 | P1 | Orphaned high-value pages | #47 | PARTLY DONE | The linking half is done; the content half is not. 8 of the 10 tab-01 rows say "refresh" and four name new assets (downloadable template, formula/benchmark blocks, hiring-ops cluster fold, interview-bias guide base). In `BLOCKED.md`. |
| 2 | P1 | No XML sitemap | #47 | PARTLY DONE | `web/pages/sitemap.xml.js` emits 44 absolute URLs. Tab 02 row 9 — submit in Search Console and monitor Index Coverage — needs property access. In `BLOCKED.md`. |
| 3 | P1 | No robots.txt | #47 | PARTLY DONE | `web/public/robots.txt` matches tab 03 rows A7-A9. Tab 03 row 10 (apex host) is a Vercel domain setting; `https://polymer.co/robots.txt` still answers 308. In `BLOCKED.md`. |
| 4 | P1 | Canonical tags missing site-wide | #48 | DONE | All 41 tab-04 rows resolve to their prescribed value through one line in `web/components/seo.js`. |
| 5 | P1 | Zero structured data | #50 | PARTLY DONE | 7 `@type` values across every HTML route. Tab 05 cell C10 "add real author profiles" needs a Sanity schema field that does not exist; row A12 (`/compare/*` Article + FAQPage) names pages that do not exist. |
| 6 | P1 | Backlinked /contact page returns 404 | #48 | PARTLY DONE | The 301 to `/about` is in `web/next.config.js`. Tab 06 cell E7's preferred remedy, restoring `/contact` as a real page with a form, is not built. In `BLOCKED.md`. |
| 7 | P1 | Title tags under-optimized | #49 | PARTLY DONE | 9 of 13 rows render the workbook cell exactly (two of those are `(keep)`). Rows A16-A19 are four blog titles sitting in unpublished Sanity drafts. |
| 8 | P2 | No llms.txt | #47 | PARTLY DONE | `web/public/llms.txt` carries all five sections tab 08 names. `llms-full.txt` (row 12, marked optional) was not created — `web/public/llms-full.txt` does not exist. |
| 9 | P2 | AI search: zero ChatGPT presence, citations informational-only | **none** | **NOT STARTED** | **Assigned to no phase of the master prompt.** The technical grounding it depends on (issues 2/3/5/8) is built; the AEO content tier and comparison pages are not started. See section 6. |
| 10 | P2 | Legacy 'Wrk' brand remnants & dead help links | #51 | PARTLY DONE | Nothing in the repo changed. All fixes are unpublished Sanity drafts; `/changelog` serves three dead `help.wrk.xyz` links today, verified live. Row A7's premise was disproved — the Webflow post's body contains "wrk" only in its slug, which the row says to keep. |
| 11 | P2 | Oversized images | #51 | PARTLY DONE | Width clamp applied at all four Sanity builder call sites plus nine `sizes` props. The tab's `fm=webp` half was applied then deliberately reversed on measurement. Zero binaries compressed; 7 of 16 responsive call sites still emit `sizes="100vw"`; the `_next/image` quality half untouched. |
| 12 | P2 | Meta descriptions over limit | #49 | PARTLY DONE | 8 of 9 rows rewritten in code. Row A14 `/blog/first-impression-bias` is an unpublished draft; it renders 162 characters live. |
| 13 | P2 | Content freshness / E-E-A-T on traffic-driving posts | **none** | **NOT STARTED** | **Assigned to no phase of the master prompt.** Zero content changes to any of the nine posts. See section 6. |
| 14 | P2 | Broken / bot-walled external links | #51 | PARTLY DONE | Zero of the 20 URLs exist in any repo file; all live in Sanity content. All five confirmed 404s plus a sixth the tab omits have replacements in unpublished drafts. Row A17 is the one bot-walled row the tab asks to CHANGE, not leave — `http://www.pcmag.com` to https — and both of its markDefs are now upgraded in the draft. The other 14 bot-walled links were left in place, as the tab instructs. Eight further broken links found in published Sanity content are not on tab 14 and are not actioned: `springrecruit.com`, `polywork.com`, `kornferry.com`, `pallet.com/spotlight`, `careerarc.com`, `hrsg.ca`, `statista.com`. |
| 15 | P3 | Security headers missing | #51 | DONE | `web/next.config.js` `async headers()` emits all four at the tab's exact values, CSP as `Content-Security-Policy-Report-Only` per row A7's rollout procedure. |
| 16 | P3 | Internal links to redirecting URLs | #48 | PARTLY DONE | The repo half is done — zero apex `href` strings remain under `web/`. The fourth occurrence is a `markDefs[].href` in a published Sanity changelog document and still renders on `/changelog` today. Tab 16 row A9's 52 external redirecting URLs were not actioned; the tab names none of them. |
| 17 | P4 | Heading hygiene | #49 | PARTLY DONE | 9 of 12 rows closed. Rows A16-A18 ("Move CTA below content headings") could not be done as written — all three posts carry zero content `h2` blocks in Sanity. What landed is a demotion of the sidebar CTA; the first `<h2>` on all three is still `Start hiring with Polymer for free`. |

Two issues DONE, thirteen PARTLY DONE, two NOT STARTED.

---

## 2. URLs touched

### Pages whose metadata changed (titles, meta descriptions, canonicals)

Every URL on the site gains a canonical — `web/components/seo.js` emits it, and all 21 page templates that render HTML render that component. (`web/pages/api/hello.js` and `web/pages/sitemap.xml.js` render no HTML. `web/components/jsonLd.js`, added in phase 5, is a second `next/head` consumer.) On top of that:

- `https://www.polymer.co/` — new `<SEO>` element; `<title>` `Polymer | Applicant Tracking System & Job Boards for Startups`
- `https://www.polymer.co/pricing` — `before: pageTitle={headerContent.title}` → `after: pageTitle="Polymer Pricing - Simple ATS Plans from $124/mo"`
- `https://www.polymer.co/about` — `before: pageTitle={headerContent.title}` → `after: pageTitle="About Polymer - The Team Behind the Simple ATS"`
- `https://www.polymer.co/changelog` — `before: pageTitle={headerContent.title}` → `after: pageTitle="Polymer Changelog - What's New in the ATS"`
- `https://www.polymer.co/blog` — `before: pageTitle="Blog"` → `after: pageTitle="Hiring & Recruiting Blog - Guides and Templates"`
- `https://www.polymer.co/features/jobboard` — `before: pageTitle="Job Board Software"` → `after: pageTitle="Job Board Software - Branded, Instant, Free to Start"`
- `https://www.polymer.co/plato` — title plus a new `<h1>`, visually hidden (see section 5)
- `https://www.polymer.co/terms` — `metaDescription` 160 → 104 chars; `pageTitle` deliberately left alone per tab 07 cell E14 `(keep)`
- `https://www.polymer.co/privacy` — three anchor `href`s apex → www; `pageTitle` `(keep)`
- The seven industry pages — `metaDescription` only, 219-289 chars → 116-140. One of the eight, from the changelog: `before: metaDescription={`${verticalData.heroDescription} Simple, powerful ATS built for real estate brokerages and proptech companies.`}` → `after: metaDescription="Simple, powerful ATS for real estate: streamline hiring for brokerages and proptech teams. Branded job board, team tools, free 14-day trial."`
- All 26 `https://www.polymer.co/blog/<slug>` pages — table of contents demoted to `<nav>`, sidebar CTA and related-posts label demoted out of the heading outline, and `noBrandSuffix` scoped to four slugs
- `https://www.polymer.co/applicant-tracking-for-legal-services` and its `/industries/` twin — `pathname` corrected to the short form so both emit the tab 04 C23 canonical
- `https://www.polymer.co/plato` and `/features/jobboard` — `before: image="https://polymer.co/images/platocard.png"` → `after: image="https://www.polymer.co/images/platocard.png"`, same on `jobboardcard.png`. Neither URL appears in any tab row; disclosed as a scope extension.

### Pages that gained structured data

| URL | Types emitted |
|---|---|
| Every HTML route (22 templates) | `Organization`, `WebSite` |
| `/`, `/features`, `/plato` | + `SoftwareApplication` with 3 `Offer` and 6 `UnitPriceSpecification` |
| `/pricing` | + `Product` with 3 `Offer` and 6 `UnitPriceSpecification` |
| All 26 `/blog/<slug>` | + `Article`, `BreadcrumbList` (Home → Blog → post) |
| The 7 `/applicant-tracking-for-*` pages and their `/industries/` twins | + `Service`, `BreadcrumbList` (Home → page) |
| `/about`, `/blog`, `/changelog`, `/terms`, `/privacy`, `/404`, `/features/jobboard`, `/features/candidate-management-software` | `Organization` + `WebSite` only |
| `/sitemap.xml`, `/api/*` | none — not HTML routes |

### New routes and files

- `https://www.polymer.co/sitemap.xml` — `web/pages/sitemap.xml.js`, 18 static routes + 26 blog posts = 44 absolute `<loc>` values, `<lastmod>` only where a Sanity `_updatedAt` exists. The tab prescribes `app/sitemap.ts`; this repo is Next.js 12.1.0 Pages Router with no `web/app/` directory, so the Pages Router equivalent was used. Same route, same output, different file. The workbook was wrong about the file, not the requirement.
- `https://www.polymer.co/robots.txt` — `web/public/robots.txt`, `Allow: /` for `*` plus GPTBot, ClaudeBot, PerplexityBot and Google-Extended individually, and `Sitemap: https://www.polymer.co/sitemap.xml`
- `https://www.polymer.co/llms.txt` — `web/public/llms.txt`, 43 lines, sections `# Polymer`, `## Products`, `## Pricing`, `## Docs & API`, `## Guides`
- `https://www.polymer.co/features/jobboard` — new "Keep reading" block linking `/blog/best-job-board-software`, its copy read from Sanity rather than written

### Redirects and header changes

- `/contact` → `/about`, `statusCode: 301`. `301` rather than `permanent: true` is deliberate: `permanent: true` emits 308 in Next 12.1.0 and tab 06 cell E7 says 301.
- `/:path*` — four headers on all 107 URLs: `X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN`, `Referrer-Policy: strict-origin-when-cross-origin`, `Content-Security-Policy-Report-Only` with eleven directives.

### Sanity documents drafted (nine, all unpublished)

Project `a6d1clb1`, dataset `production`. A dataset query for documents with `_updatedAt > 2026-08-05` returns nothing, confirming no published document was mutated.

| Draft id | URL | Change |
|---|---|---|
| `2dc23f74-…` | `/blog/hello-polymer` | `pageTitle` |
| `54ea4d1f-…` | `/blog/use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site` | `pageTitle` |
| `e563dba0-…` | `/blog/hiring-gen-z` | `pageTitle` |
| `a239b0d1-…` | `/blog/first-impression-bias` | `metaDescription`, 162 → 123 chars |
| `fcfc319d-…` | `/blog/best-applicant-tracking-software` | `pageTitle` + three content changes from two phases |
| `5fd6bab5-…` | `/blog/talent-acquisition` | `content[35].markDefs[0].href` → `https://topgrading.com/` |
| `914dc19a-…` | `/changelog` (2021-06-06 entry) | `help.wrk.xyz/…5280480…` → `help.polymer.co/…10250419…` |
| `609fbb42-…` | `/changelog` (2022-04-25 entry) | Slack notifications article, host repointed |
| `3d2afcd8-…` | `/changelog` (2022-01-03 entry) | Discord notifications article, host repointed |

Three further drafts sit in the Studio's pending list and are **not** audit output: `c6e4e552-…` (`ogre`, 2022 demo content), `83ff9bc1-…` (`changelog`, last written 2022-08-18) and `3323e96f-…` (`changelog`, 2023). `QUESTIONS-FOR-JESSICA.md` lines 99-101 present `83ff9bc1-…` as engagement output under the heading "One more Sanity draft, from the Phase 3 review". That is wrong — its `_updatedAt` is `2022-08-18T22:49:35Z`, identical to its published document's, and Sanity bumps `_updatedAt` on every mutation. The engagement produced nine drafts, not ten.

---

## 3. Pull requests

**None of the six is merged.** Each is based on the previous branch, so they merge in order or not at all.

| PR | Branch | Base | Carries |
|---|---|---|---|
| #47 | `seo-phase-1-2-deorphan-crawl` | `main` | Issues #1, #2, #3, #8. Blog index uncapped, related-posts module, `/features/jobboard` link, `sitemap.xml.js`, `robots.txt`, `llms.txt`. 7 files. |
| #48 | `seo-phase-3-redirects-canonicals` | #47's branch | Issues #4, #6, #16. Canonical tag, `/contact` 301, apex→www hrefs, `BLOCKED.md` created. 9 files. |
| #49 | `seo-phase-4-metadata-headings` | #48's branch | Issues #7, #12, #17. Title and meta rewrites, `noBrandSuffix`, `/plato` H1, heading demotions. 19 files. |
| #50 | `seo-phase-5-structured-data` | #49's branch | Issue #5. `jsonLd.js`, `softwareApplicationJsonLd.js`, `industryJsonLd.js` and their call sites. 17 files. |
| #51 | `seo-phase-6-images-links-headers` | #50's branch | Issues #10, #11, #14, #15. `headers()` + CSP, `sanityImage.js` width clamp, nine `sizes` props, three customer links unlinked. 13 files. |
| not yet opened | `seo-phase-7-final-report` | #51's branch | This report, plus the corrections its verification pass produced. Contains every phase. |

### Two defects on the open branches, found while compiling this report

**The `https://ca.la` href was removed from a link that works.** `web/components/home/brands.js:26` reads `{ src: cala, alt: "CALA", width: 70 },` — commit `6029add` removed `href: "https://ca.la"`, giving the reason "ca.la returns SERVFAIL". It does not: `dig @1.1.1.1` and `@8.8.8.8` both return A records, and a fetch against `104.26.4.176` returns `301 → https://www.mercer.design/ → 200`. The SERVFAIL is this machine's own resolver. Four sources say the href was left alone — `REVIEW-phase-6.md`, `SEO-CHANGELOG.md` lines 2307, 2529 and 3123, and `QUESTIONS-FOR-JESSICA.md` item 2b ("The `https://ca.la` href at `brands.js:26` is untouched, because it works"). The code disagrees with all four; three customer links were unlinked, not two.

**`billingIncrement` diverges between two blocks describing the same three offers.** `web/components/softwareApplicationJsonLd.js` lines 55 and 64 emit `billingIncrement: 12` and `billingIncrement: 1`; `web/pages/pricing.js:46` does not, with the reason written at lines 42-44 ("that is how many months go on one charge, which the page never states"). So `/pricing` and `/`, `/features`, `/plato` carry different property sets for the same offers. Four sources — the component's own comment at line 16 and `SEO-CHANGELOG.md` lines 1738, 2073 and 1827-1834 — say they match. `logs/phase-5-fixes-round-3.md` lines 262-270 names the remaining edit.

### `SEO-CHANGELOG.md` is stale about its own commits

The changelog was written phase by phase, and each phase's fix pass shipped its corrections inside the same commit that made them false. Roughly forty statements describe committed, pushed work as "uncommitted", "working-tree only" or "not in PR #N" — lines 16, 32, 350, 379, 422, 515, 658, 660 and 667 (phase 1/2); 690-704, 839, 845, 879 (phase 3); 944, 966, 987, 1018, 1084, 1105, 1397-1470 (phase 4); and fourteen in the phase 6 section including the bolded table at 2312-2321 headed "PR #51 as it stands ships the opposite of what this record describes." All of it is on the branches: the five PR branches each equal their `origin/` ref at `05eed5c`, `e822d00`, `87ba3ae`, `8743f7f` and `6029add`.

Three further changelog claims are contradicted by the code, and the code wins: line 981 says `web/components/start.js:105` became a `styled.div` (it reads `styled.h2`, reverted in phase 4 round 3); lines 2100 and 2265 say each industry page renders two Organization descriptions (`web/components/industryJsonLd.js:32` is `provider: { "@id": ORGANIZATION_ID }` and renders one); and line 709 calls `web/components/seo.js` the repo's only `next/head` consumer, which phase 5 made false by adding `web/components/jsonLd.js`.

(A fourth was checked and is not a defect: line 726 quotes the canonical as `href={seo.url}`, but it sits inside a block explicitly describing commit `4fbc64f`, and lines 733-739 amend it on the spot with the change to `href={seo.canonicalUrl}`. That is a superseded historical record, not an uncorrected claim.)

---

## 4. Awaiting a human

45 distinct items, deduplicated from 71 entries across `BLOCKED.md`, `QUESTIONS-FOR-JESSICA.md` and `QUESTIONS-FOR-SHAWN.md`.

### A. Decisions only Jessica can make

| # | Item | Question |
|---|---|---|
| 1 | Blog content refresh (issues #1 and #13, 10 + 9 posts, 4 overlapping) | Is the content refresh separate work outside this engagement, or does it get scoped now? |
| 2 | The nine Sanity drafts | Do you approve and publish them? Two riders: do not click Generate on the slug field (the schema sources the slug from `pageTitle`, and the Webflow post's URL carries 8 referring domains), and `fcfc319d-…` bundles four changes from three phases into one publish button. |
| 3 | `/contact` | Does it become a real page with a lead-capture form, or does the 301 to `/about` stand? |
| 4 | The CALA href (defect above) | Restore `https://ca.la`, and then keep the CALA logo, swap it for Mercer's, or drop the link and keep the logo? |
| 5 | Makelog and Bodeswell, now unlinked on the home page | Do they stay unlinked, come off the page, or get their links back? |
| 6 | Three titles over the tab's own ≤60 rule — E7 (61), E10 (62), E19 (61) | Shorten them, and to what? The overrun is in the auditor's copy, not the wiring. |
| 7 | `editorialTitle` on `hello-polymer` and `hiring-gen-z` | Do the H1 and `og:title` strings change too, and to what copy? |
| 8 | The "Keep reading" block on `/features/jobboard` | Does it stay? It reverts by deleting the block. |
| 9 | `/blog` now renders all 26 posts | Do you want server-rendered pagination (`/blog/page/2`), or does the full archive stand? |
| 10 | Related-posts ranking is lexical word overlap | Does `blogPost` get a `tags` or `relatedPosts` field? |
| 11 | `Organization.address` | The Wilmington registered-agent address from `/terms`, a Charlotte street address you supply, or omit the property? |
| 12 | `Article.author` (tab 05 C10, tab 13 E7) | Does it stay as the Polymer Organization, or do real bylines get added to the schema first? |
| 13 | `Article.dateModified` | Does it stay as Sanity's `_updatedAt`, accepting that a metadata-only publish moves it? |
| 14 | `Article.datePublished` has no time or timezone (Google reports both as optional issues) | Change `publishDate` from `date` to `datetime` and re-enter all 26 documents, or leave the two warnings standing? |
| 15 | `sameAs` | Does the Discord invite stay, and is `https://www.linkedin.com/company/withpolymer` the right company page? |
| 16 | Breadcrumbs on the 14 root-level routes | Flat two-item breadcrumb as well, or only where a real parent page exists? |
| 17 | `/pricing` emits `Product` while three pages emit `SoftwareApplication` | Should `/pricing` also emit `SoftwareApplication`, for one entity across all four pages? |
| 18 | Plato has no price of its own | Is Plato a separate product commercially, or part of Polymer? |
| 19 | The Offers lead with $124/$233/$415 | Confirm they lead with the annual monthly-equivalent rather than $149/$279/$499. |
| 20 | `llms-full.txt` (tab 08 row 12, optional) | Do you want one, and which pages should it cover? |
| 21 | `robots.txt` has no llms.txt pointer | Add a commented pointer? No standard directive exists. |
| 22 | `/changelog` is one sitemap entry, 85 entries on one page | Is one entry what tab 02 row 7 intends? |
| 23 | The seven industry rewrites still return 200 at both URLs | Convert to permanent redirects so only the short URL resolves? |
| 24 | `/404` emits a canonical to itself | Suppress it? |
| 25 | The homepage states its URL two ways — canonical with a trailing slash, `og:url` without | Move `og:url` to match? |
| 26 | The privacy policy displays `https://polymer.co/` while linking to www | Change the three displayed strings? Re-generating in Termly reverts both. |
| 27 | Two `og:image` URLs moved apex → www | Confirm they stay on www. If kept, both pages need re-scraping in the card debuggers after deploy. |
| 28 | `fm=webp` applied then reversed | Accept that a re-crawl reports all 79 image rows unchanged, or add `.format('webp')` back at ~86 kB more per image for real visitors? |
| 29 | `_next/image` quality is the default 75 | Lower it, and to what? Visual trade-off, needs a number. |
| 30 | Five wildcard CSP hosts | Keep them so the report week is not drowned in noise, or strike them and let the week name exact hosts? |
| 31 | No CSP report collector exists | Build `pages/api/csp-report.js` before the report week starts? |
| 32 | Four footer `<h2>` elements in every page's heading outline | Demote them site-wide? Tab 17 does not flag them. |
| 33 | Two posts skip heading levels (h1→h3, h1→h4) | Promote those body headings to h2? It would also give them a real first H2 and a table of contents. |
| 34 | Tab 10 row 7's premise is disproved | Do you agree the row is closed, or was there a rewrite beyond de-Wrk-ing? |
| 35 | One live post says "try Wrk for free" in three blocks | Swap "Wrk" for "Polymer"? Last reader-facing brand remnant. |
| 36 | Fourteen dated changelog entries name Wrk | Keep them as historical record? Rewriting makes the changelog claim Polymer shipped things it did not exist to ship. |
| 37 | Eight image `alt` strings say "Wrk"/"WRK" | Change them? Alt text is indexed and read aloud. |
| 38 | Eleven live `wrk.xyz` links costing a redirect hop, one printed as visible body text | Repoint now, or leave for the opportunistic pass tab 16 suggests? |
| 39 | The Crazy Egg credit, now unlinked plain text | Does the credit line stay under the screenshot? |
| 40 | 36 unreferenced Sanity assets, 37.1 MB | Scope an item to delete them, or not worth the risk? |
| 41 | Node version is a three-way mismatch — `.nvmrc` 18.x, `engines` 22.x, only 16.20.2 completed a build | Which is authoritative, and should the two be reconciled? |
| 42 | Tab 17 rows A16-A18 could not be done as written | Accept the sidebar-CTA demotion, or ask for something else? All three posts carry zero content `h2` blocks. |

### B. Credentials or access

| # | Item | Question |
|---|---|---|
| 43 | Search Console for `www.polymer.co` (tab 02 row 9) | Can I get access, or will you submit `https://www.polymer.co/sitemap.xml` yourself after deploy? Row 9's Current state is `unknown`, so whether the property exists is not established anywhere. |
| 44 | GTM container `GTM-N6H844WJ` tag list (tab 15) | Can you export it, or would you rather read the console reports during the week and hand over the hosts that appear? |
| 45 | The raw Screaming Frog crawl export | Can MakeReality send it? Tab 16 row 9 is the literal string `(52 external URLs)`, tab 11 note A4's "ALL 111 images lack width/height" is a count with no list, and eight tab 11 rows have a literal `...` in place of the URL. |

### C. Outside the repo entirely — Vercel, DNS, Search Console

| Item | Question |
|---|---|
| Apex `robots.txt` (tab 03 row 10) | Should `polymer.co/robots.txt` answer 200 instead of 308, and who changes the Vercel domain settings? The redirect fires at the platform edge before the Next app runs; there is no `vercel.json` under `web/` or at the repo root. |
| HSTS preload (tab 06 row 9 Notes) | Should `polymer.co` carry `includeSubDomains; preload` and go on the preload list? **This is the only open item that reaches the do-not-touch list** — `includeSubDomains` binds `app.polymer.co`, `developer.polymer.co`, `jobs.polymer.co` and `help.polymer.co` to HTTPS, and preload submission is slow to undo. `BLOCKED.md` line 71 says `web/next.config.js` has no `headers()` function; phase 6 added one at line 66, so that sentence is now stale. The conclusion stands — the header comes from the platform. |
| The apex redirect chain is two hops, not one | Collapse it? Tab 06 cell E9 assumes single-hop and says "No action"; `curl -sIL http://polymer.co/` reports 2 redirects. 59 backlinks and 445 referring domains traverse both. Vercel domain setting, no `BLOCKED.md` entry. |
| Search Console sitemap submission | See item 43. |
| `jobs.polymer.co` `JobPosting.datePosted` is `2026-06-03 16:36:07 UTC`, not ISO 8601, and `validThrough` is absent | Route to Shawn. The property does emit `JobPosting` with all five Google-required fields, as tab 05 cell D13 asked us to verify; these two defects live in the Rails job board, which is on the do-not-touch list. |
| `/plato`'s H1 is visually hidden (`QUESTIONS-FOR-SHAWN.md`, the whole file) | Shawn: is a visually-hidden H1 an acceptable trade, or does it need to be visible? Shipped with Jessica's approval; sign-off outstanding. |

---

## 5. The two issues no phase covered

The master prompt's Phase 1-6 assignments cover 15 of the 17 issues. Issues #9 and #13 are assigned to none of them. Both carry Implementation "Both" on the Overview tab — I19 "Both (content plan + technical grounding)", I23 "Both (Claude drafts, Polymer reviews)" — which is the same Overview cell C7 that says "14 of 17 fully automatable … 3 more with Polymer's input (content refresh sign-off, AI-visibility content plan)". Those are these two. Neither is in `BLOCKED.md`; #9 appears in none of the three human-facing files at all, so the one issue with no owner is also the one invisible to the file that exists to track what has no owner.

### #9 — AI search: zero ChatGPT presence, citations informational-only

**What the tab asks for.** Overview K19: "Execute the AEO tier of the keyword plan (definitional + cost + comparison content, answer-first formatting), plus items 2/3/5/8 which give AI engines crawlable, structured grounding." Tab 09 cell E12: "All informational; zero 'best ATS'-class prompts. The fix is the AEO tier + comparison pages, grounded by tabs 02/03/05/08."

**What the technical work contributes.** The grounding half — items 2, 3, 5 and 8 — is built and is the part of #9 that genuinely moved:

- `robots.txt` names GPTBot, ClaudeBot, PerplexityBot and Google-Extended individually with `Allow: /` — the direct AI-crawler lever, and the site currently has no robots.txt at all
- `sitemap.xml` gives 44 URLs a discovery path, including the ten previously orphaned posts
- `llms.txt` carries the product description, both pricing rates, canonical URLs and the ten guides
- JSON-LD gives every route an `Organization` and `WebSite` identity, the blog posts `Article`, and the pricing page real offers — validated in Google's Rich Results Test (result id `4AoIBbNXQYpnwZ2WqfrcRQ`: 6 valid items, 0 invalid, 0 errors) and against the schema.org vocabulary dump (149 properties, 0 unknown types, 0 unknown properties, 0 domain violations)

None of it is reachable by any AI crawler today, because nothing is deployed.

**What is not started.** The AEO tier itself — not partially, not scaffolded. `git diff --name-status main...seo-phase-7-final-report` adds nine files and the only one under `web/pages/` is `sitemap.xml.js`; `web/pages/compare/` does not exist. `FAQPage` is emitted on zero URLs, and the phase 5 survey found no visible Q&A set anywhere on the site, so tab 05 row A12 ("Comparison pages (planned `/compare/*`) — Article + FAQPage") is unactionable by construction rather than skipped.

**It also has a missing input.** K19 and K27 both cite "the keyword plan". That plan is not one of the workbook's 19 tabs and appears in none of the master prompt files — a full scan returns only those two Overview cells. Whoever picks #9 up starts by obtaining or writing it.

### #13 — Content freshness / E-E-A-T on traffic-driving posts

**What the tab asks for.** Nine posts in a traffic-weighted refresh order, tab 13 cells E7-E15, from row 1 `/blog/problem-solving-interview-questions` ("Update examples, add 2026 context + author byline + dateModified schema; keep URL") to row 9 `/blog/a-player` ("Merge candidates: could redirect into a broader hiring guide"). Note A4: "no update dates or author profiles are shown anywhere on the blog."

**Zero content changes to any of the nine, on any branch, published or draft.** None of the nine audit drafts is a tab-13 post. One is easy to misread: `drafts.5fd6bab5-…` is `/blog/talent-acquisition`, not tab 13 row 5's `/blog/talent-acquisition-vs-recruitment`. They are separate posts and both return 200.

**Three pieces of row 1's scope moved anyway.** The `dateModified` schema is emitted at template level on all 26 posts, from Sanity `_updatedAt` — with the caveat that `_updatedAt` moves on any write, so it is a modified-date signal, not evidence of a refresh. Eight of the nine posts (all but `/blog/onboarding`) are also tab-01 rows, so they moved from unreachable to two clicks from the homepage and each picks up 3-5 inbound related-post links. The author byline did not move and cannot: `studio/schemas/blogPost.js` has no author field, `studio/schemas/` has no author document type, and `web/pages/blog/[slug].js:380` still renders only `Posted on {date}`.

**Where it is recorded.** `BLOCKED.md`'s Phase 1 entry covers eight of the nine by URL, under the name "refresh the ten orphaned blog posts". Answering it does not close #13: `/blog/onboarding` is tab 13 row A14 and appears in neither tab 01, nor `BLOCKED.md`, nor `llms.txt`'s Guides list, so it is the one post no artefact of this engagement names. The other eight tab 13 rows are all tab 01 rows as well.

**The two are coupled.** Three of the four prompt clusters tab 09 cell B12 credits for Polymer's only 71 AI citations are tab-13 refresh rows: problem-solving interview questions (row 1), job rejection email sample (row 6), and interview rating scale, which is the rubric/scorecard cluster row 3 sits on. Tab 13 calls them decaying assets. The grounding work on these branches makes those same posts more crawlable, not more current.

---

## 6. The verification pass

Everything below runs **after** the six PRs merge and the site deploys. Nothing in it is meaningful before then.

### Re-crawl

Re-run Screaming Frog against the Overview tab's baseline — 363 URLs crawled, 33 internal HTML pages, 31 indexable 2xx, 2 apex 308s, starting at `https://polymer.co` to reproduce the original entry point. Expect: the 10 orphaned pages now reachable and no longer reported as orphans; 31 pages carrying a canonical where 0 did; 0 pages missing structured data where 31 did; `/contact` 301 rather than 404; 107 URLs carrying the four security headers.

Two things the re-crawl will report as unchanged, and both are properties of the tool rather than of the work. **Image bytes.** Tab 11's figures are inflated roughly 16x — the crawler sends no image `Accept` header, so it records PNG originals; across an 18-row sample, 39,251,301 crawl-reported bytes measure 2,443,805 in a browser. All 79 rows will re-report at their original sizes. **Image dimensions.** No `width`/`height` attributes were added, so tab 11 note A4's "ALL 111 images lack width/height" stands; the `sizes` props change which candidate is fetched, not whether dimensions are declared.

### Search Console

Submit `https://www.polymer.co/sitemap.xml` in the `www.polymer.co` property, then watch Index Coverage specifically for the ten previously-orphaned posts (tab 02 row 9). This needs access nobody on the engagement has — item 43 above.

One risk to watch in the coverage report: `web/pages/sitemap.xml.js` reads Sanity per request through `getServerSideProps`, while `web/pages/blog/[slug].js` uses `getStaticPaths` with `fallback: false` and `revalidate` appears nowhere in `web/pages`. A post published after the last deploy is emitted in the sitemap while its URL 404s until a rebuild, which Search Console reports as "Submitted URL not found (404)". Whether that can happen turns on whether Sanity fires a Vercel deploy hook on publish, which cannot be determined from the repo. This is recorded only at `SEO-CHANGELOG.md` line 3235 and in no other file.

### Schema validation

Re-run against the deployed pages rather than pasted snippets, one URL per template: `/` (SoftwareApplication), `/pricing` (Product), a `/blog/<slug>` (Article + BreadcrumbList), an `/applicant-tracking-for-*` page (Service + BreadcrumbList), and one plain page for `Organization` + `WebSite` alone.

- Google Rich Results Test — the code-snippet run returned 6 valid items, 0 invalid, 0 errors across all 8 blocks. Two optional-field issues will persist until the Sanity schema changes: `Invalid datetime value for "datePublished"` and `Datetime property "datePublished" is missing a timezone`, both because `publishDate` is declared `type: "date"`.
- **The schema.org Schema Markup Validator was never run.** `https://validator.schema.org` answered this machine with a 302 to a CAPTCHA and HTTP 429 on every attempt across two sessions and a 25-minute backoff. A vocabulary-level substitute was run against the schema.org JSON-LD dump and covers property existence and domain, but not value ranges — which is exactly where the two Google issues live. Completing it is one person, one paste, one CAPTCHA solve.
- Confirm the cross-block `@id` references still resolve once the blocks are on separate `<script>` tags in a live page: `Article.author` and `Article.publisher` point at `https://www.polymer.co/#organization`, which `web/pages/_app.js` emits in a different block.

### Security-header report week

Run the console walk against `next build` + `next start`, never `next dev` — the dev bundler's eval devtool violates `script-src` and the HMR websocket is not matched by `connect-src 'self'`. Two known gaps a local pass will miss: `lex.33across.com` fires only for US-non-California Safari visitors, and the Google Ads hosts only when a container tag fires. Define "clean" as clean apart from AdRoll's cookie-match `img-src` stream, which cannot go empty — `roundtrip.js` populates `cm_urls` from AdRoll's server response, not from any file in the repo. Only then change `Content-Security-Policy-Report-Only` to `Content-Security-Policy`; it is a one-word edit at `web/next.config.js:84`.

Also worth one DevTools pass at 1440px retina on `/`, `/blog`, a post, `/changelog` and `/features/candidate-management-software`, reading `currentSrc` on each responsive image: six of the nine `sizes` values are arithmetic only, and a wrong value fetches too small an image and looks soft, which no byte measurement catches.

### AI-visibility re-benchmark

Re-run the SE Ranking AI-search dataset against tab 09's July 2026 baseline, after a citation lag long enough for the crawl and grounding changes to land:

| Domain | AI Overview link citations | ChatGPT link citations |
|---|---|---|
| breezy.hr | 3,054 | 22 |
| recruitee.com | 1,369 | 10 |
| homerun.co | 888 | 0 |
| ashbyhq.com | 367 | 0 |
| **polymer.co** | **71** | **0** |

**Measure link citations, not brand mentions.** Tab 09 note A4: Polymer's 35,920 brand mentions "are inflated by the generic word 'polymer' (35,920 mentions are mostly chemistry) — link citations are the honest comparison." SE Ranking's 41% brand share-of-voice is inflated the same way. The honest number is 71, and on that measure Polymer is last of the five.

Set the expectation with the re-benchmark: issue #9's content half is not started, so the grounding work alone is being measured. Tab 09 cell E11 reads "Citations exist only where content exists: interview/HR posts. No category presence, no ChatGPT presence." Nothing on these six branches creates category content. Track separately whether Polymer's existing 71 citations hold or grow, and whether any 'best ATS'-class prompt starts citing the site — the second is what the AEO tier is for, and it has not been built.

---

## 7. Do-not-touch, honoured

The master prompt's Phase 7 do-not-touch list: `jobs.polymer.co` and its job-post templates, `app.polymer.co`, `developer.polymer.co`, billing/auth code, any customer data, DNS.

Evidence, from `git diff main...seo-phase-7-final-report` (38 files, 4,379 insertions, 90 deletions):

- **Every changed file is under `web/`, plus `SEO-CHANGELOG.md` and `BLOCKED.md` at the repo root.** `git diff --name-only main...HEAD | awk -F/ '{print $1}' | sort -u` returns exactly three entries: `BLOCKED.md`, `SEO-CHANGELOG.md`, `web`. The `studio/` directory — the Sanity Studio and its schemas — is untouched, so no schema field was added, removed or retyped.
- **`jobs.polymer.co`** — zero occurrences in the code diff. The only mentions are prose in `SEO-CHANGELOG.md`, recording that tab 05 row A13's verification was done read-only against the live product (`https://jobs.polymer.co/aboard/40210` was fetched, nothing was sent) and that tab 02 row 10 deliberately excludes the host from the sitemap. No job-post template exists in this repo; the job board is served by inflow-ats.
- **`app.polymer.co`** — one occurrence in the code diff, and it is a deletion of prose, not a change to the host: `web/pages/terms.js`'s meta description previously read "…located at polymer.co and app.polymer.co. Curious One, Inc. operates Polymer." and was replaced by the tab 12 D15 rewrite. Every `app.polymer.co` link in the repo — the three "Get started free" buttons on `/pricing` and the rest — is byte-identical to `main`.
- **`developer.polymer.co`** — one occurrence in the code diff, an added line in the new `web/public/llms.txt`: `- [Public API reference](https://developer.polymer.co): Documentation for Polymer's public API.` That is a link written into a new static file on this site. Nothing on that host was fetched with anything other than a GET, and nothing on it was changed.
- **Billing / auth code** — `git diff --name-only main...HEAD | grep -iE "auth|billing|stripe|payment"` returns nothing. The `/climate` redirect to `climate.stripe.com` in `web/next.config.js` is byte-identical to `main`; the phase 3 diff added a sibling entry below it and touched no existing line.
- **Customer data** — no customer data exists in this repo. Every Sanity write in the engagement was a `drafts.`-prefixed mutation on a `blogPost` or `changelog` document, and a dataset query for published documents with `_updatedAt > 2026-08-05T00:00:00Z` returns nothing. No id without a `drafts.` prefix was passed to a mutation; `.publish()` was never called.
- **DNS** — no DNS record was read for modification or changed. There is no `vercel.json` at the repo root or under `web/`, and none was created; `git diff --name-only main...HEAD | grep -iE "vercel|dns|domain"` returns nothing. Every DNS-adjacent finding in this report — the apex 308, the two-hop redirect chain, HSTS preload — is recorded as a question for a human with access to the Vercel domain settings, in section 4C above.

The one open item that reaches into do-not-touch territory is HSTS `includeSubDomains`, which would bind `app.polymer.co`, `developer.polymer.co`, `jobs.polymer.co` and `help.polymer.co` to HTTPS. It was not implemented; it is a question.
