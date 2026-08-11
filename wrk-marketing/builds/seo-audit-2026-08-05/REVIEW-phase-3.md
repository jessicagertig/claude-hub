# Phase 3 review — redirects and canonicals (PR #48)

Branch `seo-phase-3-redirects-canonicals`. Graded against the working tree on disk at 2026-08-06, not against the pushed commit alone. `git rev-parse HEAD` and `git rev-parse origin/seo-phase-3-redirects-canonicals` are both `94a8f05`. `git status --short` lists four modified, unstaged files: `BLOCKED.md`, `SEO-CHANGELOG.md`, `web/components/seo.js`, `web/pages/sitemap.xml.js`.

Two files that earlier rounds reported as changed are not changed now. `web/pages/404.js` and `web/next.config.js` both read their `4fbc64f` state on disk. The round-3 findings about a `noindex` override on the 404 template and an absolute `destination: 'https://www.polymer.co/about'` describe edits that were reverted. `SEO-CHANGELOG.md` records both reverts.

---

## 1. Still not done, and why

### The record Jessica reads describes an implementation that is not on disk

`QUESTIONS-FOR-JESSICA.md`, "Phase 3, item 1 — self-referencing canonicals", question 1 states: "`web/components/seo.js` line 13 is now `` let url = `${baseUrl}/${pathname || ""}`; `` — one variable, no second canonical-only value."

On disk, `web/components/seo.js` line 13 is `` let url = pathname ? `${baseUrl}/${pathname}` : baseUrl; // No trailing slash allowed! `` and line 14 is `` let canonicalUrl = pathname ? url : `${baseUrl}/`; ``. There are two variables. The second canonical-only value exists.

Question 4 of the same section states: "The homepage `og:url` moved to the trailing-slash form along with the canonical — confirm you want that." It did not move. Line 77 is `<meta property="og:url" content={seo.url} key="ogurl" />` and `seo.url` on the homepage is `https://www.polymer.co` with no trailing slash. Question 4 also quotes line 58 as `<link rel="canonical" href={seo.url} key="canonical" />`; line 60 on disk reads `href={seo.canonicalUrl}`.

`SEO-CHANGELOG.md` describes the on-disk implementation correctly at lines 736-742 and 845. The two files disagree, and the one Jessica reads is the wrong one.

### Tab 04 rows A7 and A38, and tab 06 row A8 — the values are on disk but not in PR #48

Tab 04 C7 and C38 ask for canonical `https://www.polymer.co/` with the trailing slash. Tab 06 E8 asks for the same value on the partner-parameter URL.

The working tree emits it. `web/components/seo.js` line 14 binds `canonicalUrl`, line 26 puts it on the `seo` object, line 60 emits `href={seo.canonicalUrl}`. `web/pages/index.js` renders no `<SEO>`, so the homepage takes the prop-less `<SEO />` at `web/pages/_app.js` line 93, `pathname` is undefined, and `canonicalUrl` is `` `${baseUrl}/` `` = `https://www.polymer.co/`.

None of it is committed. `HEAD` is `94a8f05` and `git status` lists `web/components/seo.js` as modified and unstaged. PR #48 as pushed carries `href={seo.url}`, which on the homepage is `https://www.polymer.co` with no trailing slash. If the PR merges as it stands, rows A7, A38 and tab 06 A8 ship the no-slash form. `SEO-CHANGELOG.md` line 845 states this itself: "**Uncommitted; not in `4fbc64f` and not in PR #48 as it stands.**"

### Tab 16 row A8 — one apex internal link is still live, in Sanity

Row A8 asks: update internal hrefs pointing at `https://polymer.co/` to the www URL.

Three of four were updated. `web/pages/privacy.js` now holds zero apex `href` values and three `href="https://www.polymer.co/"`. The fourth is not a repo file. Sanity changelog document `_id` `83ff9bc1-0a12-4def-9beb-49f2489abbd6` carries a Portable Text link mark with `"href": "https://polymer.co/"`. Confirmed live against the public CDN today: a GROQ query over every document with a `content` field returns exactly three non-www `polymer.co` hrefs, and that one is the only http(s) apex link — the other two are `mailto:support@polymer.co`.

