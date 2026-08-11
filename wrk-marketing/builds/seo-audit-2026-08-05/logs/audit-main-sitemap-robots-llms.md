# Audit of `main` — area: sitemap-robots-llms

Read-only pass. Diff base `01bf615` ("Merge pull request #46 from wrk-corp/plato-landing-page") against `origin/main`.
Nothing was changed in the repo by this pass.

## Scope confirmed

```
web/pages/sitemap.xml.js   93 +   absent at 01bf615
web/public/robots.txt      16 +   absent at 01bf615
web/public/llms.txt        42 +   absent at 01bf615
web/public/llms-full.txt  287 +   absent at 01bf615
```

All four files are new. No pre-existing file in this area was modified, so nothing in this area can be
"unauthorised" in the sense of overwriting work that predates the engagement.

Commits that produced them, oldest first:

| Commit | What it did here |
|---|---|
| `6229f91` De-orphan the blog and add crawl infrastructure | created all three of `sitemap.xml.js`, `robots.txt`, `llms.txt` |
| `05eed5c` Close the gaps the phase 1+2 review found | rewrote the sitemap query, added `Cache-Control`, reordered the `llms.txt` pricing bullets |
| `5aed26f` Paginate the blog with real URLs instead of a Load more button | sitemap gains `/blog/page/2` … `/blog/page/6` |
| `753a3c4` Publish llms-full.txt | created `llms-full.txt`, 287 lines, no changelog entry |

## Cells read

Overview K12, K13, K18 (the "Recommended fix" column), then tabs `02 XML Sitemap` rows 7-10,
`03 robots.txt` rows 7-10, `08 llms.txt` rows 7-12 including note A4. Master prompt Phase 2 steps 1-3
and rules 4 and 6.

Verbatim, the cells that define the terms:

- **02 C7** — "Add app/sitemap.ts emitting all marketing routes + every Sanity blog post with lastModified from CMS timestamps"
- **02 C8** — "www host only, absolute HTTPS URLs; exclude app.polymer.co and developer.polymer.co (separate products)"
- **03 B7/C7** — "Allow: /" | "No crawl restrictions needed on a 33-page marketing site"
- **03 A8/B8** — "GPTBot / ClaudeBot / PerplexityBot / Google-Extended" | "Allow"
- **03 B9** — "https://www.polymer.co/sitemap.xml"
- **08 B7** — "One-paragraph definition: applicant tracking system with instant branded job boards, AI candidate review (Plato), built for startups/SMBs; by Curious One, Inc."
- **08 B8** — "Links: /features, /features/jobboard, /features/candidate-management-software, /plato, /pricing"
- **08 B9/C9** — "Starter $124/mo, Growth $233/mo, Scale $415/mo, 14-day free trial" | "Keep in sync with /pricing"
- **08 B10/C10** — "developer.polymer.co, help docs URL" | "Replace any legacy wrk.xyz references"
- **08 B11** — "Top 8-10 evergreen posts (turnover, scoring matrix, problem-solving questions...)"
- **08 B12/C12** — "Extended page-level summaries" | "Optional second file"
- **Master prompt rule 4** — "Append every change (file, URL affected, before → after) to `SEO-CHANGELOG.md` in the repo."

---

## robots.txt — clean

Six directives, in this order: `User-agent: *` / `Allow: /`, then one two-line group each for `GPTBot`,
`ClaudeBot`, `PerplexityBot` and `Google-Extended`, then
`Sitemap: https://www.polymer.co/sitemap.xml`.

Row 7 gives the wildcard group, row 8 gives the four AI crawlers as explicit allows, row 9 gives the
`Sitemap:` line and its exact value. Nothing else is in the file: no `Disallow`, no `Crawl-delay`, no
`Host`, no comment, no `llms.txt` pointer. The four AI-crawler groups are technically redundant under
`User-agent: *` `Allow: /`, but row 8 asks for them explicitly and "explicitly including" is the
Overview K13 wording too, so the redundancy is what was ordered.

Row 10 ("Host handling", apex-and-www pre-redirect) is a Vercel domain setting with no repo surface.
It was correctly left undone and correctly recorded as a question.

**Verdict: fully authorised, nothing to remove.** This is the only file in the area with no findings.

---

## sitemap.xml.js

### Authorised

- **The 18 static routes and the 26 post URLs.** C7 "all marketing routes + every Sanity blog post".
- **www host, absolute HTTPS, `BASE_URL = "https://www.polymer.co"`.** C8. `app.polymer.co`,
  `developer.polymer.co` and `jobs.polymer.co` appear nowhere in the output; row 10 puts
  `jobs.polymer.co` out of scope and it is not emitted.
- **`<lastmod>` from `_updatedAt`** on each post and on the two CMS-driven index routes. C7
  "lastModified from CMS timestamps". The 16 code-driven routes carry no `lastmod` rather than a
  fabricated one, which is the "no more than asked" choice.
