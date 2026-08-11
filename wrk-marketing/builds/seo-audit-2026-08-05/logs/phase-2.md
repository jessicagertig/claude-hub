# Phase 2 log

## Item 3 — create llms.txt (2026-08-05)

### Tab rows read

**Tab 08 llms.txt** — all rows. A1 title `llms.txt (missing)`, A4 instruction note ("Verified 404 on both hosts. Recommended structure below - keep it accurate and short; wrong URLs or stale pricing in llms.txt is worse than none."), row 6 header, and the six content rows 7-12: `# Polymer`, `## Products`, `## Pricing`, `## Docs & API`, `## Guides`, `llms-full.txt`.

**Tab 01 Orphaned Pages** — all 10 data rows (7-16), used for the `## Guides` section in the tab's stated top-down priority order.

### Live-page verification performed before writing

Every factual claim in the file was sourced from a page fetched at execution time. Nothing came from memory or from the repo.

| Fetched | Result |
|---|---|
| `https://www.polymer.co/pricing` | 200. Rendered text: "Starter $ 124 / month", "Growth $ 233 / month" (Most Popular), "Scale $ 415 / month"; per-plan limits "Up to 5/20/50 published jobs", "Up to 5/20/50 users", "50/100/150 Plato AI credits per month"; billing toggle "Monthly / Annual / 2 months free!"; "You'll have unlimited time to explore Polymer and a 14-day free trial when you publish your first job."; "If you require more than 50 published jobs, custom integrations, or specialized workflows" → Contact Us → `mailto:support@polymer.co` |
| `https://www.polymer.co/terms` | 200. "Curious One, Inc. operates Polymer." — this is the live source for the entity name in the summary paragraph |
| `https://www.polymer.co/plato` | 200. meta description: "Plato, the AI reviewer in Polymer's applicant tracking system, scores job applications against your job criteria, so you review the best candidates first." H2s: "Reviewed the moment they apply", "Scored against your own criteria", "Anonymized before it's scored" |
| `https://www.polymer.co/features` | 200. H2s "Instant job board", "Distribution", "Candidate management", "Team collaboration" |
| `https://www.polymer.co/features/jobboard` | 200. meta: "No code job board software." Pricing page feature list supplied "Custom domain support", "Google Jobs integration", "LinkedIn Limited Listings", "We Work Remotely integration" |
| `https://www.polymer.co/features/candidate-management-software` | 200. H2s "A dashboard to run your hiring", "Rich candidate profiles", "Built-in candidate messaging"; pricing feature list supplied "Custom hiring workflows" |
| `https://www.polymer.co/applicant-tracking-for-startups` | 200. meta: "Purpose-built ATS for fast-growing startups." H1 "Simple hiring tools for growing teams" — source for the "purpose-built for startups and growing teams" clause |
| `https://developer.polymer.co` | 200. `<title>API Reference`, H1s "Introduction" / "Public API" |
| `https://help.polymer.co/` | 200. `<title>Home \| Polymer Help Center`, H1 "Advice and answers from the Polymer Team" |
| `https://help.polymer.co/en/collections/2544541-quick-start-guide` | 200. "A collection of short, to-the-point articles to get you up and running with the basics of Polymer" |
| `https://www.polymer.co/changelog` | 200. meta: "…the latest updates and improvements to Polymer." |
| All 10 Tab 01 blog URLs | all 200. H1 and meta description of each pulled live and used for the link text and one-line note |
| `https://docs.polymer.co` | DNS failure (curl exit code 000). Not used anywhere in the file |
| `https://www.polymer.co/llms.txt` | 404 — confirms the tab's "(missing)" status before the change |
| `https://www.polymer.co/robots.txt`, `/sitemap.xml` | both 404. Out of scope for this item; noted because llms.txt discoverability is usually assisted by a robots.txt reference |

**Pricing discrepancy check: none.** Live page matches the audit exactly — Starter $124/mo, Growth $233/mo, Scale $415/mo, 14-day free trial. No QUESTIONS entry needed on pricing.