`web/pages/changelog.js` line 14 queries `*[_type == "changelog"] | order(date desc)` and lines 73-74 render `log.content` through `PortableText`, so that href ships on `https://www.polymer.co/changelog` and takes the 308 hop. The search that drove this item was a repo grep; `SEO-CHANGELOG.md` line 781 records it as covering `web/pages`, `web/components`, `web/lib`, `web/public`. CMS content was never queried.

### Tab 16 row A8 — the visible link text still reads the apex URL

Row A8's Fix column names hrefs. `web/pages/privacy.js` line 44 now renders three anchors as `<a href="https://www.polymer.co/" data-custom-class="link">https://polymer.co/</a>`. Counted on disk: 0 apex hrefs, 3 www hrefs, 3 remaining bare `https://polymer.co/` strings, all of them anchor text. The rendered privacy policy displays a URL that differs from where the link goes. Before this branch the href and the text agreed.

### Tab 16 row A9 — 52 external redirecting URLs, not done

Cell A9 is the literal string `(52 external URLs)` and cell C9 is `various`. No individual URL appears in tab 16, which has 9 rows and no continuation, and no other tab enumerates them. The build directory holds no crawl export — no `.csv` and no `.json` anywhere under it. Nothing in the branch touches this row, and it has no entry in `BLOCKED.md`, so master prompt Phase 7 item 1 will not list it.

Partly identified since: `QUESTIONS-FOR-JESSICA.md` line 210 names eleven live `wrk.xyz` links in Sanity as tab 16 row 9 material, including `13e77379-4459-4ed8-9b5b-e6b9385be30b`, which prints `https://jobs.wrk.xyz/aperturelabs/15394?source=linkedin` as visible body text.

### Tab 06 row A7 — the page restore is not built

Cell E7: "Restore /contact with demo/sales form; until then 301 -> /about or /pricing".

The interim 301 is shipped and committed. `web/next.config.js` lines 19-23 declare `{ source: '/contact', destination: '/about', statusCode: 301 }`. That emits 301 specifically: `web/node_modules/next/dist/lib/load-custom-routes.js` line 60 is `return route.statusCode || (route.permanent ? PERMANENT_REDIRECT_STATUS : TEMPORARY_REDIRECT_STATUS)`, and lines 44-50 put 301 in `allowedStatusCodes`. `permanent: true` would have emitted 308.

`web/pages/contact.js` does not exist. Live check today: `https://www.polymer.co/contact` returns 404, because the branch is unmerged. Recorded in `BLOCKED.md` under "Phase 3 — restore `/contact` as a real page".

### Tab 06 row A9 — the row's premise does not match live behaviour

Cell E9 reads "No action - redirect chain is single-hop and correct", and cell D9 records the current status as "308 -> https://www".

The "no action" instruction is honoured: `redirects()` in `web/next.config.js` holds only the `/climate` and `/contact` entries, there is no apex rule, and the only `vercel.json` in the repo is `studio/vercel.json`, which does not build the marketing site.

The premise is wrong. `curl -sIL http://polymer.co/` today reports 2 redirects: `http://polymer.co/` 308s to `https://polymer.co/`, which 308s to `https://www.polymer.co/`, which returns 200. That is two hops. The 59 backlinks and 445 referring domains on `http://polymer.co/` each traverse both. Collapsing it is a Vercel domain-redirect setting, not a file in this repo.

### Tab 06 row A10 — the content refresh is not done

Cell E10: "Refresh content (see tab 10); do not change URL without 301".

The URL half is done: the slug `use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site` is unchanged, its only repo reference is the `linkTo` value at `web/components/home/integrations.js` line 29 which this branch does not touch, and no entry in `redirects()` or `rewrites()` matches it. The refresh half is deferred to tab 10, which the master prompt assigns to Phase 6. It has no entry in `BLOCKED.md`.

### `/404` emits a canonical, and no tab 04 row covers it

