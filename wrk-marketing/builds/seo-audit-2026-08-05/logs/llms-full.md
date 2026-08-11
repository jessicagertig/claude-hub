# llms-full.txt build log

Output: `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/public/llms-full.txt`
Branch: `seo-phase-1-2-deorphan-crawl` (not committed, not pushed)
Size: 287 lines, 63.8 KB, 37 page headings
Companion file: `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/public/llms.txt` (read first, conventions matched)

## Conventions carried over from llms.txt

- `# Polymer` H1, `>` blockquote product summary (byte-identical to llms.txt line 3)
- `## Section` H2 groupings, `[Title](url)` markdown link format
- Same section names where they exist: Products, Pricing, Docs & API, Guides
- Added sections: Industries, Company (pages llms.txt does not index but which were in scope)
- Per-page format: `### [Title](canonical www URL)` then the extended summary, so a lookup is one heading away
- Annual price leads, monthly follows, matching llms.txt lines 17-19 and `pages/pricing.js:17` (`isAnnual` defaults to true)
- Curly apostrophe kept in "What’s the Difference?" to match llms.txt line 40 exactly

## Structure

| Section | Pages |
|---|---|
| Products | `/`, `/features`, `/features/jobboard`, `/features/candidate-management-software`, `/plato` |
| Pricing | `/pricing` |
| Industries | the seven vertical pages |
| Company | `/about`, `/terms`, `/privacy` |
| Docs & API | developer.polymer.co, help.polymer.co + its seven collections, `/changelog` |
| Guides | `/blog` + the ten guides llms.txt already names |

## URL verification

Every URL in the file was curled this session. All 200.

Marketing pages (200, no redirect):
`https://www.polymer.co/`, `/features`, `/features/jobboard`, `/features/candidate-management-software`, `/plato`, `/pricing`, `/about`, `/terms`, `/privacy`, `/blog`, `/changelog`, `/applicant-tracking-for-startups`, `/applicant-tracking-for-fintech-companies`, `/applicant-tracking-for-cryptocurrency-companies`, `/applicant-tracking-for-greentech-companies`, `/applicant-tracking-for-healthcare-companies`, `/applicant-tracking-for-legal-services`, `/applicant-tracking-for-real-estate-companies`

Blog guides (200): `/blog/problem-solving-interview-questions`, `/blog/behavioral-interview-scoring-matrix`, `/blog/employee-turnover`, `/blog/interview-feedback-examples`, `/blog/job-rejection-email`, `/blog/a-player`, `/blog/agile-recruiting-process`, `/blog/talent-acquisition-vs-recruitment`, `/blog/first-impression-bias`, `/blog/best-job-board-software`

Off-site (200): `https://app.polymer.co/auth-register`, `https://developer.polymer.co`, `https://help.polymer.co/`, and all seven help collections (`2544541-quick-start-guide`, `2625932-job-board-configuration`, `2547724-team-management`, `2598915-job-management`, `2547812-candidate-management`, `2542626-integrations`, `2896742-subscription-management`)

Changelog anchor: `curl https://www.polymer.co/changelog | grep 'id="2026-01-31"'` returned a match, so the `#YYYY-MM-DD` anchor form in the file is real.

Verified 404 and therefore NOT listed: `https://www.polymer.co/faq`, `https://www.polymer.co/blog/page/2`, `https://www.polymer.co/llms.txt`, `https://www.polymer.co/robots.txt`. The last two are 404 only because the branch is not deployed yet; the file therefore refers to "llms.txt" by name with no URL.

## Sources per page

### `/` (homepage)
`pages/index.js:1-25` (section order); `pages/_app.js:93` + `components/seo.js:19,23` (title and default meta description); `components/home/intro.js:23,25-27,33-34`; `components/home/brands.js:18-26,32`; `components/home/toolkit.js:12-15,19-22,26-29,38`; `components/home/features.js:12,21,24-30,35,44,49,58`; `components/home/tailor.js:14-16,20-22,31,34`; `components/home/integrations.js:27,39,51,63,75,86,98,110,122,130,132`; `components/start.js:14,16`

### `/features`
`pages/features.js:19-21,27,34-39,42-116,124,134-210,218,225-230,233-306,314,323-396,407-408,426`; `components/start.js:14-16`

### `/features/jobboard`
`pages/features/jobboard.js:24-25,44`; `components/jobBoard/intro.js:19,21-22,28-29`; `components/jobBoard/basics.js:17-19,26-28,35-38,49`; `components/jobBoard/features.js:12-16,20-23,27-31`; `components/jobBoard/other.js:13-69,77,80`; `components/start.js:14-16`