Footer link hrefs were read off the live `/pricing` HTML rather than guessed: API → `https://developer.polymer.co`, Help docs → `https://help.polymer.co/`, Quick start guide → `https://help.polymer.co/en/collections/2544541-quick-start-guide`, Contact us → `mailto:support@polymer.co`.

Tab 08 note "Replace any legacy wrk.xyz references" — grepped `web/pages`, `web/components`, `web/lib`, `web/public` for `wrk.xyz`. Zero hits. Nothing to replace; no such reference introduced.

### File touched

`/Users/jessica/wrk/wrk-corp/wrk-marketing/web/public/llms.txt` — **created** (new file, 0 → 44 lines).

**Before:** file did not exist. `https://www.polymer.co/llms.txt` returned 404.

**After:** full contents of the new file —

```
# Polymer

> Polymer is an applicant tracking system with an instant branded job board and Plato, an AI reviewer that scores every application against your own job criteria. It is purpose-built for startups and growing teams rather than enterprise recruiting, and every plan includes the complete feature set. Polymer is operated by Curious One, Inc.

## Products

- [Features](https://www.polymer.co/features): Instant job board, distribution, candidate management and team collaboration in one applicant tracking system.
- [Job board software](https://www.polymer.co/features/jobboard): No-code branded job board with custom domain support, Google Jobs, LinkedIn Limited Listings and We Work Remotely distribution.
- [Candidate management software](https://www.polymer.co/features/candidate-management-software): Hiring dashboard, rich candidate profiles, built-in candidate messaging and custom hiring workflows.
- [Plato AI](https://www.polymer.co/plato): Reviews each application the moment it arrives, scores it against your own criteria, and anonymizes candidate details before scoring.
- [Pricing](https://www.polymer.co/pricing): Plan limits, the free trial, and the full feature list included on every plan.

## Pricing

https://www.polymer.co/pricing is the source of truth; check it before quoting these figures.

- Starter, $124/month: up to 5 published jobs, up to 5 users, 50 Plato AI credits per month.
- Growth, $233/month: up to 20 published jobs, up to 20 users, 100 Plato AI credits per month.
- Scale, $415/month: up to 50 published jobs, up to 50 users, 150 Plato AI credits per month.
- All features are included on every plan. Annual billing is 2 months free.
- Unlimited time to explore Polymer, plus a 14-day free trial when you publish your first job.
- For more than 50 published jobs, custom integrations or specialized workflows: support@polymer.co.

## Docs & API

- [Public API reference](https://developer.polymer.co): Documentation for Polymer's public API.
- [Help Center](https://help.polymer.co/): Advice and answers from the Polymer team.
- [Quick start guide](https://help.polymer.co/en/collections/2544541-quick-start-guide): Short articles to get up and running with the basics of Polymer.
- [Changelog](https://www.polymer.co/changelog): The latest updates and improvements to Polymer.

## Guides

- [How to Use Problem-Solving Interview Questions to Hire A-Players](https://www.polymer.co/blog/problem-solving-interview-questions): Ten problem-solving interview questions and how to use them to streamline interviews.
- [Behavioral Interview Scoring Matrix: A Template & Simple Guide](https://www.polymer.co/blog/behavioral-interview-scoring-matrix): A scoring matrix for a fair, unbiased interview evaluation.
- [A Definitive Guide to Employee Turnover and How to Reduce It](https://www.polymer.co/blog/employee-turnover): Why employee turnover matters and the strategies that reduce it.
- [Interview Feedback Examples: What to Say and How to Deliver It](https://www.polymer.co/blog/interview-feedback-examples): Eight interview feedback examples and when to use each one.
- [How to Write Personalized Job Rejection Emails](https://www.polymer.co/blog/job-rejection-email): Writing job rejection emails, with sample templates.
- [What is an A-Player? A Complete Guide on How to Source, Hire, & Retain Them](https://www.polymer.co/blog/a-player): Sourcing, hiring and retaining A-player talent.
- [What is an Agile Recruiting Process? 5 Steps to Implement](https://www.polymer.co/blog/agile-recruiting-process): What an agile recruiting process is and how to put one in place.
- [Talent Acquisition vs. Recruitment: What's the Difference?](https://www.polymer.co/blog/talent-acquisition-vs-recruitment): How talent acquisition and recruitment differ and how to use both.
- [How to Overcome (and Recognize) First Impression Bias When Hiring](https://www.polymer.co/blog/first-impression-bias): Identifying and overcoming first impression bias in hiring.
- [Best Job Board Software to Improve your Hiring Process](https://www.polymer.co/blog/best-job-board-software): Seven job board software platforms compared for sourcing new hires.
```