`web/pages/404.js` line 11 passes `pathname="404"`, so the shared component emits `<link rel="canonical" href="https://www.polymer.co/404">` on the template Next serves for every unmatched URL. The response status is 404. Tab 04 lists 41 URLs and none is `/404`. Recorded at `QUESTIONS-FOR-JESSICA.md` question 3 under "Phase 3, item 1".

### The homepage states its own URL two ways

`web/components/seo.js` emits canonical `https://www.polymer.co/` (line 60, from `canonicalUrl`) and `og:url` `https://www.polymer.co` (line 77, from `url`). `web/pages/sitemap.xml.js` line 44 is now `` <loc>${BASE_URL}/${pathname}</loc> `` with no ternary, so the homepage `<loc>` is `https://www.polymer.co/` and matches the canonical. `og:url` is the one left behind. No tab row asks for `og:url` to change; no tab row asks for it to stay. `SEO-CHANGELOG.md` line 742 states the consequence.

### Two `og:image` values were moved from apex to www, which no tab row asks for

`web/pages/plato.js` line 19 and `web/pages/features/jobboard.js` line 27 changed from `image="https://polymer.co/images/..."` to the www host. Neither URL appears in tab 16, tab 04, tab 06, `master-prompt-pages-router.md` or `master-prompt.txt`. Tab 16's Fix column names hrefs; an `og:image` is a meta `content` value. Both are `image` prop values that `web/components/seo.js` forwards to `og:image` and `twitter:image`. These two pages are the only ones in the repo that override the `image` prop. Disclosed in `SEO-CHANGELOG.md` and filed in `QUESTIONS-FOR-JESSICA.md` with an offer to revert; it has no entry in `BLOCKED.md`.

### Blog canonicals and sitemap `<loc>` are built by two different rules

`web/pages/blog/[slug].js` line 283 passes `` pathname={`blog/${post.slug.current}`} `` with the raw Sanity slug. `web/pages/sitemap.xml.js` line 69 emits `` urlEntry(`blog/${encodeURIComponent(post.slug.current)}`, post._updatedAt) ``. A slug containing any character `encodeURIComponent` escapes would make a post's canonical and its `<loc>` disagree. Every slug in the CMS today is plain kebab-case, so no post is currently affected. The unencoded `pathname` is pre-existing; this branch is what makes it feed a canonical rather than only `og:url`.

### Tab 04 row A23 — the sitemap comment that described the exception

`web/pages/industries/applicant-tracking-for-legal-services.js` line 90 now declares the short form, so row A23 is satisfied. The stale comment at `web/pages/sitemap.xml.js` that described the `industries/`-prefixed exception has been rewritten on disk — lines 5-10 now read that both the `pathname` and the sitemap entry use the top-level rewrite source. This one is closed.

---

## 2. Needs Jessica

**1. `/contact` — restore the page, or keep the 301?**
Tab 06 E7 asked to restore `/contact` with a demo/sales form, with a 301 to `/about` or `/pricing` as the interim. The 301 is shipped.
**Question:** Should `/contact` exist as a real page — and if so, what does the form collect and where does it submit?
This is a decision plus new marketing copy. Outside what an agent can write.

**2. `/contact` — `/about` or `/pricing` as the redirect target?**
Tab 06 E7 offers both and does not choose. The config uses `/about`, per the master prompt's redirect map.
**Question:** Should the target be `/pricing` instead, since that is where the enterprise "Contact Us" CTA lives?
A decision. One-word edit either way.

**3. The two "Contact Us" CTAs point at `mailto:`, not `/contact`.**
Tab 06 note F7 says "Footer 'Contact us' and pricing's enterprise 'Contact Us' CTA imply this page should exist". Neither does. `web/components/footer.js` lines 98-103 render `<a className="intercom-launcher" href="mailto:support@polymer.co">Contact us</a>` — and `web/pages/_app.js` sets `custom_launcher_selector: ".intercom-launcher"` in `window.intercomSettings`, so that anchor opens the Intercom messenger and the `mailto` is the no-JS fallback. `web/pages/pricing.js` lines 204-210 render `<Button label="Contact Us" type="outbound" to="mailto:support@polymer.co" />`, which resolves to an `<a href="mailto:...">`.
**Question:** If `/contact` is restored, should those two CTAs be repointed at it?
A decision. Note the footer one currently opens Intercom, so repointing it changes behaviour beyond the URL.