### `/features/candidate-management-software`
`pages/features/candidate-management-software.js:13-14,21`; `components/candidateManagement/intro.js:19,21-22,28-30`; `components/candidateManagement/basics.js:12-14,18-20,24-26,35`; `components/candidateManagement/features.js:13-16,23-30,33-40`; `components/candidateManagement/other.js:13-48,57,60`; `components/start.js:14-16`

### `/plato`
`pages/plato.js:16-18,20`; `components/plato/platoHero.js:98,100`; `components/plato/platoDescription.js:28-29,36-37`; `components/plato/platoFeatures.js:13,17,22,26,31,39,47`; `components/plato/platoFilter.js:53,55,59`; `components/plato/fitStars.js:23-29`; `components/plato/platoPrivacy.js:33,35-36`; `pages/pricing.js:93,133,172` (credit allowances)

### `/pricing`
`pages/pricing.js:17` (isAnnual default true), `:20-23`, `:26` (annual 124/233/415), `:27` (monthly 149/279/499), `:38`, `:62`, `:72,79-80,85,89,93,97`, `:110,112,119,125,129,133,137`, `:151,158,164,168,172,176`, `:101,105`, `:194`, `:202-203`, `:205,209`, `:217,219`, `:229-239`, `:246-256`, `:263-273`, `:280-290`, `:357-360`; `components/start.js:14-16`

### Industry pages
Each page's `verticalData` object: `pages/industries/<slug>.js:19-22` (title, hero), `:24-49` (challenges), `:51-57` (benefits), `:59-75` (features), `:77-82` (integrations), `:103-104,111-112,117` (section headings). Bare top-level URL form confirmed from `next.config.js` rewrites, `pages/sitemap.xml.js:13-32` and `components/footer.js:117-147`. Startups closing copy from `pages/industries/applicant-tracking-for-startups.js:125`.

### `/about`
`pages/about.js:15-18,22-27,29,32-58,62-63,72-73,83`; `components/start.js:14-17`; entity and address from `pages/terms.js:279-286`

### `/terms`
`pages/terms.js:8-13,16-20,30-45,54-72,74-89,101-122,124-151,153-175,178-196,198-237,239-254,256-264,266-276,278-288`

### `/privacy`
`pages/privacy.js:44` (whole policy is one template literal on this line; sections 1 through 14 read within it), `:59-64` (SEO), `:61` (meta description)

### Help centre
Collection pages and every article beneath them, all fetched and 200. Named articles: `4436511`, `4436525`, `4440860`, `6753174`, `4440453`, `4442191`, `4450433` (quick start); `10250419`, `5018719` (job board configuration); `4442110`, `4442398`, `4442458` (team management); `4568585`, `5013806`, `10122505`, `4547329`, `4547829` (job management); `4442592`, `4475485`, `5506525`, `8910345`, `4568425`, `4464155`, `8793293`, `6122360`, `6126305` (candidate management); `5721143`, `5721747`, `4428576`, `4436181`, `4428575`, `6218084`, `8828635`, `15293740`, `9415910` (integrations); `5729632`, `5144729` (subscription management)

### `/changelog`
`pages/changelog.js:14,48-52,56-61,64-80` (single page, `order(date desc)`, no slice, `<a href={"#"+log.date} id={log.date}>`)

### `/blog` and the ten guides
`pages/blog.js:12`; `components/blogIndex.js:33-37,79`; `pages/blog/[slug].js:290,326`; per-post `editorialTitle` and `metaDescription` from Sanity project `a6d1clb1`, dataset `production`, `_type == "blogPost"`

## Excluded, and why

Everything below was available but is not in the file.

**Contradicts pricing.js, so unusable as fact**
- "Pay only for active jobs" (`pages/features/jobboard.js:25` meta description). Contradicts the per-plan published-job caps in llms.txt lines 17-19.
- "Collaborate with unlimited team members at no extra cost" and its five variants (`pages/industries/*.js:54` or `:55`). Contradicts the 5/20/50 user caps in `pages/pricing.js`. All seven industry entries were written without any unlimited-seats claim.
- The help centre's "per job pricing model" (`help.polymer.co` articles `5729632`, `4442191`) and "hidden jobs continue to incur billing charges" (`4547329`). The Help Center entry names the discrepancy and points at `/pricing` as the source of truth rather than repeating either claim.

**Unverifiable social proof**
- "Join thousands of startups using Polymer", "Join leading fintech companies...", "Join innovative cryptocurrency companies...", "Join innovative greentech companies...", "Join healthcare organizations...", "Join law firms and legal departments...", "Join successful real estate companies..." (`pages/industries/*.js:125`).