### Why `web/public/`

Next.js 12 serves `web/public/*` verbatim at the site root, so `web/public/llms.txt` is reachable at `https://www.polymer.co/llms.txt` with no route, no API handler and no config change. The existing static-root files in that directory — `site.webmanifest`, `browserconfig.xml`, `favicon.ico` — are the analogs. `web/.gitignore` does not exclude `public/`, so the file is tracked.

Link text for each `## Guides` entry is the live `<h1>` of that post, not the `<title>` tag, so the label matches what the page actually displays. The one-line note after each link is a condensed form of that page's live meta description.

### Check run

Extracted every URL from the written file and requested each one:

```
cd /Users/jessica/wrk/wrk-corp/wrk-marketing/web/public && grep -oE 'https://[^)[:space:]]+' llms.txt | sort -u | while read -r u; do printf "%s %s\n" "$(curl -s -o /dev/null -w '%{http_code}' -A 'Mozilla/5.0' -L "$u")" "$u"; done
```

All 19 distinct URLs returned 200. No URL was dropped — every URL the tabs called for resolved, so there is nothing to report under "dropped and logged".

### Not done, and why

- **`llms-full.txt`** — Tab 08 row 12 marks it "Optional second file". Not created. Logged as a question for Jessica rather than assumed; an extended page-level summary file would need per-page prose written from live fetches of every page on the site, which is a much larger item than this one.
- Nothing was committed, pushed, or branched. My working tree change is the one new untracked file above.

### Concurrent work in the same tree

At the time I fetched them, `https://www.polymer.co/robots.txt` and `/sitemap.xml` were both 404 live. By the time I finished writing, sibling agents had landed `web/public/robots.txt`, `web/pages/sitemap.xml.js`, and edits to `web/pages/blog.js` and `web/pages/blog/[slug].js` in this same tree. I touched none of them. The new `web/public/robots.txt` carries `Sitemap: https://www.polymer.co/sitemap.xml` and no llms.txt reference; there is no standard robots.txt directive for llms.txt, so I left it as the other item wrote it.

---

## Item 2 — create `web/public/robots.txt` (2026-08-05)

**This section is a reconstruction, written 2026-08-05 by the round-1 fix agent. The original implementer entry never appeared in this file.** Its sections went straight from "Item 3 — create llms.txt" to "Verification pass — Phase 2, item 2 (robots.txt)" to "Item 1 — create `web/pages/sitemap.xml.js`", with no Item 2 implementer entry between them. This is the same parallel read-then-write clobber `SEO-CHANGELOG.md` diagnoses for Phase 1 Item 1 — the workflow gave the Phase 2 agents this one log path and the later writer overwrote the earlier one's section. `SEO-CHANGELOG.md` line 543 records that defect as "the workflow gave both Phase 1 agents the same log file and both Phase 2/1 agents the same questions file"; it names the questions file for Phase 2, not this log, so this second lost entry is recorded nowhere else. Every fact below is taken from `git show seo-phase-1-2-deorphan-crawl:web/public/robots.txt`, `git log`, the `SEO-CHANGELOG.md` "Item 2 — robots.txt" section (lines 420-453), and a fresh read of tab `03 robots.txt`. Nothing the original implementer knew but did not put in the changelog is recoverable, and nothing has been invented to fill the gap.

### Tab rows read

**Tab 03 robots.txt** — rows 7-9 implemented, row 10 not implementable in-repo. Re-read from the workbook at reconstruction time:

- Row 7 `User-agent: *` / `Allow: /` / "No crawl restrictions needed on a 33-page marketing site"
- Row 8 `GPTBot / ClaudeBot / PerplexityBot / Google-Extended` / `Allow` / "AI-answer visibility is part of the growth strategy; blocking them contradicts the AEO plan"
- Row 9 `Sitemap:` / `https://www.polymer.co/sitemap.xml` / "Declare the new sitemap"
- Row 10 `Host handling` / `serve at both apex and www` / "Apex 308s to www; ensure robots.txt resolves pre-redirect too"

The tab is silent on `Crawl-delay`, `Disallow` and `Host`, so none were written.

### File touched

`/Users/jessica/wrk/wrk-corp/wrk-marketing/web/public/robots.txt` — **created** (new file, 0 → 16 lines, 203 bytes).

**URL affected:** `https://www.polymer.co/robots.txt` — 404 on both hosts before, served from `web/public/` after.

**Before:** the file did not exist. `git show main:web/public/robots.txt` → `fatal: path 'web/public/robots.txt' exists on disk, but not in 'main'`. A grep over `web` and `studio` found zero robots or sitemap references, so nothing was overwritten.

**After** — the complete new file, byte for byte as it stands on `seo-phase-1-2-deorphan-crawl` (commit `6229f91`):

```
User-agent: *
Allow: /

User-agent: GPTBot
Allow: /

User-agent: ClaudeBot
Allow: /

User-agent: PerplexityBot
Allow: /

User-agent: Google-Extended
Allow: /

Sitemap: https://www.polymer.co/sitemap.xml
```

ASCII, LF endings, trailing newline, no BOM (confirmed with `git cat-file -p … | od -c`).

### Why `web/public/`

Next.js 12 serves `web/public/*` verbatim at the site root, so the file needs no route, no build step and no config change. The existing static-root files in that directory — `site.webmanifest`, `browserconfig.xml` — are the analogs. The `Sitemap:` host matches `baseUrl` in `web/components/seo.js` line 12 and `BASE_URL` in `web/pages/sitemap.xml.js`.

### Not done

- **Tab row 10, host handling.** Not implementable as a repo change: `web/next.config.js` carries only the `/climate` redirect and the seven industry rewrites, and there is no `vercel.json` under `web/`. Whether `polymer.co/robots.txt` answers 200 pre-redirect or 308s to www is a Vercel domain setting. Raised as question 9 in `QUESTIONS-FOR-JESSICA.md`.
- **The apex/www question the implementer reported appending to `QUESTIONS-FOR-JESSICA.md`.** The verification pass below found it absent from that file — the same concurrent-write loss. It was later restored to `QUESTIONS-FOR-JESSICA.md` as question 9.

### Workbook misquote in the round-1 task packet

The tab reproduction handed to the round-1 agents truncates C8 to "AI-answer visibility is part of the growth strategy". The workbook cell reads "AI-answer visibility is part of the growth strategy; blocking them contradicts the AEO plan". The dropped clause does not change what the row asks for. All other tab 03 cells in the packet match the workbook.

---

## Verification pass — Phase 2, item 2 (robots.txt)

Verifier read tab `03 robots.txt` independently (all populated cells A1-C10), plus tabs `02 XML Sitemap`, `08 llms.txt` and `09 AI Visibility` to check for cross-tab robots requirements (none: tab 08 never asks robots.txt to reference llms.txt, tab 09 names no additional crawler tokens). Also re-read `master-prompt-pages-router.md` line 24.

Files read: `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/public/robots.txt`, `web/next.config.js`, `web/components/seo.js`, `web/package.json`, `web/pages/sitemap.xml.js`, `studio/vercel.json`, `logs/phase-2.md`, `QUESTIONS-FOR-JESSICA.md`.

Result: file contents match tab rows 7-9 exactly, byte for byte ASCII, LF endings, trailing newline, no BOM. Nothing fabricated — `https://www.polymer.co/sitemap.xml` matches tab B9, `BASE_URL` in `web/pages/sitemap.xml.js` and `baseUrl` in `web/components/seo.js` line 12. No tests or specs written. Repo scope limited to the one new file.