**4. The privacy policy displays the apex URL while linking to www.**
Tab 16 A8 asked to update internal hrefs. The three hrefs were changed; the three visible anchor texts still read `https://polymer.co/`.
**Question:** Should the visible text in `web/pages/privacy.js` be changed to `https://www.polymer.co/` to match its href?
A decision — it is the wording of a legal document, and it is a hand edit inside a 167 KB Termly-generated template literal that a future regeneration would revert.

**5. The two `og:image` URLs moved from apex to www, past what tab 16 asked for.**
No tab row names either URL.
**Question:** Keep the two `og:image` moves in `web/pages/plato.js` and `web/pages/features/jobboard.js`, or revert them?
A decision. If kept, `/plato` and `/features/jobboard` need re-scraping through the Twitter, LinkedIn and Facebook card debuggers after deploy, because those caches hold the apex URLs.

**6. HSTS preload for `polymer.co`.**
Tab 06 note F9: "Verify HSTS preload eventually". Verified and now recorded in `BLOCKED.md`: both hosts answer `strict-transport-security: max-age=63072000` with no `includeSubDomains` and no `preload`, and `hstspreload.org` reports the domain as absent from the list with exactly those two errors.
**Question:** Should `polymer.co` be submitted to the HSTS preload list?
Outside the repo — the header comes from the Vercel domain settings, and `includeSubDomains` would bind `app.polymer.co`, `developer.polymer.co`, `help.polymer.co` and `jobs.polymer.co` to HTTPS.

**7. The apex redirect chain is two hops, not the one tab 06 A9 assumes.**
`http://polymer.co/` → 308 → `https://polymer.co/` → 308 → `https://www.polymer.co/`. 59 backlinks and 445 referring domains traverse both.
**Question:** Should the Vercel domain configuration be changed to send `http://polymer.co/` straight to `https://www.polymer.co/` in one hop?
Outside the repo — a Vercel domain-redirect setting.

**8. Sitemap submission in Search Console.**
Tab 02 row 9. The sitemap ships; the submission does not.
**Question:** Do you want to submit `https://www.polymer.co/sitemap.xml` yourself once this deploys, or grant Search Console access to the `www.polymer.co` property?
A credential.

**9. `robots.txt` on the apex host.**
Tab 03 row 10 asks it to resolve pre-redirect. `https://polymer.co/robots.txt` currently 308s, and that fires at the platform edge before Next sees the request.
**Question:** Should `polymer.co/robots.txt` answer 200 instead of 308?
Outside the repo — a Vercel domain-configuration change.

**10. The ten orphaned blog posts.**
Tab 01 rows 7-16. The linking half shipped in Phase 1; eight of the ten Recommended actions ask for a content refresh and four name specific new content.
**Question:** Is the content refresh part of this engagement, or separate work?
Editorial judgment about your own published content.

**11. Tab 16 row A9 and the eleven `wrk.xyz` links.**
Row A9 is an aggregate with no URL list, and the crawl export is not in the build directory. Eleven concrete `wrk.xyz` links in Sanity have been identified since, all alive via redirect.
**Question:** Do you want the eleven `wrk.xyz` links repointed at their final destinations now, or left for the opportunistic pass the row describes?
A decision. The remaining 52-URL list needs the SE Ranking crawl export, which no agent has.

**12. `/404` emits a canonical to itself.**
Tab 04 has no row for `/404`. `web/pages/404.js` line 11 passes `pathname="404"`, so every unmatched URL returns a 404 response carrying `<link rel="canonical" href="https://www.polymer.co/404">`.
**Question:** Do you want that canonical suppressed on the 404 template?
A decision. An earlier fix agent implemented a suppression and it has since been reverted; nothing is on disk now.

---

## 3. Fixed during review