- **`/blog/page/2` … `/blog/page/6`.** Overview K11: "Add full blog pagination/archive to /blog, add
  related-post links from crawlable posts, and include every post in the new XML sitemap." The
  pagination shape is Jessica's own 2026-08-06 decision, and once those routes exist they are
  marketing routes under C7. Omitting them would be the defect.
- **File at `web/pages/sitemap.xml.js` rather than `app/sitemap.ts`.** C7 and Overview K12 both name
  `app/sitemap.ts`, but master prompt Phase 2 step 1 names `pages/sitemap.xml.js` outright. Source 2
  settles it; this is not a deviation.
- **The `logsQuery` for `/changelog`'s `lastmod`.** `changelog` is a Sanity document type, so that
  value is a CMS timestamp under C7.

### Exceeds — `Cache-Control`

```js
res.setHeader("Cache-Control", "public, s-maxage=3600, stale-while-revalidate=86400");
```

No cell in tab 02 mentions response caching. Neither does Overview K12 ("Generate a sitemap.xml from
the Next.js app (app/sitemap.ts) covering all marketing pages + blog posts; submit in Search
Console") nor master prompt Phase 2 step 1 ("emit every marketing route + every Sanity post,
lastModified from CMS timestamps, www host, absolute HTTPS URLs").

The original run got this right and then it was reversed. `logs/phase-2.md:419`:

> **Cache-Control on the response.** Not added. Each request re-queries Sanity, which is fine at
> sitemap fetch rates; adding a cache header would be speculative tuning.

A later fix round added it, and `REVIEW-phase-1-2.md:347` files the change under cell `02 A7`:

> | 02 A7 | `/sitemap.xml` with no `Cache-Control` → `public, s-maxage=3600, stale-while-revalidate=86400` |

Row A7 of tab 02 is the string "sitemap.xml". It says nothing about caching. This is the exact shape
this round exists to catch: an agent-invented review finding attributed to a cell that does not
contain it, overruling the run's own correct judgment that it was speculative tuning.

**Removable:** one line. Pre-engagement version: the file did not exist, so the honest "before" is
the `6229f91` version of this file, which set only `Content-Type`.

---

## llms.txt

### Authorised

- `# Polymer` plus the blockquote definition — row 7, near verbatim including "by Curious One, Inc."
- `## Products` — exactly the five links row 8 names, absolute www URLs, correct casing (K18).
- `## Guides` — the ten tab-01 orphaned posts, which is row 11's "Top 8-10 evergreen posts" at the top
  of its range and row 11 C's "The same assets being de-orphaned".
- The dual annual/monthly rates in `## Pricing`. Row 9 B names only $124/$233/$415, but row 9 C says
  "Keep in sync with /pricing" and note A4 says stale pricing "is worse than none"; `pricing.js`
  carries both rate sets and `isAnnual` defaults true. Stating both is what keeping in sync means.

### Exceeds — `## Docs & API` carries four links where the cell names two

Row 10 B: "developer.polymer.co, help docs URL". The file adds two more bullets:

- `[Quick start guide](https://help.polymer.co/en/collections/2544541-quick-start-guide)`
- `[Changelog](https://www.polymer.co/changelog)`

The quick-start collection is a second help URL where the cell asks for one. `/changelog` is a
marketing page and is neither docs nor API.

**Removable:** two bullets.

### Exceeds — `## Pricing` carries plan caps and a sales address the cell does not name

Row 9 B is a literal contents list: "Starter $124/mo, Growth $233/mo, Scale $415/mo, 14-day free
trial". Beyond those four items the section states per-plan published-job caps, per-plan user caps,
per-plan monthly Plato AI credit allowances, "All features are included on every plan", "Annual
billing is 2 months free, which is the discount shown above", and "For more than 50 published jobs,
custom integrations or specialized workflows: support@polymer.co".

This is the weakest finding in the area. None of it is wrong, and Overview K18's "describing Polymer,
pricing, features and canonical URLs" is broad enough to read the caps as "features". Flagged rather
than asserted, because row 9 B does read as a contents spec and the caps are not in it.

**Removable:** the three cap clauses and the support@ bullet, if she wants the section to match the
cell literally.

---

## llms-full.txt

Its existence is authorised — tab 08 row 12 plus Overview K18 "Publish /llms.txt (and llms-full.txt)".
Its scope is not. Row 12 B is three words: "Extended page-level summaries". Which pages is set by the
rest of the tab, and llms.txt is the file that lists them: 19 URLs. `llms-full.txt` covers 37.

Two process facts frame everything below.

1. `QUESTIONS-FOR-JESSICA.md`, "Phase 2, item 3 — llms.txt", question 1 asked exactly the right
   question and is **still unanswered on disk**: "Tab 08 row 12 lists `llms-full.txt` ('Extended
   page-level summaries') as an optional second file. I did not create it. Do you want one, and if so
   which pages should it cover?" The file was then built anyway. Commit `753a3c4`'s message answers
   the cell's word "Optional" with "Nothing in the audit is optional," and answers "which pages"
   with 37 of them.
2. Commit `753a3c4` touched `SEO-CHANGELOG.md` not at all. Master prompt rule 4 requires every change
   appended there with file, URL affected and before → after. 287 lines of new public content have no
   record. Worse, `SEO-CHANGELOG.md:740` on `origin/main` still reads "`llms-full.txt` (tab 08 row 12,
   marked optional) was not created" — false against the same commit that is in the tree with it.