Two deferred checks resolved statically, no live check needed:
- `web/pages/sitemap.xml.js` now exists on this branch and emits at `/sitemap.xml` with the same host, so the `Sitemap:` line resolves in-repo.
- Repo root has no `package.json` (only `web/package.json` and `studio/package.json`, and `studio/` carries its own `vercel.json`), so the marketing Vercel project root must be `web/` — `web/public/robots.txt` therefore serves at `/robots.txt`. `next.config.js` sets no `basePath` or `assetPrefix` and no route named `robots` exists to shadow it.

Row 10 confirmed not implementable in-repo: `next.config.js` carries only the `/climate` redirect and 7 industry rewrites, and there is no `vercel.json` under `web/`.

Discrepancy found: the implementer's report lists `QUESTIONS-FOR-JESSICA.md` as touched and states a question was appended about apex/www host handling. That file (mtime 19:18, later than `robots.txt` at 19:15) contains only the llms.txt agent's two questions. The robots.txt question is absent — concurrent-write loss or never written. Not repaired by the verifier; reported instead.

---

## Item 1 — create `web/pages/sitemap.xml.js` (2026-08-05)

### Tab rows read

**Tab 02 XML Sitemap** — all four data rows (7-10), plus the A1 title band, the A2 branding band, and the A4 instruction note. Read via the tab payload supplied in my task, which reproduces every cell A1-C10.

- Row 7 `sitemap.xml` / "404 on both hosts" / "Add app/sitemap.ts emitting all marketing routes + every Sanity blog post with lastModified from CMS timestamps"
- Row 8 `Sitemap scope` / n/a / "www host only, absolute HTTPS URLs; exclude app.polymer.co and developer.polymer.co (separate products)"
- Row 9 `Search Console` / unknown / "Submit sitemap; monitor Index Coverage for the 10 currently-orphaned posts"
- Row 10 `jobs.polymer.co` / "customer job boards, separate host" / "Out of scope for this sitemap"

**Workbook contradiction, resolved as instructed by the task.** A4 says "Spec below for a Next.js app-router implementation" and C7 says "Add app/sitemap.ts". This repo is Next.js 12.1.0 Pages Router — `web/package.json` pins `"next": "12.1.0"`, there is no `web/app/` directory, and no Metadata API exists in that version. Implemented as the Pages Router equivalent: `web/pages/sitemap.xml.js`, a page component that renders `null` with `getServerSideProps` writing the XML directly to `res`. Route and output are identical (`/sitemap.xml`, `Content-Type: text/xml`); only the file location differs from what C7 names.

**Rows 9 and 10 need no code.** Row 9 (Search Console submission) is an action outside the repo. Row 10 (`jobs.polymer.co`) is a separate host and is not emitted. Row 8's exclusions (`app.polymer.co`, `developer.polymer.co`) are likewise not emitted — nothing in `web/pages` maps to either host.

### Analogs read before writing

`web/pages/blog.js`, `web/pages/blog/[slug].js`, `web/pages/changelog.js` (the three named analogs), plus `web/lib/sanity.js`, `web/components/seo.js`, `web/next.config.js`, `web/components/footer.js`, `web/.babelrc`, `web/package.json`, `studio/schemas/blogPost.js`, `studio/schemas/changelog.js`.

Idioms taken from them: `import sanity from "../lib/sanity"` and `sanity.fetch(query)` with the GROQ string held in a module-level `const query` (blog.js line 17, changelog.js line 14); data-fetching export placed after the component and `export default` last (blog.js lines 90-99, changelog.js lines 88-95); optional chaining, already used in blog.js line 58 (`posts?.length`). No `Styled = {}` object — this page renders nothing, so it has no styles.

### Route list — how it was derived

Walked `web/pages` (`find web/pages -type f`), then cross-checked every route against the `pathname` prop each page passes to `components/seo.js`, which is the site's own declaration of its canonical URL (`seo.js` line 13 builds `https://www.polymer.co/${pathname}` and the file carries the comment "No trailing slash allowed!").

Files found and how each was treated:

| File | Treatment |
|---|---|
| `pages/index.js` | emitted as `https://www.polymer.co` (seo.js emits the bare base URL when `pathname` is absent) |
| `pages/about.js` | emitted, `about` |
| `pages/blog.js` | emitted, `blog` |
| `pages/changelog.js` | emitted, `changelog` |
| `pages/features.js` | emitted, `features` |
| `pages/features/candidate-management-software.js` | emitted, `features/candidate-management-software` |
| `pages/features/jobboard.js` | emitted, `features/jobboard` |
| `pages/industries/*.js` (7 files) | emitted under their **top-level rewrite source**, not `industries/…` — see below |
| `pages/plato.js` | emitted, `plato` |
| `pages/pricing.js` | emitted, `pricing` |
| `pages/privacy.js` | emitted, `privacy` |
| `pages/terms.js` | emitted, `terms` |
| `pages/blog/[slug].js` | **not** a static entry; enumerated per-post from Sanity |
| `pages/api/hello.js` | **excluded** — API route, task says exclude `pages/api` |
| `pages/404.js` | **excluded** — error page, task says exclude |
| `pages/_app.js` | **excluded** — not a route |
| `pages/sitemap.xml.js` | **excluded** — the sitemap does not list itself |

### How the `next.config.js` rewrites were treated (explicitly requested)

`web/next.config.js` lines 21-52 declare seven rewrites, each mapping a top-level source to an `/industries/…` destination, e.g. `source: '/applicant-tracking-for-startups'` → `destination: '/industries/applicant-tracking-for-startups'`.

**Decision: the sitemap lists the rewrite SOURCE (short top-level path) for all seven, and never lists `/industries/…`.** Two pieces of evidence in the repo, not a guess:

1. `web/components/footer.js` lines 117-147 link all seven with the short form — `<Link href="/applicant-tracking-for-startups">`, `<Link href="/applicant-tracking-for-legal-services">`, and so on. The site's own internal linking uses the short URL exclusively; `grep -rn "applicant-tracking-for" components/ pages/` returns no internal link to any `/industries/…` URL.
2. Six of the seven industry pages declare the short form as their own `og:url` via the SEO `pathname` prop: `pathname="applicant-tracking-for-startups"`, `"applicant-tracking-for-cryptocurrency-companies"`, `"applicant-tracking-for-fintech-companies"`, `"applicant-tracking-for-greentech-companies"`, `"applicant-tracking-for-healthcare-companies"`, `"applicant-tracking-for-real-estate-companies"`.

The seventh, `pages/industries/applicant-tracking-for-legal-services.js` line 90, declares `pathname="industries/applicant-tracking-for-legal-services"` — the long form, disagreeing with its six siblings and with the footer link that points at it. I did **not** change that page: this item is the sitemap, and editing another page's SEO props is outside its scope. The sitemap emits the short form for legal-services along with the other six, matching the footer. Logged as a question for Jessica.

Note for whoever handles canonicals: rewrites do not block the destination path, so both URL forms are live. Verified against the dev server — `/applicant-tracking-for-legal-services` → 200 and `/industries/applicant-tracking-for-legal-services` → 200. `web/components/seo.js` emits no `<link rel="canonical">` at all (only `og:url`), so nothing currently tells a crawler which of the two pairs is canonical. Out of scope here; raised as a question.

The `/climate` redirect (`next.config.js` lines 12-20) is an external redirect to `https://climate.stripe.com/Cg9EBK`, not a page. Not emitted.

### Sanity content — what is emitted and why

Query used (single fetch, both branches in one round trip):

```
{
  "posts": *[_type == "blogPost"]{ "slug": slug.current, _updatedAt } | order(_updatedAt desc),
  "changelogUpdatedAt": *[_type == "changelog"] | order(_updatedAt desc)[0]._updatedAt
}
```

The `posts` filter `*[_type == "blogPost"]` is byte-identical to the filter in `pages/blog/[slug].js` `getStaticPaths` (line 256: `*[_type == "blogPost"]{ slug }`). That is deliberate — the sitemap then contains exactly the set of blog URLs that Next.js pre-renders, no more and no less. `getStaticPaths` uses `fallback: false`, so any extra URL would be a 404 in the sitemap.