- **Tab 04 A7** — canonical `https://www.polymer.co` → `https://www.polymer.co/`, via a new `canonicalUrl` binding at `web/components/seo.js` line 14. Uncommitted.
- **Tab 04 A38** — same code path, same before → after. Uncommitted.
- **Tab 06 A8** — canonical on `/?partner_source=whatjobs`: `https://www.polymer.co` → `https://www.polymer.co/`. Uncommitted.
- **Tab 04 A23** — `web/pages/industries/applicant-tracking-for-legal-services.js` line 90: `pathname="industries/applicant-tracking-for-legal-services"` → `pathname="applicant-tracking-for-legal-services"`. Committed in `4fbc64f`.
- **Tab 04 A23 side effect** — `web/pages/sitemap.xml.js` lines 5-10: the comment asserting that legal-services' `og:url` does not match its `<loc>` → rewritten to describe the current state. Uncommitted.
- **Tab 04 A7 side effect** — `web/pages/sitemap.xml.js` line 44 `urlEntry`: `` ${pathname ? `${BASE_URL}/${pathname}` : BASE_URL} `` → `` ${BASE_URL}/${pathname} ``, so the homepage `<loc>` is `https://www.polymer.co/` and matches the canonical. Uncommitted.
- **Tab 06 F9** — HSTS preload: recorded nowhere → a full `BLOCKED.md` entry with the live header values and the `hstspreload.org` API results. Uncommitted.
- **Master prompt rule 3 routing** — three Phase 1 / Phase 2 items filed only in `QUESTIONS-FOR-JESSICA.md` (a hub scratchpad outside the repo) → added to `BLOCKED.md`, which Phase 7 compiles from. Uncommitted.
- **`SEO-CHANGELOG.md`** — the Phase 3 section's stale claims (row A7 "actioned with a differing value", "the canonical cannot drift from `og:url`", the uncommitted-file list) → amended in place, including an explicit record of the two reverted edits to `web/next.config.js` and `web/pages/404.js`. Uncommitted.
- **`web/next.config.js`** — `destination: 'https://www.polymer.co/about'` (a round-2 fix that made `/contact` leave localhost and Vercel previews for production) → reverted to `destination: '/about'`.
- **`web/pages/404.js`** — a `<Head>` override with `<meta name="robots" content="noindex" key="canonical" />` (a round-2 fix that suppressed the canonical by colliding on the React key) → reverted. The file is unmodified from `4fbc64f`.

---

**Rounds run:** 3. Not converged — round 3 changed the tree, and the tree changed again after round 3.

**Reviewers:** every angle returned in every round. Six angles per round (tab-04, tab-06, tab-16, code-correctness, conventions, deferrals), 18 returns, no dead agents.

**Severity remaining:** HIGH. Two HIGH items are open — the apex `href` in Sanity changelog document `83ff9bc1-0a12-4def-9beb-49f2489abbd6`, live on `/changelog` today; and the tab 04 A7 / A38 / tab 06 A8 canonical fix existing only in the uncommitted working tree, so PR #48 as pushed does not carry it. Below that: MED on the `QUESTIONS-FOR-JESSICA.md` description of an implementation not on disk, on the `/contact` page restore, and on tab 16 row A9 having no `BLOCKED.md` entry. The rest is LOW.

**Workbook check:** the orchestrator's transcription of tabs 04, 06 and 16 is accurate. Verified with `read-workbook.py`: tab 04 has 47 rows and 41 data rows A7:A47, C7 and C38 both carry the trailing slash, D38 is verbatim, D7:D37 all read "Self-referencing canonical via Next.js metadata"; tab 06 has 4 data rows A7:A10, all cells verbatim; tab 16 has 3 data rows A7:A9 plus note A4, all verbatim. One point worth naming, in the workbook rather than the brief: note D39 reads "Also canonicalize the 10 orphaned posts when re-linked" but spans nine rows, A39:A47. The tenth orphan, `https://www.polymer.co/blog/first-impression-bias` (tab 01 row A15), has its canonical row at tab 04 A29 inside the crawled block. All ten are covered either way, because `web/pages/blog/[slug].js` line 283 builds the `pathname` from `post.slug.current` for every post.