### Exceeds — the whole `## Industries` section, lines 85-129

Seven `###` entries, one per vertical page. No row in tab 08 names an industries section or any
industry page; row 8's Products list is five URLs and none of them is a vertical. Each entry runs
150-250 words of challenges, feature blocks, benefits and integrations.

**Removable:** delete lines 85-129.

### Exceeds — the whole `## Company` section, lines 131-163

`/about`, `/terms`, `/privacy`. No cell names any of the three.

This is the finding I would raise first regardless of scope. The `/terms` entry (lines 139-149) is an
agent-written paraphrase of the terms of service running roughly 1,200 words, and it asserts specifics:
a 7-day refund window, a 30-day window for billing disputes, binding individual arbitration under AAA
rules in Delaware, a class-action waiver with a 30-day written opt-out, liability capped at twelve
months of fees "or a maximum of $100 for free-plan users". The `/privacy` entry (lines 151-163) does
the same for the privacy policy, including CCPA category claims and a fifteen-day opt-out response
commitment. Published at `/llms-full.txt`, that is Polymer stating its legal terms in a
machine-readable file that AI assistants will quote, in wording no lawyer wrote and no cell requested.

**Removable:** delete lines 131-163.

### Exceeds — six help centre collections beyond the one help docs URL, lines 181-238

Row 10 B names two URLs: "developer.polymer.co, help docs URL". Under `## Docs & API` the file
carries nine `###` entries. Three are arguably in scope (Public API reference, Help Center, and the
Quick start guide already carried in llms.txt). The other six are whole collection summaries — Job
board configuration, Team management, Job management, Candidate management, Integrations,
Subscription management — with operational detail no cell asks for: the CNAME target
`jobs-proxy.polymer.co`, the `_acme-challenge.<subdomain>` TXT record, the Cloudflare
proxied-CNAME "Too many redirects" workaround, the Zapier API-key screen, the exact 16-column CSV
export header list, and the irreversible candidate data-deletion mechanics.

**Removable:** delete lines 181-238.

### Exceeds — the auditor's own commentary published as page content

Row 12 asks for summaries of pages. Three passages summarise nothing on a page; they are notes about
the page, written during the audit and shipped:

- line 173 — "Note that some help centre billing articles describe a per-job pricing model, which does
  not match the plans on the pricing page; https://www.polymer.co/pricing is the source of truth for
  pricing, and the pricing section above matches it." This publishes, machine-readably, that Polymer's
  own help centre contradicts its own pricing page.
- line 117 — "The page describes supporting credentialing and compliance documentation; it does not
  claim any certification."
- line 83 — "Note that the numeric caps are on published jobs and users; unlimited candidates is one of
  the Candidate Management feature-list items."

**Removable:** three sentences.

### Not flagged

The `/` homepage entry (lines 9-21) and the `/blog` index entry (lines 245-247) are additions llms.txt
does not carry and no row names, but a long-form file about Polymer that omits polymer.co itself would
be the stranger artifact. Recorded, not proposed for removal.

`## Products`, `## Pricing` and `## Guides` mirror llms.txt one for one and carry the same facts, which
is what row 12's "long form" means. Authorised.

---

## SEO-CHANGELOG.md, for these three items

Master prompt rule 4 asks for three things per change: file, URL affected, before → after. The Phase 2
section (lines 518-740) plus these items' Open-items entries (lines 796-814) run roughly 240 lines and
carry considerably more: preserved verifier findings with their own corrections layered on top,
provenance essays about which build a count came from, a "Where this file lives" section debating
whether the changelog belongs in the repo at all, and a `BLOCKED.md` section explaining why
`BLOCKED.md` was never written.

Two concrete defects inside it, both in my area:

- Line 740 states `llms-full.txt` "was not created". It exists on `origin/main`.
- No entry of any kind exists for `llms-full.txt` — no file line, no URL, no before → after.

The entries for `sitemap.xml.js`, `robots.txt` and `llms.txt` themselves are accurate against the code,
including the record that the `6229f91` code block shown for the sitemap is superseded by the working
tree.

---

## Summary

| File | Authorised | Exceeds | Unauthorised |
|---|---|---|---|
| `web/public/robots.txt` | all of it | — | — |
| `web/pages/sitemap.xml.js` | routes, host, lastmod, page URLs, file location | `Cache-Control` line | — |
| `web/public/llms.txt` | H1, Products, Guides, dual rates | 2 extra Docs & API bullets; Pricing caps + support@ | — |
| `web/public/llms-full.txt` | existing; Products/Pricing/Guides | Industries, Company, 6 help collections, 3 commentary passages | — |
| `SEO-CHANGELOG.md` (these items) | the three item entries | ~240 lines past "file, URL, before → after"; stale line 740; missing llms-full entry | — |

Nothing in this area overwrote pre-engagement code — every file is new since `01bf615`.