**Changelog entries have no per-entry URL.** `studio/schemas/changelog.js` defines the type with exactly two fields, `date` and `content` — there is no slug field, and `pages/changelog.js` renders every entry on the single `/changelog` page with an in-page anchor (`<a href={"#" + log.date} id={log.date}>`, line 68). Fragment URLs are not sitemap entries. So the 85 changelog documents produce **one** URL, `https://www.polymer.co/changelog`, whose `<lastmod>` is the newest `_updatedAt` across all changelog documents. That is the honest reading of the tab's "lastModified from CMS timestamps" for this content type.

Verified against the live public Sanity read API (read-only GET, no token, same `production` dataset the site uses): 26 `blogPost` documents, all with a non-null `slug.current`; 85 `changelog` documents, all with `slug` null; `_updatedAt` present on every document.

### `<lastmod>` policy — no fabricated dates

- `/blog/<slug>` → that post's `_updatedAt`.
- `/blog` → the newest `_updatedAt` across `blogPost` (the index's content is exactly those posts).
- `/changelog` → the newest `_updatedAt` across `changelog`.
- **Every other route → no `<lastmod>` element at all.** Those pages ship with the code and have no CMS timestamp. `<lastmod>` is optional in the sitemap protocol, and emitting a build timestamp or today's date for eighteen hand-written pages would be inventing data. Omitted rather than faked.

`_updatedAt` is already a W3C datetime (`2026-05-21T19:43:53Z`) and is passed straight through with no reformatting.

### File touched

`/Users/jessica/wrk/wrk-corp/wrk-marketing/web/pages/sitemap.xml.js`

**Before:** the file did not exist. `/sitemap.xml` 404'd, exactly as tab row 7 states. Nothing at `web/public/sitemap.xml` either.

**After** — the complete new file, 2155 bytes:

```js
import sanity from "../lib/sanity";

const BASE_URL = "https://www.polymer.co";

// Every static marketing route, written the way the site's own SEO component
// declares it in `pathname`. The industries pages appear under their top-level
// rewrite source (see the rewrites in next.config.js) because that is the URL
// the footer links to. New pages need a line here.
const staticRoutes = [
  "",
  "about",
  "blog",
  "changelog",
  "features",
  "features/candidate-management-software",
  "features/jobboard",
  "applicant-tracking-for-cryptocurrency-companies",
  "applicant-tracking-for-fintech-companies",
  "applicant-tracking-for-greentech-companies",
  "applicant-tracking-for-healthcare-companies",
  "applicant-tracking-for-legal-services",
  "applicant-tracking-for-real-estate-companies",
  "applicant-tracking-for-startups",
  "plato",
  "pricing",
  "privacy",
  "terms",
];

const query = `{
  "posts": *[_type == "blogPost"]{ "slug": slug.current, _updatedAt } | order(_updatedAt desc),
  "changelogUpdatedAt": *[_type == "changelog"] | order(_updatedAt desc)[0]._updatedAt
}`;

const urlEntry = (pathname, lastmod) => `  <url>
    <loc>${pathname ? `${BASE_URL}/${pathname}` : BASE_URL}</loc>${lastmod ? `
    <lastmod>${lastmod}</lastmod>` : ""}
  </url>`;

const Sitemap = () => null;

export const getServerSideProps = async ({ res }) => {
  const { posts, changelogUpdatedAt } = await sanity.fetch(query);

  // Only the two CMS-driven index pages have an honest last-modified date. The
  // rest ship with the code, so they carry no lastmod rather than a made-up one.
  const lastmodByRoute = {
    blog: posts[0]?._updatedAt,
    changelog: changelogUpdatedAt,
  };

  const urls = [
    ...staticRoutes.map((pathname) => urlEntry(pathname, lastmodByRoute[pathname])),
    ...posts.map((post) => urlEntry(`blog/${encodeURIComponent(post.slug)}`, post._updatedAt)),
  ];

  res.setHeader("Content-Type", "text/xml");
  res.write(`<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.join("\n")}