**Not rendered on the live page**
- `components/home/build.js` ("Build before you buy") and `components/home/ready.js` ("Get to hiring in minutes", the four-step sequence, the Matthew Bellows testimonial). Neither is imported by `pages/index.js`.
- `partnerBrand.js` / `partnerSetup.js`, gated behind `process.env.NEXT_PUBLIC_REFERRER_SOURCE`.
- The commented-out "Application forms that fit your needs" block at `components/jobBoard/features.js:36-45`.
- The `/features#teamcollaboration` anchor. `pages/features.js` has no element with that id, so it is not described as a working deep link.

**Counts that go stale**
- Blog post count (26), blog date range, page count. `/blog` is described structurally instead.
- Changelog entry count (85), end date, and the ten most recent entry headings. The anchor mechanism is kept because it does not drift.
- Help centre article counts (37 total). Collections are described, articles are not counted.
- Default hiring stage count. Two help articles disagree (six vs seven) over the same list, so the stages are named and no count is asserted.
- User role count. The roles article opens "three different user roles" then documents four, so the four roles are named and no count is asserted.

**Claims no Polymer surface makes**
- Plato: any accuracy or bias figure, the model or vendor, any data retention or training policy, any EEOC/GDPR/compliance claim, any SLA, any claim Plato rejects or decides. Also the mock fixture names and scores in the page's product mockups.
- Plato "Now in beta": that string exists only inside `images/plato-video-still.png`, not in any HTML copy. Left out. See question 2 below.
- Pricing: currency code, tax, how annual billing is charged, refund/cancellation/proration, what happens when Plato credits run out, whether the job cap is concurrent.
- Healthcare: HIPAA, SOC 2 or any certification. The entry says explicitly that the page describes credentialing and compliance documentation and claims no certification.
- Real estate: an MLS integration. The page offers it only as an example of what the API could be built against, so the entry says "industry-specific platforms".
- About: "North Carolina" (the page says only "Charlotte"), founding year, team size, funding.
- Privacy: a Cookie Notice URL (named in the policy but no such page exists), a data subject request form URL, any compliance certification, named subprocessors beyond Stripe.
- Terms: any price (the terms name none), any named security certification, any uptime or SLA, a DPA, a concrete retention period, integrations beyond the five it lists literally.
- Candidate management page: any Plato claim, bulk CSV import (that is a `/features` claim), and "template-based" automation wording (that is `/features` wording, not this page's).

**Deployment-gated**
- `/blog/page/2` through `/blog/page/6`. The pagination exists on this branch only; all six return 404 live today and `/blog` still renders "Load more". No pagination URL is listed. When the branch deploys, a sentence naming `/blog` as page one and `/blog/page/2` through `/blog/page/6` can be appended, sourced to `lib/blog.js:13,22` and `next.config.js:23-32`.

**Judgement calls**
- `/faq` was in the instruction's page list but returns 404 on both hosts, has no `faq.js`, and returns zero matches across the repo. Nothing was invented for it and it does not appear in the file.
- Blog posts not already in llms.txt were left out. The instruction says llms-full.txt "covers the same pages in depth", and keeping the two files on the same ten guides means one edit keeps both in sync. Candidates for a later addition, all verified 200 and evergreen: `skills-mapping-for-hiring-a-complete-guide`, `employer-branding-steps`, `onboarding`, `talent-acquisition`, `hiring-gen-z`.
- `best-applicant-tracking-software` was deliberately not added. It is a competitor roundup, and naming it invites an assistant to surface rival ATS products when asked about Polymer. (`best-job-board-software` is already in llms.txt and was kept for parity with it.)
- `one-click-distribution-to-we-work-remotelys-community-of-job-seekers` (2.5M) excluded because it contradicts the 2025 post's 6M for the same integration. `hello-polymer` excluded because it would reintroduce the retired Wrk name. `use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site` excluded because its slug carries the retired brand. `utc-is-the-timezone-of-the-future` excluded as off-subject.
- `careers.curious.vc` (the live job board example on `/features/jobboard`) and `climate.stripe.com/Cg9EBK` were not listed. Both are third-party URLs that add nothing an assistant needs and can rot independently of Polymer.

## Style rules applied

- No em-dashes anywhere. Verified with grep. Three source strings carrying em-dashes were re-voiced rather than quoted: `components/jobBoard/intro.js:21-22`, `components/plato/platoDescription.js:28-29`, `components/plato/platoFeatures.js:17`, and `pages/pricing.js:219` ("complete feature set—no limitations, no compromises" became "the complete feature set, with no limitations and no compromises").
- No URL is immediately followed by a period.
- Only one non-ASCII character in the file, the curly apostrophe matching llms.txt.
- CO2 written as "CO2" rather than the subscript character used in `pages/pricing.js:359`, to keep the file plain ASCII.