</urlset>
`);
  res.end();

  return { props: {} };
};

export default Sitemap;
```

No other file in the repo was modified. `web/pages/blog.js` and `web/pages/blog/[slug].js` show as modified in `git status` — those are a sibling agent's de-orphaning edits, not mine. I read them to confirm nothing there changes blog slugs or routes; it does not (the blog.js change removes the "Load more" pagination so the index renders every post).

### Design choices worth naming

**Static route list is an explicit array, not a runtime directory walk.** The task said to walk `web/pages`; I walked it to *derive* the list, then wrote the result as a literal array rather than calling `fs.readdirSync` at request time. Reasons: (a) the pages source directory is not guaranteed to be present in a deployed serverless function bundle, so an fs walk can silently return an empty sitemap in production while working locally; (b) a walk cannot produce the industries mapping anyway — that comes from `next.config.js` rewrites, not from the filesystem — so it would still need a hand-maintained exception table and would save nothing. The array carries a comment saying new pages need a line here. Next.js 12 exposes no supported runtime API for enumerating routes.

**`encodeURIComponent` on the blog slug.** Slugs come from the CMS, and a `&` in a slug would make the whole sitemap invalid XML rather than break one entry. One stdlib call at the boundary; static routes are hardcoded and need none.

### Verification performed

Ran the real dev server rather than reasoning about the output. `npx` is not on PATH in this shell; used `/Users/jessica/.nvm/versions/node/v18.20.8/bin/node node_modules/next/dist/bin/next dev -p 3111` (port 3111 chosen to stay clear of Jessica's own long-running `next dev` on the default port — that process, pid 16054, was untouched, and my server was stopped afterwards by port lookup, leaving port 3111 free).

- `GET /sitemap.xml` → `HTTP/1.1 200 OK`, `Content-Type: text/xml`
- Parses as XML (`xml.etree.ElementTree`), 44 `<url>` elements = 18 static + 26 blog posts
- 28 `<lastmod>` elements = 26 posts + `/blog` + `/changelog`, matching the policy above
- Zero duplicate `<loc>` values; every `<loc>` starts `https://www.polymer.co`; no trailing slashes
- Spot-checked live: `/blog/hiring-gen-z` 200, `/applicant-tracking-for-startups` 200, `/applicant-tracking-for-legal-services` 200, `/plato` 200
- `node node_modules/eslint/bin/eslint.js pages/sitemap.xml.js` → clean, no warnings

First 4 and last 1 entries of the emitted document:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://www.polymer.co</loc>
  </url>
  <url>
    <loc>https://www.polymer.co/about</loc>
  </url>
  <url>
    <loc>https://www.polymer.co/blog</loc>
    <lastmod>2026-05-21T19:43:53Z</lastmod>
  </url>
  <url>
    <loc>https://www.polymer.co/changelog</loc>
    <lastmod>2026-02-03T00:47:51Z</lastmod>
  </url>
  …
  <url>
    <loc>https://www.polymer.co/blog/five-things-a-startup-should-keep-in-mind-when-hiring</loc>
    <lastmod>2022-05-14T19:57:57Z</lastmod>
  </url>
</urlset>
```

### Consistent with the sibling robots.txt item

`web/public/robots.txt` (landed by another agent at 19:15) ends with `Sitemap: https://www.polymer.co/sitemap.xml`. That URL is exactly what this page serves — same host, same path, no trailing slash. No coordination needed and that file was not touched.

### Could not do / not done

- **Tab row 9, Search Console submission and Index Coverage monitoring.** Outside the repo entirely; nothing to implement. Not attempted.
- **`<changefreq>` and `<priority>`.** Not requested by any tab row and ignored by Google. Not emitted.
- **Cache-Control on the response.** Not added. Each request re-queries Sanity, which is fine at sitemap fetch rates; adding a cache header would be speculative tuning.
- **The legal-services `pathname` inconsistency** described above. Deliberately left alone — out of this item's scope. Question raised.
- **Nothing committed, branched, or pushed.** One new untracked file.
- **No tests and no specs written**, per the task rules.
